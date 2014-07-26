!> @file
!! module implementing the freezing string technique
!!     
!! @author Bastian Schaefer
!! @section LICENCE
!!    Copyright (C) 2014 UNIBAS
!!    This file is not freely distributed.
!!    A licence is necessary from UNIBAS
module module_freezingstring
    implicit none
    
    contains
!TODO: create function "get_input_guess" which returns
!an inpute guess for a ts (consisting of corrds. and minmode dir.)
!this method simply calls grow_string
!and then uses cubic splines to find the tangent at the highest energy node
!=====================================================================
subroutine grow_string(nat,alat,gammainv,perpnrmtol,trust,&
                       nstepsmax,nstringmax,nstring,string,energies)
    use module_base
    use yaml_output
    use module_global_variables, only: iproc
    implicit none
    !parameters
    integer, intent(in) :: nat
    integer, intent(in) :: nstepsmax
    integer, intent(inout) :: nstringmax
    integer, intent(inout) :: nstring
    real(gp) , intent(in) :: step
    real(gp) , intent(in) :: gammainv
    real(gp) , intent(in) :: perpnrmtol
    real(gp) , intent(in) :: trust
    real(gp) , intent(in) :: alat(3)
    real(gp), allocatable, intent(inout) :: string(:,:,:)
    real(gp), allocatable, intent(inout) :: energies(:,:)
                         !energies(1,1) and energies(2,1)
                         !are not computed inside this routine.
                         !if needed, they mus be computed outside
    !constants
    character(len=10), parameter :: method = 'linlst'
    !internal
    integer :: i,j,k,istart
    integer, parameter :: resize=10
    real(gp), allocatable :: stringTMP(:,:,:)
    real(gp) :: tangentleft(3*nat)
    real(gp) :: tangentright(3*nat)
    real(gp) :: step
    real(gp) :: perpnrmtol_squared
    real(gp) :: trust_squared
    integer :: finished=2 !if finished ==2: not finished
                          !if finished ==0: finished
                          !if finished ==1: one more node
                          !                 in the middle
    integer :: nresizes

    if((.not. allocated(string)) .or. .not. allocated(energies))then
        if(iproc==0)call yaml_warning('(MHGPS) STOP, string or&
                    energies in grow_string not allocated')
        stop
    endif
    perpnrmtol_squared=perpnrmtol**2
    trust_squared=trust**2

    nstring=1
    step=-1._gp
    nresizes=0
    do!maximum 100 resizes of string array
        istart=nstring
        do i=istart,nstringmax-1
            call interpol(method,nat,string(1,1,nstring),&
                 string(1,2,nstring),step,string(1,1,nstring+1),&
                 string(1,2,nstring+1),tangentleft,tangentright,&
                 finished)

            if(finished==0)then!interpolation done
                return
            endif

            call optim_cg(nat,alat,step,gammainv,&
                 perpnrmtol_squared,trust_squared,nstepsmax,&
                 tangentleft,tangentright,string(1,1,i+1),&
                 string(1,2,i+1),epotleft,epotright)
            nstring=nstring+1
        enddo
        nresizes=nresizes+1
        if(nresizes>100)then
            if(iproc==0)call yaml_warning('(MHGPS) STOP, too&
                        many resizes in grow_string')
            stop
        endif
        if(allocated(stringTmp))then
            deallocate(stringTmp)
        endif
        allocate(stringTmp(3*nat,2,nstringmax))
        stringTmp=string
        deallocate(string)
        nstringmax=nstringmax+resize
        allocate(string(3*nat,2,nstringmax))
        do k=1,(nstringmax-resize)
            string(:,:,k)=stringTmp(:,:,k)
        enddo
        deallocate(stringTmp)
    enddo

end subroutine
!=====================================================================
subroutine optim_cg(nat,alat,step,gammainv,perpnrmtol_squared,&
           trust_squared,nstepsmax,tangent1,tangent2,&
           rxyz1,rxyz2,epot1,epot2)
    use module_base
    use module_energyandofrces
    implicit none
    !parameters
    integer, intent(in)  :: nat
    integer, intent(in)  :: nstepsmax
    real(gp), intent(in) :: tangent1(3*nat)
    real(gp), intent(in) :: tangent2(3*nat)
    real(gp), intent(in) :: step
    real(gp), intent(in) :: gammainv
    real(gp), intent(in) :: perpnrmtol_squared
    real(gp), intent(in) :: trust_squared
    real(gp), intent(in) :: trust_squared
    real(gp), intent(in) :: alat(3)
    real(gp), intent(inout) :: rxyz2(3*nat)
    real(gp), intent(inout) :: rxyz1(3*nat)
    real(gp), intent(out) :: epot1
    real(gp), intent(out) :: epot2
    !internal
    real(gp) :: d0 !inital distance between the new nodes
    real(gp) :: fxyz1(3*nat),fxyz2(3*nat)
    real(gp) :: perp1(3*nat),perp2(3*nat)
    real(gp) :: dmax,dist,dir(3*nat)
    real(gp) :: dispPrev1(3*nat),disp1(3*nat)
    real(gp) :: dispPrev2(3*nat),disp2(3*nat)
    real(gp) :: alpha1,alpha2
    real(gp) :: perpnrmPrev1_squared, perpnrm1_squared
    real(gp) :: perpnrmPrev2_squared, perpnrm2_squared
    real(gp) :: dispnrm_squared
    integer :: istep
    real(gp) :: fnoise
    !functionals
    real(gp) :: dnrm2

    d0=dnrm2(3*nat,dir(1),1)
    dmax=d0+0.5_gp*step

    call energyandforces(nat,alat,rxyz1,fxyz1,fnoise,epot1)
    call energyandforces(nat,alat,rxyz2,fxyz2,fnoise,epot2)

    !first steps: steepest descent
    !left
    call perpend(nat,tangent1,fxyz1,perp1)
    perpnrmPrev1_squared = ddot(3*nat,perp1(1),1,perp1(1),1)
    perpnrm1_squared=perpnrmPrev1_squared
    dispPrev1=gammainv*perp1
    dispnrm_squared=maxval(dispPrev1**2)
    if(dispnrm_squared > trust_squared)then
        dispPrev1=dispPrev1*sqrt(trust_squared/dispnrm_squared)
    endif
    rxyz1=rxyz1+dispPrev1
    !right
    call perpend(nat,tangent2,fxyz2,perp2)
    perpnrmPrev2_squared = ddot(3*nat,perp2(1),1,perp2(1),1)
    perpnrm2_squared=perpnrmPrev2_squared
    dispPrev2=gammainv*perp2
    dispnrm_squared=maxval(dispPrev2**2)
    if(dispnrm_squared > trust_squared)then
        dispPrev2=dispPrev2*sqrt(trust_squared/dispnrm_squared)
    endif
    rxyz2=rxyz2+dispPrev2

    dir=rxyz2-rxyz1
    dist=dnrm2(3*nat,dir(1),1)
    if(dist>dmax)then
        return
    endif

!    call energyandforces(nat,alat,rxyz1,fxyz1,fnoise,epot1)
!    call energyandforces(nat,alat,rxyz2,fxyz2,fnoise,epot2)

    !other steps: cg
    do istep=2,nstepsmax

        call energyandforces(nat,alat,rxyz1,fxyz1,fnoise,epot1)
        call energyandforces(nat,alat,rxyz2,fxyz2,fnoise,epot2)

        !move left node
        call perpend(nat,tangent1,fxyz1,perp1)
        perpnrm1_squared = ddot(3*nat,perp1(1),1,perp1(1),1)
        if(perpnrm1_squared>perpnrmPrev1_squared)then
            alpha1=1._gp
        else
            alpha1 = perpnrm1_squared / perpnrmPrev1_squared
        endif
        disp1=gammainv*perp1+ alpha1 * dispPrev1
        dispnrm_squared=maxval(disp1**2)
        if(dispnrm_squared > trust_squared)then
             disp1=disp1*sqrt(trust_squared/dispnrm_squared)
        endif
        rxyz1=rxyz1+disp1
        dispPrev1=disp1
        perpnrmPrev1_squared=perpnrm1_squared
    
        !move right node
        call perpend(nat,tangent2,fxyz2,perp2)
        perpnrm2_squared = ddot(3*nat,perp2(1),1,perp2(1),1)
        if(perpnrm2_squared>perpnrmPrev2_squared)then
            alpha2=1._gp
        else
            alpha2 = perpnrm2_squared / perpnrmPrev2_squared
        endif
        disp2=gammainv*perp2+ alpha2 * dispPrev2
        dispnrm_squared=maxval(disp2**2)
        if(dispnrm_squared > trust_squared)then
             disp2=disp2*sqrt(trust_squared/dispnrm_squared)
        endif
        rxyz2=rxyz2+disp2
        dispPrev2=disp2
        perpnrmPrev2_squared=perpnrm2_squared
    
        dir=rxyz2-rxyz1
        dist=dnrm2(3*nat,dir(1),1)
        if(dist>dmax.or. (perpnrm1_squared<perpnrmtol_squared&
        !if((perpnrm1_squared<perpnrmtol_squared &
           &.and. perpnrm2_squared<perpnrmtol_squared))then
            if(dist>dmax)then
                 write(200,*)'exit due to dmax'   
            endif
            !we do not compute and do not return energies and
            !forces of the latest rxyz2 and rxyz2. If needed,
            !the must be computed outside.
            return
        endif

    enddo
end subroutine
!=====================================================================
subroutine perpend(nat,tangent,fxyz,perp)
    use module_base
    !returns a vector perp that contains
    !the perpendicular components of fyxz to
    !the tangent vector
    !that is: all components of fxyz in direction
    !of tangent are substracted from xyz
    implicit none
    !parameters
    integer, intent(in) :: nat
    real(gp), intent(in) :: tangent(3*nat),fxyz(3*nat)
    real(gp), intent(out) :: perp(3*nat)

    perp = fxyz - dot_product(tangent,fxyz)*tangent
    
end subroutine
!=====================================================================
subroutine lin_interpol(nat,left, right, step,interleft,interright,&
                       tangent, finished)
    use module_base
    implicit none
    !parameters
    integer, intent(in)    :: nat
    real(gp), intent(in)   :: left(3*nat)
    real(gp), intent(in)   :: right(3*nat)
    real(gp), intent(inout):: step
    real(gp), intent(out)  :: interleft(3*nat)
    real(gp), intent(out)  :: interright(3*nat)
    real(gp), intent(out)  :: tangent(3*nat)
    integer, intent(out)   :: finished
    !constants
    real(gp), parameter :: stepfrct=0.1_gp! freezing string step size
    !internal
    real(gp) :: arcl
    !functions
    real(gp) :: dnrm2

    !tangent points from left to right:    
    tangent = right-left
    arcl = dnrm2(3*nat,tangent(1),1)
    tangent = tangent / arcl
    
    if(step<0._gp)step=stepfrct * arcl

    if(arcl < step)then
        finished=0
    else if(arcl < 2._gp*step)then!only one more point
        interleft  = left + 0.5_gp * arcl * tangent
        finished = 1
    else
        interleft  = left + step * tangent
        interright = right - step * tangent
        finished = 2
    endif
end subroutine
!=====================================================================
subroutine lst_interpol(nat,left,right,step,interleft,interright,&
                        tangentleft,tangentright,finished)
    !Given two distinct structures, lst_interpol interpolates
    !inwards (that is in a direction connecting both strucutres)
    !using the linear synchronous transit (LST) technique.
    !A high density path made from 'nimages' nodes using LST
    !is generated. Then this path is parametrized as a function
    !of its integrated path length using natural cubic splines.
    !In order to avoid uncontinous changes of the tangent direction,
    !a second spline parametrization is done by using
    !nimagesC<<nimages equally spaced nodes from the first spline
    !parameterization. Tangent directions are taken from this 
    !second spline.
    !
    !on return:
    !if finished =2: interleft and intergiht contain the new nodes
    !if finished =1 0: left and right are too close, only one new node
    !                 is returned in interleft.
    !                 interright is meaningless in this case.
    !if finished = 0: left and right are closer than 'step'
    !                 => freezing string search finsihed
    !                 nothing is returned, interleft and interright
    !                 are meaningless
    use module_base
    use module_interpol
    implicit none
    !parameters
    integer, intent(in)      :: nat
    real(gp), intent(in)     :: left(3,nat)
    real(gp), intent(in)     :: right(3,nat)
    real(gp), intent(inout)  :: step
    real(gp), intent(out)    :: interleft(3,nat)
    real(gp), intent(out)    :: interright(3,nat)
    real(gp), intent(out)    :: tangentleft(3,nat)
    real(gp), intent(out)    :: tangentright(3,nat)
    integer, intent(out)     :: finished
    !constants
    integer, parameter  :: nimages=200 
    integer, parameter  :: nimagesC=5 !setting nimagesC=nimages
                                      !should give similar implementation
                                      !to the freezing string publication
    real(gp), parameter :: stepfrct=0.1_gp! freezing string step size
    !internal
    integer  :: i
    integer  :: j
    integer  :: tnat
    integer  :: iat
    integer  :: nimagestang
    real(gp) :: lstpath(3,nat,nimages)
    real(gp) :: lstpathRM(nimages,3,nat)
    real(gp) :: lstpathCRM(nimagesC,3,nat)
    real(gp) :: arc(nimages)
    real(gp) :: arcl
    real(gp) :: arcC(nimagesC)
    real(gp) :: arclC
    real(gp) :: diff(3,nat)
    real(gp) :: nimo
    real(gp) :: yp1=huge(1._gp), ypn=huge(1._gp)!natural splines
    real(gp) :: y2vec(nimages,3,nat)
    real(gp) :: y2vecC(nimagesC,3,nat)
    real(gp) :: tau
    real(gp) :: rdmy
    real(gp) :: lambda
    !functions
    real(gp) :: dnrm2

!<-DEBUG START------------------------------------------------------>
!character(len=5) :: fc5
!character(len=200) :: filename,line
!integer :: istat
!integer, save :: ic
!real(gp) :: dmy
!character(len=5):: xat(22)
!open(unit=33,file='input001/pos001.ascii')
!read(33,*)
!read(33,*)
!read(33,*)
!read(33,*)
!do iat=1,22
!    read(33,'(a)',iostat=istat)line
!    if(istat/=0)exit
!    read(line,*)dmy,dmy,dmy,xat(iat)
!enddo
!close(33)
!<-DEBUG END-------------------------------------------------------->

    tnat=3*nat

    !create high density lst path
    nimo=1._gp/real(nimages-1,gp)
    do i=1,nimages
        lambda  = real(i-1,gp)*nimo
        call lstpthpnt(nat,left,right,lambda,lstpath(1,1,i))
    enddo

    !measure arc length 
    arc(1)=0._gp
    do i=2,nimages
        diff = lstpath(:,:,i) - lstpath(:,:,i-1)
        arc(i)  = arc(i-1) + dnrm2(tnat,diff(1,1),1)
    enddo
    arcl=arc(nimages)

    if(step<0._gp)step=stepfrct*arcl

    if(arcl < step)then
        finished=0
        return
    endif

    !rewrite lstpath to row major ordering
    !(for faster access in spline routines)
    do iat=1,nat
        do i=1,nimages
            lstpathRM(i,1,iat)=lstpath(1,iat,i)
            lstpathRM(i,2,iat)=lstpath(2,iat,i)
            lstpathRM(i,3,iat)=lstpath(3,iat,i)
        enddo
    enddo

    !compute the spline parameters (y2vec)
    !parametrize curve as a function of the
    !integrated arc length
    do i=1,nat
        call spline_wrapper(arc,lstpathRM(1,1,i),nimages,&
                           yp1,ypn,y2vec(1,1,i))
        call spline_wrapper(arc,lstpathRM(1,2,i),nimages,&
                           yp1,ypn,y2vec(1,2,i))
        call spline_wrapper(arc,lstpathRM(1,3,i),nimages,&
                           yp1,ypn,y2vec(1,3,i))
    enddo

    !generate nodes at which tangents are computed
    nimagestang=min(nimagesC,nimages)
    nimo=1._gp/real(nimagestang-1,gp)
    do j=1,nimagestang
        tau  = arcl*real(j-1,gp)*nimo
        arcC(j)=tau
        do i=1,nat
            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
                 nimages,tau,lstpathCRM(j,1,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
                 nimages,tau,lstpathCRM(j,2,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
                 nimages,tau,lstpathCRM(j,3,i),rdmy)
        enddo
    enddo
   
    !generate spline parameters for splines used for tangents
    do i=1,nat
        call spline_wrapper(arcC,lstpathCRM(1,1,i),nimagestang,&
                           yp1,ypn,y2vecC(1,1,i))
        call spline_wrapper(arcC,lstpathCRM(1,2,i),nimagestang,&
                           yp1,ypn,y2vecC(1,2,i))
        call spline_wrapper(arcC,lstpathCRM(1,3,i),nimagestang,&
                           yp1,ypn,y2vecC(1,3,i))
    enddo

!<-DEBUG START------------------------------------------------------>
!!check interpolated path
!do j=1,200
!tau  = arcl*real(j-1,gp)/real(200-1,gp)
!!tau  = arc(j)
!        do i=1,nat
!            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
!                 nimages,tau,interleft(1,i),rdmy)
!            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
!                 nimages,tau,interleft(2,i),rdmy)
!            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
!                 nimages,tau,interleft(3,i),rdmy)
!        enddo
!        do i=1,nat
!            call splint_wrapper(arcC,lstpathCRM(1,1,i),y2vecC(1,1,i),&
!                 nimagestang,tau,rdmy,tangentleft(1,i))
!write(*,*)rdmy-interleft(1,i)
!!write(*,*)y2vecC(:,1,i)-y2vec(:,1,i)
!!write(*,*)lstpathCRM(:,1,i)-lstpathRM(:,1,i)
!            call splint_wrapper(arcC,lstpathCRM(1,2,i),y2vecC(1,2,i),&
!                 nimagestang,tau,rdmy,tangentleft(2,i))
!write(*,*)rdmy-interleft(2,i)
!!write(*,*)y2vecC(:,2,i)-y2vec(:,2,i)
!!write(*,*)lstpathCRM(:,2,i)-lstpathRM(:,2,i)
!            call splint_wrapper(arcC,lstpathCRM(1,3,i),y2vecC(1,3,i),&
!                 nimagestang,tau,rdmy,tangentleft(3,i))
!write(*,*)rdmy-interleft(3,i)
!!write(*,*)y2vecC(:,3,i)-y2vec(:,3,i)
!!write(*,*)lstpathCRM(:,3,i)-lstpathRM(:,3,i)
!        enddo
!!if(mod(j,100)==0)then
!write(fc5,'(i5.5)')j
!write(filename,*)'pospline_'//fc5//'.ascii'
!open(99,file=trim(adjustl((filename))))
!write(99,'(a)')'# BigDFT file'
!write(99,*)10.0 ,0, 10.0 
!write(99,*)0, 0, 10.0 
!do iat=1,nat
!write(99,'(3(1xes24.17),1x,a)')interleft(1,iat)*0.529d0,interleft(2,iat)&
!                           *0.529d0,interleft(3,iat)*0.529d0,xat(iat)
!enddo
!write(99,'(a)')"#metaData: forces (Ha/Bohr) =[ \"
!do iat=1,nat-1
!write(99,'(a,3(1x,es24.17";"),1x,a)')'#',tangentleft(1,iat)*0.529d0,&
!            tangentleft(2,iat)*0.529d0,tangentleft(3,iat)*0.529d0,' \'
!enddo
!iat=nat
!write(99,'(a,3(1x,es24.17";"),1x,a)')'#',tangentleft(1,iat)*0.529d0,&
!            tangentleft(2,iat)*0.529d0,tangentleft(3,iat)*0.529d0,' ]'
!close(99)
!!endif
!
!
!enddo
!stop
!<-DEBUG END-------------------------------------------------------->


    if(arcl < 2._gp*step)then!only one more point
        !we have to return the point in the 'middle'    
        tau = 0.5_gp*arcl
        !generate coordinates
        do i=1,nat
            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
                 nimages,tau,interleft(1,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
                 nimages,tau,interleft(2,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
                 nimages,tau,interleft(3,i),rdmy)
        enddo
        !generate tangent
        do i=1,nat
            call splint_wrapper(arcC,lstpathCRM(1,1,i),y2vecC(1,1,i),&
                 nimagestang,tau,rdmy,tangentleft(1,i))
            call splint_wrapper(arcC,lstpathCRM(1,2,i),y2vecC(1,2,i),&
                 nimagestang,tau,rdmy,tangentleft(2,i))
            call splint_wrapper(arcC,lstpathCRM(1,3,i),y2vecC(1,3,i),&
                 nimagestang,tau,rdmy,tangentleft(3,i))
        enddo
        rdmy = dnrm2(tnat,tangentleft(1,1),1)
        tangentleft = tangentleft / rmdy
        !return code: only one more node inserted
        finished=1
    else! standard case
        !we have to return the two points interleft
        !and interright whose distances to left and right
        !are roughly 'step'

        !first left...
        tau = step
        do i=1,nat
            !potentially performance issues since lstpath
            !is not transversed in column-major order in
            !splint_wrapper
            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
                 nimages,tau,interleft(1,i),tangentleft(1,i))
            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
                 nimages,tau,interleft(2,i),tangentleft(2,i))
            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
                 nimages,tau,interleft(3,i),tangentleft(3,i))
        enddo
        !generate coordinates for left node
        do i=1,nat
            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
                 nimages,tau,interleft(1,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
                 nimages,tau,interleft(2,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
                 nimages,tau,interleft(3,i),rdmy)
        enddo
        !generate tangent for left node
        do i=1,nat
            call splint_wrapper(arcC,lstpathCRM(1,1,i),y2vecC(1,1,i),&
                 nimagestang,tau,rdmy,tangentleft(1,i))
            call splint_wrapper(arcC,lstpathCRM(1,2,i),y2vecC(1,2,i),&
                 nimagestang,tau,rdmy,tangentleft(2,i))
            call splint_wrapper(arcC,lstpathCRM(1,3,i),y2vecC(1,3,i),&
                 nimagestang,tau,rdmy,tangentleft(3,i))
        enddo
        rdmy = dnrm2(tnat,tangentleft(1,1),1)
        tangentleft = tangentleft / rmdy

        !...then right
        tau = arcl-step
        !generate coordinates for right node
        do i=1,nat
            call splint_wrapper(arc,lstpathRM(1,1,i),y2vec(1,1,i),&
                 nimages,tau,interright(1,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,2,i),y2vec(1,2,i),&
                 nimages,tau,interright(2,i),rdmy)
            call splint_wrapper(arc,lstpathRM(1,3,i),y2vec(1,3,i),&
                 nimages,tau,interright(3,i),rdmy)
        enddo
        !generate tangent for right node
        do i=1,nat
            call splint_wrapper(arcC,lstpathCRM(1,1,i),y2vecC(1,1,i),&
                 nimagestang,tau,rdmy,tangentright(1,i))
            call splint_wrapper(arcC,lstpathCRM(1,2,i),y2vecC(1,2,i),&
                 nimagestang,tau,rdmy,tangentright(2,i))
            call splint_wrapper(arcC,lstpathCRM(1,3,i),y2vecC(1,3,i),&
                 nimagestang,tau,rdmy,tangentright(3,i))
        enddo
        rdmy = dnrm2(tnat,tangentright(1,1),1)
        tangentright = tangentright / rmdy

        !return code: two more nodes inserted
        finished=2
    endif
end subroutine
!=====================================================================
subroutine interpol(method,nat,left,right,step,interleft,interright,&
                    tangentleft,tangentright,finished)
    use module_base
    implicit none
    !parameters
    character(len=*), intent(in) :: method
    integer, intent(in)  :: nat
    real(gp), intent(in)  :: left(3*nat)
    real(gp), intent(in)  :: right(3*nat)
    real(gp), intent(inout)  :: step
    real(gp), intent(out) :: interleft(3*nat)
    real(gp), intent(out) :: interright(3*nat)
    real(gp), intent(out) :: tangentleft(3*nat)
    real(gp), intent(out) :: tangentright(3*nat)
    integer, intent(out) :: finished

    if(trim(adjustl(method))=='lincat')then
        call lin_interpol(nat,left, right, step,interleft,interright,&
                       tangentleft,finished)
        tangentright=tangentleft
    else if(trim(adjustl(method))=='linlst')then
        call lst_interpol(nat,left, right, step,interleft,interright,&
                       tangentleft,tangentright,finished)
    endif
end subroutine
!=====================================================================
subroutine spline_wrapper(xvec,yvec,ndim,yp1,ypn,y2vec)
    !routine for initializing the spline vectors
    !xvec[1..ndim] and yvec[1..ndim] contain the tabulated function.
    !yi= f(xi), x1 < x2 < ... < xN .
    !yp1, ypn: values of first derivative of the interpolating
    !function at points 1 and ndim
    !y2vec: second derivatives of the interpolating function at the
    !tabulated points
    use module_base
    implicit none
    !parameters
    integer, intent(in)  :: ndim
    real(gp), intent(in) :: xvec(ndim), yvec(ndim)
    real(gp), intent(in) :: yp1, ypn
    real(gp), intent(out) :: y2vec(ndim)
    !internal
    real(gp) :: xt(ndim), yt(ndim)
    real(gp) :: ytp1, ytpn
    if(xvec(1).eq.xvec(ndim)) then
        y2vec=0.0_gp
    elseif(xvec(1).gt.xvec(2)) then
        xt=-xvec
        yt=yvec
        ytp1=-yp1
        ytpn=-ypn
        call spline(xt,yt,ndim,ytp1,ytpn,y2vec)
    else
        call spline(xvec,yvec,ndim,yp1,ypn,y2vec)
    endif
end subroutine
!=====================================================================
subroutine splint_wrapper(xvec,yvec,y2vec,ndim,tau,yval,dy)
    !xvec[1..ndim] and yvec[1..ndim] contain the tabulated function.
    !yi= f(xi), x1 < x2 < ... < xN .
    !y2vec: second derivatives of the interpolating function at the
    !tabulated points
    !tau: spline's parameter
    !yval: cubic spline interpolation value at tay
    !dy: derivative of spline at tau (with respect to 
    !    the parametrization
    use module_base
    implicit none
    !parameters
    integer, intent(in)  :: ndim
    real(gp), intent(in) :: xvec(ndim), yvec(ndim)
    real(gp), intent(in) :: tau
    real(gp), intent(out) :: yval, dy
    real(gp), intent(in) :: y2vec(ndim)
    !internal
    real(gp) :: xt(ndim), yt(ndim), taut
    if(xvec(1).eq.xvec(ndim)) then
        yval=yvec(1)
        dy=0.0_gp
    elseif(xvec(1).gt.xvec(2)) then
        xt=-xvec
        yt=yvec
        taut=-tau
        call splint(xt,yt,y2vec,ndim,taut,yval,dy)
        dy=-dy
    else
        call splint(xvec,yvec,y2vec,ndim,tau,yval,dy)
    endif
end subroutine
!=====================================================================
subroutine spline(xvec,yvec,ndim,yp1,ypn,y2vec)
    !translated to f90 from numerical recipes
    use module_base
    implicit none
    !parameter
    integer, intent(in) :: ndim
    real(gp), intent(in) :: xvec(ndim), yvec(ndim)
    real(gp), intent(in) :: yp1, ypn
    real(gp), intent(out) :: y2vec(ndim)
    !internal
    integer  :: i,k
    real(gp) :: p,qn,sig,un,work(ndim)
    if (yp1 > .99e30_gp) then
        y2vec(1)=0.0_gp
        work(1)=0.0_gp
    else
        y2vec(1)=-0.5_gp
        work(1)=(3./(xvec(2)-xvec(1)))*((yvec(2)-yvec(1))/&
                (xvec(2)-xvec(1))-yp1)
    endif
    do i=2,ndim-1
        sig=(xvec(i)-xvec(i-1))/(xvec(i+1)-xvec(i-1))
        p=sig*y2vec(i-1)+2.0_gp
        y2vec(i)=(sig-1.0_gp)/p
        work(i)=(6.0_gp*((yvec(i+1)-yvec(i))/(xvec(i+1)-xvec(i))-&
                (yvec(i)-yvec(i-1))/(xvec(i)-xvec(i-1)))/&
                (xvec(i+1)-xvec(i-1))-sig*work(i-1))/p  
    enddo
    if(ypn>.99e30_gp) then
        qn=0.0_gp
        un=0.0_gp
    else
        qn=0.5_gp
        un=(3.0_gp/(xvec(ndim)-xvec(ndim-1)))*&
           (ypn-(yvec(ndim)-yvec(ndim-1))/(xvec(ndim)-xvec(ndim-1)))
    endif
    y2vec(ndim)=(un-qn*work(ndim-1))/(qn*y2vec(ndim-1)+1.0_gp)
    do k=ndim-1,1,-1
        y2vec(k)=y2vec(k)*y2vec(k+1)+work(k)
    enddo
end subroutine
!=====================================================================
subroutine splint(xvec,yvec,y2vec,ndim,tau,yval,dy)
    !translated to f90 from numerical recipes
    use module_base
    implicit none
    !parameters
    integer, intent(in) :: ndim
    real(gp), intent(in) :: xvec(ndim), yvec(ndim)
    real(gp), intent(in) :: y2vec(ndim)
    real(gp), intent(in)  :: tau
    real(gp), intent(out) :: yval, dy
    !internal
    integer :: k,khi,klo
    real(gp):: a,b,h,hy
    klo=1
    khi=ndim
    do while(khi-klo>1)
        k=(khi+klo)/2
        if(xvec(k)>tau)then
            khi=k
        else
            klo=k
        endif
    enddo
    h=xvec(khi)-xvec(klo)
    if(almostequal(xvec(khi),xvec(klo),4))&
            stop 'bad xvec input in splint'
    a=(xvec(khi)-tau)/h
    b=(tau-xvec(klo))/h
    yval=a*yvec(klo)+b*yvec(khi)+((a**3-a)*y2vec(klo)+&
         (b**3-b)*y2vec(khi))*(h**2)/6.0_gp  
    
    !compute the derivative at point x with respect to x
    hy=yvec(khi)-yvec(klo)
    dy=hy/h+(-(3.0_gp*a**2-1.0_gp)*y2vec(klo)+&
       (3.0_gp*b**2-1.0_gp)*y2vec(khi))/6.0_gp*h
end subroutine
!=====================================================================
logical function almostequal( x, y, ulp )
    use module_base
    real(gp), intent(in) :: x
    real(gp), intent(in) :: y
    integer, intent(in) :: ulp
    almostequal = abs(x-y)<( real(ulp,gp)*&
                  spacing(max(abs(x),abs(y)))) 
end function 
!=====================================================================
end module
