
!>   Fill the proj array with the PSP projectors or their derivatives, following idir value
subroutine Linearfill_projectors(iproc,lr,hx,hy,hz,at,orbs,rxyz,nlpspd,proj,idir)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,idir
  real(gp), intent(in) :: hx,hy,hz
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(locreg_descriptors),intent(in) :: lr
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(wp), dimension(nlpspd%nprojel), intent(out) :: proj
  !Local variables
  integer, parameter :: nterm_max=20 !if GTH nterm_max=4
  integer :: istart_c,iat,iproj,nwarnings,ikpt,iskpt,iekpt,iatom

  if (iproc.eq.0 .and. nlpspd%nproj /=0 .and. idir==0) write(*,'(1x,a)',advance='no') &
       'Calculating wavelets expansion of projectors...'
  !warnings related to the projectors norm
  nwarnings=0
  !allocate these vectors up to the maximum size we can get
  istart_c=1

  !create projectors for any of the k-point hosted by the processor
  !starting kpoint
  if (orbs%norbp > 0) then
     iskpt=orbs%iokpt(1)
     iekpt=orbs%iokpt(orbs%norbp)
  else
     iskpt=1
     iekpt=1
  end if

  do ikpt=iskpt,iekpt
     iproj=0
     iatom = 0
     do iat=1,at%nat
        if (lr%projflg(iat) == 0) cycle
        iatom = iatom + 1
        !this routine is defined to uniformise the call for on-the-fly application
        call Linearatom_projector(ikpt,iat,iatom,idir,istart_c,iproj,&
             lr,hx,hy,hz,rxyz,at,orbs,nlpspd,proj,nwarnings)
     enddo
     if (iproj /= nlpspd%nproj) stop 'incorrect number of projectors created'
     ! projector part finished
  end do
  if (istart_c-1 /= nlpspd%nprojel) stop 'incorrect once-and-for-all psp generation'

  if (iproc == 0 .and. nlpspd%nproj /=0 .and. idir == 0) then
     if (nwarnings == 0) then
        write(*,'(1x,a)')'done.'
     else
        write(*,'(1x,a,i0,a)')'found ',nwarnings,' warnings.'
        write(*,'(1x,a)')'Some projectors may be too rough.'
        write(*,'(1x,a,f6.3)')&
             'Consider the possibility of modifying hgrid and/or the localisation radii.'
     end if
  end if

END SUBROUTINE Linearfill_projectors

subroutine Linearatom_projector(ikpt,iat,iatom,idir,istart_c,iproj,&
     lr,hx,hy,hz,rxyz,at,orbs,nlpspd,proj,nwarnings)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iat,iatom,idir,ikpt
  real(gp), intent(in) :: hx,hy,hz
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(locreg_descriptors),intent(in) :: lr
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  integer, intent(inout) :: istart_c,iproj,nwarnings
  real(wp), dimension(nlpspd%nprojel), intent(out) :: proj
  !Local variables
  integer :: ityp,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,jseg_c,l,i,ncplx
  real(gp) :: kx,ky,kz

  !features of the k-point ikpt
  kx=orbs%kpts(1,ikpt)
  ky=orbs%kpts(2,ikpt)
  kz=orbs%kpts(3,ikpt)

  !evaluate the complexity of the k-point
  if (kx**2 + ky**2 + kz**2 == 0.0_gp) then
     ncplx=1
  else
     ncplx=2
  end if

  ityp=at%iatype(iat)
  mbvctr_c=nlpspd%nvctr_p(2*iatom-1)!-nlpspd%nvctr_p(2*iat-2)
  mbvctr_f=nlpspd%nvctr_p(2*iatom  )!-nlpspd%nvctr_p(2*iat-1)

  mbseg_c=nlpspd%nseg_p(2*iatom-1)!-nlpspd%nseg_p(2*iat-2)
  mbseg_f=nlpspd%nseg_p(2*iatom  )!-nlpspd%nseg_p(2*iat-1)

  jseg_c = 1
  do l=1,iatom-1
     jseg_c = jseg_c +  nlpspd%nseg_p(2*l - 1) + nlpspd%nseg_p(2*l) 
  end do

  !decide the loop bounds
  do l=1,4 !generic case, also for HGHs (for GTH it will stop at l=2)
     do i=1,3 !generic case, also for HGHs (for GTH it will stop at i=2)
        if (at%psppar(l,i,ityp) /= 0.0_gp) then
           call local_projector(at%geocode,at%atomnames(ityp),iatom,idir,l,i,&
                at%psppar(l,0,ityp),rxyz(1,iat),lr,&
                hx,hy,hz,kx,ky,kz,ncplx,&
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                nlpspd%keyv_p(jseg_c),nlpspd%keyg_p(1,jseg_c),proj(istart_c),nwarnings)
           iproj=iproj+2*l-1
           istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*(2*l-1)*ncplx
           !print *,'iproc,istart_c,nlpspd%nprojel',istart_c,nlpspd%nprojel,ncplx
           if (istart_c > nlpspd%nprojel+1) stop 'istart_c > nprojel+1'
        endif
     enddo
  enddo
END SUBROUTINE Linearatom_projector


!>  Calculates the nonlocal forces on all atoms arising from the wavefunctions 
!!  belonging to iproc and adds them to the force array
!!  recalculate the projectors at the end if refill flag is .true.
subroutine Linearnonlocal_forces(iproc,nproc,Lzd,hx,hy,hz,at,rxyz,&
     orbs,proj,psi,fsep,refill,linorbs,coeff,phi)
  use module_base
  use module_types
  implicit none
  !Arguments-------------
  type(atoms_data), intent(in) :: at
  logical, intent(in) :: refill
  integer, intent(in) :: iproc, nproc
  real(gp), intent(in) :: hx,hy,hz
  type(local_zone_descriptors) :: Lzd
  type(orbitals_data), intent(in) :: orbs
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(wp), dimension(Lzd%Lpsidimtot), intent(inout) :: psi
  real(wp), dimension(Lzd%Gnlpspd%nprojel), intent(inout) :: proj
  real(gp), dimension(3,at%nat), intent(inout) :: fsep
  type(orbitals_data), intent(in) :: linorbs                         
  real(8),dimension(linorbs%npsidim),intent(in),optional:: phi                !optional for Trace Minimizing orbitals
  real(8),dimension(linorbs%norb,orbs%norb),intent(in),optional:: coeff       !optional for Trace Minimizing orbitals
  !local variables--------------
  character(len=*), parameter :: subname='Linearnonlocal_forces'
  integer :: istart_c,iproj,iat,ityp,i,j,l,m,jproc, ierr, jjorb2, jjorb
  integer :: mbseg_c,mbseg_f,jseg_c,jseg_f,jorbd
  integer :: mbvctr_c,mbvctr_f,iorb,nwarnings,ispinor
  real(gp) :: offdiagcoeff,hij,sp0,spi,sp0i,sp0j,spj,orbfac, t1, t2, time, tcomm1, tcomm2, timecomm, tcomp1, tcomp2, timecomp
  integer :: idir,i_all,i_stat,ncplx,icplx,isorb,ikpt,ieorb,istart_ck,ispsi_k,ispsi,jorb, jst
  real(gp), dimension(2,2,3) :: offdiagarr
  real(gp),dimension(:),allocatable:: temparr
  real(gp), dimension(:,:), allocatable :: fxyz_orb
  real(gp),dimension(:,:,:),allocatable:: fxyz_tmo, fxyz_tmo_temp
  real(dp), dimension(:,:,:,:,:,:,:), allocatable :: scalprod!!, scalprodGlobal
  real(dp), dimension(:,:,:,:,:,:), allocatable :: scalprodGlobal
  integer :: ilr,iatom,ii,iiat,iilr,iorb2,nilr,iiorb,ilr2,kptshft,orbtot
  integer :: norb,itmorb,itmorb2,jorb2, ncount
  real(gp) :: spi2,sp1,sum_scalprod, dsum
  integer,dimension(:),allocatable :: ilrtable, sendcounts, displs
  logical :: calcproj,newvalue,useTMO
  logical,dimension(:,:),allocatable:: nonzeroValue
  logical,dimension(:),allocatable:: nonzero

  !quick return if no orbitals on this processor
  if (orbs%norbp == 0 .and. .not.present(phi)) return


  !calculate the coefficients for the off-diagonal terms
  do l=1,3
     do i=1,2
        do j=i+1,3
           offdiagcoeff=0.0_gp
           if (l==1) then
              if (i==1) then
                 if (j==2) offdiagcoeff=-0.5_gp*sqrt(3._gp/5._gp)
                 if (j==3) offdiagcoeff=0.5_gp*sqrt(5._gp/21._gp)
              else
                 offdiagcoeff=-0.5_gp*sqrt(100._gp/63._gp)
              end if
           else if (l==2) then
              if (i==1) then
                 if (j==2) offdiagcoeff=-0.5_gp*sqrt(5._gp/7._gp)
                 if (j==3) offdiagcoeff=1._gp/6._gp*sqrt(35._gp/11._gp)
              else
                 offdiagcoeff=-7._gp/3._gp*sqrt(1._gp/11._gp)
              end if
           else if (l==3) then
              if (i==1) then
                 if (j==2) offdiagcoeff=-0.5_gp*sqrt(7._gp/9._gp)
                 if (j==3) offdiagcoeff=0.5_gp*sqrt(63._gp/143._gp)
              else
                 offdiagcoeff=-9._gp*sqrt(1._gp/143._gp)
              end if
           end if
           offdiagarr(i,j-i,l)=offdiagcoeff
        end do
     end do
  end do

  if(Lzd%linear .and. present(coeff) .and. present(phi)) then
     useTMO = .true.
     norb = linorbs%norbp
  else
     useTMO = .false.
     norb = orbs%norbp
  end if


  !find the different llr present on this process
  if(Lzd%linear) then
     allocate(ilrtable(norb),stat=i_stat)
     call memocc(i_stat,ilrtable,'ilrtable',subname)
     ilrtable = 0
     ii=0
     do iorb=1,norb
        newvalue=.true.
        if(.not. useTMO) ilr = orbs%inwhichlocreg(iorb+orbs%isorb)
        if(useTMO) ilr = linorbs%inwhichlocreg(iorb+linorbs%isorb)
        loop_iorb2: do iorb2=1,norb
           if(ilrtable(iorb2) == ilr) then
              newvalue=.false.
              exit loop_iorb2
           end if
        end do loop_iorb2
        if (newvalue) then
          ii = ii + 1
          ilrtable(ii)=ilr
        end if
     end do 
     nilr = ii
  end if

  !always put complex scalprod
  !also nspinor for the moment is the biggest as possible
  if(useTMO) then
     allocate(scalprod(2,0:3,7,3,4,at%nat,max(linorbs%norbp,1)*linorbs%nspinor+ndebug),stat=i_stat)   
     call memocc(i_stat,scalprod,'scalprod',subname)
     call razero(2*4*7*3*4*at%nat*max(linorbs%norbp,1)*linorbs%nspinor,scalprod)
     allocate(nonzeroValue(max(linorbs%norbp,1),at%nat), stat=i_stat)
     call memocc(i_stat,nonzeroValue,'nonzeroValue',subname)
     nonzeroValue=.false.
  else
     allocate(scalprod(2,0:3,7,3,4,at%nat,orbs%norbp*orbs%nspinor+ndebug),stat=i_stat)   
     call memocc(i_stat,scalprod,'scalprod',subname)
     call razero(2*4*7*3*4*at%nat*orbs%norbp*orbs%nspinor,scalprod)
  end if

!##############################################################################################
! Scalar Product of projectors and wavefunctions: Linear scaling with Trace Minimizing Orbitals
!##############################################################################################

  if (useTMO) then

     !starting k-point
     ikpt=1!orbs%iokpt(1)
     ispsi_k=1
     orbtot=0
!DEACTIVATED K-points
!     loop_kptTMO: do

!        call orbs_in_kpt(ikpt,orbs,isorb,ieorb,nspinor)

!        call ncplx_kpt(ikpt,orbs,ncplx)
        ncplx = 1
        nwarnings=0 !not used, simply initialised 
        iproj=0 !should be equal to four times nproj at the end
        kptshft = orbtot
        call mpi_barrier(mpi_comm_world, ierr)
        call cpu_time(t1)
        do iat=1,at%nat
           !check if projector for this atom must be generated
           calcproj = .false.
           loop_orb: do iorb=1,orbs%norb
              loop_iiorb: do iiorb = 1,linorbs%norbp
!                 if(coeff(iiorb+linorbs%isorb,iorb) < 10**-12) cycle
                 ilr = linorbs%inwhichlocreg(iiorb+linorbs%isorb)
                 if(Lzd%Llr(ilr)%projflg(iat) == 0) cycle
                 calcproj = .true.
                 exit loop_iiorb
                 exit loop_orb
              end do loop_iiorb
           end do loop_orb
           if (.not. calcproj) cycle  !if not, don't calculate it
           do iilr=1,nilr      !loop on different localization regions on this proc
              ilr = ilrtable(iilr)
              if(ilr == 0) stop 'Linearnonlocal_forces'
              if(Lzd%Llr(ilr)%projflg(iat) == 0) cycle
              iatom=0             !iatom is index of atom in local region
              jseg_c = 1
              do iiat=1,iat  !find index of atom for this locreg
                 if(Lzd%Llr(ilr)%projflg(iiat) == 0) cycle
                 if(iatom > 0) then
                   jseg_c = jseg_c + Lzd%Lnlpspd(ilr)%nseg_p(2*iatom - 1)+ Lzd%Lnlpspd(ilr)%nseg_p(2*iatom)
                 end if
                 iatom = iatom + 1
              end do
              mbseg_c=Lzd%Lnlpspd(ilr)%nseg_p(2*iatom-1)
              mbseg_f=Lzd%Lnlpspd(ilr)%nseg_p(2*iatom  )
              mbvctr_c=Lzd%Lnlpspd(ilr)%nvctr_p(2*iatom-1)
              mbvctr_f=Lzd%Lnlpspd(ilr)%nvctr_p(2*iatom  )
              ityp=at%iatype(iat)

              do idir=0,3
                 !calculate projectors
                 istart_c=1
                 call Linearatom_projector(ikpt,iat,iatom,idir,istart_c,iproj,&
                      Lzd%Llr(ilr),hx,hy,hz,rxyz,at,orbs,Lzd%Lnlpspd(ilr),proj,nwarnings)

                 !calculate the contribution for each Trace minimizing orbital
                 !here the nspinor contribution should be adjusted
                 ! loop over all my orbitals
                 ispsi=ispsi_k
                 do iorb=1,linorbs%norbp
                    if(linorbs%inwhichlocreg(iorb+linorbs%isorb) .ne. ilr) cycle
                    jorb = iorb+kptshft
                    ispsi = 1
                    do iiorb=1,iorb-1             !does not work with spinor...
                       ilr2 = linorbs%inwhichlocreg(iiorb+linorbs%isorb)
                       ispsi = ispsi + (Lzd%Llr(ilr2)%wfd%nvctr_c+7*Lzd%Llr(ilr2)%wfd%nvctr_f)*ncplx
                    end do
                    do ispinor=1,orbs%nspinor,ncplx
                       istart_c=1
                       do l=1,4
                          do i=1,3
                             if (at%psppar(l,i,ityp) /= 0.0_gp) then
                                do m=1,2*l-1
                                   call wpdot_wrap(ncplx,&
                                        Lzd%Llr(ilr)%wfd%nvctr_c,Lzd%Llr(ilr)%wfd%nvctr_f,&
                                        Lzd%Llr(ilr)%wfd%nseg_c,Lzd%Llr(ilr)%wfd%nseg_f,&
                                        Lzd%Llr(ilr)%wfd%keyv,Lzd%Llr(ilr)%wfd%keyg,phi(ispsi),&
                                        mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                                        Lzd%Lnlpspd(ilr)%keyv_p(jseg_c),Lzd%Lnlpspd(ilr)%keyg_p(1,jseg_c),&        !must define jseg_c
                                        proj(istart_c),&
                                        scalprod(1,idir,m,i,l,iat,jorb))
                                        !write(*,'(a,7i7,es15.7)') 'iproc, iat, jorb, idir, m, i, l, value', iproc, iat, jorb, idir, m, i, l, scalprod(1,idir,m,i,l,iat,jorb)
                                        nonzeroValue(jorb,iat)=.true.
                                   istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*ncplx
                                end do
                             end if
                          end do
                       end do
                       !write(*,'(a,3i7,es15.7)') 'iproc, iat, jorb, dsum', iproc, iat, jorb, dsum(2*4*7*3*4, scalprod(1,0,1,1,1,iat,jorb))
                       jorb = jorb + 1
                       orbtot = orbtot + 1
                    end do
                 end do
                 if (istart_c-1  > Lzd%Lnlpspd(ilr)%nprojel) stop '2:applyprojectors'
              end do
           end do
        end do
        call mpi_barrier(mpi_comm_world, ierr)
        call cpu_time(t2)
        time=t2-t1
        if(iproc==0) write(*,'(a,es11.4)') 'time for calculating scalprod:',time
!        if (ieorb == orbs%norbp) exit loop_kptTMO
!        ikpt=ikpt+1
!        ispsi_k=ispsi
!     end do loop_kptTMO


! Communicate scalprod
!!allocate(sendcounts(0:nproc-1), stat=i_stat)
!!call memocc(i_stat,sendcounts,'sendcounts',subname)
!!allocate(displs(0:nproc-1), stat=i_stat)
!!call memocc(i_stat,displs,'displs',subname)

!!allocate(scalprodGlobal(2,0:3,7,3,4,at%nat,linorbs%norb*linorbs%nspinor+ndebug),stat=i_stat)   
!!call memocc(i_stat,scalprodGlobal,'scalprodGlobal',subname)
!!displs(0)=0
!!do jproc=0,nproc-1
!!    sendcounts(jproc)=2*4*7*3*4*at%nat*linorbs%norb_par(jproc)*linorbs%nspinor
!!    if(jproc>0) displs(jproc)=displs(jproc-1)+sendcounts(jproc-1)
!!end do
!!call mpi_allgatherv(scalprod, sendcounts(iproc), mpi_double_precision, &
!!     scalprodGlobal, sendcounts, displs, mpi_double_precision, mpi_comm_world, ierr) 
!!!call mpi_gatherv(scalprod, sendcounts(iproc), mpi_double_precision, &
!     scalprodGlobal, sendcounts, displs, mpi_double_precision, 0, mpi_comm_world, ierr)
!call mpi_bcast(scalprodGlobal, 2*4*7*3*4*at%nat*linorbs%norb*linorbs%nspinor, mpi_double_precision, 0, &
!     mpi_comm_world, ierr)

!!i_all = -product(shape(sendcounts))*kind(sendcounts)
!!deallocate(sendcounts,stat=i_stat)
!!call memocc(i_stat,i_all,'sendcounts',subname)
!!i_all = -product(shape(displs))*kind(displs)
!!deallocate(displs,stat=i_stat)
!!call memocc(i_stat,i_all,'displs',subname)
!!i_all = -product(shape(scalprod))*kind(scalprod)
!!deallocate(scalprod,stat=i_stat)
!!call memocc(i_stat,i_all,'scalprod',subname)



!DEBUG
!sum_scalprod = sum(scalprod)
!call mpiallred(sum_scalprod,1,MPI_SUM,MPI_COMM_WORLD,i_all)
!if(iproc==0) print *,'sum(scalprod)',sum(scalprod)
!END DEBUG

!##########################################################################################
! Standard OnTheFLY calculation, including Linear Scaling without Trace Minimizing Orbitals
!#########################################################################################
  else if (DistProjApply) then

     !apply the projectors on the fly for each k-point of the processor
     !starting k-point
     ikpt=orbs%iokpt(1)
     ispsi_k=1
     orbtot=0
     loop_LkptD: do

        call orbs_in_kpt(ikpt,orbs,isorb,ieorb,orbs%nspinor)

        call ncplx_kpt(ikpt,orbs,ncplx)

        nwarnings=0 !not used, simply initialised 
        iproj=0 !should be equal to four times nproj at the end
        kptshft = orbtot
        do iat=1,at%nat
           !check if projector for this atom must be generated
           calcproj = .false.
           loop_orb2: do iorb=1,orbs%norbp
              ilr = orbs%inwhichlocreg(iorb+orbs%isorb)
              if(Lzd%Llr(ilr)%projflg(iat) == 0) cycle
              calcproj = .true.
              exit loop_orb2
           end do loop_orb2
           if (.not. calcproj) cycle  !if not, don't calculate it
           do iilr=1,nilr      !loop on different localization regions on this proc
              ilr = ilrtable(iilr)
              if(ilr == 0) stop 'should not happen'
              if(Lzd%Llr(ilr)%projflg(iat) == 0) cycle
              iatom=0             !iatom is index of atom in local region
              jseg_c = 1
              do iiat=1,iat  !find index of atom for this locreg
                 if(Lzd%Llr(ilr)%projflg(iiat) == 0) cycle
                 if(iatom > 0) then
                   jseg_c = jseg_c + Lzd%Lnlpspd(ilr)%nseg_p(2*iatom - 1)+ Lzd%Lnlpspd(ilr)%nseg_p(2*iatom)
                 end if
                 iatom = iatom + 1 
              end do
              mbseg_c=Lzd%Lnlpspd(ilr)%nseg_p(2*iatom-1)
              mbseg_f=Lzd%Lnlpspd(ilr)%nseg_p(2*iatom  )
              mbvctr_c=Lzd%Lnlpspd(ilr)%nvctr_p(2*iatom-1)
              mbvctr_f=Lzd%Lnlpspd(ilr)%nvctr_p(2*iatom  )
              ityp=at%iatype(iat)

              do idir=0,3
                 !calculate projectors
                 istart_c=1
                 call Linearatom_projector(ikpt,iat,iatom,idir,istart_c,iproj,&
                      Lzd%Llr(ilr),hx,hy,hz,rxyz,at,orbs,Lzd%Lnlpspd(ilr),proj,nwarnings)

                 !calculate the contribution for each orbital
                 !here the nspinor contribution should be adjusted
                 ! loop over all my orbitals
                 ispsi=ispsi_k
                 do iorb=isorb,ieorb
                    if(orbs%inwhichlocreg(iorb+orbs%isorb) .ne. ilr) cycle
                    jorb = iorb+kptshft
                    ispsi = 1
                    do iiorb=1,iorb-1             !does not work with spinor...
                       ilr2 = orbs%inwhichlocreg(iiorb+orbs%isorb)
                       ispsi = ispsi + (Lzd%Llr(ilr2)%wfd%nvctr_c+7*Lzd%Llr(ilr2)%wfd%nvctr_f)*ncplx
                    end do
                    do ispinor=1,orbs%nspinor,ncplx
                       istart_c=1
                       do l=1,4
                          do i=1,3
                             if (at%psppar(l,i,ityp) /= 0.0_gp) then
                                do m=1,2*l-1
                                   call wpdot_wrap(ncplx,&
                                        Lzd%Llr(ilr)%wfd%nvctr_c,Lzd%Llr(ilr)%wfd%nvctr_f,&
                                        Lzd%Llr(ilr)%wfd%nseg_c,Lzd%Llr(ilr)%wfd%nseg_f,&
                                        Lzd%Llr(ilr)%wfd%keyv,Lzd%Llr(ilr)%wfd%keyg,psi(ispsi),&
                                        mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                                        Lzd%Lnlpspd(ilr)%keyv_p(jseg_c),Lzd%Lnlpspd(ilr)%keyg_p(1,jseg_c),&        !must define jseg_c
                                        proj(istart_c),&
                                        scalprod(1,idir,m,i,l,iat,jorb))
                                   istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*ncplx
                                end do
                             end if
                          end do
                       end do
                       jorb = jorb + 1
                       orbtot = orbtot + 1
                    end do
                 end do
                 if (istart_c-1  > Lzd%Lnlpspd(ilr)%nprojel) stop '2:applyprojectors'
              end do
           end do
        end do
        if (ieorb == orbs%norbp) exit loop_LkptD
        ikpt=ikpt+1
        ispsi_k=ispsi
     end do loop_LkptD

!############################################################################################################################################
! Cubic On The Fly Calculation
!############################################################################################################################################
  else if (DistProjApply) then
     !apply the projectors on the fly for each k-point of the processor
     !starting k-point
     ikpt=orbs%iokpt(1)
     ispsi_k=1
     jorb=0
     loop_kptD: do

        call orbs_in_kpt(ikpt,orbs,isorb,ieorb,orbs%nspinor)

        call ncplx_kpt(ikpt,orbs,ncplx)

        nwarnings=0 !not used, simply initialised 
        iproj=0 !should be equal to four times nproj at the end
        jorbd=jorb
        do iat=1,at%nat

           mbseg_c=Lzd%Gnlpspd%nseg_p(2*iat-1)-Lzd%Gnlpspd%nseg_p(2*iat-2)
           mbseg_f=Lzd%Gnlpspd%nseg_p(2*iat  )-Lzd%Gnlpspd%nseg_p(2*iat-1)
           jseg_c=Lzd%Gnlpspd%nseg_p(2*iat-2)+1
           jseg_f=Lzd%Gnlpspd%nseg_p(2*iat-1)+1
           mbvctr_c=Lzd%Gnlpspd%nvctr_p(2*iat-1)-Lzd%Gnlpspd%nvctr_p(2*iat-2)
           mbvctr_f=Lzd%Gnlpspd%nvctr_p(2*iat  )-Lzd%Gnlpspd%nvctr_p(2*iat-1)
           ityp=at%iatype(iat)

           do idir=0,3
              !calculate projectors
              istart_c=1
              call atom_projector(ikpt,iat,idir,istart_c,iproj,&
                   Lzd%Glr,hx,hy,hz,rxyz,at,orbs,Lzd%Gnlpspd,proj,nwarnings)
!              print *,'iat,ilr,idir,sum(proj)',iat,ilr,idir,sum(proj)

              !calculate the contribution for each orbital
              !here the nspinor contribution should be adjusted
              ! loop over all my orbitals
              ispsi=ispsi_k
              jorb=jorbd
              do iorb=isorb,ieorb
                 do ispinor=1,orbs%nspinor,ncplx
                    jorb=jorb+1
                    istart_c=1
                    do l=1,4
                       do i=1,3
                          if (at%psppar(l,i,ityp) /= 0.0_gp) then
                             do m=1,2*l-1
                                call wpdot_wrap(ncplx,&
                                     Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f,Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,&
                                     Lzd%Glr%wfd%keyv,Lzd%Glr%wfd%keyg,psi(ispsi),&
                                     mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                                     Lzd%Gnlpspd%keyv_p(jseg_c),Lzd%Gnlpspd%keyg_p(1,jseg_c),&
                                     proj(istart_c),&
                                     scalprod(1,idir,m,i,l,iat,jorb))
                                istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*ncplx
                             end do
                          end if
                       end do
                    end do
                    ispsi=ispsi+(Lzd%Glr%wfd%nvctr_c+7*Lzd%Glr%wfd%nvctr_f)*ncplx
                 end do
              end do
              if (istart_c-1  > Lzd%Gnlpspd%nprojel) stop '2:applyprojectors'
           end do

        end do

        if (ieorb == orbs%norbp) exit loop_kptD
        ikpt=ikpt+1
        ispsi_k=ispsi
     end do loop_kptD

!#############################################################################################################################################
! Cubic Not On The Fly calculation : NOT ADAPTED FOR LINEAR YET (PERTINENT??) !!
!#############################################################################################################################################
  else

     !calculate all the scalar products for each direction and each orbitals
     do idir=0,3

        if (idir /= 0) then !for the first run the projectors are already allocated
           call fill_projectors(iproc,Lzd%Glr,hx,hy,hz,at,orbs,rxyz,Lzd%Gnlpspd,proj,idir)
        end if
        !apply the projectors  k-point of the processor
        !starting k-point
        ikpt=orbs%iokpt(1)
        istart_ck=1
        ispsi_k=1
        jorb=0
        loop_kpt: do

           call orbs_in_kpt(ikpt,orbs,isorb,ieorb,orbs%nspinor)

           call ncplx_kpt(ikpt,orbs,ncplx)
           ! calculate the scalar product for all the orbitals
           ispsi=ispsi_k
           do iorb=isorb,ieorb
              do ispinor=1,orbs%nspinor,ncplx
                 jorb=jorb+1
                 ! loop over all projectors of this k-point
                 iproj=0
                 istart_c=istart_ck
                 do iat=1,at%nat
                    mbseg_c=Lzd%Gnlpspd%nseg_p(2*iat-1)-Lzd%Gnlpspd%nseg_p(2*iat-2)
                    mbseg_f=Lzd%Gnlpspd%nseg_p(2*iat  )-Lzd%Gnlpspd%nseg_p(2*iat-1)
                    jseg_c=Lzd%Gnlpspd%nseg_p(2*iat-2)+1
                    jseg_f=Lzd%Gnlpspd%nseg_p(2*iat-1)+1
                    mbvctr_c=Lzd%Gnlpspd%nvctr_p(2*iat-1)-Lzd%Gnlpspd%nvctr_p(2*iat-2)
                    mbvctr_f=Lzd%Gnlpspd%nvctr_p(2*iat  )-Lzd%Gnlpspd%nvctr_p(2*iat-1)
                    ityp=at%iatype(iat)
                    do l=1,4
                       do i=1,3
                          if (at%psppar(l,i,ityp) /= 0.0_gp) then
                             do m=1,2*l-1
                                iproj=iproj+1
                                call wpdot_wrap(ncplx,&
                                     Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f,&
                                     Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,&
                                     Lzd%Glr%wfd%keyv,Lzd%Glr%wfd%keyg,psi(ispsi),  &
                                     mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                                     Lzd%Gnlpspd%keyv_p(jseg_c),Lzd%Gnlpspd%keyg_p(1,jseg_c),&
                                     proj(istart_c),scalprod(1,idir,m,i,l,iat,jorb))
                                istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*ncplx
                             end do
                          end if
                       end do
                    end do
                 end do
                 ispsi=ispsi+(Lzd%Llr(ilr)%wfd%nvctr_c+7*Lzd%Llr(ilr)%wfd%nvctr_f)*ncplx
              end do
              if (iproj /= Lzd%Lnlpspd(ilr)%nproj) stop '1:applyprojectors'
           end do
           istart_ck=istart_c
           if (ieorb == orbs%norbp) exit loop_kpt
           ikpt=ikpt+1
           ispsi_k=ispsi
        end do loop_kpt
        if (istart_ck-1  /= Lzd%Lnlpspd(ilr)%nprojel) stop '2:applyprojectors'

     end do

     !restore the projectors in the proj array (for on the run forces calc., tails or so)
     if (refill) then
        call fill_projectors(iproc,Lzd%Glr,hx,hy,hz,at,orbs,rxyz,Lzd%Gnlpspd,proj,0)
     end if

  end if

  i_all = -product(shape(ilrtable))*kind(ilrtable)
  deallocate(ilrtable,stat=i_stat)
  call memocc(i_stat,i_all,'ilrtable',subname)

!#####################################################################################
! Force calculation
!#####################################################################################

  allocate(fxyz_orb(3,at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,fxyz_orb,'fxyz_orb',subname)

  if(useTMO) then
  
     allocate(fxyz_tmo(3,linorbs%norb,linorbs%norb), stat=i_stat)
     call memocc(i_stat, fxyz_tmo, 'fxyz_tmo', subname)
     allocate(fxyz_tmo_temp(3,linorbs%norb,linorbs%norbp), stat=i_stat)
     call memocc(i_stat, fxyz_tmo_temp, 'fxyz_tmo_temp', subname)

     allocate(scalprodGlobal(2,0:3,7,3,4,linorbs%norb*linorbs%nspinor+ndebug),stat=i_stat)   
     call memocc(i_stat,scalprodGlobal,'scalprodGlobal',subname)
     ncount=2*4*7*3*4*max(linorbs%norbp,1)*linorbs%nspinor
     allocate(temparr(ncount+ndebug),stat=i_stat)   
     call memocc(i_stat,temparr,'temparr',subname)

     allocate(sendcounts(0:nproc-1), stat=i_stat)
     call memocc(i_stat,sendcounts,'sendcounts',subname)
     allocate(displs(0:nproc-1), stat=i_stat)
     call memocc(i_stat,displs,'displs',subname)
     allocate(nonzero(linorbs%norb), stat=i_stat)
     call memocc(i_stat,nonzero,'nonzero',subname)

     
     !apply the projectors  k-point of the processor
     !starting k-point
     ikpt=1!orbs%iokpt(1)
     orbtot = 0
!     loop_kptF: do                          !DISABLED KPOINTS
!
!        call orbs_in_kpt(ikpt,orbs,isorb,ieorb,nspinor)
!
!        call ncplx_kpt(ikpt,orbs,ncplx)

        kptshft = orbtot
        ! loop over all my orbitals for calculating forces
        !do iorb=1,orbs%norbp
        do iorb=1,maxval(orbs%norb_par)
           call razero(3*at%nat,fxyz_orb)
           do iat=1,at%nat
              ityp=at%iatype(iat)
              if(iproc==0) write(*,'(a,i0)') 'iat=',iat

              ! Copy scalprod to temporary array for communication.
              ncount=2*4*7*3*4
              jst=1
              !do jorb=1,max(linorbs%norbp,1)*linorbs%nspinor
              do jorb=1,linorbs%norbp*linorbs%nspinor
                  if(nonzeroValue(jorb,iat)) then
                      call dcopy(ncount, scalprod(1,0,1,1,1,iat,jorb), 1, temparr(jst), 1)
                      jst=jst+ncount
                  !else
                  !    write(*,*) 'CHECK: ', dsum(ncount, scalprod(1,0,1,1,1,iat,jorb))==0.d0
                  end if
              end do

              ! Communicate nonzeroValue to communicate scalprod later.
              displs(0)=0
              do jproc=0,nproc-1
                  sendcounts(jproc)=linorbs%norb_par(jproc)
                  if(jproc>0) displs(jproc)=displs(jproc-1)+sendcounts(jproc-1)
              end do
              call mpi_allgatherv(nonzeroValue(1,iat), sendcounts(iproc), mpi_logical, &
                   nonzero, sendcounts, displs, mpi_logical, mpi_comm_world, ierr) 

              displs(0)=0
              do jproc=0,nproc-1
                  iiorb=0
                  do jorb=1,linorbs%norb_par(jproc)
                      jjorb=jorb+linorbs%isorb_par(jproc)
                      if(nonzero(jjorb)) iiorb = iiorb + 1
                  end do
                  sendcounts(jproc)=2*4*7*3*4*iiorb*linorbs%nspinor
                  if(jproc>0) displs(jproc)=displs(jproc-1)+sendcounts(jproc-1)
              end do
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomm1)
              call mpi_allgatherv(temparr, sendcounts(iproc), mpi_double_precision, &
                   scalprodGlobal, sendcounts, displs, mpi_double_precision, mpi_comm_world, ierr) 
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomm2)
              timecomm=tcomm2-tcomm1
              if(iproc==0) write(*,'(a,es12.5)') 'first timecomm:',timecomm

              fxyz_tmo=0.d0
              fxyz_tmo_temp=0.d0
              !do itmorb = 1,linorbs%norb
              jorb=0
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomp1)
              do itmorb = 1,linorbs%norbp
                 !jorb = itmorb + kptshft
                 !jjorb=itmorb+linorbs%isorb
                 if(nonzeroValue(itmorb,iat)) then
                    !jorb = itmorb + kptshft + linorbs%isorb
                    !jorb = itmorb + kptshft + linorbs%isorb
                    jjorb2=0
                    do itmorb2=1,linorbs%norb
                       jorb2=itmorb2 + kptshft
                       if(nonzero(jorb2)) then
                          jjorb2=jjorb2+1
                          do ispinor=1,orbs%nspinor,ncplx
                             do l=1,4
                                do i=1,3
                                   if (at%psppar(l,i,ityp) /= 0.0_gp) then
                                      do m=1,2*l-1
                                         do icplx=1,ncplx
                                            ! scalar product with the derivatives in all the directions
                                            !!sp0=real(scalprodGlobal(icplx,0,m,i,l,iat,jorb),gp)
                                            !sp0=real(scalprodGlobal(icplx,0,m,i,l,jorb),gp)
                                            sp0=real(scalprod(icplx,0,m,i,l,iat,itmorb),gp)
                                            !sp1=real(scalprodGlobal(icplx,0,m,i,l,iat,jorb2),gp)
                                            do idir=1,3
                                               !!spi=real(scalprodGlobal(icplx,idir,m,i,l,iat,jorb2),gp)
                                               !spi=real(scalprodGlobal(icplx,idir,m,i,l,jorb2),gp)
                                               spi=real(scalprodGlobal(icplx,idir,m,i,l,jjorb2),gp)
                                             !  spi2=real(scalprodGlobal(icplx,idir,m,i,l,iat,jorb),gp)
                                               !fxyz_tmo(idir,jorb2,jorb) = fxyz_tmo(idir,jorb2,jorb) + at%psppar(l,i,ityp)*(sp0*spi)
                                               !write(*,'(a,4i6,2es15.7)') 'iat, iorb, jorb, jorb2, sp0, spi', iat, iorb, jorb, jorb2, sp0, spi
                                               !fxyz_tmo_temp(idir,jorb2,itmorb) = fxyz_tmo_temp(idir,jorb2,itmorb) + at%psppar(l,i,ityp)*(sp0*spi)
                                               fxyz_tmo_temp(idir,jorb2,itmorb) = fxyz_tmo_temp(idir,jorb2,itmorb) + at%psppar(l,i,ityp)*(sp0*spi)
                                            end do
                                         end do
                                      end do
                                   end if
                                end do
                             end do
                             !HGH case, offdiagonal terms
                             if (at%npspcode(ityp) == 3 .or. at%npspcode(ityp) == 10) then
                                do l=1,3 !no offdiagoanl terms for l=4 in HGH-K case
                                   do i=1,2
                                      if (at%psppar(l,i,ityp) /= 0.0_gp) then
                                         loop_jTMO: do j=i+1,3
                                            if (at%psppar(l,j,ityp) == 0.0_gp) exit loop_jTMO
                                            !offdiagonal HGH term
                                            if (at%npspcode(ityp) == 3) then !traditional HGH convention
                                               hij=offdiagarr(i,j-i,l)*at%psppar(l,j,ityp)
                                            else !HGH-K convention
                                               hij=at%psppar(l,i+j+1,ityp)
                                            end if
                                            do m=1,2*l-1
                                               !F_t= 2.0*h_ij (<D_tp_i|psi><psi|p_j>+<p_i|psi><psi|D_tp_j>)
                                               !(the two factor is below)
                                               do icplx=1,ncplx
                                                  !!sp0i=real(scalprodGlobal(icplx,0,m,i,l,iat,jorb),gp)
                                                  !!sp0j=real(scalprodGlobal(icplx,0,m,j,l,iat,jorb2),gp)
                                                  !sp0i=real(scalprodGlobal(icplx,0,m,i,l,jorb),gp)
                                                  sp0i=real(scalprod(icplx,0,m,i,l,iat,itmorb),gp)
                                                  !sp0j=real(scalprodGlobal(icplx,0,m,j,l,jorb2),gp)
                                                  sp0j=real(scalprodGlobal(icplx,0,m,j,l,jjorb2),gp)
                                                  do idir=1,3
                                                     !!spi=real(scalprodGlobal(icplx,idir,m,i,l,iat,jorb),gp)
                                                     !!spj=real(scalprodGlobal(icplx,idir,m,j,l,iat,jorb2),gp)
                                                     !spi=real(scalprodGlobal(icplx,idir,m,i,l,jorb),gp)
                                                     spi=real(scalprod(icplx,idir,m,i,l,iat,itmorb),gp)
                                                     !spj=real(scalprodGlobal(icplx,idir,m,j,l,jorb2),gp)
                                                     spj=real(scalprodGlobal(icplx,idir,m,j,l,jjorb2),gp)
                                                     !fxyz_tmo(idir,jorb2,jorb) = fxyz_tmo(idir,jorb2,jorb) + hij*(sp0j*spi+spj*sp0i)
                                                     !fxyz_tmo_temp(idir,jorb2,itmorb) = fxyz_tmo(idir,jorb2,itmorb) + hij*(sp0j*spi+spj*sp0i)
                                                     fxyz_tmo_temp(idir,jorb2,itmorb) = fxyz_tmo(idir,jorb2,itmorb) + hij*(sp0j*spi+spj*sp0i)
                                                  end do
                                               end do
                                            end do
                                         end do loop_jTMO
                                      end if
                                   end do
                                end do
                             end if
                          end do
                       end if
                    end do
                 end if
              end do
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomp2)
              timecomp=tcomp2-tcomp1
              if(iproc==0) write(*,'(a,es15.7)') 'time for first loop:',timecomp

              displs(0)=0
              do jproc=0,nproc-1
                  sendcounts(jproc)=3*linorbs%norb_par(jproc)*linorbs%norb
                  if(jproc>0) displs(jproc)=displs(jproc-1)+sendcounts(jproc-1)
              end do
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomm1)
              call mpi_allgatherv(fxyz_tmo_temp, sendcounts(iproc), mpi_double_precision, &
                   fxyz_tmo, sendcounts, displs, mpi_double_precision, mpi_comm_world, ierr) 
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomm2)
              timecomm=tcomm2-tcomm1
              if(iproc==0) write(*,'(a,es12.5)') 'second timecomm:',timecomm
              !call mpiallred(fxyz_tmo(1,1,1), 3*linorbs%norb**2, mpi_sum, mpi_comm_world, ierr)
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(tcomp1)
              if(iorb<=orbs%norbp) then
                 do itmorb = 1,linorbs%norb
                    jorb = itmorb + kptshft
                    do itmorb2=1,linorbs%norb
                       jorb2=itmorb2 + kptshft
                       do idir=1,3
                          fxyz_orb(idir,iat) = fxyz_orb(idir,iat) + coeff(jorb,iorb+orbs%isorb)*coeff(jorb2,iorb+orbs%isorb)*fxyz_tmo(idir,jorb2,jorb)
                       end do
                    end do
                 end do
              end if
              call mpi_barrier(mpi_comm_world, ierr)
              call cpu_time(t2)
              timecomp=t2-tcomp1
              if(iproc==0) write(*,'(a,es15.7)') 'time for send loop:',timecomp
              time=t2-t1
              if(iproc==0) write(*,'(a,i0,a,es11.4)') 'time for calculating atom',iat,':',time
           end do



           !orbital-dependent factor for the forces
!           orbfac=orbs%kwgts(orbs%iokpt(iorb))*orbs%occup(iorb)*2.0_gp
            if(iorb<=orbs%norbp) then
                orbfac=orbs%occup(iorb+orbs%isorb)*2.0_gp
                do iat=1,at%nat
                   fsep(1,iat)=fsep(1,iat)+orbfac*fxyz_orb(1,iat)
                   fsep(2,iat)=fsep(2,iat)+orbfac*fxyz_orb(2,iat)
                   fsep(3,iat)=fsep(3,iat)+orbfac*fxyz_orb(3,iat)
                end do
            end if

        end do
!        if (ieorb == orbs%norbp) exit loop_kptF
!        ikpt=ikpt+1
!        ispsi_k=ispsi
!     end do loop_kptF

     i_all=-product(shape(temparr))*kind(temparr)
     deallocate(temparr,stat=i_stat)
     call memocc(i_stat,i_all,'temparr',subname)
     i_all = -product(shape(sendcounts))*kind(sendcounts)
     deallocate(sendcounts,stat=i_stat)
     call memocc(i_stat,i_all,'sendcounts',subname)
     i_all = -product(shape(displs))*kind(displs)
     deallocate(displs,stat=i_stat)
     call memocc(i_stat,i_all,'displs',subname)
     i_all = -product(shape(scalprod))*kind(scalprod)
     deallocate(scalprod,stat=i_stat)
     call memocc(i_stat,i_all,'scalprod',subname)
     i_all = -product(shape(fxyz_tmo))*kind(fxyz_tmo)
     deallocate(fxyz_tmo,stat=i_stat)
     call memocc(i_stat,i_all,'fxyz_tmo',subname)
     i_all = -product(shape(nonzeroValue))*kind(nonzeroValue)
     deallocate(nonzeroValue,stat=i_stat)
     call memocc(i_stat,i_all,'nonzeroValue',subname)
     i_all = -product(shape(nonzero))*kind(nonzero)
     deallocate(nonzero,stat=i_stat)
     call memocc(i_stat,i_all,'nonzero',subname)

  else
     !apply the projectors  k-point of the processor
     !starting k-point
     ikpt=orbs%iokpt(1)
     orbtot = 0
     loop_kptF: do

        call orbs_in_kpt(ikpt,orbs,isorb,ieorb,orbs%nspinor)

        call ncplx_kpt(ikpt,orbs,ncplx)

        kptshft = orbtot
        ! loop over all my orbitals for calculating forces
        do iorb=isorb,ieorb
           ! loop over all projectors
           call razero(3*at%nat,fxyz_orb)
           jorb = iorb + kptshft
           do ispinor=1,orbs%nspinor,ncplx
              do iat=1,at%nat
                 ityp=at%iatype(iat)
                 do l=1,4
                    do i=1,3
                       if (at%psppar(l,i,ityp) /= 0.0_gp) then
                          do m=1,2*l-1
                             do icplx=1,ncplx
                                ! scalar product with the derivatives in all the directions
                                sp0=real(scalprod(icplx,0,m,i,l,iat,jorb),gp)
                                do idir=1,3
                                   spi=real(scalprod(icplx,idir,m,i,l,iat,jorb),gp)
                                   fxyz_orb(idir,iat)=fxyz_orb(idir,iat)+&
                                        at%psppar(l,i,ityp)*sp0*spi
                                end do
                             end do
                          end do
                       end if
                    end do
                 end do
                 !HGH case, offdiagonal terms
                 if (at%npspcode(ityp) == 3 .or. at%npspcode(ityp) == 10) then
                    do l=1,3 !no offdiagoanl terms for l=4 in HGH-K case
                       do i=1,2
                          if (at%psppar(l,i,ityp) /= 0.0_gp) then
                             loop_j: do j=i+1,3
                                if (at%psppar(l,j,ityp) == 0.0_gp) exit loop_j
                                !offdiagonal HGH term
                                if (at%npspcode(ityp) == 3) then !traditional HGH convention
                                   hij=offdiagarr(i,j-i,l)*at%psppar(l,j,ityp)
                                else !HGH-K convention
                                   hij=at%psppar(l,i+j+1,ityp)
                                end if
                                do m=1,2*l-1
                                   !F_t= 2.0*h_ij (<D_tp_i|psi><psi|p_j>+<p_i|psi><psi|D_tp_j>)
                                   !(the two factor is below)
                                   do icplx=1,ncplx
                                      sp0i=real(scalprod(icplx,0,m,i,l,iat,jorb),gp)
                                      sp0j=real(scalprod(icplx,0,m,j,l,iat,jorb),gp)
                                      do idir=1,3
                                         spi=real(scalprod(icplx,idir,m,i,l,iat,jorb),gp)
                                         spj=real(scalprod(icplx,idir,m,j,l,iat,jorb),gp)
                                         fxyz_orb(idir,iat)=fxyz_orb(idir,iat)+&
                                              hij*(sp0j*spi+spj*sp0i)
                                      end do
                                   end do
                                end do
                             end do loop_j
                          end if
                       end do
                    end do
                 end if
              end do
              jorb = jorb +1
              orbtot = orbtot + 1 
           end do

           !orbital-dependent factor for the forces
           orbfac=orbs%kwgts(orbs%iokpt(iorb))*orbs%occup(iorb+orbs%isorb)*2.0_gp

           do iat=1,at%nat
              fsep(1,iat)=fsep(1,iat)+orbfac*fxyz_orb(1,iat)
              fsep(2,iat)=fsep(2,iat)+orbfac*fxyz_orb(2,iat)
              fsep(3,iat)=fsep(3,iat)+orbfac*fxyz_orb(3,iat)
           end do

        end do
        if (ieorb == orbs%norbp) exit loop_kptF
        ikpt=ikpt+1
        ispsi_k=ispsi
     end do loop_kptF
  end if

!!!  do iat=1,at%nat
!!!     write(20+iat,'(1x,i5,1x,3(1x,1pe12.5))') &
!!!          iat,fsep(1,iat),fsep(2,iat),fsep(3,iat)
!!!  end do

  i_all=-product(shape(fxyz_orb))*kind(fxyz_orb)
  deallocate(fxyz_orb,stat=i_stat)
  call memocc(i_stat,i_all,'fxyz_orb',subname)

  if(.not.useTMO) then
      i_all=-product(shape(scalprod))*kind(scalprod)
      deallocate(scalprod,stat=i_stat)
      call memocc(i_stat,i_all,'scalprod',subname)
  else
      i_all=-product(shape(scalprodGlobal))*kind(scalprodGlobal)
      deallocate(scalprodGlobal,stat=i_stat)
      call memocc(i_stat,i_all,'scalprodGlobal',subname)
  end if

END SUBROUTINE Linearnonlocal_forces





function dsum(n, x)
  implicit none
  
  ! Calling arguments
  integer,intent(in):: n
  real(8),dimension(n),intent(in):: x
  real(8):: dsum
  
  ! Local variables
  integer:: m, i, mp1
  real(8):: tt
  
  dsum=0.d0
  do i=1,n
      dsum = dsum + x(i)
  end do
  
  !!tt=0.d0
  !!dsum=0.d0
  !!m=mod(n,5)
  !!if(m/=0) then
  !!    do i=1,m
  !!        tt=tt+x(i)
  !!    end do
  !!    if(n<5) then
  !!        dsum=tt
  !!        return
  !!    end if
  !!end if
  !!mp1=m+1
  !!do i=mp1,n,5
  !!    tt = tt + x(i) + x(i+1) + x(i+2) + x(i+3) + x(i+4)
  !!end do
  !!dsum=tt

end function dsum

