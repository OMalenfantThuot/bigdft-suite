subroutine readAtomicOrbitals(iproc,ngx,xp,psiat,occupat,ng,nl,nzatom,nelpsp,&
     & psppar,npspcode,norbe,norbsc,atomnames,ntypes,iatype,iasctype,nat,natsc,&
     & scorb,norbsc_arr)
  implicit none
  ! character(len = *), intent(in) :: filename
  integer, intent(in) :: ngx, iproc, ntypes
  integer, intent(in) :: nzatom(ntypes), nelpsp(ntypes)
  real*8, intent(in) :: psppar(0:4,0:4,ntypes)
  integer, intent(in) :: npspcode(ntypes),iasctype(ntypes)
  real*8, intent(out) :: xp(ngx, ntypes), psiat(ngx, 5, ntypes), occupat(5, ntypes)
  integer, intent(out) :: ng(ntypes), nl(4,ntypes)
  character(len = 20), intent(in) :: atomnames(100)
  integer, intent(out) :: norbe,norbsc
  integer, intent(in) :: nat,natsc
  integer, intent(in) :: iatype(nat)
  logical, dimension(4,natsc), intent(out) :: scorb
  integer, dimension(natsc+1), intent(out) :: norbsc_arr

  character(len = 20) :: pspatomname
  logical :: exists,found
  integer :: ity,i,j,l,ipsp,ifile,ng_fake,ierror,iatsc,iat,ipow,lsc,inorbsc,iorbsc_count
  real(kind=8) :: sccode

  ! Read the data file.
  nl(1:4,1:ntypes) = 0
  ng(1:ntypes) = 0
  xp(1:ngx,1:ntypes) = 0.d0
  psiat(1:ngx,1:5,1:ntypes) = 0.d0
  occupat(1:5,1:ntypes)= 0.d0

  ! Test if the file 'inguess.dat exists
  inquire(file='inguess.dat',exist=exists)
  if (exists) then
     open(unit=24,file='inguess.dat',form='formatted',action='read',status='old')
  end if

  loop_assign: do ity=1,ntypes

     if (exists) then
        rewind(24)
     end if
     found = .false.

     loop_find: do
        if (.not.exists) then
           !          The file 'inguess.dat' does not exist: automatic generation
           exit loop_find
        end if
        read(24,'(a)',iostat=ierror) pspatomname
        if (ierror /= 0) then
           !          Read error or end of file
           exit loop_find
        end if

        if (pspatomname .eq. atomnames(ity)) then
           if (iproc.eq.0) then
              write(*,'(1x,a,a,a)') 'input wavefunction data for atom ',trim(atomnames(ity)),&
                   ' found'
           end if
           found = .true.
           read(24,*) nl(1,ity),(occupat(i,ity),i=1,nl(1,ity)),  &
              nl(2,ity),(occupat(i,ity),i=1+nl(1,ity),nl(2,ity)+nl(1,ity)) ,&
              nl(3,ity),(occupat(i,ity),i=1+nl(2,ity)+nl(1,ity),nl(3,ity)+nl(2,ity)+nl(1,ity)),&
              nl(4,ity),(occupat(i,ity),&
              i=1+nl(3,ity)+nl(2,ity)+nl(1,ity),nl(4,ity)+nl(3,ity)+nl(2,ity)+nl(1,ity))
           !print *,nl(:,ity),occupat(:,ity)
           if (nl(1,ity)+nl(2,ity)+nl(3,ity)+nl(4,ity).gt.5) then
              print *,'error: number of valence orbitals too big'
              print *,nl(:,ity),occupat(:,ity)
              stop
           end if
           read(24,*) ng(ity)
           !print *, pspatomnames(ity),(nl(l,ity),l=1,4),ng(ity),ngx,npsp
           if (ng(ity).gt.ngx) stop 'enlarge ngx'
           !read(24,'(30(e12.5))') (xp(i,ity)  ,i=1,ng(ity))
           read(24,*) (xp(i,ity)  ,i=1,ng(ity))
           do i=1,ng(ity) 
              read(24,*) (psiat(i,j,ity),j=1,nl(1,ity)+nl(2,ity)+nl(3,ity)+nl(4,ity))
           enddo

           exit loop_find

        else

           read(24,*)
           read(24,*)ng_fake
           read(24,*) 
           do i=1,ng_fake
              read(24,*)
           enddo

        end if

     enddo loop_find

     if (.not.found) then

        if (iproc.eq.0) then
           write(*,'(1x,a,a6,a)',advance='no')&
                'Input wavefunction data for atom ',trim(atomnames(ity)),&
                ' NOT found, automatic generation...'
        end if

        !the default value for the gaussians is chosen to be 21
        ng(ity)=21
        call iguess_generator(iproc, nzatom(ity), nelpsp(ity),psppar(0,0,ity),npspcode(ity),&
             ng(ity)-1,nl(1,ity),5,occupat(1:5,ity),xp(1:ng(ity),ity),psiat(1:ng(ity),1:5,ity))

        !values obtained from the input guess generator in iguess.dat format
        !write these values on a file
        if (iproc .eq. 0) then
           open(unit=12,file='inguess.new',status='unknown')

           !write(*,*)' --------COPY THESE VALUES INSIDE inguess.dat--------'
           write(12,*)trim(atomnames(ity))//' (remove _lda)'
           write(12,*)nl(1,ity),(occupat(i,ity),i=1,nl(1,ity)),&
                nl(2,ity),(occupat(i+nl(1,ity),ity),i=1,nl(2,ity)),&
                nl(3,ity),(occupat(i+nl(1,ity)+nl(2,ity),ity),i=1,nl(3,ity)),&
                nl(4,ity),(occupat(i+nl(1,ity)+nl(2,ity)+nl(3,ity),ity),i=1,nl(4,ity))
           write(12,*)ng(ity)
           write(12,'(30(e12.5))')xp(1:ng(ity),ity)
           do j=1,ng(ity)
              write(12,*)(psiat(j,i,ity),i=1,nl(1,ity)+nl(2,ity)+nl(3,ity)+nl(4,ity))
           end do
           !print *,' --------^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--------'
           write(*,'(1x,a)')'done.'
        end if

     end if


  end do loop_assign

  close(unit=24)

  ! number of orbitals, total and semicore
  norbe=0
  norbsc=0
  iatsc=0
  do iat=1,nat
     ity=iatype(iat)
     norbe=norbe+nl(1,ity)+3*nl(2,ity)+5*nl(3,ity)+7*nl(4,ity)
     if (iasctype(ity)/=0) then !the atom has some semicore orbitals
        iatsc=iatsc+1
        sccode=real(iasctype(ity),kind=8)
        inorbsc=ceiling(dlog(sccode)/dlog(10.d0))
        if (sccode==1.d0) inorbsc=1
        ipow=inorbsc-1
        scorb(:,iatsc)=.false.
        !count the semicore orbitals for this atom
        iorbsc_count=0
        do i=1,inorbsc
           lsc=floor(sccode/10.d0**ipow)
           iorbsc_count=iorbsc_count+(2*lsc-1)
           scorb(lsc,iatsc)=.true.
           sccode=sccode-real(lsc,kind=8)*10.d0**ipow
           ipow=ipow-1
           !print *,iasctype(ity),inorbsc,lsc
        end do
        norbsc_arr(iatsc)=iorbsc_count
        norbsc=norbsc+iorbsc_count
     end if
  end do
  !orbitals which are non semicore
  norbsc_arr(natsc+1)=norbe-norbsc

  if (iproc ==0) then
     write(*,'(1x,a,i0,a)')'Generating ',norbe,' Atomic Input Orbitals'
     if (norbsc /=0)   write(*,'(1x,a,i0,a)')'  of which ',norbsc,' are semicore orbitals'
  end if


END SUBROUTINE readAtomicOrbitals

subroutine createAtomicOrbitals(iproc, nproc, atomnames,&
     & nat, rxyz, norbe, norbep, norbsc, occupe, occupat, ngx, xp, psiat, ng, nl, &
     & nvctr_c, nvctr_f, n1, n2, n3, hgrid, nfl1, nfu1, nfl2, nfu2, nfl3, nfu3, nseg_c, nseg_f, &
     & keyg, keyv, iatype, ntypes, iasctype, natsc, psi, eks, scorb)

  implicit none
  logical, dimension(4,natsc), intent(in) :: scorb
  integer, intent(in) :: nat, norbe, norbep, ngx, iproc, nproc
  integer, intent(in) :: nvctr_c, nvctr_f, n1, n2, n3, nseg_c, nseg_f
  integer, intent(in) :: nfl1, nfu1, nfl2, nfu2, nfl3, nfu3, ntypes
  integer, intent(in) :: norbsc,natsc
  integer, intent(in) :: keyg(2, nseg_c + nseg_f), keyv(nseg_c + nseg_f)
  integer, intent(in) :: iatype(nat),iasctype(ntypes)
  real(kind=8), intent(in) :: hgrid
  real(kind=8), intent(out) :: eks
  !character(len = 20), intent(in) :: pspatomnames(npsp)
  character(len = 20), intent(in) :: atomnames(100)
  integer, intent(inout) :: ng(ntypes), nl(4,ntypes)
  real(kind=8), intent(in) :: rxyz(3, nat)
  real(kind=8), intent(inout) :: xp(ngx, ntypes), psiat(ngx, 5, ntypes)
  real(kind=8), intent(inout) :: occupat(5, ntypes)
  real(kind=8), intent(out) :: psi(nvctr_c + 7 * nvctr_f, norbep), occupe(norbe)
  integer, parameter :: nterm_max=3

  logical :: myorbital
  integer :: iatsc,iorbsc,iorbv,inorbsc,ipow,lsc,i_all,i_stat
  real(kind=8) :: sccode
  integer :: lx(nterm_max),ly(nterm_max),lz(nterm_max)
  real(kind=8) :: fac_arr(nterm_max)
  integer :: iorb, jorb, iat, ity, ipsp, i, ictot, inl, l, m, nctot, nterm
  real(kind=8) :: rx, ry, rz, ek, scpr
  logical, dimension(:), allocatable :: semicore
  real(kind=8), dimension(:), allocatable :: psiatn

  allocate(semicore(4),stat=i_stat)
  call memocc(i_stat,product(shape(semicore))*kind(semicore),'semicore','createatomicorbitals')
  allocate(psiatn(ngx),stat=i_stat)
  call memocc(i_stat,product(shape(psiatn))*kind(psiatn),'psiatn','createatomicorbitals')
  

  eks=0.d0
  iorb=0
  ipsp = 1
  iatsc=0
  iorbsc=0
  iorbv=norbsc

  if (iproc ==0) then
     write(*,'(1x,a)',advance='no')'Calculating AIO wavefunctions...'
  end if

  do iat=1,nat

     rx=rxyz(1,iat)
     ry=rxyz(2,iat)
     rz=rxyz(3,iat)

     ity=iatype(iat)

     !here we can evaluate whether the atom has semicore orbitals and with
     !which value(s) of l
     semicore(:)=.false.
     if (iasctype(ity)/=0) then !the atom has some semicore orbitals
        iatsc=iatsc+1
        semicore(:)=scorb(:,iatsc)
     end if

     ipsp=ity

     !calculate the atomic input orbitals
     ictot=0
     nctot=nl(1,ipsp)+nl(2,ipsp)+nl(3,ipsp)+nl(4,ipsp)
     if (iorbsc+nctot .gt.norbe .and. iorbv+nctot .gt.norbe) then
        print *,'transgpw occupe',nl(:,ipsp),norbe
        stop
     end if
     do l=1,4
        do inl=1,nl(l,ipsp)
           ictot=ictot+1
           call atomkin(l-1,ng(ipsp),xp(1,ipsp),psiat(1,ictot,ipsp),psiatn,ek)
           eks=eks+ek*occupat(ictot,ipsp)!occupe(iorb)*real(2*l-1,kind=8)
           !the order of the orbitals (iorb,jorb) must put in the beginning
           !the semicore orbitals
           if (semicore(l) .and. inl==1) then
              !the orbital is semi-core
              iorb=iorbsc
              !print *,'iproc, SEMICORE orbital, iat,l',iproc,iat,l
           else
              !normal case, the orbital is a valence orbital
              iorb=iorbv
           end if
           do m=1,2*l-1
              iorb=iorb+1
              jorb=iorb-iproc*norbep
              occupe(iorb)=occupat(ictot,ipsp)/real(2*l-1,kind=8)
              if (myorbital(iorb,norbe,iproc,nproc)) then
                 !this will calculate the proper spherical harmonics
                 call calc_coeff_inguess(l,m,nterm_max,nterm,lx,ly,lz,fac_arr)
                 !fac_arr=1.d0
                 call crtonewave(n1,n2,n3,ng(ipsp),nterm,lx,ly,lz,fac_arr,xp(1,ipsp),psiatn,&
                      rx,ry,rz,hgrid, & 
                      0,n1,0,n2,0,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,  & 
                      nseg_c,nvctr_c,keyg(1,1),keyv(1),nseg_f,nvctr_f,&
                      keyg(1,nseg_c+1),keyv(nseg_c+1),&
                      psi(1,jorb),psi(nvctr_c+1,jorb))
                 call wnrm(nvctr_c,nvctr_f,psi(1,jorb),psi(nvctr_c+1,jorb),scpr) 
                 !write(*,'(1x,a24,a7,2(a3,i1),a16,i4,i4,1x,e14.7)')&
                 !     'ATOMIC INPUT ORBITAL for atom',trim(atomnames(ity)),&
                 !     'l=',l,'m=',m,'iorb,jorb,norm',iorb,jorb,scpr 
                 scpr=1.d0/sqrt(scpr)
                 call wscal(nvctr_c,nvctr_f,scpr,psi(1,jorb),psi(nvctr_c+1,jorb))
                 call wnrm(nvctr_c,nvctr_f,psi(1,jorb),psi(nvctr_c+1,jorb),scpr) 
                 !print *,'newnorm', scpr,occupe(iorb),occupat(ictot,ipsp),ictot
              endif
           end do
           if (semicore(l) .and. inl==1) then
              !increase semicore orbitals
              iorbsc=iorb
           else
              !increase valence orbitals
              iorbv=iorb
           end if
        end do
     end do
     
     if (ictot /= nctot) stop 'createAtomic orbitals: error (nctot)'

  end do
   if (iorbsc /= norbsc) stop 'createAtomic orbitals: error (iorbsc)'
  if (iorbv /= norbe) stop 'createAtomic orbitals: error (iorbv)'
  if (iatsc /= natsc) stop 'createAtomic orbitals: error (iatsc)'

  i_all=-product(shape(semicore))*kind(semicore)
  deallocate(semicore,stat=i_stat)
  call memocc(i_stat,i_all,'semicore','createatomicorbitals')
  i_all=-product(shape(psiatn))*kind(psiatn)
  deallocate(psiatn,stat=i_stat)
  call memocc(i_stat,i_all,'psiatn','createatomicorbitals')

  if (iproc ==0) then
     write(*,'(1x,a)')'done.'
  end if


END SUBROUTINE createAtomicOrbitals


subroutine iguess_generator(iproc,izatom,ielpsp,psppar,npspcode,ng,nl,nmax_occ,occupat,expo,psiat)
  implicit none
  integer, intent(in) :: iproc,izatom,ielpsp,ng,npspcode,nmax_occ
  real(kind=8), dimension(0:4,0:4), intent(in) :: psppar
  integer, dimension(4), intent(out) :: nl
  real(kind=8), dimension(ng+1), intent(out) :: expo
  real(kind=8), dimension(nmax_occ), intent(out) :: occupat
  real(kind=8), dimension(ng+1,nmax_occ), intent(out) :: psiat
  
  !local variables
  character(len=27) :: string 
  character(len=2) :: symbol
  integer, parameter :: lmax=3,nint=100,noccmax=2
  real(kind=8), parameter :: fact=4.d0
  real(kind=8), dimension(:), allocatable :: xp,gpot,alps,ott
  real(kind=8), dimension(:,:), allocatable :: aeval,chrg,res,vh,hsep,occup,ofdcoef
  real(kind=8), dimension(:,:,:), allocatable :: psi
  real(kind=8), dimension(:,:,:,:), allocatable :: rmt
  integer, dimension(:,:), allocatable :: neleconf
  logical :: exists
  integer :: lpx,ncount,nsccode
  integer :: l,i,j,iocc,il,lwrite,i_all,i_stat
  real(kind=8) :: alpz,alpl,rcov,rprb,zion,rij,a,a0,a0in,tt,ehomo

  !filename = 'psppar.'//trim(atomname)

  lpx=0
  lpx_determination: do i=1,4
     if (psppar(i,0) == 0.d0) then
     exit lpx_determination
     else
        lpx=i-1
     end if
  end do lpx_determination

  allocate(gpot(3),stat=i_stat)
  call memocc(i_stat,product(shape(gpot))*kind(gpot),'gpot','iguess_generator')
  allocate(alps(lpx+1),stat=i_stat)
  call memocc(i_stat,product(shape(alps))*kind(alps),'alps','iguess_generator')
  allocate(hsep(6,lpx+1),stat=i_stat)
  call memocc(i_stat,product(shape(hsep))*kind(hsep),'hsep','iguess_generator')
  allocate(ott(6),stat=i_stat)
  call memocc(i_stat,product(shape(ott))*kind(ott),'ott','iguess_generator')
  allocate(occup(noccmax,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(occup))*kind(occup),'occup','iguess_generator')
  allocate(ofdcoef(3,4),stat=i_stat)
  call memocc(i_stat,product(shape(ofdcoef))*kind(ofdcoef),'ofdcoef','iguess_generator')
  allocate(neleconf(6,4),stat=i_stat)
  call memocc(i_stat,product(shape(neleconf))*kind(neleconf),'neleconf','iguess_generator')

  !assignation of radii and coefficients of the local part
  alpz=psppar(0,0)
  alpl=psppar(0,0)
  alps(1:lpx+1)=psppar(1:lpx+1,0)
  gpot(1:3)=psppar(0,1:3)

  !assignation of the coefficents for the nondiagonal terms
  if (npspcode == 2) then !GTH case
     ofdcoef(:,:)=0.d0
  else if (npspcode == 3) then !HGH case
     ofdcoef(1,1)=-0.5d0*sqrt(3.d0/5.d0) !h2
     ofdcoef(2,1)=0.5d0*sqrt(5.d0/21.d0) !h4
     ofdcoef(3,1)=-0.5d0*sqrt(100.d0/63.d0) !h5

     ofdcoef(1,2)=-0.5d0*sqrt(5.d0/7.d0) !h2
     ofdcoef(2,2)=1.d0/6.d0*sqrt(35.d0/11.d0) !h4
     ofdcoef(3,2)=-7.d0/3.d0*sqrt(1.d0/11.d0) !h5

     ofdcoef(1,3)=-0.5d0*sqrt(7.d0/9.d0) !h2
     ofdcoef(2,3)=0.5d0*sqrt(63.d0/143.d0) !h4
     ofdcoef(3,3)=-9.d0*sqrt(1.d0/143.d0) !h5

     ofdcoef(1,4)=0.d0 !h2
     ofdcoef(2,4)=0.d0 !h4
     ofdcoef(3,4)=0.d0 !h5
  end if
  !define the values of hsep starting from the pseudopotential file
  do l=1,lpx+1
     hsep(1,l)=psppar(l,1)
     hsep(2,l)=psppar(l,2)*ofdcoef(1,l)
     hsep(3,l)=psppar(l,2)
     hsep(4,l)=psppar(l,3)*ofdcoef(2,l)
     hsep(5,l)=psppar(l,3)*ofdcoef(3,l)
     hsep(6,l)=psppar(l,3)
  end do

  !Now the treatment of the occupation number
  call eleconf(izatom,ielpsp,symbol,rcov,rprb,ehomo,neleconf,nsccode)

  occup(:,:)=0.d0
   do l=0,lmax
     iocc=0
     do i=1,6
        ott(i)=real(neleconf(i,l+1),kind=8)
        if (ott(i).gt.0.d0) then
           iocc=iocc+1
            if (iocc.gt.noccmax) stop 'iguess_generator: noccmax too small'
           occup(iocc,l+1)=ott(i)
        endif
     end do
     nl(l+1)=iocc
  end do

  !allocate arrays for the gatom routine
  allocate(aeval(noccmax,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(aeval))*kind(aeval),'aeval','iguess_generator')
  allocate(chrg(noccmax,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(chrg))*kind(chrg),'chrg','iguess_generator')
  allocate(res(noccmax,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(res))*kind(res),'res','iguess_generator')
  allocate(vh(4*(ng+1)**2,4*(ng+1)**2),stat=i_stat)
  call memocc(i_stat,product(shape(vh))*kind(vh),'vh','iguess_generator')
  allocate(psi(0:ng,noccmax,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(psi))*kind(psi),'psi','iguess_generator')
  allocate(xp(0:ng),stat=i_stat)
  call memocc(i_stat,product(shape(xp))*kind(xp),'xp','iguess_generator')
  allocate(rmt(nint,0:ng,0:ng,lmax+1),stat=i_stat)
  call memocc(i_stat,product(shape(rmt))*kind(rmt),'rmt','iguess_generator')

  zion=real(ielpsp,kind=8)

  !can be switched on for debugging
  !if (iproc.eq.0) write(*,'(1x,a,a7,a9,i3,i3,a9,i3,f5.2)')&
  !     'Input Guess Generation for atom',trim(atomname),&
  !     'Z,Zion=',izatom,ielpsp,'ng,rprb=',ng+1,rprb

  rij=3.d0
  ! exponents of gaussians
  a0in=alpz
  a0=a0in/rij
  !       tt=sqrt(sqrt(2.d0))
  tt=2.d0**.3d0
  do i=0,ng
     a=a0*tt**i
     xp(i)=.5d0/a**2
  end do

  ! initial guess
  do l=0,lmax
     do iocc=1,noccmax
        do i=0,ng
           psi(i,iocc,l+1)=0.d0
        end do
     end do
  end do

  call crtvh(ng,lmax,xp,vh,rprb,fact,nint,rmt)

  call gatom(rcov,rprb,lmax,lpx,noccmax,occup,&
       zion,alpz,gpot,alpl,hsep,alps,vh,xp,rmt,fact,nint,&
       aeval,ng,psi,res,chrg)

  !postreatment of the inguess data
  do i=1,ng+1
     expo(i)=sqrt(0.5/xp(i-1))
  end do

  i=0
  do l=1,4
     do iocc=1,nl(l)
        i=i+1
        occupat(i)=occup(iocc,l)
        do j=1,ng+1
           psiat(j,i)=psi(j-1,iocc,l)
        end do
     end do
  end do

  i_all=-product(shape(aeval))*kind(aeval)
  deallocate(aeval,stat=i_stat)
  call memocc(i_stat,i_all,'aeval','iguess_generator')
  i_all=-product(shape(chrg))*kind(chrg)
  deallocate(chrg,stat=i_stat)
  call memocc(i_stat,i_all,'chrg','iguess_generator')
  i_all=-product(shape(res))*kind(res)
  deallocate(res,stat=i_stat)
  call memocc(i_stat,i_all,'res','iguess_generator')
  i_all=-product(shape(vh))*kind(vh)
  deallocate(vh,stat=i_stat)
  call memocc(i_stat,i_all,'vh','iguess_generator')
  i_all=-product(shape(psi))*kind(psi)
  deallocate(psi,stat=i_stat)
  call memocc(i_stat,i_all,'psi','iguess_generator')
  i_all=-product(shape(xp))*kind(xp)
  deallocate(xp,stat=i_stat)
  call memocc(i_stat,i_all,'xp','iguess_generator')
  i_all=-product(shape(rmt))*kind(rmt)
  deallocate(rmt,stat=i_stat)
  call memocc(i_stat,i_all,'rmt','iguess_generator')
  i_all=-product(shape(gpot))*kind(gpot)
  deallocate(gpot,stat=i_stat)
  call memocc(i_stat,i_all,'gpot','iguess_generator')
  i_all=-product(shape(hsep))*kind(hsep)
  deallocate(hsep,stat=i_stat)
  call memocc(i_stat,i_all,'hsep','iguess_generator')
  i_all=-product(shape(alps))*kind(alps)
  deallocate(alps,stat=i_stat)
  call memocc(i_stat,i_all,'alps','iguess_generator')
  i_all=-product(shape(ott))*kind(ott)
  deallocate(ott,stat=i_stat)
  call memocc(i_stat,i_all,'ott','iguess_generator')
  i_all=-product(shape(occup))*kind(occup)
  deallocate(occup,stat=i_stat)
  call memocc(i_stat,i_all,'occup','iguess_generator')
  i_all=-product(shape(ofdcoef))*kind(ofdcoef)
  deallocate(ofdcoef,stat=i_stat)
  call memocc(i_stat,i_all,'ofdcoef','iguess_generator')
  i_all=-product(shape(neleconf))*kind(neleconf)
  deallocate(neleconf,stat=i_stat)
  call memocc(i_stat,i_all,'neleconf','iguess_generator')

end subroutine iguess_generator

subroutine gatom(rcov,rprb,lmax,lpx,noccmax,occup,&
     zion,alpz,gpot,alpl,hsep,alps,vh,xp,rmt,fact,nintp,&
     aeval,ng,psi,res,chrg)
     implicit real*8 (a-h,o-z)
     logical noproj
     parameter(nint=100)
     dimension psi(0:ng,noccmax,lmax+1),aeval(noccmax,lmax+1),&
       hh(0:ng,0:ng),ss(0:ng,0:ng),eval(0:ng),evec(0:ng,0:ng),&
       aux(2*ng+2),&
       gpot(3),hsep(6,lpx+1),rmt(nint,0:ng,0:ng,lmax+1),&
       pp1(0:ng,lpx+1),pp2(0:ng,lpx+1),pp3(0:ng,lpx+1),alps(lpx+1),&
       potgrd(nint),&
       rho(0:ng,0:ng,lmax+1),rhoold(0:ng,0:ng,lmax+1),xcgrd(nint),&
       occup(noccmax,lmax+1),chrg(noccmax,lmax+1),&
       vh(0:ng,0:ng,4,0:ng,0:ng,4),&
       res(noccmax,lmax+1),xp(0:ng)
     if (nintp.ne.nint) stop 'nint><nintp'

     do l=0,lmax
        if (occup(1,l+1).gt.0.d0) lcx=l
     end do
     !write(6,*) 'lcx',lcx
 
     noproj=.true.
     do l=1,lpx+1
        noproj = noproj .and. (alps(l) .eq. 0.d0)
     end do


!    projectors, just in case
     if (.not. noproj) then
        do l=0,lpx
           gml1=sqrt( gamma(l+1.5d0) / (2.d0*alps(l+1)**(2*l+3)) )
           gml2=sqrt( gamma(l+3.5d0) / (2.d0*alps(l+1)**(2*l+7)) )&
               /(l+2.5d0)
           gml3=sqrt( gamma(l+5.5d0) / (2.d0*alps(l+1)**(2*l+11)) )&
               /((l+3.5d0)*(l+4.5d0))
           tt=1.d0/(2.d0*alps(l+1)**2)
           do i=0,ng
              ttt=1.d0/(xp(i)+tt)
              pp1(i,l+1)=gml1*(sqrt(ttt)**(2*l+3))
              pp2(i,l+1)=gml2*ttt*(sqrt(ttt)**(2*l+3))
              pp3(i,l+1)=gml3*ttt**2*(sqrt(ttt)**(2*l+3))
           end do
        end do
     else
        pp1(:,:)=0.d0
        pp2(:,:)=0.d0
        pp3(:,:)=0.d0
     end if

     do l=0,lmax
        do j=0,ng
           do i=0,ng
              rho(i,j,l+1)=0.d0
           end do
        end do
     end do

     evsum=1.d30
     do 2000,it=1,50
        evsumold=evsum
        evsum=0.d0
        
        ! coefficients of charge density
        do l=0,lmax
           do j=0,ng
              do i=0,ng
                 rhoold(i,j,l+1)=rho(i,j,l+1)
                 rho(i,j,l+1)=0.d0        
              end do
           end do
        end do

        do l=0,lmax
           do iocc=1,noccmax
              if (occup(iocc,l+1).gt.0.d0) then
                 do j=0,ng
                    do i=0,ng
                       rho(i,j,l+1)=rho(i,j,l+1) + &
                            psi(i,iocc,l+1)*psi(j,iocc,l+1)*occup(iocc,l+1)
                    end do
                 end do
              end if
           end do
        end do


        rmix=.5d0
        if (it.eq.1) rmix=1.d0
        do 2834,l=0,lmax
        do 2834,j=0,ng
        do 2834,i=0,ng
        tt=rmix*rho(i,j,l+1) + (1.d0-rmix)*rhoold(i,j,l+1)
        rho(i,j,l+1)=tt
2834        continue

! XC potential on grid
!        do 3728,k=1,nint
!3728        xcgrd(k)=0.d0        
!        do 3328,l=0,lmax
!        do 3328,j=0,ng
!        do 3328,i=0,ng
!        do 3328,k=1,nint
!3328        xcgrd(k)=xcgrd(k)+rmt(k,i,j,l+1)*rho(i,j,l+1)
        call DGEMV('N',nint,(lcx+1)*(ng+1)**2,1.d0,&
                   rmt,nint,rho,1,0.d0,xcgrd,1)

        dr=fact*rprb/nint
        do 3167,k=1,nint
        r=(k-.5d0)*dr
! divide by 4 pi
        tt=xcgrd(k)*0.07957747154594768d0
! multiply with r^2 to speed up calculation of matrix elements
        xcgrd(k)=emuxc(tt)*r**2
3167        continue

        do 1000,l=0,lmax
        gml=.5d0*gamma(.5d0+l)

!  lower triangles only
        do 100,i=0,ng
        do 100,j=0,i
        d=xp(i)+xp(j)
        sxp=1.d0/d
        const=gml*sqrt(sxp)**(2*l+1)
! overlap        
        ss(i,j)=const*sxp*(l+.5d0)
! kinetic energy
        hh(i,j)=.5d0*const*sxp**2* ( 3.d0*xp(i)*xp(j) +&
             l*(6.d0*xp(i)*xp(j)-xp(i)**2-xp(j)**2) -&
             l**2*(xp(i)-xp(j))**2  ) + .5d0*l*(l+1.d0)*const
! potential energy from parabolic potential
        hh(i,j)=hh(i,j) +&
             .5d0*const*sxp**2*(l+.5d0)*(l+1.5d0)/rprb**4 
! hartree potential from ionic core charge
        tt=sqrt(1.d0+2.d0*alpz**2*d)
        if (l.eq.0) then
        hh(i,j)=hh(i,j) -zion/(2.d0*d*tt)
        else if (l.eq.1) then
        hh(i,j)=hh(i,j) -zion* &
             (1.d0 + 3.d0*alpz**2*d)/(2.d0*d**2*tt**3)
        else if (l.eq.2) then
        hh(i,j)=hh(i,j) -zion* &
             (2.d0 + 10.d0*alpz**2*d + 15.d0*alpz**4*d**2)/(2.d0*d**3*tt**5)
        else if (l.eq.3) then
        hh(i,j)=hh(i,j) -zion*3.d0* &
             (2.d0 +14.d0*alpz**2*d +35.d0*alpz**4*d**2 +35.d0*alpz**6*d**3)/&
             (2.d0*d**4*tt**7)
        else 
        stop 'l too big'
        end if
! potential from repulsive gauss potential
        tt=alpl**2/(.5d0+d*alpl**2)
        hh(i,j)=hh(i,j)  + gpot(1)*.5d0*gamma(1.5d0+l)*tt**(1.5d0+l)&
             + (gpot(2)/alpl**2)*.5d0*gamma(2.5d0+l)*tt**(2.5d0+l)&
             + (gpot(3)/alpl**4)*.5d0*gamma(3.5d0+l)*tt**(3.5d0+l)
        ! separable terms
        if (l.le.lpx) then
           hh(i,j)=hh(i,j) + pp1(i,l+1)*hsep(1,l+1)*pp1(j,l+1)&
                + pp1(i,l+1)*hsep(2,l+1)*pp2(j,l+1)&
                + pp2(i,l+1)*hsep(2,l+1)*pp1(j,l+1)&
                + pp2(i,l+1)*hsep(3,l+1)*pp2(j,l+1)&
                + pp1(i,l+1)*hsep(4,l+1)*pp3(j,l+1)&
                + pp3(i,l+1)*hsep(4,l+1)*pp1(j,l+1)&
                + pp2(i,l+1)*hsep(5,l+1)*pp3(j,l+1)&
                + pp3(i,l+1)*hsep(5,l+1)*pp2(j,l+1)&
                + pp3(i,l+1)*hsep(6,l+1)*pp3(j,l+1)
        end if
! hartree potential from valence charge distribution
!        tt=0.d0
!        do 4982,lp=0,lcx
!        do 4982,jp=0,ng
!        do 4982,ip=0,ng
!        tt=tt + vh(ip,jp,lp+1,i,j,l+1)*rho(ip,jp,lp+1)
!4982        continue
        tt=DDOT((lcx+1)*(ng+1)**2,vh(0,0,1,i,j,l+1),1,rho(0,0,1),1)
        hh(i,j)=hh(i,j) + tt
! potential from XC potential
        dr=fact*rprb/nint
!        tt=0.d0
!        do 8049,k=1,nint
!8049        tt=tt+xcgrd(k)*rmt(k,i,j,l+1)
        tt=DDOT(nint,rmt(1,i,j,l+1),1,xcgrd(1),1)
        hh(i,j)=hh(i,j)+tt*dr
100        continue
 
! ESSL
!        call DSYGV(1,hh,ng+1,ss,ng+1,eval,evec,ng+1,ng+1,aux,2*ng+2)
! LAPACK
        call DSYGV(1,'V','L',&
             ng+1,hh,ng+1,ss,ng+1,eval,evec,(ng+1)**2,info)
        if (info.ne.0) write(6,*) 'LAPACK',info
        do 334,iocc=0,noccmax-1
        do 334,i=0,ng
334        evec(i,iocc)=hh(i,iocc)
! end LAPACK
        do 9134,iocc=1,noccmax
        evsum=evsum+eval(iocc-1)
        aeval(iocc,l+1)=eval(iocc-1)
        do 9134,i=0,ng
9134        psi(i,iocc,l+1)=evec(i,iocc-1)

!        write(6,*) 'eval',l
!55        format(5(e14.7))
!        write(6,55) eval 
!        write(6,*) 'diff eval'
!        write(6,55) (eval(i)-eval(i-1),i=1,ng)
        
!        write(6,*) 'evec',l
!        do i=0,ng
!33        format(10(e9.2))
!        write(6,33) (evec(i,iocc),iocc=0,noccmax-1)
!        end do

1000        continue

        tt=abs(evsum-evsumold)
!        write(6,*) 'evdiff',it,tt
        if (tt.lt.1.d-12) goto 3000
2000        continue
3000        continue
        call resid(lmax,lpx,noccmax,rprb,xp,aeval,psi,rho,ng,res,&
             zion,alpz,alpl,gpot,pp1,pp2,pp3,alps,hsep,fact,nint,&
             potgrd,xcgrd)

! charge up to radius rcov
        if (lmax.gt.3) stop 'cannot calculate chrg'
        do 3754,l=0,lmax
        do 3754,iocc=1,noccmax
3754        chrg(iocc,l+1)=0.d0

        do 3761,iocc=1,noccmax
        do 3761,j=0,ng
        do 3761,i=0,ng
        d=xp(i)+xp(j)
        sd=sqrt(d)
        terf=erf(sd*rcov) 
        texp=exp(-d*rcov**2)

        tt=0.4431134627263791d0*terf/sd**3 - 0.5d0*rcov*texp/d
        chrg(iocc,1)=chrg(iocc,1) + psi(i,iocc,1)*psi(j,iocc,1)*tt
        if (lmax.eq.0) goto 3761
        tt=0.6646701940895686d0*terf/sd**5 + &
             (-0.75d0*rcov*texp - 0.5d0*d*rcov**3*texp)/d**2
        chrg(iocc,2)=chrg(iocc,2) + psi(i,iocc,2)*psi(j,iocc,2)*tt
        if (lmax.eq.1) goto 3761
        tt=1.661675485223921d0*terf/sd**7 + &
             (-1.875d0*rcov*texp-1.25d0*d*rcov**3*texp-.5d0*d**2*rcov**5*texp) &
             /d**3
        chrg(iocc,3)=chrg(iocc,3) + psi(i,iocc,3)*psi(j,iocc,3)*tt
        if (lmax.eq.2) goto 3761
        tt=5.815864198283725d0*terf/sd**9 + &
             (-6.5625d0*rcov*texp - 4.375d0*d*rcov**3*texp - &
             1.75d0*d**2*rcov**5*texp - .5d0*d**3*rcov**7*texp)/d**4
        chrg(iocc,4)=chrg(iocc,4) + psi(i,iocc,4)*psi(j,iocc,4)*tt
3761        continue


        !writing lines suppressed
!!$        write(66,*)  lmax+1
!!$        write(66,*) ' #LINETYPE{1324}' 
!!$        write(66,*) ' $' 
        do l=0,lmax
!!$           write(66,*) ' 161'
           r=0.d0
           do
              tt= wave(ng,l,xp,psi(0,1,l+1),r)
!!$              write(66,*) r,tt
              r=r+.025d0
              if(r > 4.00001d0) exit
           end do
        end do
        !writing lines suppressed
!!$        write(67,*) min(lmax+1,3)
!!$        write(67,*) ' #LINETYPE{132}'
!!$        write(67,*) ' #TITLE{FOURIER}' 
!!$        write(67,*) ' $'
        dr=6.28d0/rprb/200.d0
!!$        write(67,*) ' 200'
        rk=0.d0
        loop_rk1: do 
           tt=0.d0
           do i=0,ng
              texp=exp(-.25d0*rk**2/xp(i))
!              texp=exp(-.5d0*energy/xp(i))
              sd=sqrt(xp(i))
              tt=tt+psi(i,1,1)*0.4431134627263791d0*texp/sd**3
           end do
!!$           write(67,*) rk,tt
           rk=rk+dr
           if(rk > 6.28d0/rprb-.5d0*dr) exit loop_rk1
        end do loop_rk1
        if (lmax.ge.1) then
!!$           write(67,*) ' 200'
           rk=0.d0
           loop_rk2: do 
              tt=0.d0
              do i=0,ng
                 texp=exp(-.25d0*rk**2/xp(i))
                 sd=sqrt(xp(i))
                 tt=tt+psi(i,1,2)*0.2215567313631895d0*rk*texp/sd**5
              end do
!!$              write(67,*) rk,tt
              rk=rk+dr
              if (rk > 6.28d0/rprb-.5d0*dr) exit loop_rk2
           end do loop_rk2
        end if
        if (lmax.ge.2) then
!!$           write(67,*) ' 200'
           rk=0.d0
           do 
              tt=0.d0
              do i=0,ng
                 texp=exp(-.25d0*rk**2/xp(i))
                 sd=sqrt(xp(i))
              tt=tt+psi(i,1,3)*0.1107783656815948d0*rk**2*texp/sd**7
              end do
!!$              write(67,*) rk,tt
              rk=rk+dr
              if (rk > 6.28d0/rprb-.5d0*dr) exit
           end do
        end if


      end subroutine gatom



      subroutine resid(lmax,lpx,noccmax,rprb,xp,aeval,psi,rho,&
           ng,res,zion,alpz,alpl,gpot,pp1,pp2,pp3,alps,hsep,fact,nint,&
           potgrd,xcgrd)
        implicit real*8 (a-h,o-z)
        dimension psi(0:ng,noccmax,lmax+1),rho(0:ng,0:ng,lmax+1),&
             gpot(3),pp1(0:ng,lmax+1),pp2(0:ng,lmax+1),pp3(0:ng,lmax+1),&
             alps(lmax+1),hsep(6,lmax+1),res(noccmax,lmax+1),xp(0:ng),&
             xcgrd(nint),aeval(noccmax,lmax+1),potgrd(nint)
        
!   potential on grid 
        dr=fact*rprb/nint
        do 9873,k=1,nint
        r=(k-.5d0)*dr
        potgrd(k)= .5d0*(r/rprb**2)**2 - &
             zion*erf(r/(sqrt(2.d0)*alpz))/r &
             + exp(-.5d0*(r/alpl)**2)*&
             ( gpot(1) + gpot(2)*(r/alpl)**2 + gpot(3)*(r/alpl)**4 )&
             + xcgrd(k)/r**2
        do 2487,j=0,ng
        do 2487,i=0,ng
        spi=1.772453850905516d0
        d=xp(i)+xp(j)
        sd=sqrt(d)
        tx=exp(-d*r**2)
        tt=spi*erf(sd*r)
           ud0=tt/(4.d0*sd**3*r)
        potgrd(k)=potgrd(k)+ud0*rho(i,j,1)
           ud1=-tx/(4.d0*d**2) + 3.d0*tt/(8.d0*sd**5*r)
        if (lmax.ge.1) potgrd(k)=potgrd(k)+ud1*rho(i,j,2)
        ud2=-tx*(7.d0 + 2.d0*d*r**2)/(8.d0*d**3) +&
             15.d0*tt/(16.d0*sd**7*r)
        if (lmax.ge.2) potgrd(k)=potgrd(k)+ud2*rho(i,j,3)
        ud3=-tx*(57.d0+22.d0*d*r**2+4.d0*d**2*r**4)/(16.d0*d**4) + &
             105.d0*tt/(32.d0*sd**9*r)
        if (lmax.ge.3) potgrd(k)=potgrd(k)+ud3*rho(i,j,4)
2487    continue
9873        continue

        do 1500,ll=0,lmax
        if (ll.le.lpx) then
        rnrm1=1.d0/sqrt(.5d0*gamma(ll+1.5d0)*alps(ll+1)**(2*ll+3))
        rnrm2=1.d0/sqrt(.5d0*gamma(ll+3.5d0)*alps(ll+1)**(2*ll+7))
        rnrm3=1.d0/sqrt(.5d0*gamma(ll+5.5d0)*alps(ll+1)**(2*ll+11))
        end if
        do 1500,iocc=1,noccmax
! separabel part
        if (ll.le.lpx) then
        scpr1=DDOT(ng+1,psi(0,iocc,ll+1),1,pp1(0,ll+1),1)
        scpr2=DDOT(ng+1,psi(0,iocc,ll+1),1,pp2(0,ll+1),1)
        scpr3=DDOT(ng+1,psi(0,iocc,ll+1),1,pp3(0,ll+1),1)
        end if
        res(iocc,ll+1)=0.d0
        do 1500,j=1,nint
!  wavefunction on grid
        r=(j-.5d0)*dr
        psigrd = wave(ng,ll,xp,psi(0,iocc,ll+1),r)
!   kinetic energy        
        rkin=0.d0
        do 5733,i=0,ng
        rkin=rkin + psi(i,iocc,ll+1) *  (&
             xp(i)*(3.d0+2.d0*ll-2.d0*xp(i)*r**2)*exp(-xp(i)*r**2) )
5733        continue
        rkin=rkin*r**ll
!   separabel part
        if (ll.le.lpx) then
           sep =& 
                (scpr1*hsep(1,ll+1) + scpr2*hsep(2,ll+1) + scpr3*hsep(4,ll+1))&
                *rnrm1*r**ll*exp(-.5d0*(r/alps(ll+1))**2)   +&
                (scpr1*hsep(2,ll+1) + scpr2*hsep(3,ll+1) + scpr3*hsep(5,ll+1))&
                *rnrm2*r**(ll+2)*exp(-.5d0*(r/alps(ll+1))**2)   +&
                (scpr1*hsep(4,ll+1) + scpr2*hsep(5,ll+1) + scpr3*hsep(6,ll+1))&
                *rnrm3*r**(ll+4)*exp(-.5d0*(r/alps(ll+1))**2)
        else
        sep=0.d0
        end if
! resdidue
        tt=rkin+sep+(potgrd(j)-aeval(iocc,ll+1))*psigrd
!384        format(6(e12.5))
!12        format(i2,i2,e9.2,3(e12.5),e10.3)
        res(iocc,ll+1)=res(iocc,ll+1) + tt**2*dr
1500        continue
!        do 867,l=0,lmax
!        do 867,iocc=1,noccmax
!867        write(6,*) 'res',l,iocc,res(iocc,l+1)
        return
        end subroutine resid



        subroutine crtvh(ng,lmax,xp,vh,rprb,fact,nint,rmt)
        implicit real*8 (a-h,o-z)
        dimension vh(0:ng,0:ng,0:3,0:ng,0:ng,0:3),xp(0:ng),&
             rmt(nint,0:ng,0:ng,lmax+1)
        if (lmax.gt.3) stop 'crtvh'

        dr=fact*rprb/nint
        do 8049,l=0,lmax
        do 8049,k=1,nint
        r=(k-.5d0)*dr
        do 8049,j=0,ng
        do 8049,i=0,ng
8049        rmt(k,i,j,l+1)=(r**2)**l*exp(-(xp(i)+xp(j))*r**2)

        do 100,j=0,ng
        do 100,i=0,ng
        c=xp(i)+xp(j)
        do 100,jp=0,ng
        do 100,ip=0,ng
        d=xp(ip)+xp(jp)
        scpd=sqrt(c+d)
        vh(ip,jp,0,i,j,0)=0.2215567313631895d0/(c*d*scpd)
        vh(ip,jp,1,i,j,0)=&
             .1107783656815948d0*(2.d0*c+3.d0*d)/(c*d**2*scpd**3)
        vh(ip,jp,2,i,j,0)=.05538918284079739d0*&
             (8.d0*c**2+20.d0*c*d+15.d0*d**2)/(c*d**3*scpd**5)
        vh(ip,jp,3,i,j,0)=.0830837742611961d0*&
        (16.d0*c**3+56.d0*c**2*d+70.d0*c*d**2+35.d0*d**3)/&
             (c*d**4*scpd**7)


        vh(ip,jp,0,i,j,1)=&
             .1107783656815948d0*(3.d0*c+2.d0*d)/(c**2*d*scpd**3)
        vh(ip,jp,1,i,j,1)=&
             .05538918284079739d0*(6.d0*c**2+15.d0*c*d+6.d0*d**2)/&
             (c**2*d**2*scpd**5)
        vh(ip,jp,2,i,j,1)=.02769459142039869d0*&
             (24.d0*c**3+84.d0*c**2*d+105.d0*c*d**2+30.d0*d**3)/&
             (c**2*d**3*scpd**7)
        vh(ip,jp,3,i,j,1)=0.04154188713059803d0*&
             (48.d0*c**4+216.d0*c**3*d+378.d0*c**2*d**2+&
             315.d0*c*d**3+70.d0*d**4)/(c**2*d**4*scpd**9)

        vh(ip,jp,0,i,j,2)=&
             .05538918284079739d0*(15.d0*c**2+20.d0*c*d+8.d0*d**2)/&
             (c**3*d*scpd**5)
        vh(ip,jp,1,i,j,2)=.02769459142039869d0*&
             (30.d0*c**3+105.d0*c**2*d+84.d0*c*d**2+24.d0*d**3)/&
             (c**3*d**2*scpd**7)
        vh(ip,jp,2,i,j,2)=&
             .2077094356529901d0*(8.d0*c**4+36.d0*c**3*d+63.d0*c**2*d**2+&
             36.d0*c*d**3+8.d0*d**4)/(c**3*d**3*scpd**9)
        vh(ip,jp,3,i,j,2)=&
             .1038547178264951d0*(48.d0*c**5+264.d0*c**4*d+594.d0*c**3*d**2+&
             693.d0*c**2*d**3+308.d0*c*d**4+56.d0*d**5)/&
             (c**3*d**4*scpd**11)

        vh(ip,jp,0,i,j,3)=.0830837742611961d0*&
             (35.d0*c**3+70.d0*c**2*d+56.d0*c*d**2+16.d0*d**3)/&
             (c**4*d*scpd**7)
        vh(ip,jp,1,i,j,3)=&
             .04154188713059803d0*(70.d0*c**4+315.d0*c**3*d+378.d0*c**2*d**2+&
             216.d0*c*d**3+48.d0*d**4)/(c**4*d**2*scpd**9)
        vh(ip,jp,2,i,j,3)=&
             .1038547178264951d0*(56.d0*c**5+308.d0*c**4*d+693.d0*c**3*d**2+&
             594.d0*c**2*d**3+264.d0*c*d**4+48.d0*d**5)/&
             (c**4*d**3*scpd**11)
        vh(ip,jp,3,i,j,3)=&
             1.090474537178198d0*(16.d0*c**6+104.d0*c**5*d+286.d0*c**4*d**2+&
             429.d0*c**3*d**3+286.d0*c**2*d**4+104.d0*c*d**5+16.d0*d**6)/&
             (c**4*d**4*scpd**13)
100        continue
        return
        end subroutine crtvh

        real*8 function wave(ng,ll,xp,psi,r)
        implicit real*8 (a-h,o-z)
        dimension psi(0:ng),xp(0:ng)

        wave=0.d0
        do 9373,i=0,ng
9373    wave=wave + psi(i)*exp(-xp(i)*r**2)
        wave=wave*r**ll
        return
        end function wave


      real*8 function emuxc(rho)
      implicit real*8 (a-h,o-z)
      parameter (a0p=.4581652932831429d0,&
           a1p=2.217058676663745d0,&
           a2p=0.7405551735357053d0,&
           a3p=0.01968227878617998d0)
      parameter (b1p=1.0d0,&
           b2p=4.504130959426697d0,&
           b3p=1.110667363742916d0,&
           b4p=0.02359291751427506d0)
      parameter (rsfac=.6203504908994000d0,ot=1.d0/3.d0)
      parameter (c1=4.d0*a0p*b1p/3.0d0,  c2=5.0d0*a0p*b2p/3.0d0+a1p*b1p,&
           c3=2.0d0*a0p*b3p+4.0d0*a1p*b2p/3.0d0+2.0d0*a2p*b1p/3.0d0,&
           c4=7.0d0*a0p*b4p/3.0d0+5.0d0*a1p*b3p/3.0d0+a2p*b2p+a3p*b1p/3.0d0,&
           c5=2.0d0*a1p*b4p+4.0d0*a2p*b3p/3.0d0+2.0d0*a3p*b2p/3.0d0,&
           c6=5.0d0*a2p*b4p/3.0d0+a3p*b3p,c7=4.0d0*a3p*b4p/3.0d0)
      if(rho.lt.1.d-24) then
        emuxc=0.d0
      else
        if(rho.lt.0.d0) write(6,*) ' rho less than zero',rho
        rs=rsfac*rho**(-ot)
        top=-rs*(c1+rs*(c2+rs*(c3+rs*(c4+rs*(c5+rs*(c6+rs*c7))))))
        bot=rs*(b1p+rs*(b2p+rs*(b3p+rs*b4p)))
        emuxc=top/(bot*bot)
      end if
      end function emuxc

      real*8 function gamma(x)
!     restricted version of the Gamma function
      implicit real*8 (a-h,o-z)

      if (x.le.0.d0) stop 'wrong argument for gamma'
      if (mod(x,1.d0).eq.0.d0) then
         ii=x
         do i=2,ii
            gamma=gamma*(i-1)
         end do
      else if (mod(x,.5d0).eq.0.d0) then
         ii=x-.5d0
!         gamma=sqrt(3.14159265358979d0)
         gamma=1.772453850905516027d0
         do i=1,ii
            gamma=gamma*(i-.5d0)
         end do
      else
         stop 'wrong argument for gamma'
      end if
      end function gamma
