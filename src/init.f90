!> @file
!!  Routines to initialize the information about localisation regions
!! @author
!!    Copyright (C) 2007-2011 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!>   Calculates the descriptor arrays and nvctrp
!!   Calculates also the bounds arrays needed for convolutions
!!   Refers this information to the global localisation region descriptor
subroutine createWavefunctionsDescriptors(iproc,hx,hy,hz,atoms,rxyz,radii_cf,&
     crmult,frmult,Glr,output_grid)
  use module_base
  use module_types
  implicit none
  !Arguments
  type(atoms_data), intent(in) :: atoms
  integer, intent(in) :: iproc
  real(gp), intent(in) :: hx,hy,hz,crmult,frmult
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  real(gp), dimension(atoms%ntypes,3), intent(in) :: radii_cf
  type(locreg_descriptors), intent(inout) :: Glr
  logical, intent(in), optional :: output_grid
  !local variables
  character(len=*), parameter :: subname='createWavefunctionsDescriptors'
  integer :: i_all,i_stat,i1,i2,i3,iat
  integer :: n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3
  logical :: my_output_grid
  logical, dimension(:,:,:), allocatable :: logrid_c,logrid_f

  !assign the dimensions to improve (a little) readability
  n1=Glr%d%n1
  n2=Glr%d%n2
  n3=Glr%d%n3
  nfl1=Glr%d%nfl1
  nfl2=Glr%d%nfl2
  nfl3=Glr%d%nfl3
  nfu1=Glr%d%nfu1
  nfu2=Glr%d%nfu2
  nfu3=Glr%d%nfu3

  !allocate kinetic bounds, only for free BC
  if (atoms%geocode == 'F') then
     allocate(Glr%bounds%kb%ibyz_c(2,0:n2,0:n3+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibyz_c,'Glr%bounds%kb%ibyz_c',subname)
     allocate(Glr%bounds%kb%ibxz_c(2,0:n1,0:n3+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibxz_c,'Glr%bounds%kb%ibxz_c',subname)
     allocate(Glr%bounds%kb%ibxy_c(2,0:n1,0:n2+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibxy_c,'Glr%bounds%kb%ibxy_c',subname)
     allocate(Glr%bounds%kb%ibyz_f(2,0:n2,0:n3+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibyz_f,'Glr%bounds%kb%ibyz_f',subname)
     allocate(Glr%bounds%kb%ibxz_f(2,0:n1,0:n3+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibxz_f,'Glr%bounds%kb%ibxz_f',subname)
     allocate(Glr%bounds%kb%ibxy_f(2,0:n1,0:n2+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%kb%ibxy_f,'Glr%bounds%kb%ibxy_f',subname)
  end if

  if (iproc == 0) then
     write(*,'(1x,a)')&
          '------------------------------------------------- Wavefunctions Descriptors Creation'
  end if

  ! determine localization region for all orbitals, but do not yet fill the descriptor arrays
  allocate(logrid_c(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,logrid_c,'logrid_c',subname)
  allocate(logrid_f(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,logrid_f,'logrid_f',subname)

  ! coarse grid quantities
  call fill_logrid(atoms%geocode,n1,n2,n3,0,n1,0,n2,0,n3,0,atoms%nat,&
       atoms%ntypes,atoms%iatype,rxyz,radii_cf(1,1),crmult,hx,hy,hz,logrid_c)
  call num_segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_c,Glr%wfd%nseg_c,Glr%wfd%nvctr_c)
  if (iproc == 0) write(*,'(2(1x,a,i10))') &
       'Coarse resolution grid: Number of segments= ',Glr%wfd%nseg_c,'points=',Glr%wfd%nvctr_c

  if (atoms%geocode == 'F') then
     call make_bounds(n1,n2,n3,logrid_c,Glr%bounds%kb%ibyz_c,Glr%bounds%kb%ibxz_c,Glr%bounds%kb%ibxy_c)
  end if

  if (atoms%geocode == 'P' .and. .not. Glr%hybrid_on .and. Glr%wfd%nvctr_c /= (n1+1)*(n2+1)*(n3+1) ) then
     if (iproc ==0)then
        write(*,*)&
          ' ERROR: the coarse grid does not fill the entire periodic box'
        write(*,*)&
          '          errors due to translational invariance breaking may occur'
        !stop
     end if
     if (GPUconv) then
!        if (iproc ==0)then
           write(*,*)&
                '          The code should be stopped for a GPU calculation     '
           write(*,*)&
                '          since density is not initialised to 10^-20               '
!        end if
        stop
     end if
  end if

  call fill_logrid(atoms%geocode,n1,n2,n3,0,n1,0,n2,0,n3,0,atoms%nat,&
       atoms%ntypes,atoms%iatype,rxyz,radii_cf(1,2),frmult,hx,hy,hz,logrid_f)
  call num_segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_f,Glr%wfd%nseg_f,Glr%wfd%nvctr_f)
  if (iproc == 0) write(*,'(2(1x,a,i10))') & 
       '  Fine resolution grid: Number of segments= ',Glr%wfd%nseg_f,'points=',Glr%wfd%nvctr_f
  if (atoms%geocode == 'F') then
     call make_bounds(n1,n2,n3,logrid_f,Glr%bounds%kb%ibyz_f,Glr%bounds%kb%ibxz_f,Glr%bounds%kb%ibxy_f)
  end if

  ! allocations for arrays holding the wavefunctions and their data descriptors
  call allocate_wfd(Glr%wfd,subname)

  ! now fill the wavefunction descriptor arrays
  ! coarse grid quantities
  call segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_c,Glr%wfd%nseg_c,Glr%wfd%keyg(1,1),Glr%wfd%keyv(1))

  ! fine grid quantities
  if (Glr%wfd%nseg_f > 0) then
     call segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_f,Glr%wfd%nseg_f,Glr%wfd%keyg(1,Glr%wfd%nseg_c+1), &
          & Glr%wfd%keyv(Glr%wfd%nseg_c+1))
  end if

! Create the file grid.xyz to visualize the grid of functions
  my_output_grid = .false.
  if (present(output_grid)) my_output_grid = output_grid
  if (my_output_grid) then
     open(unit=22,file='grid.xyz',status='unknown')
     write(22,*) Glr%wfd%nvctr_c+Glr%wfd%nvctr_f+atoms%nat,' atomic'
     if (atoms%geocode=='F') then
        write(22,*)'complete simulation grid with low and high resolution points'
     else if (atoms%geocode =='S') then
        write(22,'(a,2x,3(1x,1pe24.17))')'surface',atoms%alat1,atoms%alat2,atoms%alat3
     else if (atoms%geocode =='P') then
        write(22,'(a,2x,3(1x,1pe24.17))')'periodic',atoms%alat1,atoms%alat2,atoms%alat3
     end if
     do iat=1,atoms%nat
        write(22,'(a6,2x,3(1x,e12.5),3x)') &
             trim(atoms%atomnames(atoms%iatype(iat))),rxyz(1,iat),rxyz(2,iat),rxyz(3,iat)
     enddo
     do i3=0,n3  
        do i2=0,n2  
           do i1=0,n1
              if (logrid_c(i1,i2,i3))&
                   write(22,'(a4,2x,3(1x,e10.3))') &
                   '  g ',real(i1,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
           enddo
        enddo
     end do
     do i3=0,n3 
        do i2=0,n2 
           do i1=0,n1
              if (logrid_f(i1,i2,i3))&
                   write(22,'(a4,2x,3(1x,e10.3))') &
                   '  G ',real(i1,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
           enddo
        enddo
     enddo
     close(22)
  endif

  i_all=-product(shape(logrid_c))*kind(logrid_c)
  deallocate(logrid_c,stat=i_stat)
  call memocc(i_stat,i_all,'logrid_c',subname)
  i_all=-product(shape(logrid_f))*kind(logrid_f)
  deallocate(logrid_f,stat=i_stat)
  call memocc(i_stat,i_all,'logrid_f',subname)

  !for free BC admits the bounds arrays
  if (atoms%geocode == 'F') then

     !allocate grow, shrink and real bounds
     allocate(Glr%bounds%gb%ibzxx_c(2,0:n3,-14:2*n1+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%gb%ibzxx_c,'Glr%bounds%gb%ibzxx_c',subname)
     allocate(Glr%bounds%gb%ibxxyy_c(2,-14:2*n1+16,-14:2*n2+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%gb%ibxxyy_c,'Glr%bounds%gb%ibxxyy_c',subname)
     allocate(Glr%bounds%gb%ibyz_ff(2,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%gb%ibyz_ff,'Glr%bounds%gb%ibyz_ff',subname)
     allocate(Glr%bounds%gb%ibzxx_f(2,nfl3:nfu3,2*nfl1-14:2*nfu1+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%gb%ibzxx_f,'Glr%bounds%gb%ibzxx_f',subname)
     allocate(Glr%bounds%gb%ibxxyy_f(2,2*nfl1-14:2*nfu1+16,2*nfl2-14:2*nfu2+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%gb%ibxxyy_f,'Glr%bounds%gb%ibxxyy_f',subname)

     allocate(Glr%bounds%sb%ibzzx_c(2,-14:2*n3+16,0:n1+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%sb%ibzzx_c,'Glr%bounds%sb%ibzzx_c',subname)
     allocate(Glr%bounds%sb%ibyyzz_c(2,-14:2*n2+16,-14:2*n3+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%sb%ibyyzz_c,'Glr%bounds%sb%ibyyzz_c',subname)
     allocate(Glr%bounds%sb%ibxy_ff(2,nfl1:nfu1,nfl2:nfu2+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%sb%ibxy_ff,'Glr%bounds%sb%ibxy_ff',subname)
     allocate(Glr%bounds%sb%ibzzx_f(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%sb%ibzzx_f,'Glr%bounds%sb%ibzzx_f',subname)
     allocate(Glr%bounds%sb%ibyyzz_f(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%sb%ibyyzz_f,'Glr%bounds%sb%ibyyzz_f',subname)

     allocate(Glr%bounds%ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16+ndebug),stat=i_stat)
     call memocc(i_stat,Glr%bounds%ibyyzz_r,'Glr%bounds%ibyyzz_r',subname)

     call make_all_ib(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
          Glr%bounds%kb%ibxy_c,Glr%bounds%sb%ibzzx_c,Glr%bounds%sb%ibyyzz_c,&
          Glr%bounds%kb%ibxy_f,Glr%bounds%sb%ibxy_ff,Glr%bounds%sb%ibzzx_f,Glr%bounds%sb%ibyyzz_f,&
          Glr%bounds%kb%ibyz_c,Glr%bounds%gb%ibzxx_c,Glr%bounds%gb%ibxxyy_c,&
          Glr%bounds%kb%ibyz_f,Glr%bounds%gb%ibyz_ff,Glr%bounds%gb%ibzxx_f,Glr%bounds%gb%ibxxyy_f,&
          Glr%bounds%ibyyzz_r)

  end if

  if ( atoms%geocode == 'P' .and. Glr%hybrid_on) then
     call make_bounds_per(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,Glr%bounds,Glr%wfd)
     call make_all_ib_per(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
          Glr%bounds%kb%ibxy_f,Glr%bounds%sb%ibxy_ff,Glr%bounds%sb%ibzzx_f,Glr%bounds%sb%ibyyzz_f,&
          Glr%bounds%kb%ibyz_f,Glr%bounds%gb%ibyz_ff,Glr%bounds%gb%ibzxx_f,Glr%bounds%gb%ibxxyy_f)
  endif

  !assign geocode and the starting points
  Glr%geocode=atoms%geocode

END SUBROUTINE createWavefunctionsDescriptors


!>   Determine localization region for all projectors, but do not yet fill the descriptor arrays
subroutine createProjectorsArrays(iproc,lr,rxyz,at,orbs,&
     radii_cf,cpmult,fpmult,hx,hy,hz,nlpspd,proj)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc
  real(gp), intent(in) :: cpmult,fpmult,hx,hy,hz
  type(locreg_descriptors),intent(in) :: lr
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(gp), dimension(at%ntypes,3), intent(in) :: radii_cf
  type(nonlocal_psp_descriptors), intent(out) :: nlpspd
  real(wp), dimension(:), pointer :: proj
  !local variables
  character(len=*), parameter :: subname='createProjectorsArrays'
  integer :: n1,n2,n3,nl1,nl2,nl3,nu1,nu2,nu3,mseg,mproj
  integer :: iat,i_stat,i_all,iseg
  logical, dimension(:,:,:), allocatable :: logrid
  
  allocate(nlpspd%nseg_p(0:2*at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%nseg_p,'nlpspd%nseg_p',subname)
  allocate(nlpspd%nvctr_p(0:2*at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%nvctr_p,'nlpspd%nvctr_p',subname)
  allocate(nlpspd%nboxp_c(2,3,at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%nboxp_c,'nlpspd%nboxp_c',subname)
  allocate(nlpspd%nboxp_f(2,3,at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%nboxp_f,'nlpspd%nboxp_f',subname)


  ! define the region dimensions
    n1 = lr%d%n1
    n2 = lr%d%n2
    n3 = lr%d%n3

  ! determine localization region for all projectors, but do not yet fill the descriptor arrays
  allocate(logrid(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,logrid,'logrid',subname)

  call localize_projectors(iproc,n1,n2,n3,hx,hy,hz,cpmult,fpmult,rxyz,radii_cf,&
       logrid,at,orbs,nlpspd)

  ! allocations for arrays holding the projectors and their data descriptors
  allocate(nlpspd%keyg_p(2,nlpspd%nseg_p(2*at%nat)+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%keyg_p,'nlpspd%keyg_p',subname)
  allocate(nlpspd%keyv_p(nlpspd%nseg_p(2*at%nat)+ndebug),stat=i_stat)
  call memocc(i_stat,nlpspd%keyv_p,'nlpspd%keyv_p',subname)
  allocate(proj(nlpspd%nprojel+ndebug),stat=i_stat)
  call memocc(i_stat,proj,'proj',subname)

  ! After having determined the size of the projector descriptor arrays fill them
  do iat=1,at%nat
     call numb_proj(at%iatype(iat),at%ntypes,at%psppar,at%npspcode,mproj)
     if (mproj.ne.0) then 

        ! coarse grid quantities
        nl1=nlpspd%nboxp_c(1,1,iat) 
        nl2=nlpspd%nboxp_c(1,2,iat) 
        nl3=nlpspd%nboxp_c(1,3,iat) 

        nu1=nlpspd%nboxp_c(2,1,iat)
        nu2=nlpspd%nboxp_c(2,2,iat)
        nu3=nlpspd%nboxp_c(2,3,iat)

        call fill_logrid(at%geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,3),cpmult,hx,hy,hz,logrid)

        iseg=nlpspd%nseg_p(2*iat-2)+1
        mseg=nlpspd%nseg_p(2*iat-1)-nlpspd%nseg_p(2*iat-2)

        call segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,  & 
             logrid,mseg,nlpspd%keyg_p(1,iseg),nlpspd%keyv_p(iseg))

        ! fine grid quantities
        nl1=nlpspd%nboxp_f(1,1,iat)
        nl2=nlpspd%nboxp_f(1,2,iat)
        nl3=nlpspd%nboxp_f(1,3,iat)

        nu1=nlpspd%nboxp_f(2,1,iat)
        nu2=nlpspd%nboxp_f(2,2,iat)
        nu3=nlpspd%nboxp_f(2,3,iat)

        call fill_logrid(at%geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,2),fpmult,hx,hy,hz,logrid)
        iseg=nlpspd%nseg_p(2*iat-1)+1
        mseg=nlpspd%nseg_p(2*iat)-nlpspd%nseg_p(2*iat-1)
        if (mseg > 0) then
           call segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,  & 
                logrid,mseg,nlpspd%keyg_p(1,iseg),nlpspd%keyv_p(iseg))
        end if
     endif
  enddo

  i_all=-product(shape(logrid))*kind(logrid)
  deallocate(logrid,stat=i_stat)
  call memocc(i_stat,i_all,'logrid',subname)

  !fill the projectors if the strategy is a distributed calculation
  if (.not. DistProjApply) then
     !calculate the wavelet expansion of projectors
     call fill_projectors(iproc,lr,hx,hy,hz,at,orbs,rxyz,nlpspd,proj,0)
  end if

END SUBROUTINE createProjectorsArrays


!>   input guess wavefunction diagonalization
subroutine input_wf_diag(iproc,nproc,at,&
     orbs,nvirt,comms,Glr,hx,hy,hz,rxyz,rhopot,rhocore,pot_ion,&
     nlpspd,proj,pkernel,pkernelseq,ixc,psi,hpsi,psit,G,&
     nscatterarr,ngatherarr,nspin,potshortcut,symObj,irrzon,phnons,GPU,input,radii_cf,orbsv)
  ! Input wavefunctions are found by a diagonalization in a minimal basis set
  ! Each processors write its initial wavefunctions into the wavefunction file
  ! The files are then read by readwave
  use module_base
  use module_interfaces, except_this_one => input_wf_diag
  use module_types
  use Poisson_Solver
  use libxc_functionals
  implicit none
  !Arguments
  integer, intent(in) :: iproc,nproc,ixc,symObj
  integer, intent(inout) :: nspin,nvirt
  real(gp), intent(in) :: hx,hy,hz
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(inout) :: orbs
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(locreg_descriptors), intent(in) :: Glr
  type(communications_arrays), intent(in) :: comms
  type(GPU_pointers), intent(inout) :: GPU
  type(input_variables):: input
  integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
  integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(wp), dimension(nlpspd%nprojel), intent(in) :: proj
  real(dp), dimension(*), intent(inout) :: rhopot,pot_ion
  type(gaussian_basis), intent(out) :: G !basis for davidson IG
  real(wp), dimension(:), pointer :: psi,hpsi,psit,rhocore
  real(dp), dimension(:), pointer :: pkernel,pkernelseq
  integer, intent(in) ::potshortcut
  integer, dimension(*), intent(in) :: irrzon
  real(dp), dimension(*), intent(in) :: phnons
  real(gp), dimension(at%ntypes,3+ndebug), intent(in) :: radii_cf
  !local variables
  character(len=*), parameter :: subname='input_wf_diag'
  logical :: switchGPUconv,switchOCLconv
  integer :: i_stat,i_all,iat,nspin_ig,iorb,idum=0
  real(kind=4) :: tt,builtin_rand
  real(gp) :: hxh,hyh,hzh,eks,eexcu,vexcu,epot_sum,ekin_sum,ehart,eexctX,eproj_sum,etol,accurex
  type(orbitals_data) :: orbse
  type(communications_arrays) :: commse
  integer, dimension(:,:), allocatable :: norbsc_arr
  real(wp), dimension(:), allocatable :: potxc
  real(gp), dimension(:), allocatable :: locrad
  real(wp), dimension(:), pointer :: pot
  real(wp), dimension(:,:,:), pointer :: psigau
! #### Linear Scaling Variables
  type(locreg_descriptors), dimension(:), allocatable :: Llr
  integer :: nlr,npsidim,ilr,norbe,ind, indSmall, indLarge, indSpin, ispin, i1, i2, i3
  integer,dimension(:,:), allocatable :: outofzone
  integer, parameter :: nmax=6,lmax=3,noccmax=2,nelecmax=32
  integer,dimension(lmax+1) :: nmoments
  real(gp), dimension(noccmax,lmax+1) :: occup
  integer,dimension(:),allocatable:: Localnorb
  real(dp),dimension(:),pointer:: Lpot,Lpsi,Lhpsi
  real(wp),dimension(:,:,:),allocatable :: Lhamovr,hamovr
  real(wp),dimension(:,:,:,:,:),allocatable :: work1, work2
  integer :: size_pot,size_Lpot,Gpsidim,norbp
  logical :: exctX,linear
  integer :: dim1,dim2
  integer :: ilr2,isovrlp,psidim1,psishift1,psidim2,psishift2
  integer :: dim_Lhamovr,Lnorbovr
  real(dp) :: factor
  integer,dimension(at%nat) :: projflg
  type(nonlocal_psp_descriptors) :: Lnlpspd
  integer :: norbi_max,ndim_hamovr
  integer,dimension(5) :: sizes
  integer :: lastrow,lastcol,firstrow,firstcol,spinshift,orbshift,totshift
  integer :: ikpt,ikptp,natsceff,ispsi,norbsc,ldim     ! for testing DiagHam
  integer :: nvctrp,norbtot,ispsie,ispsiv              !
  integer, dimension(:,:), allocatable :: norbgrp      !
  type(orbitals_data), optional, intent(in) :: orbsv   !
  real(wp), dimension(:), pointer :: psivirt           ! still for testing DiagHam


  nlr = at%nat   !!<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  allocate(norbsc_arr(at%natsc+1,nspin+ndebug),stat=i_stat)
  call memocc(i_stat,norbsc_arr,'norbsc_arr',subname)
  allocate(locrad(nlr+ndebug),stat=i_stat)
  call memocc(i_stat,locrad,'locrad',subname)

  if (iproc == 0) then
     write(*,'(1x,a)')&
          '------------------------------------------------------- Input Wavefunctions Creation'
  end if

  !spin for inputguess orbitals
  if (nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=nspin
  end if

  call inputguess_gaussian_orbitals(iproc,nproc,at,rxyz,Glr,nvirt,nspin_ig,&
       orbs,orbse,norbsc_arr,locrad,G,psigau,eks)

  !allocate communications arrays for inputguess orbitals
  !call allocate_comms(nproc,orbse,commse,subname)
  call orbitals_communicators(iproc,nproc,Glr,orbse,commse)  

  hxh=.5_gp*hx
  hyh=.5_gp*hy
  hzh=.5_gp*hz

  !check the communication distribution
  !call check_communications(iproc,nproc,orbse,Glr,commse)

  !once the wavefunction coefficients are known perform a set 
  !of nonblocking send-receive operations to calculate overlap matrices

!!!  !create mpirequests array for controlling the success of the send-receive operation
!!!  allocate(mpirequests(nproc-1+ndebug),stat=i_stat)
!!!  call memocc(i_stat,mpirequests,'mpirequests',subname)
!!!
!!!  call nonblocking_transposition(iproc,nproc,G%ncoeff,orbse%isorb+orbse%norbp,&
!!!       orbse%nspinor,psigau,orbse%norb_par,mpirequests)

! ###################################################################
!!experimental part for building the localisation regions
! ###################################################################
  linear = .true.
  if (linear) then  
     !allocate the array of localisation regions
     allocate(Llr(nlr+ndebug),stat=i_stat)
     !call memocc(i_stat,Llr,'Llr',subname)
     allocate(outofzone(3,nlr),stat=i_stat)
     call memocc(i_stat,outofzone,'outofzone',subname)
   
     ! For now, set locrad by hand HERE
     locrad = 30.0d+0                    !<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<LOCRAD
     !print *,'locrad',locrad
   
   ! Write some physical information on the Glr
     write(*,'(a24,3i4)')'Global region n1,n2,n3:',Glr%d%n1,Glr%d%n2,Glr%d%n3
     write(*,'(a27,f6.2,f6.2,f6.2)')'Global dimension (x,y,z):',Glr%d%n1*input%hx,Glr%d%n2*input%hy,Glr%d%n3*input%hz
     write(*,'(a17,f12.2)')'Global volume: ',Glr%d%n1*input%hx*Glr%d%n2*input%hy*Glr%d%n3*input%hz
     print *,'Global statistics:',Glr%wfd%nseg_c,Glr%wfd%nseg_f,Glr%wfd%nvctr_c,Glr%wfd%nvctr_f
   
     call determine_locreg_periodic(nlr,rxyz,locrad,hx,hy,hz,Glr,Llr,outofzone)
   
     allocate(Localnorb(nlr), stat=i_stat)
     call memocc(i_stat,Localnorb,'Localnorb',subname)
   
   ! Calculate the dimension of the total wavefunction
   ! NOTES: WORKS ONLY BECAUSE Llr coincides with the atoms !!
   ! NOTES: K-Points??
     npsidim = 0
     do ilr = 1, nlr
        call count_atomic_shells(lmax+1,noccmax,nelecmax,input%nspin,orbse%nspinor,at%aocc(1,ilr),occup,nmoments)
        norbe=(nmoments(1)+3*nmoments(2)+5*nmoments(3)+7*nmoments(4))
        Localnorb(ilr)=norbe
        npsidim = npsidim +(Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*norbe*orbse%nspinor*input%nspin
     end do
   !  print *,'orbse%npsidim,npsidim',orbse%npsidim,npsidim
     orbse%npsidim=npsidim
   
   ! Determine inwhichlocreg
     call assignToLocreg(iproc, at%nat, nlr, input%nspin, Localnorb, orbse)
     print *,'orbs%norb',orbs%norb
     print *,'orbse%norb',orbse%norb
     print *,'Localnorb',Localnorb
     do ilr=1,orbse%norb
       write(*,*) 'iorb, iwl', ilr, orbse%inWhichLocreg(ilr)
     end do
   
    !allocate the wavefunction in the transposed way to avoid allocations/deallocations
     allocate(Lpsi(npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,psi,'psi',subname)
     call razero(npsidim,Lpsi)
   
    ! Construct wavefunction inside the locregs (the orbitals are ordered by locreg)
        call gaussians_to_wavelets_new2(iproc,nproc,nlr,Llr,orbse,&
          hx,hy,hz,G,psigau(1,1,min(orbse%isorb+1,orbse%norb)),Lpsi(1))
    
     ! Print the wavefunctions
     factor = real(Glr%d%n1,dp)/real(Llr(1)%d%n1,dp)
     dim1 = Llr(1)%wfd%nvctr_c+7*Llr(1)%wfd%nvctr_f
     dim2 = Llr(2)%wfd%nvctr_c+7*Llr(2)%wfd%nvctr_f
     call plot_wf('orbital1   ',1,at,factor,Llr(1),hx,hy,hz,rxyz,Lpsi(1:dim1),'')
     call plot_wf('orbital2   ',1,at,factor,Llr(1),hx,hy,hz,rxyz,Lpsi(dim1+1:dim1+dim1),'')
     factor = real(Glr%d%n1,dp)/real(Llr(2)%d%n1,dp)
     call plot_wf('orbital3   ',1,at,factor,Llr(2),hx,hy,hz,rxyz,Lpsi(dim1+dim1+1:2*dim1+dim2),'')
     call plot_wf('orbital4   ',1,at,factor,Llr(2),hx,hy,hz,rxyz,Lpsi(2*dim1+dim2+1:2*dim1+2*dim2),'')

     open(44,file='Lpsi2',status='unknown')
     do ilr = 1,size(Lpsi)
     write(44,*)Lpsi(ilr)
     end do
     close(44)
   
     call sumrhoLinear(iproc,nproc,nlr,orbse,Glr,Llr,ixc,hxh,hyh,hzh,&
       Lpsi,rhopot,&
       & Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,1),nscatterarr,nspin,GPU, &
       & symObj, irrzon, phnons)    
 
     !call sumrho(iproc,nproc,orbse,Glr,ixc,hxh,hyh,hzh,psi,rhopot,&
     !     & Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,1),nscatterarr,nspin,GPU, &
     !     & symObj, irrzon, phnons)
   
         
        !i_all=-product(shape(Lrho))*kind(Lrho)
        !deallocate(Lrho,stat=i_stat)
        !call memocc(i_stat,i_all,'Lrho',subname)
   
     !ind=1
     !do ilr= 1, nlr
   
        !!allocate(Lrho(Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*nspin), stat=i_stat)
        !!call memocc(i_stat,Lrho,'Lrho',subname)
   
        !if (nscatterarr(iproc,2) >0) then
           allocate(potxc(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)*nspin+ndebug),stat=i_stat)
           !!allocate(Lpotxc(Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*nspin+ndebug),stat=i_stat)
           !!call memocc(i_stat,Lpotxc,'Lpotxc',subname)
        !else
        !   allocate(potxc(1+ndebug),stat=i_stat)
        !   call memocc(i_stat,potxc,'potxc',subname)
        !end if
   
        call XC_potential(Glr%geocode,'D',iproc,nproc,&
             Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,ixc,hxh,hyh,hzh,&
             rhopot,eexcu,vexcu,nspin,rhocore,potxc)
   
         write(*,*) 'eexcu, vexcu', eexcu, vexcu
   
        if( iand(potshortcut,4)==0) then
           call H_potential(Glr%geocode,'D',iproc,nproc,&
                Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,hxh,hyh,hzh,&
                rhopot,pkernel,pot_ion,ehart,0.0_dp,.true.)
        endif
   
   
        !sum the two potentials in rhopot array
        !fill the other part, for spin, polarised
        if (nspin == 2) then
           call dcopy(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),rhopot(1),1,&
                rhopot(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)+1),1)
        end if
        !spin up and down together with the XC part
        call axpy(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)*nspin,1.0_dp,potxc(1),1,&
             rhopot(1),1)
   
        i_all=-product(shape(potxc))*kind(potxc)
        deallocate(potxc,stat=i_stat)
        call memocc(i_stat,i_all,'potxc',subname)
   
        if (input%exctxpar == 'OP2P') eexctX = -99.0_gp
    
        call full_local_potential(iproc,nproc,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
             Glr%d%n1i*Glr%d%n2i*Glr%d%n3i,nspin,&
             orbse%norb,orbse%norbp,ngatherarr,rhopot,pot)    
        print *,'sum of pot:',sum(pot)
   
   
       !allocate the wavefunction in the transposed way to avoid allocations/deallocations
        allocate(Lhpsi(npsidim+ndebug),stat=i_stat)
        call memocc(i_stat,Lhpsi,'Lhpsi',subname)
   
        exctX = libxc_functionals_exctXfac() /= 0.0_gp
   
   
        ! Copy the value of orbse%norbp to a buffer
          norbp = orbse%norbp
   
        ! Beginning loop on locregs
        ind = 1
        do ilr= 1, nlr
   
           allocate(Lpot(Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*nspin), stat=i_stat)
           call memocc(i_stat,Lpot,'Lpot',subname)
           
           ! replace orbse%norbp by Localnorb for HamiltonianApplication
           orbse%norbp = Localnorb(ilr)*input%nspin
   
           !determine the dimension of the potential array (copied from full_local_potential)
           if (exctX) then
              size_pot=Glr%d%n1i*Glr%d%n2i*Glr%d%n3i*nspin + &
               max(max(Glr%d%n1i*Glr%d%n2i*Glr%d%n3i*orbse%norbp,ngatherarr(0,1)*orbse%norb),1) !part which refers to exact exchange
              size_Lpot=Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*nspin + &
                 max(max(Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*orbse%norbp,ngatherarr(0,1)*orbse%norb),1) !CHECK THIS...DOES NOT WORK YET
           else
              size_pot=Glr%d%n1i*Glr%d%n2i*Glr%d%n3i*nspin
              size_Lpot = Llr(ilr)%d%n1i*Llr(ilr)%d%n2i*Llr(ilr)%d%n3i*nspin
           end if
   
           ! Cut the potential into locreg pieces
           call global_to_local(Glr,Llr(ilr),nspin,size_pot,size_Lpot,pot,Lpot)
           print *,'ilr, sum(Lpot):',ilr, sum(Lpot)
   
           ! Make the local non-linear pseudopotentials descriptors
           call nlpspd_to_locreg(input,iproc,Glr,Llr(ilr),rxyz,at,orbse,&
   &       radii_cf,input%frmult,input%frmult,input%hx,input%hy,input%hz,nlpspd,Lnlpspd,projflg)
   
           call HamiltonianApplication(iproc,nproc,at,orbse,hx,hy,hz,rxyz,&
                 Lnlpspd,proj,Llr(ilr),ngatherarr,Lpot,&
                 Lpsi(ind:ind+(Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*Localnorb(ilr)*orbse%nspinor*input%nspin-1),&
                 Lhpsi(ind:ind+(Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*Localnorb(ilr)*orbse%nspinor*input%nspin-1),&
                 ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU,pkernel=pkernelseq,projflg=projflg)
   
           accurex=abs(eks-ekin_sum)
           !tolerance for comparing the eigenvalues in the case of degeneracies
           etol=accurex/real(orbse%norbu,gp)
           if (iproc == 0 .and. verbose > 1) write(*,'(1x,a,2(f19.10))') 'done. ekin_sum,eks:',ekin_sum,eks
           if (iproc == 0) then
              write(*,'(1x,a,3(1x,1pe18.11))') 'ekin_sum,epot_sum,eproj_sum',  &
                   ekin_sum,epot_sum,eproj_sum
              write(*,'(1x,a,3(1x,1pe18.11))') '   ehart,   eexcu,    vexcu',ehart,eexcu,vexcu
           endif   
   
           ind = ind + (Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*Localnorb(ilr)*orbse%nspinor*input%nspin
   
           ! deallocate Lpot
           call free_full_potential(nproc,Lpot,subname)
   
           !free GPU if it is the case
           if (GPUconv) then
              call free_gpu(GPU,orbse%norbp)
           else if (OCLconv) then
              call free_gpu_OCL(GPU,orbse,nspin_ig)
           end if
         
           if (iproc == 0 .and. verbose > 1) write(*,'(1x,a)')&
                'Input Wavefunctions Orthogonalization:'
         
        end do
   
   ! Now the wavefunctions (Lpsi) and the Hamiltonian applied to the wavefunctions (Lhpsi)
   ! are completely constructed. We must now solve the eigensystem by diagonalizating the
   ! Hamiltonian (usually done by calling DiagHam_linear). In our case, we must fisrt construct
   ! the sparse hamiltonian/overlap matrix using the locregs
   
    if (iproc == 0 .and. verbose > 1) write(*,'(1x,a)',advance='no')&
          'Overlap Matrix...'
   
       ! number of orbitals, dimension and allocation of Global hamiltonian/overlap matrix
       norbi_max=max(orbse%norbu,orbse%norbd)
       ndim_hamovr = norbi_max**2
       allocate(hamovr(nspin*ndim_hamovr,2,orbse%nkpts+ndebug),stat=i_stat)
       call memocc(i_stat,hamovr,'hamovr',subname)
   
       ! put zeros everywhere
       call razero(nspin*ndim_hamovr*2*orbse%nkpts+ndebug,hamovr)
   
       ! reshape for easy assignation
       allocate(work1(norbi_max, norbi_max, nspin,2,orbse%nkpts+ndebug),stat=i_stat)
       call memocc(i_stat,work1,'work1',subname)
       sizes = (/ norbi_max, norbi_max, nspin, 2, orbse%nkpts+ndebug /)
       work1 = reshape(hamovr,sizes)
   
       psishift1 = 1
       firstrow  = 1
       lastrow   = 0
       ! The loop on ilr gives the row indexes, the loop on ilr2 gives the column indexes
       do ilr = 1, nlr
          firstcol = 1
          lastcol  = 0
          psishift2 = 1
          lastrow  = lastrow  + Localnorb(ilr)
          psidim1 = (Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*Localnorb(ilr)*orbs%nspinor
          do ilr2 = 1,nlr
          
             psidim2 = (Llr(ilr2)%wfd%nvctr_c+7*Llr(ilr2)%wfd%nvctr_f)*Localnorb(ilr2)*orbs%nspinor
   
             call get_number_of_overlap_region(ilr,ilr2,Glr,isovrlp,Llr,nlr,outofzone)

             ! If no overlap, increment the index of Lpsi and overlap matrix then cycle
             if(isovrlp == 0)then
                psishift2 = psishift2 + psidim2*nspin
                firstcol = firstcol + Localnorb(ilr2)
                lastcol  = lastcol  + Localnorb(ilr2)
                cycle
             end if
             ! dimensions and allocation of Local hamiltonian/overlap matrix
             dim_Lhamovr = Localnorb(ilr) * Localnorb(ilr2)
             allocate(Lhamovr(nspin*dim_Lhamovr,2,orbse%nkpts+ndebug),stat=i_stat)
             call memocc(i_stat,Lhamovr,'Lhamovr',subname)
   
          ! In this routine, we begin by calculating the hamiltonian/overlap matrix between two locregs.
             call overlap_matrix_between_locreg(ilr,ilr2,isovrlp,nlr,nspin,psidim1,psidim2,psishift1,&
                psishift2,npsidim,orbse,Glr,Llr,Lpsi,Lhpsi,Localnorb,outofzone,dim_Lhamovr,Lhamovr)
   
          ! update the shift for second wavefunction
             psishift2 = psishift2 + psidim2*nspin
   
          ! reshape the hamiltonian/overlap matrix for easy assignations
            allocate(work2(Localnorb(ilr),Localnorb(ilr2),nspin,2,orbse%nkpts+ndebug),stat=i_stat)
            call memocc(i_stat,work2,'work2',subname)
            sizes = (/ Localnorb(ilr), Localnorb(ilr2), nspin, 2, orbse%nkpts+ndebug /)
            work2 = reshape(Lhamovr,sizes)
   
          ! Assign the calculated values inside global matrix (for truly O(N) this should be replaced) 
            lastcol  = lastcol  + Localnorb(ilr2)
            work1(firstrow:lastrow,firstcol:lastcol,:,:,:) = work2(:,:,:,:,:)
   
          ! deallocate this instance of Lhamovr
             i_all=-product(shape(work2))*kind(work2)
             deallocate(work2,stat=i_stat)
             call memocc(i_stat,i_all,'work2',subname) 
   
             i_all=-product(shape(Lhamovr))*kind(Lhamovr)
             deallocate(Lhamovr,stat=i_stat)
             call memocc(i_stat,i_all,'Lhamovr',subname) 
   
          ! update indexes
            firstcol = firstcol + Localnorb(ilr2)
          end do 
          ! increment the shift of wavefunctions
          psishift1 = psishift1 + psidim1*input%nspin
          firstrow = firstrow + Localnorb(ilr)
       end do
   
       ! reshape back to original shape
       hamovr = reshape(work1,(/ nspin*ndim_hamovr, 2, orbse%nkpts+ndebug /))
       i_all=-product(shape(work1))*kind(work1)
       deallocate(work1,stat=i_stat)
       call memocc(i_stat,i_all,'work1',subname) 
   
       print *,'hamovr, ham:',hamovr(:,1,:)
       print *,'hamovr, ovr:',hamovr(:,2,:)

       ! Don't need Lhpsi anymore
       i_all=-product(shape(Lhpsi))*kind(Lhpsi)
       deallocate(Lhpsi,stat=i_stat)
       call memocc(i_stat,i_all,'Lhpsi',subname)

       ! Now solve the eigensystem: H |Lpsi> = epsilon S |Lpsi>  
       if(iproc==0) write(*,'(1x,a)') 'Direct diagonalization...'

!       call timing(iproc, 'Input_comput', 'ON')

       ! SET SOME VARIABLE FOR NOW (NO SEMICORE)
       ispsi=1
       natsceff = 0
       allocate(norbgrp(1,nspin+ndebug),stat=i_stat)
       call memocc(i_stat,norbgrp,'norbgrp',subname)
       norbsc=0
       norbgrp(1,1)=orbse%norbu
       if (nspin == 2) norbgrp(1,2)=orbse%norbd

       !it is important that the k-points repartition of the inputguess orbitals
       !coincides with the one of the SCF orbitals
       do ikptp=1,orbse%nkptsp
          ikpt=orbse%iskpts+ikptp!orbs%ikptsp(ikptp)
          call solve_eigensystem(iproc,orbs%norb,orbs%norbu,orbs%norbd,norbi_max,&
               ndim_hamovr,natsceff,nspin,orbs%nspinor,etol,norbgrp,hamovr(1,1,ikpt),&
               orbs%eval((ikpt-1)*orbs%norb+1))
       end do

       if (iproc == 0 .and. verbose > 1) write(*,'(1x,a)',advance='no')'Building orthogonal Wavefunctions...'


!      FOR NOW, just transform the Lpsi to psi in global region.
       Gpsidim = (Glr%wfd%nvctr_c+7*Glr%wfd%nvctr_f)*orbs%norb*orbs%nspinor*nspin
       allocate(psi(Gpsidim+ndebug),stat=i_stat)
       call memocc(i_stat,psi,'psi',subname)
       call razero(Gpsidim+ndebug,psi)

!      WATCH OUT, does not work for nspinor > 1
       psishift1 = 1
       totshift = 0
       do ilr = 1,nlr
          ldim = (Llr(ilr)%wfd%nvctr_c+7*Llr(ilr)%wfd%nvctr_f)*Localnorb(ilr)*orbs%nspinor*nspin
          call Lpsi_to_global(Glr,Gpsidim,Llr(ilr),Lpsi(psishift1:psishift1+ldim-1),&
               ldim,Localnorb(ilr),orbs%nspinor,nspin,totshift,psi)
          psishift1 = psishift1 + ldim
          totshift = (Glr%wfd%nvctr_c+7*Glr%wfd%nvctr_f)*Localnorb(ilr)*orbs%nspinor
       end do

       allocate(psit(orbs%npsidim+ndebug),stat=i_stat)
       call memocc(i_stat,psit,'psit',subname)

       ispsi=1
       ispsie=1
       ispsiv=1
       norbtot = orbse%norb 
       do ikptp=1,orbse%nkptsp
          ikpt=orbse%iskpts+ikptp!orbsu%ikptsp(ikptp)\

!         nvctrp is not a simple quantity anymore has it depends on the locregs (can be different for every locreg)
!         for an O(N) code, should change these routines.
!         FOR NOW, just transform the Lpsi to psi in global region.
          nvctrp=Glr%wfd%nvctr_c+7*Glr%wfd%nvctr_f

          if (nvctrp == 0) cycle
          call build_eigenvectors(iproc,orbs%norbu,orbs%norbd,orbs%norb,norbtot,nvctrp,&
               natsceff,nspin,orbs%nspinor,orbs%nspinor,ndim_hamovr,norbgrp,hamovr(1,1,ikpt),&
               psi(ispsie:),psit(ispsi:))
          ispsi=ispsi+nvctrp*orbs%norb*orbs%nspinor
          ispsie=ispsie+nvctrp*norbtot*orbs%nspinor
          if (present(orbsv)) ispsiv=ispsiv+nvctrp*orbsv%norb*orbs%nspinor
       end do

 
       !if(nproc==1.and.nspinor==4) call psitransspi(nvctrp,norbu+norbd,psit,.false.)
       if (iproc == 0 .and. verbose > 1) write(*,'(1x,a)') 'done.'

       !deallocate psi
       i_all=-product(shape(psi))*kind(psi)
       deallocate(psi,stat=i_stat)
       call memocc(i_stat,i_all,'psi',subname) 
       !reallocate psi
       allocate(psi(orbs%npsidim+ndebug),stat=i_stat)
       call memocc(i_stat,psi,'psi',subname)
       psi = psit

       !allocate hpsi for rest of code
       allocate(hpsi(orbs%npsidim+ndebug),stat=i_stat)
       call memocc(i_stat,hpsi,'hpsi',subname)

       !Undo the modification of orbse%norbp
        orbse%norbp = norbp
        orbse%npsidim = npsidim
       !deallocate potential
       !call free_full_potential(nproc,pot,subname)
   
!####################################################################################################################################################
! END EXPERIMENTAL
!####################################################################################################################################################
  else
   !allocate the wavefunction in the transposed way to avoid allocations/deallocations
     allocate(psi(orbse%npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,psi,'psi',subname)
   
     !allocate arrays for the GPU if a card is present
     switchGPUconv=.false.
     switchOCLconv=.false.
     if (GPUconv .and. potshortcut ==0 ) then
        call prepare_gpu_for_locham(Glr%d%n1,Glr%d%n2,Glr%d%n3,nspin_ig,&
             hx,hy,hz,Glr%wfd,orbse,GPU)
     else if (OCLconv .and. potshortcut ==0) then
        call allocate_data_OCL(Glr%d%n1,Glr%d%n2,Glr%d%n3,at%geocode,&
             nspin_ig,hx,hy,hz,Glr%wfd,orbse,GPU)
        if (iproc == 0) write(*,*)&
             'GPU data allocated'
     else if (GPUconv .and. potshortcut >0 ) then
        switchGPUconv=.true.
        GPUconv=.false.
     else if (OCLconv .and. potshortcut >0 ) then
        switchOCLconv=.true.
        OCLconv=.false.
     end if
   
   
   !use only the part of the arrays for building the hamiltonian matrix
     call gaussians_to_wavelets_new(iproc,nproc,Glr,orbse,hx,hy,hz,G,&
          psigau(1,1,min(orbse%isorb+1,orbse%norb)),psi)
   
   
     i_all=-product(shape(locrad))*kind(locrad)
     deallocate(locrad,stat=i_stat)
     call memocc(i_stat,i_all,'locrad',subname)
   
     !application of the hamiltonian for gaussian based treatment
     call sumrho(iproc,nproc,orbse,Glr,ixc,hxh,hyh,hzh,psi,rhopot,&
          & Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,1),nscatterarr,nspin,GPU, &
          & symObj, irrzon, phnons)
        
     !-- if spectra calculation uses a energy dependent potential
     !    input_wf_diag will write (to be used in abscalc)
     !    the density to the file electronic_density.cube
     !  The writing is activated if  5th bit of  in%potshortcut is on.
     if( iand( potshortcut,16)==0 .and. potshortcut /= 0) then
        call plot_density_cube_old(at%geocode,'electronic_density',&
             iproc,nproc,Glr%d%n1,Glr%d%n2,Glr%d%n3,Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,nscatterarr(iproc,2),  & 
             nspin,hxh,hyh,hzh,at,rxyz,ngatherarr,rhopot(1+nscatterarr(iproc,4)*Glr%d%n1i*Glr%d%n2i))
     endif
     !---
     
     if(orbs%nspinor==4) then
        !this wrapper can be inserted inside the poisson solver 
        call PSolverNC(at%geocode,'D',iproc,nproc,Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,&
             nscatterarr(iproc,1),& !this is n3d
             ixc,hxh,hyh,hzh,&
             rhopot,pkernel,pot_ion,ehart,eexcu,vexcu,0.d0,.true.,4)
     else
        !Allocate XC potential
        if (nscatterarr(iproc,2) >0) then
           allocate(potxc(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)*nspin+ndebug),stat=i_stat)
           call memocc(i_stat,potxc,'potxc',subname)
        else
           allocate(potxc(1+ndebug),stat=i_stat)
           call memocc(i_stat,potxc,'potxc',subname)
        end if
   
        call XC_potential(at%geocode,'D',iproc,nproc,&
             Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,ixc,hxh,hyh,hzh,&
             rhopot,eexcu,vexcu,nspin,rhocore,potxc)
   
   
        if( iand(potshortcut,4)==0) then
           call H_potential(at%geocode,'D',iproc,nproc,&
                Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,hxh,hyh,hzh,&
                rhopot,pkernel,pot_ion,ehart,0.0_dp,.true.)
        endif
   
   
        !sum the two potentials in rhopot array
        !fill the other part, for spin, polarised
        if (nspin == 2) then
           call dcopy(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),rhopot(1),1,&
                rhopot(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)+1),1)
        end if
        !spin up and down together with the XC part
        call axpy(Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2)*nspin,1.0_dp,potxc(1),1,&
             rhopot(1),1)
   
   
        i_all=-product(shape(potxc))*kind(potxc)
        deallocate(potxc,stat=i_stat)
        call memocc(i_stat,i_all,'potxc',subname)
   
     end if
   
   !!!  if (nproc == 1) then
   !!!     !calculate the overlap matrix as well as the kinetic overlap
   !!!     !in view of complete gaussian calculation
   !!!     allocate(ovrlp(G%ncoeff*G%ncoeff),stat=i_stat)
   !!!     call memocc(i_stat,ovrlp,'ovrlp',subname)
   !!!     allocate(tmp(G%ncoeff,orbse%norb),stat=i_stat)
   !!!     call memocc(i_stat,tmp,'tmp',subname)
   !!!     allocate(smat(orbse%norb,orbse%norb),stat=i_stat)
   !!!     call memocc(i_stat,smat,'smat',subname)
   !!!
   !!!     !overlap calculation of the gaussian matrix
   !!!     call gaussian_overlap(G,G,ovrlp)
   !!!     call dsymm('L','U',G%ncoeff,orbse%norb,1.0_gp,ovrlp(1),G%ncoeff,&
   !!!          gaucoeff(1,1),G%ncoeff,0.d0,tmp(1,1),G%ncoeff)
   !!!
   !!!     call gemm('T','N',orbse%norb,orbse%norb,G%ncoeff,1.0_gp,&
   !!!          gaucoeff(1,1),G%ncoeff,tmp(1,1),G%ncoeff,0.0_wp,smat(1,1),orbse%norb)
   !!!
   !!!     !print overlap matrices
   !!!     do i=1,orbse%norb
   !!!        write(*,'(i5,30(1pe15.8))')i,(smat(i,iorb),iorb=1,orbse%norb)
   !!!     end do
   !!!
   !!!     !overlap calculation of the kinetic operator
   !!!     call kinetic_overlap(G,G,ovrlp)
   !!!     call dsymm('L','U',G%ncoeff,orbse%norb,1.0_gp,ovrlp(1),G%ncoeff,&
   !!!          gaucoeff(1,1),G%ncoeff,0.d0,tmp(1,1),G%ncoeff)
   !!!
   !!!     call gemm('T','N',orbse%norb,orbse%norb,G%ncoeff,1.0_gp,&
   !!!          gaucoeff(1,1),G%ncoeff,tmp(1,1),G%ncoeff,0.0_wp,smat(1,1),orbse%norb)
   !!!
   !!!     !print overlap matrices
   !!!     tt=0.0_wp
   !!!     do i=1,orbse%norb
   !!!        write(*,'(i5,30(1pe15.8))')i,(smat(i,iorb),iorb=1,orbse%norb)
   !!!        !write(12,'(i5,30(1pe15.8))')i,(smat(i,iorb),iorb=1,orbse%norb)
   !!!        tt=tt+smat(i,i)
   !!!     end do
   !!!     print *,'trace',tt
   !!!
   !!!     !overlap calculation of the kinetic operator
   !!!     call cpu_time(t0)
   !!!     call potential_overlap(G,G,rhopot,Glr%d%n1i,Glr%d%n2i,Glr%d%n3i,hxh,hyh,hzh,&
   !!!          ovrlp)
   !!!     call cpu_time(t1)
   !!!     call dsymm('L','U',G%ncoeff,orbse%norb,1.0_gp,ovrlp(1),G%ncoeff,&
   !!!          gaucoeff(1,1),G%ncoeff,0.d0,tmp(1,1),G%ncoeff)
   !!!
   !!!     call gemm('T','N',orbse%norb,orbse%norb,G%ncoeff,1.0_gp,&
   !!!          gaucoeff(1,1),G%ncoeff,tmp(1,1),G%ncoeff,0.0_wp,smat(1,1),orbse%norb)
   !!!
   !!!     !print overlap matrices
   !!!     tt=0.0_wp
   !!!     do i=1,orbse%norb
   !!!        write(*,'(i5,30(1pe15.8))')i,(smat(i,iorb),iorb=1,orbse%norb)
   !!!        !write(12,'(i5,30(1pe15.8))')i,(smat(i,iorb),iorb=1,orbse%norb)
   !!!        tt=tt+smat(i,i)
   !!!     end do
   !!!     print *,'trace',tt
   !!!     print *, 'time',t1-t0
   !!!
   !!!     i_all=-product(shape(ovrlp))*kind(ovrlp)
   !!!     deallocate(ovrlp,stat=i_stat)
   !!!     call memocc(i_stat,i_all,'ovrlp',subname)
   !!!     i_all=-product(shape(tmp))*kind(tmp)
   !!!     deallocate(tmp,stat=i_stat)
   !!!     call memocc(i_stat,i_all,'tmp',subname)
   !!!     i_all=-product(shape(smat))*kind(smat)
   !!!     deallocate(smat,stat=i_stat)
   !!!     call memocc(i_stat,i_all,'smat',subname)
   !!!  end if
   
     if(potshortcut>0) then
   !!$    if (GPUconv) then
   !!$       call free_gpu(GPU,orbs%norbp)
   !!$    end if
        if (switchGPUconv) then
           GPUconv=.true.
        end if
        if (switchOCLconv) then
           OCLconv=.true.
        end if
   
        call deallocate_orbs(orbse,subname)
        
        !deallocate the gaussian basis descriptors
        call deallocate_gwf(G,subname)
       
        i_all=-product(shape(psigau))*kind(psigau)
        deallocate(psigau,stat=i_stat)
        call memocc(i_stat,i_all,'psigau',subname)
        call deallocate_comms(commse,subname)
        i_all=-product(shape(norbsc_arr))*kind(norbsc_arr)
        deallocate(norbsc_arr,stat=i_stat)
        call memocc(i_stat,i_all,'norbsc_arr',subname)
       return 
     end if
   
     !allocate the wavefunction in the transposed way to avoid allocations/deallocations
     allocate(hpsi(orbse%npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,hpsi,'hpsi',subname)
   
     !call dcopy(orbse%npsidim,psi,1,hpsi,1)
     if (input%exctxpar == 'OP2P') eexctX = -99.0_gp
   
     call full_local_potential(iproc,nproc,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),Glr%d%n1i*Glr%d%n2i*Glr%d%n3i,nspin,&
          orbse%norb,orbse%norbp,ngatherarr,rhopot,pot)
   
     call HamiltonianApplication(iproc,nproc,at,orbse,hx,hy,hz,rxyz,&
          nlpspd,proj,Glr,ngatherarr,pot,&
          psi,hpsi,ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU,pkernel=pkernelseq)
   
     !deallocate potential
     call free_full_potential(nproc,pot,subname)
   
   !!!  !calculate the overlap matrix knowing that the original functions are gaussian-based
   !!!  allocate(thetaphi(2,G%nat+ndebug),stat=i_stat)
   !!!  call memocc(i_stat,thetaphi,'thetaphi',subname)
   !!!  thetaphi=0.0_gp
   !!!
   !!!  !calculate the scalar product between the hamiltonian and the gaussian basis
   !!!  allocate(hpsigau(G%ncoeff,orbse%norbp+ndebug),stat=i_stat)
   !!!  call memocc(i_stat,hpsigau,'hpsigau',subname)
   !!!
   !!!
   !!!  call wavelets_to_gaussians(at%geocode,orbse%norbp,Glr%d%n1,Glr%d%n2,Glr%d%n3,G,&
   !!!       thetaphi,hx,hy,hz,Glr%wfd,hpsi,hpsigau)
   !!!
   !!!  i_all=-product(shape(thetaphi))*kind(thetaphi)
   !!!  deallocate(thetaphi,stat=i_stat)
   !!!  call memocc(i_stat,i_all,'thetaphi',subname)
   
     accurex=abs(eks-ekin_sum)
     !tolerance for comparing the eigenvalues in the case of degeneracies
     etol=accurex/real(orbse%norbu,gp)
     if (iproc == 0 .and. verbose > 1) write(*,'(1x,a,2(f19.10))') 'done. ekin_sum,eks:',ekin_sum,eks
     if (iproc == 0) then
        write(*,'(1x,a,3(1x,1pe18.11))') 'ekin_sum,epot_sum,eproj_sum',  & 
             ekin_sum,epot_sum,eproj_sum
        write(*,'(1x,a,3(1x,1pe18.11))') '   ehart,   eexcu,    vexcu',ehart,eexcu,vexcu
     endif
   
   !!!  call Gaussian_DiagHam(iproc,nproc,at%natsc,nspin,orbs,G,mpirequests,&
   !!!       psigau,hpsigau,orbse,etol,norbsc_arr)
   
   
   !!!  i_all=-product(shape(mpirequests))*kind(mpirequests)
   !!!  deallocate(mpirequests,stat=i_stat)
   !!!  call memocc(i_stat,i_all,'mpirequests',subname)
   
   !!!  i_all=-product(shape(hpsigau))*kind(hpsigau)
   !!!  deallocate(hpsigau,stat=i_stat)
   !!!  call memocc(i_stat,i_all,'hpsigau',subname)
   
     !free GPU if it is the case
     if (GPUconv) then
        call free_gpu(GPU,orbse%norbp)
     else if (OCLconv) then
        call free_gpu_OCL(GPU,orbse,nspin_ig)
     end if
   
     if (iproc == 0 .and. verbose > 1) write(*,'(1x,a)')&
          'Input Wavefunctions Orthogonalization:'
   
     !psivirt can be eliminated here, since it will be allocated before davidson
     !with a gaussian basis
   !!$  call DiagHam(iproc,nproc,at%natsc,nspin_ig,orbs,Glr%wfd,comms,&
   !!$       psi,hpsi,psit,orbse,commse,etol,norbsc_arr,orbsv,psivirt)
   
     call DiagHam(iproc,nproc,at%natsc,nspin_ig,orbs,Glr%wfd,comms,&
          psi,hpsi,psit,input,orbse,commse,etol,norbsc_arr)

  end if  !if on linear

  if (input%itrpmax > 1 .or. input%Tel > 0.0_gp) then
     !use the eval array of orbse structure to save the original values
     allocate(orbse%eval(orbs%norb*orbs%nkpts+ndebug),stat=i_stat)
     call memocc(i_stat,orbse%eval,'orbse%eval',subname)
     
     call dcopy(orbs%norb*orbs%nkpts,orbs%eval(1),1,orbse%eval(1),1)

     !add a small displacement in the eigenvalues
     do iorb=1,orbs%norb*orbs%nkpts
        tt=builtin_rand(idum)
        orbs%eval(iorb)=orbs%eval(iorb)*(1.0_gp+max(input%Tel,1.0e-3_gp)*real(tt,gp))
     end do

     !correct the occupation numbers wrt fermi level
     call evaltoocc(iproc,nproc,.false.,input%Tel,orbs)

     !restore the occupation numbers
     call dcopy(orbs%norb*orbs%nkpts,orbse%eval(1),1,orbs%eval(1),1)

     i_all=-product(shape(orbse%eval))*kind(orbse%eval)
     deallocate(orbse%eval,stat=i_stat)
     call memocc(i_stat,i_all,'orbse%eval',subname)
  end if

  call deallocate_comms(commse,subname)

  i_all=-product(shape(norbsc_arr))*kind(norbsc_arr)
  deallocate(norbsc_arr,stat=i_stat)
  call memocc(i_stat,i_all,'norbsc_arr',subname)

  if (iproc == 0) then
     !gaussian estimation valid only for Free BC
     if (at%geocode == 'F') then
        write(*,'(1x,a,1pe9.2)') 'expected accuracy in energy ',accurex
        write(*,'(1x,a,1pe9.2)') &
          'expected accuracy in energy per orbital ',accurex/real(orbs%norb,kind=8)
        !write(*,'(1x,a,1pe9.2)') &
        !     'suggested value for gnrm_cv ',accurex/real(orbs%norb,kind=8)
     end if
  endif

  !here we can define the subroutine which generates the coefficients for the virtual orbitals
  call deallocate_gwf(G,subname)

  i_all=-product(shape(psigau))*kind(psigau)
  deallocate(psigau,stat=i_stat)
  call memocc(i_stat,i_all,'psigau',subname)

  call deallocate_orbs(orbse,subname)



END SUBROUTINE input_wf_diag
