program BigDFT

  use libBigDFT

  implicit real(kind=8) (a-h,o-z)

  ! For parallel MPI execution set parallel=.true., for serial parallel=.false.
  include 'parameters.h'

  ! atomic coordinates, forces
  real(kind=8), allocatable, dimension(:,:) :: rxyz, fxyz, rxyz_old
   logical :: output_wf,output_grid,calc_tail
  character(len=20) :: tatonam
  character(len=80) :: line
  ! atomic types
  integer, allocatable, dimension(:) :: iatype
  character(len=20) :: atomnames(100), units
  character(len=6), dimension(:), allocatable :: frzsymb
  logical, dimension(:), allocatable :: lfrztyp
  real(kind=8), pointer :: psi(:,:), eval(:)
  integer, pointer :: keyv(:), keyg(:,:)
  !$      interface
  !$        integer ( kind=4 ) function omp_get_num_threads ( )
  !$        end function omp_get_num_threads
  !$      end interface
  !$      interface
  !$        integer ( kind=4 ) function omp_get_thread_num ( )
  !$        end function omp_get_thread_num
  !$      end interface
  include 'mpif.h'

  ! Start MPI in parallel version
  if (parallel) then
     call MPI_INIT(ierr)
     call MPI_COMM_RANK(MPI_COMM_WORLD,iproc,ierr)
     call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)
!!$     write(unit=line,fmt='(a,i0,a,i0,a)') &
!!$          'echo "- mpi started iproc=',iproc,'/',nproc,' host: `hostname`"'
!!$     call system(trim(line))
  else
     nproc=1
     iproc=0
  endif

  !initialize memory counting
  call memocc(0,0,'count','start')

  !$omp parallel private(iam)  shared (npr)
  !$       iam=omp_get_thread_num()
  !$       if (iam.eq.0) npr=omp_get_num_threads()
  !$       write(*,*) 'iproc,iam,npr',iproc,iam,npr
  !$omp end parallel


! Read the input variables.
  open(unit=1,file='input.dat',status='old')
  read(1,*) ncount_cluster_x
  read(1,*) frac_fluct
  read(1,*) randdis
  read(1,*) betax
  read(1,*) hgrid
  read(1,*) crmult
  read(1,*) frmult
  read(1,*) cpmult
  read(1,*) fpmult
  if (fpmult.gt.frmult) write(*,*) 'NONSENSE: fpmult > frmult'
  read(1,*) ixc
  read(1,*) ncharge,elecfield
  read(1,*) gnrm_cv
  read(1,*) itermax
  read(1,*) ncong
  read(1,*) idsx
  read(1,*) calc_tail
  read(1,*) rbuf
  read(1,*) ncongt
  read(1,*) nspin,mpol
  close(1)


  ! read atomic positions
        open(unit=99,file='posinp',status='old')
        read(99,*) nat,units
  if (iproc.eq.0) write(*,'(1x,a,i0)') 'nat= ',nat
  allocate(rxyz_old(3,nat),stat=i_stat)
  call memocc(i_stat,product(shape(rxyz_old))*kind(rxyz_old),'rxyz_old','BigDFT')
  allocate(rxyz(3,nat),stat=i_stat)
  call memocc(i_stat,product(shape(rxyz))*kind(rxyz),'rxyz','BigDFT')
  allocate(iatype(nat),stat=i_stat)
  call memocc(i_stat,product(shape(iatype))*kind(iatype),'iatype','BigDFT')
  allocate(fxyz(3,nat),stat=i_stat)
  call memocc(i_stat,product(shape(fxyz))*kind(fxyz),'fxyz','BigDFT')
  ntypes=0
  do iat=1,nat
        read(99,*) rxyz(1,iat),rxyz(2,iat),rxyz(3,iat),tatonam
!! For reading in saddle points
!!        open(unit=83,file='step',status='old')
!!        read(83,*) step
!!        close(83)
!        step= .5d0
!        if (iproc.eq.0) write(*,*) 'step=',step
!        read(99,*) rxyz(1,iat),rxyz(2,iat),rxyz(3,iat),tatonam,t1,t2,t3
!        rxyz(1,iat)=rxyz(1,iat)+step*t1
!        rxyz(2,iat)=rxyz(2,iat)+step*t2
!        rxyz(3,iat)=rxyz(3,iat)+step*t3

     do ityp=1,ntypes
        if (tatonam.eq.atomnames(ityp)) then
           iatype(iat)=ityp
           goto 200
        endif
     enddo
     ntypes=ntypes+1
     if (ntypes.gt.100) stop 'more than 100 atomnames not permitted'
     atomnames(ityp)=tatonam
     iatype(iat)=ntypes
200  continue
     if (units.eq.'angstroem') then
        ! if Angstroem convert to Bohr
        do i=1,3 
           rxyz(i,iat)=rxyz(i,iat)/.529177d0  
        enddo
     else if  (units.eq.'atomic' .or. units.eq.'bohr') then
     else
        write(*,*) 'length units in input file unrecognized'
        write(*,*) 'recognized units are angstroem or atomic = bohr'
        stop 
     endif
  enddo
        close(99)
  do ityp=1,ntypes
     if (iproc.eq.0) &
          write(*,'(1x,a,i0,a,a)') 'atoms of type ',ityp,' are ',trim(atomnames(ityp))
  enddo
  
  !  Read the first line of "input.dat"
  open(unit=1,file='input.dat',status='old')
  !Only the first line for the main routine (the program)
  ! ngeostep Number of steps of geometry optimisation (default 500)
  ! ampl     Amplitude for random displacement away from input file geometry 
  ! (usually equilibrium geom.)
  ! betax    Geometry optimisation

  !for the moment avoid the possibility of blocked atoms
  allocate(lfrztyp(ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(lfrztyp))*kind(lfrztyp),'lfrztyp','BigDFT')
  lfrztyp(:)=.false.

!!$  read(1,'(a80)')line
!!$  close(unit=1)
!!$  
!!$  read(line,*,iostat=ierror)ngeostep,ampl,betax,nfrztyp
!!$  if (ierror /= 0) then
!!$     read(line,*)ngeostep,ampl,betax
!!$     lfrztyp(:)=.false.
!!$  else
!!$     allocate(frzsymb(nfrztyp),stat=i_stat)
!!$     call memocc(i_stat,product(shape(frzsymb))*kind(frzsymb),'frzsymb','BigDFT')
!!$     read(line,*,iostat=ierror)ngeostep,ampl,betax,nfrztyp,(frzsymb(i),i=1,nfrztyp)
!!$     lfrztyp(:)=.false.
!!$     do ityp=1,nfrztyp
!!$        seek_frozen: do jtyp=1,ntypes
!!$           if (trim(frzsymb(ityp))==trim(atomnames(jtyp))) then
!!$              lfrztyp(jtyp)=.true.
!!$              exit seek_frozen
!!$           end if
!!$        end do seek_frozen
!!$     end do
!!$     i_all=-product(shape(frzsymb))*kind(frzsymb)
!!$     deallocate(frzsymb,stat=i_stat)
!!$     call memocc(i_stat,i_all,'frzsymb','BigDFT')
!!$  end if

  !ampl=0.d0!2.d-2  
  if (iproc.eq.0) then
      write(*,'(1x,a,i0)') 'Max. number of wavefnctn optim ',ncount_cluster_x
      write(*,'(1x,a,1pe10.2)') 'Convergence criterion for forces: fraction of noise ',frac_fluct
      write(*,'(1x,a,1pe10.2)') 'Random displacement amplitude ',randdis
      write(*,'(1x,a,1pe10.2)') 'Steepest descent step ',betax
  end if
  do iat=1,nat
     if (.not. lfrztyp(iatype(iat))) then
        call random_number(tt)
        rxyz(1,iat)=rxyz(1,iat)+randdis*tt
        call random_number(tt)
        rxyz(2,iat)=rxyz(2,iat)+randdis*tt
        call random_number(tt)
        rxyz(3,iat)=rxyz(3,iat)+randdis*tt
     end if
  enddo
  
  output_grid=.false. 
  inputPsiId=0
  output_wf=.false. 
  call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,rxyz,energy,fxyz, &
       psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   inputPsiId, output_grid, output_wf, n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
     do iat=1,nat
     rxyz_old(1,iat) = rxyz(1,iat) 
     rxyz_old(2,iat) = rxyz(2,iat) 
     rxyz_old(3,iat) = rxyz(3,iat)
  enddo

  if (ngeostep > 1) then
     if (iproc ==0 ) write(*,"(a,2i5)") 'FINISHED FIRST CLUSTER, exit signal=',infocode
     ! geometry optimization
     !    betax=2.d0   ! Cincodinine
     !    betax=4.d0  ! Si H_4
     !   betax=7.5d0  ! silicon systems
     !    betax=10.d0  !  Na_Cl clusters
   ncount_cluster=1
   beta=betax
   energyold=1.d100
    call conjgrad(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,rxyz,etot,fxyz, &
         psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
         n1,n2,n3,rxyz_old,betax,ncount_cluster_x,ncount_cluster,frac_fluct, &
         hgrid,crmult,frmult,cpmult,fpmult,ixc,ncharge,elecfield,gnrm_cv,itermax,ncong,idsx)
  end if
  
  if (iproc.eq.0) then
     sumx=0.d0
     sumy=0.d0
     sumz=0.d0
     write(*,'(1x,a,19x,a)') 'Final values of the Forces for each atom'
     do iat=1,nat
        write(*,'(1x,i5,1x,a6,3(1x,1pe12.5))') &
             iat,trim(atomnames(iatype(iat))),(fxyz(j,iat),j=1,3)
         sumx=sumx+fxyz(1,iat)
         sumy=sumy+fxyz(2,iat)
         sumz=sumz+fxyz(3,iat)
      enddo
      write(*,'(1x,a)')'the sum of the forces is'
      write(*,'(1x,a16,3x,1pe16.8)')'x direction',sumx
      write(*,'(1x,a16,3x,1pe16.8)')'y direction',sumy
      write(*,'(1x,a16,3x,1pe16.8)')'z direction',sumz
   endif
 
   
   
  !deallocations
  i_all=-product(shape(psi))*kind(psi)
  deallocate(psi,stat=i_stat)
  call memocc(i_stat,i_all,'psi','BigDFT')
  i_all=-product(shape(eval))*kind(eval)
  deallocate(eval,stat=i_stat)
  call memocc(i_stat,i_all,'eval','BigDFT')
  i_all=-product(shape(keyg))*kind(keyg)
  deallocate(keyg,stat=i_stat)
  call memocc(i_stat,i_all,'keyg','BigDFT')
  i_all=-product(shape(keyv))*kind(keyv)
  deallocate(keyv,stat=i_stat)
  call memocc(i_stat,i_all,'keyv','BigDFT')
  i_all=-product(shape(rxyz))*kind(rxyz)
  deallocate(rxyz,stat=i_stat)
  call memocc(i_stat,i_all,'rxyz','BigDFT')
  i_all=-product(shape(rxyz_old))*kind(rxyz_old)
  deallocate(rxyz_old,stat=i_stat)
  call memocc(i_stat,i_all,'rxyz_old','BigDFT')
  i_all=-product(shape(iatype))*kind(iatype)
  deallocate(iatype,stat=i_stat)
  call memocc(i_stat,i_all,'iatype','BigDFT')
  i_all=-product(shape(fxyz))*kind(fxyz)
  deallocate(fxyz,stat=i_stat)
  call memocc(i_stat,i_all,'fxyz','BigDFT')


  !finalize memory counting
  call memocc(0,0,'count','stop')

  if (parallel) call MPI_FINALIZE(ierr)

 contains

    subroutine  conjgrad(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,gg, &
         psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
         n1,n2,n3,rxyz_old,betax,ncount_cluster_x,ncount_cluster,frac_fluct, &
         hgrid,crmult,frmult,cpmult,fpmult,ixc,ncharge,elecfield,gnrm_cv,itermax,ncong,idsx)
   use libBigDFT
     implicit real(kind=8) (a-h,o-z)
   logical :: parallel
   integer :: iatype(nat)
     character(len=20) :: atomnames(100)
     real(kind=8), pointer :: psi(:,:), eval(:)
   integer, pointer :: keyv(:), keyg(:,:)
        dimension wpos(3,nat),gg(3,nat),rxyz_old(3,nat)
     real(kind=8), allocatable, dimension(:,:) :: tpos,gp,hh

        allocate(tpos(3,nat),gp(3,nat),hh(3,nat))
        anoise=1.d-4
   fluct=-1.d100
   flucto=-1.d100

!    Open a log file for conjgrad
     open(unit=16,file='conjgrad.prc',status='unknown')

	if (betax.le.0.d0) then
        call detbetax(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos, &
             psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
             n1, n2, n3, hgrid, rxyz_old, betax, itermax, ncong, idsx,  & 
             crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv)
        endif

        avbeta=0.d0
        avnum=0.d0
        nfail=0
!        call steepdes(nat,fnrmtol,betax,alat,wpos,gg,etot,count_sd)
        call steepdes(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   n1, n2, n3, hgrid, rxyz_old, frac_fluct,itermax, ncong, idsx,  & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   betax,ncount_cluster_x,ncount_cluster,fluct,flucto,fluctoo,fnrm)
        if (fnrm.lt.sqrt(1.d0*nat)*(fluct+flucto+fluctoo)*frac_fluct/3.d0) then
        if (iproc.eq.0) write(16,*) 'Converged before entering CG',iproc
        return
        endif

12345   continue

        etotprec=etot
        do 294,iat=1,nat
        hh(1,iat)=gg(1,iat)
        hh(2,iat)=gg(2,iat)
294     hh(3,iat)=gg(3,iat)

        beta0=4.d0*betax
        it=0
1000    it=it+1

!C line minimize along hh ----

        do 394,iat=1,nat
        tpos(1,iat)=wpos(1,iat)+beta0*hh(1,iat)
        tpos(2,iat)=wpos(2,iat)+beta0*hh(2,iat)
394     tpos(3,iat)=wpos(3,iat)+beta0*hh(3,iat)
!        call energyandforces(nat,alat,tpos,gp,tetot,count_cg)

      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,tpos,tetot,gp, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
     do iat=1,nat
     rxyz_old(1,iat)=tpos(1,iat) ; rxyz_old(2,iat)=tpos(2,iat) ; rxyz_old(3,iat)=tpos(3,iat)
     enddo
      ncount_cluster=ncount_cluster+1

!C projection of gradients at beta=0 and beta onto hh
        y0=0.d0
        y1=0.d0
        do 334,iat=1,nat
          y0=y0+gg(1,iat)*hh(1,iat)+gg(2,iat)*hh(2,iat)+gg(3,iat)*hh(3,iat)
          y1=y1+gp(1,iat)*hh(1,iat)+gp(2,iat)*hh(2,iat)+gp(3,iat)*hh(3,iat)
334     continue
        tt=y0/(y0-y1)
        if (iproc.eq.0) write(16,'(a,2(1x,e10.3),2x,e12.5)')  'y0,y1,y0/(y0-y1)',y0,y1,tt
        if (iproc.eq.0) write(*,'(a,2(1x,e10.3),2x,e12.5)')  'y0,y1,y0/(y0-y1)',y0,y1,tt

        beta=beta0*max(min(tt,2.d0),-.25d0)
!        beta=beta0*max(min(tt,1.d0),-.25d0)
!        beta=beta0*max(min(tt,10.d0),-1.d0)
!        beta=beta0*tt
        do 494,iat=1,nat
        tpos(1,iat)=wpos(1,iat)
        tpos(2,iat)=wpos(2,iat)
        tpos(3,iat)=wpos(3,iat)
        wpos(1,iat)=wpos(1,iat)+beta*hh(1,iat)
        wpos(2,iat)=wpos(2,iat)+beta*hh(2,iat)
494     wpos(3,iat)=wpos(3,iat)+beta*hh(3,iat)
        avbeta=avbeta+beta/betax
        avnum=avnum+1.d0
        
!C new gradient
        do 194,iat=1,nat
        gp(1,iat)=gg(1,iat)
        gp(2,iat)=gg(2,iat)
194     gp(3,iat)=gg(3,iat)

!        call energyandforces(nat,alat,wpos,gg,etot,count_cg)

      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
     do iat=1,nat
     rxyz_old(1,iat)=wpos(1,iat) ; rxyz_old(2,iat)=wpos(2,iat) ; rxyz_old(3,iat)=wpos(3,iat)
     enddo
      ncount_cluster=ncount_cluster+1
      sumx=0.d0 ; sumy=0.d0 ; sumz=0.d0
      do iat=1,nat
         sumx=sumx+gg(1,iat) ; sumy=sumy+gg(2,iat) ; sumz=sumz+gg(3,iat)
      end do

        if (etot.gt.etotprec+anoise) then
        if (iproc.eq.0) write(16,*) 'switching back to SD:etot,etotprec',it,etot,etotprec
        if (iproc.eq.0) write(*,*) 'switching back to SD:etot,etotprec',it,etot,etotprec
        do 694,iat=1,nat
        wpos(1,iat)=tpos(1,iat)
        wpos(2,iat)=tpos(2,iat)
694     wpos(3,iat)=tpos(3,iat)
!        call steepdes(nat,fnrmtol,betax,alat,wpos,gg,etot,count_sd)
        call steepdes(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   n1, n2, n3, hgrid, rxyz_old, frac_fluct,itermax, ncong, idsx,  & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   betax,ncount_cluster_x,ncount_cluster,fluct,flucto,fluctoo,fnrm)
        goto 12345
        endif
        etotprec=etot
        if (iproc.eq.0) call wtposout(ncount_cluster,etot,nat,wpos,atomnames,iatype)
        fluctoo=flucto
        flucto=fluct
        fluct=sumx**2+sumy**2+sumz**2

        obenx=0.d0
        obeny=0.d0
        obenz=0.d0
        unten=0.d0
        fnrm=0.d0
        do 803,iat=1,nat
        obenx=obenx+(gg(1,iat)-gp(1,iat))*gg(1,iat)
        obeny=obeny+(gg(2,iat)-gp(2,iat))*gg(2,iat)
        obenz=obenz+(gg(3,iat)-gp(3,iat))*gg(3,iat)
        unten=unten+gp(1,iat)**2+gp(2,iat)**2+gp(3,iat)**2
        fnrm=fnrm+gg(1,iat)**2+gg(2,iat)**2+gg(3,iat)**2
803     continue
        if (iproc.eq.0) write(16,'(i5,1x,e12.5,1x,e21.14,a,1x,e9.2)') it,sqrt(fnrm),etot,' CG ',beta/betax
        if (iproc.eq.0) write(16,*) 'fnrm2,flucts',fnrm,sqrt(1.d0*nat)*(fluct+flucto+fluctoo)*frac_fluct/3.d0
        if (fnrm.lt.sqrt(1.d0*nat)*(fluct+flucto+fluctoo)*frac_fluct/3.d0) goto 2000
        if (ncount_cluster.gt.ncount_cluster_x) then 
           if (iproc.eq.0) write(*,*) 'ncount_cluster in CG',ncount_cluster
           goto 2000
        endif
        if (it.eq.500) then
        if (iproc.eq.0) write(16,*) 'NO conv in CG after 500 its: switching back to SD',it,fnrm,etot
        write(*,*) 'NO conv in CG after 500 its: switching back to SD',it,fnrm,etot
        do 698,iat=1,nat
        wpos(1,iat)=tpos(1,iat)
        wpos(2,iat)=tpos(2,iat)
698     wpos(3,iat)=tpos(3,iat)
!        call steepdes(nat,fnrmtol,betax,alat,wpos,gg,etot,count_sd)
        call steepdes(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   n1, n2, n3, hgrid, rxyz_old, frac_fluct,itermax, ncong, idsx,  & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   betax,ncount_cluster_x,ncount_cluster,fluct,flucto,fluctoo,fnrm)
        nfail=nfail+1
        if (nfail.ge.100) stop 'too many failures of CONJG'
        goto 12345
        endif
        rlambda=(obenx+obeny+obenz)/unten
        do 794,iat=1,nat
        hh(1,iat)=gg(1,iat)+rlambda*hh(1,iat)
        hh(2,iat)=gg(2,iat)+rlambda*hh(2,iat)
794     hh(3,iat)=gg(3,iat)+rlambda*hh(3,iat)
        
        goto 1000    
2000    continue
!!        write(6,*) 'CG finished',it,fnrm,etot
        if (iproc.eq.0) write(16,*) 'average CG stepsize in terms of betax',avbeta/avnum,iproc
        if (iproc.eq.0) write(*,*) 'average CG stepsize in terms of betax',avbeta/avnum,iproc

        deallocate(tpos,gp,hh)

!    Close the file
     close(unit=16)
        end subroutine conjgrad

       subroutine steepdes(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,ff, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   n1, n2, n3, hgrid, rxyz_old, frac_fluct,itermax, ncong, idsx,  & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   betax,ncount_cluster_x,ncount_cluster,fluct,flucto,fluctoo,fnrm)
   use libBigDFT
     implicit real(kind=8) (a-h,o-z)
   logical :: parallel
   integer :: iatype(nat)
     character(len=20) :: atomnames(100)
     real(kind=8), pointer :: psi(:,:), eval(:)
   integer, pointer :: keyv(:), keyg(:,:)
        dimension wpos(3,nat),ff(3,nat),rxyz_old(3,nat)
     real(kind=8), allocatable, dimension(:,:) :: tpos
        logical care
        allocate(tpos(3,nat))
        anoise=0.d-4

        beta=betax
        care=.true.
        nsatur=0
        etotitm2=1.d100
        fnrmitm2=1.d100
        etotitm1=1.d100
        fnrmitm1=1.d100

        do 12,iat=1,nat
        tpos(1,iat)=wpos(1,iat)
        tpos(2,iat)=wpos(2,iat)
12      tpos(3,iat)=wpos(3,iat)

        itot=0
12345   continue
        if (ncount_cluster.gt.ncount_cluster_x) then 
           if (iproc.eq.0) write(*,*) 'ncount_cluster in SD1',ncount_cluster
           goto 2000
        endif
        nitsd=500
        itsd=0
1000    itsd=itsd+1
        itot=itot+1
!        call energyandforces(nat,alat,wpos,ff,etot,count_sd)
      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,wpos,etot,ff, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
      ncount_cluster=ncount_cluster+1
     do iat=1,nat
     rxyz_old(1,iat)=wpos(1,iat) ; rxyz_old(2,iat)=wpos(2,iat) ; rxyz_old(3,iat)=wpos(3,iat)
     enddo
        if (care .and. etot.gt.etotitm1+anoise) then
          do 20,iat=1,nat
          wpos(1,iat)=tpos(1,iat)
          wpos(2,iat)=tpos(2,iat)
20        wpos(3,iat)=tpos(3,iat)
          beta=.5d0*beta
          if (iproc.eq.0) write(16,'(a,1x,e9.2,1x,i5,2(1x,e21.14))') 'SD reset, beta,itsd,etot,etotitm1= ', &
                                                           beta,itsd,etot,etotitm1
          if (beta.le.1.d-1*betax) then
            if (iproc.eq.0) write(16,*) 'beta getting too small, do not care anymore if energy goes up'
            care=.false.
          endif
          goto 12345
        endif
        
        t1=0.d0 ; t2=0.d0 ; t3=0.d0
        do iat=1,nat
        t1=t1+ff(1,iat)**2 ; t2=t2+ff(2,iat)**2 ; t3=t3+ff(3,iat)**2
        enddo
        fnrm=t1+t2+t3
        de1=etot-etotitm1
        de2=etot-2.d0*etotitm1+etotitm2
        df1=fnrm-fnrmitm1
        df2=fnrm-2.d0*fnrmitm1+fnrmitm2
        if (iproc.eq.0) write(16,'(5(1x,e11.4),1x,i3)') fnrm/fnrmitm1, de1,de2,df1,df2,nsatur
       if (care .and. itsd.ge.3 .and. beta.eq.betax .and. fnrm/fnrmitm1.gt..8d0 .and. &
          de1.gt.-.1d0 .and. fnrm.le..1d0 .and. & 
          de1.lt.anoise .and. df1.lt.anoise .and. &
          de2.gt.-2.d0*anoise .and. df2.gt.-2.d0*anoise) then 
         nsatur=nsatur+1
       else
         nsatur=0
       endif
        if (iproc.eq.0) write(16,'(i5,1x,e12.5,1x,e21.14,a)') itsd,sqrt(fnrm),etot,' SD '

        if (iproc.eq.0) call wtposout(ncount_cluster,etot,nat,wpos,atomnames,iatype)
        fluctoo=flucto
        flucto=fluct
        sumx=0.d0 
        sumy=0.d0 
        sumz=0.d0
        do iat=1,nat
           sumx=sumx+ff(1,iat) ; sumy=sumy+ff(2,iat) ; sumz=sumz+ff(3,iat)
        end do
        fluct=sumx**2+sumy**2+sumz**2
        if (iproc.eq.0) write(16,*) 'fnrm2,flucts',fnrm,sqrt(1.d0*nat)*(fluct+flucto+fluctoo)*frac_fluct/3.d0
        if (fnrm.lt.sqrt(1.d0*nat)*(fluct+flucto+fluctoo)*frac_fluct/3.d0) goto 2000
        if (nsatur.gt.5) goto 2000
        if (ncount_cluster.gt.ncount_cluster_x) then 
           if (iproc.eq.0) write(*,*) 'ncount_cluster in SD2',ncount_cluster
           goto 2000
        endif
        if (itsd.ge.nitsd) then 
           if (iproc.eq.0) write(16,'(a,i5,1x,e10.3,1x,e21.14)') 'SD: NO CONVERGENCE:itsd,fnrm,etot',itsd,fnrm,etot
          goto 2000
        endif
        if (itot.ge.nitsd) then
           if (iproc.eq.0) write(16,'(a,i5,i5,1x,e10.3,1x,e21.14)') 'SD: NO CONVERGENCE:itsd,itot,fnrm,etot:',itsd,itot,fnrm,etot
          goto 2000
        endif

        etotitm2=etotitm1
        etotitm1=etot
        fnrmitm2=fnrmitm1
        fnrmitm1=fnrm
        beta=min(1.2d0*beta,betax)
        if (beta.eq.betax) then 
          if (iproc.eq.0) write(16,*) 'beta=betax'
          care=.true.
        endif
          if (iproc.eq.0) write(16,*) 'beta=',beta
        do 10,iat=1,nat
        tpos(1,iat)=wpos(1,iat)
        tpos(2,iat)=wpos(2,iat)
        tpos(3,iat)=wpos(3,iat)
        wpos(1,iat)=wpos(1,iat)+beta*ff(1,iat)
        wpos(2,iat)=wpos(2,iat)+beta*ff(2,iat)
10      wpos(3,iat)=wpos(3,iat)+beta*ff(3,iat)

        goto 1000
2000        continue
        if (iproc.eq.0) write(16,*) 'SD FINISHED',iproc

        deallocate(tpos)
        end subroutine steepdes


      subroutine detbetax(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,pos, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   n1, n2, n3, hgrid, rxyz_old, betax, itermax, ncong, idsx,  & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv)
! determines stepsize betax
   use libBigDFT
        implicit real(kind=8) (a-h,o-z)
   logical :: parallel
   integer :: iatype(nat)
        character(len=20) :: atomnames(100)
        real(kind=8), pointer :: psi(:,:), eval(:)
   integer, pointer :: keyv(:), keyg(:,:)
        dimension pos(3,nat),alat(3),rxyz_old(3,nat)
        real(kind=8), allocatable, dimension(:,:) :: tpos,ff,gg
        allocate(tpos(3,nat),ff(3,nat),gg(3,nat))

        beta0=abs(betax)
        beta=1.d100


        nsuc=0
100     continue
!        call energyandforces(nat,alat,pos,ff,etotm1,count)
      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,pos,etotm1,ff, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
      ncount_cluster=ncount_cluster+1
     do iat=1,nat
     rxyz_old(1,iat)=pos(1,iat) ; rxyz_old(2,iat)=pos(2,iat) ; rxyz_old(3,iat)=pos(3,iat)
     enddo
          sum=0.d0
          do iat=1,nat
          tpos(1,iat)=pos(1,iat)
          tpos(2,iat)=pos(2,iat)
          tpos(3,iat)=pos(3,iat)
          t1=beta0*ff(1,iat)
          t2=beta0*ff(2,iat)
          t3=beta0*ff(3,iat)
          sum=sum+t1**2+t2**2+t3**2
          pos(1,iat)=pos(1,iat)+t1
          pos(2,iat)=pos(2,iat)+t2
          pos(3,iat)=pos(3,iat)+t3
          enddo
!        call energyandforces(nat,alat,pos,gg,etot0,count)
      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,pos,etot0,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
      ncount_cluster=ncount_cluster+1
     do iat=1,nat
     rxyz_old(1,iat)=pos(1,iat) ; rxyz_old(2,iat)=pos(2,iat) ; rxyz_old(3,iat)=pos(3,iat)
     enddo
          if (etot0.gt.etotm1) then
            do iat=1,nat
            pos(1,iat)=tpos(1,iat)
            pos(2,iat)=tpos(2,iat)
            pos(3,iat)=tpos(3,iat)
            enddo
            beta0=.5d0*beta0
            if (iproc.eq.0) write(16,*) 'beta0 reset',beta0
          goto 100
          endif
          do iat=1,nat
          tpos(1,iat)=pos(1,iat)+beta0*ff(1,iat)
          tpos(2,iat)=pos(2,iat)+beta0*ff(2,iat)
          tpos(3,iat)=pos(3,iat)+beta0*ff(3,iat)
          enddo
!        call energyandforces(nat,alat,tpos,gg,etotp1,count)
      call call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,tpos,etotp1,gg, &
                   psi, keyg, keyv, nvctr_c, nvctr_f, nseg_c, nseg_f, norbp, norb, eval, &
                   1, .false., .false., n1, n2, n3, hgrid, rxyz_old, & 
                   crmult, frmult, cpmult, fpmult, ixc, ncharge,elecfield, gnrm_cv, &
                   itermax, ncong, idsx, calc_tail, rbuf, ncongt,nspin,mpol, infocode)
      ncount_cluster=ncount_cluster+1
     do iat=1,nat
     rxyz_old(1,iat)=tpos(1,iat) ; rxyz_old(2,iat)=tpos(2,iat) ; rxyz_old(3,iat)=tpos(3,iat)
     enddo
        if (iproc.eq.0) write(16,'(a,3(1x,e21.14))') 'etotm1,etot0,etotp1',etotm1,etot0,etotp1
        der2=(etotp1+etotm1-2.d0*etot0)/sum
        tt=.25d0/der2
        beta0=.125d0/der2
        if (iproc.eq.0) write(16,*) 'der2,tt=',der2,tt
        if (der2.gt.0.d0) then
          nsuc=nsuc+1
          beta=min(beta,.5d0/der2)
        endif
          do iat=1,nat
          pos(1,iat)=pos(1,iat)+tt*ff(1,iat)
          pos(2,iat)=pos(2,iat)+tt*ff(2,iat)
          pos(3,iat)=pos(3,iat)+tt*ff(3,iat)
          enddo
        if (count.gt.100.d0) then
           if (iproc.eq.0) write(16,*) 'CANNOT DETERMINE betax '
           stop
        endif
       if (nsuc.lt.3) goto 100

       betax=beta
       if (iproc.eq.0) write(16,*) 'betax=',betax

        deallocate(tpos,ff,gg)
        end subroutine

 subroutine call_cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,rxyz,energy,fxyz,&
           psi,keyg,keyv,nvctr_c,nvctr_f,nseg_c,nseg_f,norbp,norb,eval,inputPsiId_orig,&
           output_grid,output_wf,n1,n2,n3,hgrid,rxyz_old, & 
           crmult,frmult,cpmult,fpmult,ixc,ncharge,elecfield,gnrm_cv,&
           itermax,ncong,idsx,calc_tail,rbuf,ncongt,nspin,mpol,infocode)
        use libBigDFT
        implicit none
        logical, intent(in) :: parallel,output_grid,output_wf,calc_tail
        integer, intent(in) :: iproc,nproc,nat,ntypes,norbp,norb,inputPsiId_orig
        integer, intent(in) :: nvctr_c,nvctr_f,nseg_c,nseg_f
        integer, intent(in) :: ixc,ncharge,itermax,ncong,idsx,ncongt,nspin,mpol
        integer, intent(inout) :: infocode,n1,n2,n3
        integer :: inputPsiId,i_stat,i_all,ierr
        real(kind=8), intent(in) :: crmult,frmult,cpmult,fpmult,elecfield,gnrm_cv,rbuf
        real(kind=8), intent(inout) :: hgrid
        real(kind=8), intent(out) :: energy
        character(len=20), dimension(100), intent(in) :: atomnames
        integer, dimension(nat), intent(in) :: iatype
        real(kind=8), dimension(3,nat), intent(in) :: rxyz_old
        real(kind=8), dimension(3,nat), intent(inout) :: rxyz
        real(kind=8), dimension(3,nat), intent(out) :: fxyz
        integer, dimension(:), pointer :: keyv
        integer, dimension(:,:), pointer :: keyg
        real(kind=8), dimension(:), pointer :: eval
        real(kind=8), dimension(:,:), pointer :: psi

        inputPsiId=inputPsiId_orig

        loop_cluster: do

           if (inputPsiId == 0 .and. associated(psi)) then
              i_all=-product(shape(psi))*kind(psi)
              deallocate(psi,stat=i_stat)
              call memocc(i_stat,i_all,'psi','call_cluster')
              i_all=-product(shape(eval))*kind(eval)
              deallocate(eval,stat=i_stat)
              call memocc(i_stat,i_all,'eval','call_cluster')
              i_all=-product(shape(keyg))*kind(keyg)
              deallocate(keyg,stat=i_stat)
              call memocc(i_stat,i_all,'keyg','call_cluster')
              i_all=-product(shape(keyv))*kind(keyv)
              deallocate(keyv,stat=i_stat)
              call memocc(i_stat,i_all,'keyv','call_cluster')
           end if

           call cluster(parallel,nproc,iproc,nat,ntypes,iatype,atomnames,rxyz,energy,fxyz,&
                psi,keyg,keyv,nvctr_c,nvctr_f,nseg_c,nseg_f,norbp,norb,eval,inputPsiId,&
                output_grid,output_wf,n1,n2,n3,hgrid,rxyz_old,& 
                crmult,frmult,cpmult,fpmult,ixc,ncharge,elecfield,gnrm_cv,&
                itermax,ncong,idsx,calc_tail,rbuf,ncongt,nspin,mpol,infocode)

           if (inputPsiId==1 .and. infocode==2) then
              inputPsiId=0
           else if (inputPsiId == 0 .and. infocode==3) then
              if (iproc.eq.0) then
                 write(*,'(1x,a)')'Convergence error, cannot proceed.'
                 write(*,'(1x,a)')' writing positions in file posout_999.ascii then exiting'
                 call wtposout(999,energy,nat,rxyz,atomnames,iatype)
              end if

              i_all=-product(shape(psi))*kind(psi)
              deallocate(psi,stat=i_stat)
              call memocc(i_stat,i_all,'psi','call_cluster')
              i_all=-product(shape(eval))*kind(eval)
              deallocate(eval,stat=i_stat)
              call memocc(i_stat,i_all,'eval','call_cluster')
              i_all=-product(shape(keyg))*kind(keyg)
              deallocate(keyg,stat=i_stat)
              call memocc(i_stat,i_all,'keyg','call_cluster')
              i_all=-product(shape(keyv))*kind(keyv)
              deallocate(keyv,stat=i_stat)
              call memocc(i_stat,i_all,'keyv','call_cluster')

              !finalize memory counting (there are still the positions and the forces allocated)
              call memocc(0,0,'count','stop')

              if (parallel) call MPI_FINALIZE(ierr)

              stop
           else
              exit loop_cluster
           end if

        end do loop_cluster
        
      end subroutine call_cluster
      
      
      end program BigDFT

        


subroutine wtposout(igeostep,energy,nat,rxyz,atomnames,iatype)

   implicit real(kind=8) (a-h,o-z)
   character(len=20) :: atomnames(100), filename
   character(len=3) :: fn
   dimension rxyz(3,nat),iatype(nat)

   write(fn,'(i3.3)') igeostep
   filename = 'posout_'//fn//'.ascii'
   open(unit=9,file=filename)
   xmax=0.d0 ; ymax=0.d0 ; zmax=0.d0
   do iat=1,nat
      xmax=max(rxyz(1,iat),xmax)
      ymax=max(rxyz(2,iat),ymax)
      zmax=max(rxyz(3,iat),zmax)
   enddo
   write(9,*) nat,' atomic ', energy,igeostep
   write(9,*) xmax+5.d0, 0.d0, ymax+5.d0
   write(9,*) 0.d0, 0.d0, zmax+5.d0
   do iat=1,nat
      write(9,'(3(1x,e21.14),2x,a10)') (rxyz(j,iat),j=1,3),atomnames(iatype(iat))
   enddo

end subroutine wtposout

