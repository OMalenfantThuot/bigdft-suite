!> @file 
!!   Routines to use BigDFT as a blackbox
!! @author
!!   Copyright (C) 2005-2011 BigDFT group 
!!   This file is distributed under the terms of the
!!   GNU General Public License, see ~/COPYING file
!!   or http://www.gnu.org/copyleft/gpl.txt .
!!   For the list of contributors, see ~/AUTHORS 
 

!> Routine to use BigDFT as a blackbox
subroutine call_bigdft(nproc,iproc,atoms,rxyz0,in,energy,fxyz,strten,fnoise,rst,infocode)
  use module_base
  use module_types
  use module_interfaces, except_this_one => call_bigdft
  implicit none
  integer, intent(in) :: iproc,nproc
  type(input_variables),intent(inout) :: in
  type(atoms_data), intent(inout) :: atoms
  type(restart_objects), intent(inout) :: rst
  integer, intent(inout) :: infocode
  real(gp), intent(out) :: energy,fnoise
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz0
  real(gp), dimension(6), intent(out) :: strten
  real(gp), dimension(3,atoms%nat), intent(out) :: fxyz

  !local variables
  character(len=*), parameter :: subname='call_bigdft'
  character(len=40) :: comment
  logical :: exists
  integer :: i_stat,i_all,ierr,inputPsiId_orig,iat

  !temporary interface
  interface
     subroutine cluster(nproc,iproc,atoms,rxyz,energy,fxyz,strten,fnoise,&
          KSwfn,&!psi,Lzd,gaucoeffs,gbd,orbs,
          rxyz_old,hx_old,hy_old,hz_old,in,GPU,infocode)
       use module_base
       use module_types
       implicit none
       integer, intent(in) :: nproc,iproc
       integer, intent(out) :: infocode
       real(gp), intent(inout) :: hx_old,hy_old,hz_old
       type(input_variables), intent(in) :: in
       !type(local_zone_descriptors), intent(inout) :: Lzd
       type(atoms_data), intent(inout) :: atoms
       !type(gaussian_basis), intent(inout) :: gbd
       !type(orbitals_data), intent(inout) :: orbs
       type(GPU_pointers), intent(inout) :: GPU
       type(DFT_wavefunction), intent(inout) :: KSwfn
       real(gp), intent(out) :: energy,fnoise
       real(gp), dimension(3,atoms%nat), intent(inout) :: rxyz_old
       real(gp), dimension(3,atoms%nat), target, intent(inout) :: rxyz
       real(gp), dimension(6), intent(out) :: strten
       real(gp), dimension(3,atoms%nat), intent(out) :: fxyz
     END SUBROUTINE cluster
  end interface

  !put a barrier for all the processes
  call MPI_BARRIER(MPI_COMM_WORLD,ierr)

  !fill the rxyz array with the positions
  !wrap the atoms in the periodic directions when needed
  do iat=1,atoms%nat
     if (atoms%geocode == 'P') then
        rst%rxyz_new(1,iat)=modulo(rxyz0(1,iat),atoms%alat1)
        rst%rxyz_new(2,iat)=modulo(rxyz0(2,iat),atoms%alat2)
        rst%rxyz_new(3,iat)=modulo(rxyz0(3,iat),atoms%alat3)
     else if (atoms%geocode == 'S') then
        rst%rxyz_new(1,iat)=modulo(rxyz0(1,iat),atoms%alat1)
        rst%rxyz_new(2,iat)=rxyz0(2,iat)
        rst%rxyz_new(3,iat)=modulo(rxyz0(3,iat),atoms%alat3)
     else if (atoms%geocode == 'F') then
        rst%rxyz_new(1,iat)=rxyz0(1,iat)
        rst%rxyz_new(2,iat)=rxyz0(2,iat)
        rst%rxyz_new(3,iat)=rxyz0(3,iat)
     end if
  end do

  !assign the verbosity of the output
  !the verbose variables is defined in module_base
  verbose=in%verbosity

  inputPsiId_orig=in%inputPsiId

  loop_cluster: do

     if (in%inputPsiId == 0 .and. associated(rst%KSwfn%psi)) then
        i_all=-product(shape(rst%KSwfn%psi))*kind(rst%KSwfn%psi)
        deallocate(rst%KSwfn%psi,stat=i_stat)
        call memocc(i_stat,i_all,'psi',subname)
        i_all=-product(shape(rst%KSwfn%orbs%eval))*kind(rst%KSwfn%orbs%eval)
        deallocate(rst%KSwfn%orbs%eval,stat=i_stat)
        call memocc(i_stat,i_all,'eval',subname)

        call deallocate_wfd(rst%KSwfn%Lzd%Glr%wfd,subname)
     end if
     !experimental, finite difference method for calculating forces on particular quantities
     inquire(file='input.finite_difference_forces',exist=exists)
     if (exists) then
        in%last_run=1 !do the last_run things nonetheless
        in%inputPsiId=0 !the first run always restart from IG
        !experimental_modulebase_var_onlyfion=.true. !put only ionic forces in the forces
     end if
     call cluster(nproc,iproc,atoms,rst%rxyz_new,energy,fxyz,strten,fnoise,&
          rst%KSwfn,&!psi,rst%Lzd,rst%gaucoeffs,rst%gbd,rst%orbs,&
          rst%rxyz_old,rst%hx_old,rst%hy_old,rst%hz_old,in,rst%GPU,infocode)
     if (exists) then
        call forces_via_finite_differences(iproc,nproc,atoms,in,energy,fxyz,fnoise,rst,infocode)
     end if

     if (in%inputPsiId==1 .and. infocode==2) then
        if (in%gaussian_help) then
           in%inputPsiId=11
        else
           in%inputPsiId=0
        end if
     else if ((in%inputPsiId==1 .or. in%inputPsiId==0) .and. infocode==1) then
        !in%inputPsiId=0 !better to diagonalise than to restart an input guess
        in%inputPsiId=1
        if(iproc==0) then
           write(*,*)&
                &   ' WARNING: Self-consistent cycle did not meet convergence criteria'
        end if
        exit loop_cluster
     else if (in%inputPsiId == 0 .and. infocode==3) then
        if (iproc == 0) then
           write( *,'(1x,a)')'Convergence error, cannot proceed.'
           write( *,'(1x,a)')' writing positions in file posfail.xyz then exiting'
           write(comment,'(a)')'UNCONVERGED WF '
           !call wtxyz('posfail',energy,rxyz,atoms,trim(comment))

           call write_atomic_file("posfail",energy,rst%rxyz_new,atoms,trim(comment))

        end if

        i_all=-product(shape(rst%KSwfn%psi))*kind(rst%KSwfn%psi)
        deallocate(rst%KSwfn%psi,stat=i_stat)
        call memocc(i_stat,i_all,'psi',subname)
        i_all=-product(shape(rst%KSwfn%orbs%eval))*kind(rst%KSwfn%orbs%eval)
        deallocate(rst%KSwfn%orbs%eval,stat=i_stat)
        call memocc(i_stat,i_all,'eval',subname)

        call deallocate_wfd(rst%KSwfn%Lzd%Glr%wfd,subname)

        !finalize memory counting (there are still at least positions and the forces allocated)
        call memocc(0,0,'count','stop')

        if (nproc > 1) call MPI_FINALIZE(ierr)

        stop 'unnormal end'
     else
        exit loop_cluster
     end if

  end do loop_cluster

  !preserve the previous value
  in%inputPsiId=inputPsiId_orig

  !put a barrier for all the processes
  call MPI_BARRIER(MPI_COMM_WORLD,ierr)

END SUBROUTINE call_bigdft


!>  Main routine which does self-consistent loop.
!!  Does not parse input file and no geometry optimization.
!!  Does an electronic structure calculation. 
!!  Output is the total energy and the forces 
!!
!!   @param inputPsiId 
!!           - 0 : compute input guess for Psi by subspace diagonalization of atomic orbitals
!!           - 1 : read waves from argument psi, using n1, n2, n3, hgrid and rxyz_old
!!                 as definition of the previous system.
!!           - 2 : read waves from disk
!!   @param psi, keyg, keyv and eval should be freed after use outside of the routine.
!!   @param infocode -> encloses some information about the status of the run
!!           - 0 run succesfully succeded
!!           - 1 the run ended after the allowed number of minimization steps. gnrm_cv not reached
!!               forces may be meaningless   
!!           - 2 (present only for inputPsiId=1) gnrm of the first iteration > 1 AND growing in
!!               the second iteration OR grnm 1st >2.
!!               Input wavefunctions need to be recalculated. Routine exits.
!!           - 3 (present only for inputPsiId=0) gnrm > 4. SCF error. Routine exits.
subroutine cluster(nproc,iproc,atoms,rxyz,energy,fxyz,strten,fnoise,&
     KSwfn,&!psi,Lzd,gaucoeffs,gbd,orbs,
     rxyz_old,hx_old,hy_old,hz_old,in,GPU,infocode)
  use module_base
  use module_types
  use module_interfaces
!  use Poisson_Solver
  use module_xc
!  use vdwcorrection
  use m_ab6_mixing
  use yaml_output
  implicit none
  integer, intent(in) :: nproc,iproc
  real(gp), intent(inout) :: hx_old,hy_old,hz_old
  type(input_variables), intent(in) :: in
  type(atoms_data), intent(inout) :: atoms
  type(GPU_pointers), intent(inout) :: GPU
  type(DFT_wavefunction), intent(inout) :: KSwfn
  real(gp), dimension(3,atoms%nat), intent(inout) :: rxyz_old
  real(gp), dimension(3,atoms%nat), target, intent(inout) :: rxyz
  integer, intent(out) :: infocode
  real(gp), intent(out) :: energy,fnoise
  real(gp), dimension(6), intent(out) :: strten
  real(gp), dimension(3,atoms%nat), intent(out) :: fxyz
  !local variables
  character(len=*), parameter :: subname='cluster'
  character(len=5) :: gridformat, wfformat
  logical :: refill_proj !,potential_from_disk=.false.
  logical :: DoDavidson,DoLastRunThings=.false.,scpot
  integer :: nvirt,norbv
  integer :: i, input_wf_format
  integer :: n1,n2,n3
  integer :: ncount0,ncount1,ncount_rate,ncount_max,n1i,n2i,n3i
  integer :: iat,i_all,i_stat,ierr,jproc,inputpsi,igroup,ikpt,nproctiming
  real :: tcpu0,tcpu1
  real(kind=8) :: tel
  type(energy_terms), target :: energs ! Target attribute is mandatory for C wrappers
  real(gp) :: pressure
  type(grid_dimensions) :: d_old
  type(wavefunctions_descriptors) :: wfd_old
  type(nonlocal_psp_descriptors) :: nlpspd
  type(DFT_wavefunction) :: VTwfn !< Virtual wavefunction
  type(DFT_wavefunction) :: tmb
  type(DFT_wavefunction) :: tmbder
  real(gp), dimension(3) :: shift
  real(dp), dimension(6) :: ewaldstr,hstrten,xcstr
  real(gp), dimension(:,:), allocatable :: radii_cf,thetaphi,band_structure_eval
  real(gp), dimension(:,:), pointer :: fdisp,fion
  ! Charge density/potential,ionic potential, pkernel
  type(DFT_local_fields) :: denspot
  type(DFT_optimization_loop) :: optLoop
  !wavefunction gradients, hamiltonian on vavefunction
  !transposed  wavefunction
  ! Pointers and variables to store the last psi
  ! before reformatting if useFormattedInput is .true.
  real(wp), dimension(:), pointer :: psi_old
  ! PSP projectors 
  real(kind=8), dimension(:), pointer :: proj,gbd_occ!,rhocore
  ! Variables for the virtual orbitals and band diagram.
  integer :: nkptv, nvirtu, nvirtd
  real(gp), dimension(:), allocatable :: wkptv

  ! ----------------------------------

  !copying the input variables for readability
  !this section is of course not needed
  !note that this procedure is convenient ONLY in the case of scalar variables
  !an array would have been copied, thus occupying more memory space
  !Hence WARNING: these variables are copied, in case of an update the new value should be 
  !reassigned inside the structure

  write(gridformat, "(A)") ""
  select case (in%output_denspot_format)
  case (output_denspot_FORMAT_ETSF)
     write(gridformat, "(A)") ".etsf"
  case (output_denspot_FORMAT_CUBE)
     write(gridformat, "(A)") ".cube"
  end select
  write(wfformat, "(A)") ""
  select case (in%output_wf_format)
  case (WF_FORMAT_ETSF)
     write(wfformat, "(A)") ".etsf"
  case (WF_FORMAT_BINARY)
     write(wfformat, "(A)") ".bin"
  end select

  norbv=abs(in%norbv)
  nvirt=in%nvirt

  if (iproc == 0) then
     write( *,'(1x,a,1x,i0)') &
          &   '===================== BigDFT Wavefunction Optimization =============== inputPsiId=',&
          in%inputPsiId
     call print_dft_parameters(in,atoms)
  end if

  !Time initialization
  if (verbose > 2) then
     nproctiming=-nproc !timing in debug mode
  else
     nproctiming=nproc
  end if
  call timing(nproctiming,trim(in%dir_output)//'time.yaml','IN')
  call cpu_time(tcpu0)
  call system_clock(ncount0,ncount_rate,ncount_max)

  ! We save the variables that defined the previous psi if the restart is active
  if (in%inputPsiId == INPUT_PSI_MEMORY_WVL) then
     !regenerate grid spacings (this would not be needed if hgrids is in Lzd)
     if (atoms%geocode == 'P') then
        call correct_grid(atoms%alat1,hx_old,KSwfn%Lzd%Glr%d%n1)
        call correct_grid(atoms%alat2,hy_old,KSwfn%Lzd%Glr%d%n2)
        call correct_grid(atoms%alat3,hz_old,KSwfn%Lzd%Glr%d%n3)
     else if (atoms%geocode == 'S') then 
        call correct_grid(atoms%alat1,hx_old,KSwfn%Lzd%Glr%d%n1)
        call correct_grid(atoms%alat3,hz_old,KSwfn%Lzd%Glr%d%n3)
     end if
     call copy_old_wavefunctions(nproc,KSwfn%orbs,&
          KSwfn%Lzd%Glr%d%n1,KSwfn%Lzd%Glr%d%n2,KSwfn%Lzd%Glr%d%n3,&
          KSwfn%Lzd%Glr%wfd,KSwfn%psi,d_old%n1,d_old%n2,d_old%n3,wfd_old,psi_old)
 
  else if (in%inputPsiId == INPUT_PSI_MEMORY_GAUSS) then
     !deallocate wavefunction and descriptors for placing the gaussians

     call deallocate_wfd(KSwfn%Lzd%Glr%wfd,subname)

     i_all=-product(shape(KSwfn%psi))*kind(KSwfn%psi)
     deallocate(KSwfn%psi,stat=i_stat)
     call memocc(i_stat,i_all,'psi',subname)

  end if

  ! grid spacing (same in x,y and z direction)
 
  allocate(radii_cf(atoms%ntypes,3+ndebug),stat=i_stat)
  call memocc(i_stat,radii_cf,'radii_cf',subname)

  !here we can put KSwfn
  call system_initialization(iproc,nproc,inputpsi,input_wf_format,in,atoms,rxyz,&
       KSwfn%orbs,tmb%orbs,tmbder%orbs,KSwfn%Lzd,denspot,nlpspd,&
       KSwfn%comms,tmb%comms,tmbder%comms,shift,proj,radii_cf)

  optLoop%iscf = in%iscf
  optLoop%itrpmax = in%itrpmax
  optLoop%nrepmax = in%nrepmax
  optLoop%itermax = in%itermax
  optLoop%gnrm_cv = in%gnrm_cv
  optLoop%rpnrm_cv = in%rpnrm_cv
  optLoop%gnrm_startmix = in%gnrm_startmix
  optLoop%itrp = 0
  optLoop%itrep = 0
  optLoop%iter = 0
  optLoop%infocode = 0

  if (in%signaling) then
     ! Only iproc 0 has the C wrappers.
     if (iproc == 0) then
        call wf_new_wrapper(KSwfn%c_obj, KSwfn)
        call wf_copy_from_fortran(KSwfn%c_obj, radii_cf, in%crmult, in%frmult)
        call bigdft_signals_add_wf(in%gmainloop, KSwfn%c_obj)
        call energs_new_wrapper(energs%c_obj, energs)
        call bigdft_signals_add_energs(in%gmainloop, energs%c_obj)
        call localfields_new_wrapper(denspot%c_obj, denspot)
        call bigdft_signals_add_denspot(in%gmainloop, denspot%c_obj)
        call optloop_new_wrapper(optLoop%c_obj, optLoop)
        call bigdft_signals_add_optloop(in%gmainloop, optLoop%c_obj)
     else
        KSwfn%c_obj = UNINITIALIZED(KSwfn%c_obj)
        denspot%c_obj = UNINITIALIZED(denspot%c_obj)
        optloop%c_obj = UNINITIALIZED(optloop%c_obj)
     end if
  else
     KSwfn%c_obj  = 0.d0
     tmb%c_obj    = 0.d0
     tmbder%c_obj = 0.d0
  end if

  !variables substitution for the PSolver part

  n1i=KSwfn%Lzd%Glr%d%n1i
  n2i=KSwfn%Lzd%Glr%d%n2i
  n3i=KSwfn%Lzd%Glr%d%n3i

  n1=KSwfn%Lzd%Glr%d%n1
  n2=KSwfn%Lzd%Glr%d%n2
  n3=KSwfn%Lzd%Glr%d%n3

  !calculate the rhocore contribution to the energy value
  if (associated(denspot%rho_C)) then
     !calculate the XC energy of rhocore, use the rhov array as a temporary variable
     !use Vxc and other quantities as local variables
     call xc_init_rho(denspot%dpbox%nrhodim,denspot%rhov,1)
     denspot%rhov=1.d-16
     call XC_potential(atoms%geocode,'D',iproc,nproc,&
          denspot%dpbox%ndims(1),denspot%dpbox%ndims(2),denspot%dpbox%ndims(3),in%ixc,&
          denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
          denspot%rhov,energs%excrhoc,tel,KSwfn%orbs%nspin,denspot%rho_C,denspot%V_XC,xcstr)
     if (iproc==0) write(*,*)'value for Exc[rhoc]',energs%excrhoc
  end if



  !here calculate the ionic energy and forces accordingly
  call IonicEnergyandForces(iproc,nproc,atoms,&
       denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),in%elecfield,rxyz,&
       energs%eion,fion,in%dispersion,energs%edisp,fdisp,ewaldstr,denspot%psoffset,&
       n1,n2,n3,n1i,n2i,n3i,&
       denspot%dpbox%i3s+denspot%dpbox%i3xcsh,denspot%dpbox%n3pi,&
       denspot%V_ext,denspot%pkernel)
  !calculate effective ionic potential, including counter ions if any.
  call createEffectiveIonicPotential(iproc,nproc,(iproc == 0),in,atoms,rxyz,shift,KSwfn%Lzd%Glr,&
       denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
       denspot%dpbox,denspot%pkernel,denspot%V_ext,in%elecfield,denspot%psoffset)
  if (denspot%c_obj /= 0) then
     call denspot_emit_v_ext(denspot, iproc, nproc)
  end if

  !obtain initial wavefunctions.
  call input_wf(iproc,nproc,in,GPU,atoms,rxyz,&
       denspot,nlpspd,proj,KSwfn,tmb,tmbder,energs,inputpsi,input_wf_format,norbv,&
       wfd_old,psi_old,d_old,hx_old,hy_old,hz_old,rxyz_old)

  if (inputpsi == INPUT_PSI_LINEAR .or. inputpsi == INPUT_PSI_MEMORY_LINEAR) then
     !call check_linear_and_create_Lzd(iproc,nproc,in,Lzd,atoms,orbs,rxyz)
     !this does not work with ndebug activated

     !!if(.not.lin%transformToGlobal) then
     !!    ! psi and psit will not be calculated, so only allocate them with size 1
     !!    orbs%npsidim=1
     !!end if
     !!allocate(psi(orbs%npsidim), stat=i_stat)
     !!call memocc(i_stat, psi, 'psi', subname)
     !!allocate(psit(orbs%npsidim), stat=i_stat)
     !!call memocc(i_stat, psit, 'psit', subname)
     scpot=.true.
     energs%eexctX=0.0_gp   !Exact exchange is not calculated right now 
     ! This is the main routine that does everything related to the linear scaling version.

     KSwfn%orbs%eval=-.5d0

     call linearScaling(iproc,nproc,KSwfn%Lzd%Glr,&
          KSwfn%orbs,KSwfn%comms,tmb,tmbder,&
          atoms,in,inputpsi,input_wf_format,KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
          rxyz,fion,fdisp,denspot,&
          nlpspd,proj,GPU,energs%eion,energs%edisp,energs%eexctX,scpot,KSwfn%psi,KSwfn%psit,&
          energy)

     call destroy_DFT_wavefunction(tmb)
     call destroy_DFT_wavefunction(tmbder)

     ! debug

     !!! debug: write psi to file
     !!call writemywaves(iproc,trim(in%dir_output) // "wavefunction", in%output_wf_format, &
     !!        orbs,n1,n2,n3,hx,hy,hz,atoms,rxyz,Lzd%Glr%wfd,psi)
     !!return

     !temporary allocation of the density
     allocate(denspot%rho_work(max(KSwfn%Lzd%Glr%d%n1i*KSwfn%Lzd%Glr%d%n2i*&
          denspot%dpbox%n3p*KSwfn%orbs%nspin+ndebug,1)),stat=i_stat)
     call memocc(i_stat,denspot%rho_work,'rho',subname)
     call vcopy(KSwfn%Lzd%Glr%d%n1i*KSwfn%Lzd%Glr%d%n2i*denspot%dpbox%n3p*KSwfn%orbs%nspin,&
          denspot%rhov(1),1,denspot%rho_work(1),1)

     if (nproc > 1) then
        i_all=-product(shape(KSwfn%psit))*kind(KSwfn%psit)
        deallocate(KSwfn%psit,stat=i_stat)
        call memocc(i_stat,i_all,'KSwfn%psit',subname)
     else
        nullify(KSwfn%psit)
     end if
     ! denspot%rho_full => denspot%rhov

  end if

  if (in%nvirt > norbv) then
     nvirt = norbv
  end if

  !save the new atomic positions in the rxyz_old array
  do iat=1,atoms%nat
     rxyz_old(1,iat)=rxyz(1,iat)
     rxyz_old(2,iat)=rxyz(2,iat)
     rxyz_old(3,iat)=rxyz(3,iat)
  enddo
  !save the new grid spacing into the hgrid_old value
  hx_old=KSwfn%Lzd%hgrids(1)
  hy_old=KSwfn%Lzd%hgrids(2)
  hz_old=KSwfn%Lzd%hgrids(3)

  !start the optimization
  ! Skip the following part in the linear scaling case.
  skip_if_linear: if(inputpsi /= INPUT_PSI_LINEAR .and. inputpsi /= INPUT_PSI_MEMORY_LINEAR) then

     !end of the initialization part
     call timing(iproc,'INIT','PR')

     energs%eexctX=0.0_gp
     call kswfn_optimization_loop(iproc, nproc, optLoop, &
     & in%alphamix, in%idsx, inputpsi, KSwfn, denspot, nlpspd, proj, energs, atoms, rxyz, GPU, xcstr, &
     & in)
     infocode = optLoop%infocode

     !if we are in the last_run case, validate the last_run only for the last cycle
     !do the last_run things regardless of infocode
     !nrepmax=0 is needed for the Band Structure calculations
     DoLastRunThings=(in%last_run == 1 .and. optLoop%nrepmax == 0) .or. &
          & (in%last_run == 1 .and. optLoop%itrep >= optLoop%nrepmax)
              !print the energies only if they are meaningful
     energy = energs%eKS
     !Davidson is set to false first because used in deallocate_before_exiting
     DoDavidson= .false.

     ! Treat the info code from the optimization routine.
     if (infocode == 2 .or. infocode == 3) then
        call deallocate_before_exiting
        return
     end if
  else
     infocode = 0
  end if skip_if_linear

  !last run things has to be done:
  !if it is the last run and the infocode is zero
  !if infocode is not zero but the last run has been done for nrepmax times

  DoLastRunThings= (in%last_run == 1 .and. infocode == 0) .or. DoLastRunThings

  !analyse the possibility to calculate Davidson treatment
  !(nvirt > 0 .and. in%inputPsiId == 0)
  DoDavidson= abs(in%norbv) > 0 .and. DoLastRunThings

  !project the wavefunctions on a gaussian basis and keep in memory
  if (in%gaussian_help) then
     if (iproc == 0) then
        write( *,'(1x,a)')&
             &   '---------------------------------------------------------- Gaussian Basis Projection'
     end if

     !extract the gaussian basis from the pseudowavefunctions
!!!     if (in%inputPsiId == 11) then
!!!        !extract the gaussian basis from the pseudowavefunctions
!!!        call gaussian_pswf_basis(21,.false.,iproc,atoms,rxyz,gbd)
!!!     else if (in%inputPsiId == 12) then
!!!        !extract the gaussian basis from the pseudopotential
!!!        call gaussian_psp_basis(atoms,rxyz,gbd)
!!!     end if

     !extract the gaussian basis from the pseudowavefunctions
     call gaussian_pswf_basis(21,.false.,iproc,in%nspin,atoms,rxyz,KSwfn%gbd,gbd_occ)

     if (associated(gbd_occ)) then
        i_all=-product(shape(gbd_occ))*kind(gbd_occ)
        deallocate(gbd_occ,stat=i_stat)
        call memocc(i_stat,i_all,'gbd_occ',subname)
        nullify(gbd_occ)
     end if


     if (.not. associated(KSwfn%gaucoeffs)) then
        allocate(KSwfn%gaucoeffs(KSwfn%gbd%ncoeff,KSwfn%orbs%norbp+ndebug),stat=i_stat)
        call memocc(i_stat,KSwfn%gaucoeffs,'gaucoeffs',subname)
     end if

     allocate(thetaphi(2,KSwfn%gbd%nat+ndebug),stat=i_stat)
     call memocc(i_stat,thetaphi,'thetaphi',subname)
     thetaphi=0.0_gp

     call wavelets_to_gaussians(atoms%geocode,KSwfn%orbs%norbp,KSwfn%orbs%nspinor,&
          n1,n2,n3,KSwfn%gbd,thetaphi,&
          KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
          KSwfn%Lzd%Glr%wfd,KSwfn%psi,KSwfn%gaucoeffs)

     i_all=-product(shape(thetaphi))*kind(thetaphi)
     deallocate(thetaphi,stat=i_stat)
     call memocc(i_stat,i_all,'thetaphi',subname)

  end if

  !  write all the wavefunctions into files
  if (in%output_wf_format /= WF_FORMAT_NONE .and. DoLastRunThings) then
     !add flag for writing waves in the gaussian basis form
     !if (in%gaussian_help) then
     if (in%gaussian_help .and. .not.in%inputPsiId==100 .and. .not.in%inputPsiId==101 ) then

!!!        call gaussian_orthogonality(iproc,nproc,norb,norbp,gbd,gaucoeffs)
!!!
!!!        call gaussian_orthogonality(iproc,nproc,norb,norbp,gbd,gaucoeffs)
        !write the coefficients and the basis on a file
        if (iproc ==0) write(*,*)'Writing wavefunctions in wavefunction.gau file'
        call write_gaussian_information(iproc,nproc,KSwfn%orbs,KSwfn%gbd,KSwfn%gaucoeffs,trim(in%dir_output) // 'wavefunctions.gau')

        !build dual coefficients
        call dual_gaussian_coefficients(KSwfn%orbs%norbp,KSwfn%gbd,KSwfn%gaucoeffs)

        !control the accuracy of the expansion
        call check_gaussian_expansion(iproc,nproc,KSwfn%orbs,KSwfn%Lzd,KSwfn%psi,KSwfn%gbd,KSwfn%gaucoeffs)

        call deallocate_gwf(KSwfn%gbd,subname)
        i_all=-product(shape(KSwfn%gaucoeffs))*kind(KSwfn%gaucoeffs)
        deallocate(KSwfn%gaucoeffs,stat=i_stat)
        call memocc(i_stat,i_all,'gaucoeffs',subname)
        nullify(KSwfn%gbd%rxyz)

     else
        call writemywaves(iproc,trim(in%dir_output) // "wavefunction", in%output_wf_format, &
             KSwfn%orbs,n1,n2,n3,KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
             atoms,rxyz,KSwfn%Lzd%Glr%wfd,KSwfn%psi)
     end if
  end if

  !plot the ionic potential, if required by output_denspot
  if (in%output_denspot == output_denspot_DENSPOT .and. DoLastRunThings) then
     if (iproc == 0) write(*,*) 'writing external_potential' // gridformat
     call plot_density(iproc,nproc,trim(in%dir_output)//'external_potential' // gridformat,&
          atoms,rxyz,denspot%dpbox,1,denspot%V_ext)
  end if
  if (in%output_denspot == output_denspot_DENSPOT .and. DoLastRunThings) then
     if (iproc == 0) write(*,*) 'writing local_potential' // gridformat
     call plot_density(iproc,nproc,trim(in%dir_output)//'local_potential' // gridformat,&
          atoms,rxyz,denspot%dpbox,in%nspin,denspot%rhov)
  end if

  i_all=-product(shape(denspot%V_ext))*kind(denspot%V_ext)
  deallocate(denspot%V_ext,stat=i_stat)
  call memocc(i_stat,i_all,'denspot%V_ext',subname)
  nullify(denspot%V_ext)

  if (inputpsi /= INPUT_PSI_EMPTY) then
     !------------------------------------------------------------------------
     ! here we start the calculation of the forces
     if (iproc == 0) then
        write( *,'(1x,a)')&
             &   '----------------------------------------------------------------- Forces Calculation'
     end if

     !manipulate scatter array for avoiding the GGA shift
     do jproc=0,nproc-1
        !n3d=n3p
        denspot%dpbox%nscatterarr(jproc,1)=denspot%dpbox%nscatterarr(jproc,2)
        !i3xcsh=0
        denspot%dpbox%nscatterarr(jproc,4)=0
     end do
     !change communication scheme to LDA case
     denspot%rhod%icomm=1

     call density_and_hpot(iproc,nproc,atoms%geocode,atoms%sym,KSwfn%orbs,KSwfn%Lzd,&
          denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
          denspot%dpbox%nscatterarr,&
          denspot%pkernel,denspot%rhod,GPU,KSwfn%psi,denspot%rho_work,denspot%pot_work,hstrten)

     !xc stress, diagonal for the moment
     if (atoms%geocode=='P') then
        if (atoms%sym%symObj >= 0) call symm_stress((iproc==0),xcstr,atoms%sym%symObj)
     end if

     ! calculate dipole moment associated to the charge density
     if (DoLastRunThings) then 
        call calc_dipole(iproc,nproc,KSwfn%Lzd%Glr%d%n1,KSwfn%Lzd%Glr%d%n2,KSwfn%Lzd%Glr%d%n3,&
             KSwfn%Lzd%Glr%d%n1i,KSwfn%Lzd%Glr%d%n2i,KSwfn%Lzd%Glr%d%n3i,denspot%dpbox%n3p,in%nspin,&
             denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
             atoms,rxyz,denspot%dpbox%ngatherarr,denspot%rho_work)
        !plot the density on the cube file
        !to be done either for post-processing or if a restart is to be done with mixing enabled
        if (((in%output_denspot >= output_denspot_DENSITY))) then
           if (iproc == 0) write(*,*) 'writing electronic_density' // gridformat
           
           call plot_density(iproc,nproc,trim(in%dir_output)//'electronic_density' // gridformat,&
                atoms,rxyz,denspot%dpbox,in%nspin,denspot%rho_work)
           
           if (associated(denspot%rho_C)) then
              if (iproc == 0) write(*,*) 'writing grid core_density' // gridformat
              call plot_density(iproc,nproc,trim(in%dir_output)//'core_density' // gridformat,&
                   atoms,rxyz,denspot%dpbox,1,denspot%rho_C(1,1,denspot%dpbox%i3xcsh:,1))
           end if
        end if
        !plot also the electrostatic potential
        if (in%output_denspot == output_denspot_DENSPOT) then
           if (iproc == 0) write(*,*) 'writing hartree_potential' // gridformat
           call plot_density(iproc,nproc,trim(in%dir_output)//'hartree_potential' // gridformat, &
                atoms,rxyz,denspot%dpbox,in%nspin,denspot%pot_work)
        end if
     end if

     !     !plot also the electrostatic potential
     !     if (in%output_denspot == output_denspot_DENSPOT .and. DoLastRunThings) then
     !        if (iproc == 0) write(*,*) 'writing hartree_potential' // gridformat
     !        call plot_density(iproc,nproc,trim(in%dir_output)//'hartree_potential' // gridformat, &
     !             atoms,rxyz,denspot%dpbox,1,pot)
     !     end if
     !
     call timing(iproc,'Forces        ','ON')
     !refill projectors for tails, davidson
     refill_proj=((in%rbuf > 0.0_gp) .or. DoDavidson) .and. DoLastRunThings


     call calculate_forces(iproc,nproc,KSwfn%Lzd%Glr,atoms,KSwfn%orbs,nlpspd,rxyz,&
          KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
          proj,denspot%dpbox%i3s+denspot%dpbox%i3xcsh,denspot%dpbox%n3p,&
          in%nspin,refill_proj,denspot%dpbox%ngatherarr,denspot%rho_work,&
          denspot%pot_work,denspot%V_XC,KSwfn%psi,fion,fdisp,fxyz,&
          ewaldstr,hstrten,xcstr,strten,fnoise,pressure,denspot%psoffset)

     i_all=-product(shape(denspot%rho_work))*kind(denspot%rho_work)
     deallocate(denspot%rho_work,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%rho_work',subname)
     i_all=-product(shape(denspot%pot_work))*kind(denspot%pot_work)
     deallocate(denspot%pot_work,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%pot_work',subname)
     nullify(denspot%rho_work,denspot%pot_work)
     call timing(iproc,'Forces        ','OF')
     !!stop
  end if

  i_all=-product(shape(fion))*kind(fion)
  deallocate(fion,stat=i_stat)
  call memocc(i_stat,i_all,'fion',subname)
  i_all=-product(shape(fdisp))*kind(fdisp)
  deallocate(fdisp,stat=i_stat)
  call memocc(i_stat,i_all,'fdisp',subname)

  !if (nvirt > 0 .and. in%inputPsiId == 0) then
  if (DoDavidson) then

     !for a band structure calculation allocate the array in which to put the eigenvalues
     if (associated(in%kptv)) then
        allocate(band_structure_eval(KSwfn%orbs%norbu+KSwfn%orbs%norbd+in%nspin*norbv,in%nkptv+ndebug),stat=i_stat)
        call memocc(i_stat,band_structure_eval,'band_structure_eval',subname)
     end if

     !calculate Davidson procedure for all the groups of k-points which are chosen
     ikpt=1
     do igroup=1,in%ngroups_kptv

        ! Set-up number of states and shifting values.
        nvirtu = norbv
        nvirtd = 0
        if (in%nspin==2) nvirtd=nvirtu
        ! Create the orbitals.
        if (associated(in%kptv)) then
           nvirtu = nvirtu + KSwfn%orbs%norbu
           nvirtd = nvirtd + KSwfn%orbs%norbd
           nvirt  = nvirtu+nvirtd

           !number of k-points for this group
           nkptv = in%nkptsv_group(igroup) !size(in%kptv, 2)

           allocate(wkptv(nkptv+ndebug),stat=i_stat)
           call memocc(i_stat,wkptv,'wkptv',subname)
           wkptv(:) = real(1.0, gp) / real(nkptv, gp)
           call orbitals_descriptors(iproc,nproc,nvirtu+nvirtd,nvirtu,nvirtd, &
                KSwfn%orbs%nspin,KSwfn%orbs%nspinor,nkptv, &
                in%kptv(:,sum(in%nkptsv_group(1:igroup - 1)) + 1:sum(in%nkptsv_group(1:igroup))), &
                wkptv,VTwfn%orbs,.false.)
           !allocate communications arrays for virtual orbitals
           call orbitals_communicators(iproc,nproc,KSwfn%Lzd%Glr,VTwfn%orbs,VTwfn%comms)  

           i_all=-product(shape(wkptv))*kind(wkptv)
           deallocate(wkptv,stat=i_stat)
           call memocc(i_stat,i_all,'wkptv',subname)

           !recreate the memory space for the projectors 
           call deallocate_proj_descr(nlpspd,subname)  
           i_all=-product(shape(proj))*kind(proj)
           deallocate(proj,stat=i_stat)
           call memocc(i_stat,i_all,'proj',subname)

           ! Calculate all projectors, or allocate array for on-the-fly calculation
           call timing(iproc,'CrtProjectors ','ON')
           call createProjectorsArrays(iproc,KSwfn%Lzd%Glr,rxyz,atoms,VTwfn%orbs,&
                radii_cf,in%frmult,in%frmult,KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),nlpspd,proj) 
           call timing(iproc,'CrtProjectors ','OF') 

        else
           !the virtual orbitals should be in agreement with the traditional k-points
           call orbitals_descriptors(iproc,nproc,nvirtu+nvirtd,nvirtu,nvirtd, &
                KSwfn%orbs%nspin,KSwfn%orbs%nspinor,KSwfn%orbs%nkpts,&
                KSwfn%orbs%kpts,KSwfn%orbs%kwgts,VTwfn%orbs,.false.,basedist=KSwfn%orbs%norb_par(0:,1:))
           !allocate communications arrays for virtual orbitals
           call orbitals_communicators(iproc,nproc,KSwfn%Lzd%Glr,VTwfn%orbs,VTwfn%comms,&
                basedist=KSwfn%comms%nvctr_par(0:,1:))  

        end if

        !allocate psivirt pointer (note the orbs dimension)
        allocate(VTwfn%psi(max(VTwfn%orbs%npsidim_comp,VTwfn%orbs%npsidim_orbs)+ndebug),stat=i_stat)
        call memocc(i_stat,VTwfn%psi,'psivirt',subname)
        !to avoid problems with the bindings
        VTwfn%c_obj=0.d0

        !define Local zone descriptors
        VTwfn%Lzd = KSwfn%Lzd
        VTwfn%orthpar=KSwfn%orthpar
        allocate(VTwfn%confdatarr(VTwfn%orbs%norbp))
        call default_confinement_data(VTwfn%confdatarr,VTwfn%orbs%norbp)


        if (in%norbv < 0) then
           call direct_minimization(iproc,nproc,in,atoms,& 
                nvirt,rxyz,denspot%rhov,nlpspd,proj, &
                denspot%pkernelseq,denspot%dpbox,GPU,KSwfn,VTwfn)
        else if (in%norbv > 0) then
           call davidson(iproc,nproc,in,atoms,& 
                KSwfn%orbs,VTwfn%orbs,in%nvirt,VTwfn%Lzd,&
                KSwfn%comms,VTwfn%comms,&
                rxyz,denspot%rhov,nlpspd,proj, &
                denspot%pkernelseq,KSwfn%psi,VTwfn%psi,denspot%dpbox,GPU)
!!$           call constrained_davidson(iproc,nproc,in,atoms,&
!!$                orbs,orbsv,in%nvirt,Lzd%Glr,comms,VTwfn%comms,&
!!$                hx,hy,hz,rxyz,denspot%rhov,nlpspd,proj, &
!!$                psi,VTwfn%psi,nscatterarr,ngatherarr,GPU)

        end if

        deallocate(VTwfn%confdatarr)

        ! Write virtual wavefunctions in ETSF format: WORKS ONLY FOR ONE KPOINT 
        if(in%output_wf_format == 3 .and. abs(in%norbv) > 0) then
           call  writemywaves(iproc,trim(in%dir_output) // "virtuals" // trim(wfformat),&
                in%output_wf_format, &
                VTwfn%orbs,n1,n2,n3,&
                KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
                atoms,rxyz,KSwfn%Lzd%Glr%wfd,VTwfn%psi)
        end if

        ! Write virtual wavefunctions in ETSF format
        if (in%output_wf_format /= WF_FORMAT_NONE  .and. abs(in%norbv) > 0) then
           call  writemywaves(iproc,trim(in%dir_output) // "virtuals", in%output_wf_format, &
                VTwfn%orbs,n1,n2,n3,KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
                atoms,rxyz,KSwfn%Lzd%Glr%wfd,VTwfn%psi)
        end if

        !start the Casida's treatment 
        if (in%tddft_approach=='TDA') then

           !does it makes sense to use GPU only for a one-shot sumrho?
           if (OCLconv) then
              call allocate_data_OCL(KSwfn%Lzd%Glr%d%n1,KSwfn%Lzd%Glr%d%n2,KSwfn%Lzd%Glr%d%n3,&
                   atoms%geocode,&
                   in%nspin,KSwfn%Lzd%Glr%wfd,KSwfn%orbs,GPU)
           end if

           !this could have been calculated before
           ! Potential from electronic charge density
           !WARNING: this is good just because the TDDFT is done with LDA
           call sumrho(iproc,nproc,KSwfn%orbs,KSwfn%Lzd,&
                denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
                denspot%dpbox%nscatterarr,&
                GPU,atoms%sym,denspot%rhod,KSwfn%psi,denspot%rho_psi)
           call communicate_density(iproc,nproc,KSwfn%orbs%nspin,&
                denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),KSwfn%Lzd,&
                denspot%rhod,denspot%dpbox%nscatterarr,denspot%rho_psi,denspot%rhov,.false.)
           call denspot_set_rhov_status(denspot, ELECTRONIC_DENSITY, -1)

           if (OCLconv) then
              call free_gpu_OCL(GPU,KSwfn%orbs,in%nspin)
           end if

           !Allocate second Exc derivative
           if (denspot%dpbox%n3p >0) then
              allocate(denspot%f_XC(n1i,n2i,denspot%dpbox%n3p,in%nspin+1+ndebug),stat=i_stat)
              call memocc(i_stat,denspot%f_XC,'f_XC',subname)
           else
              allocate(denspot%f_XC(1,1,1,in%nspin+1+ndebug),stat=i_stat)
              call memocc(i_stat,denspot%f_XC,'denspot%f_XC',subname)
           end if

           call XC_potential(atoms%geocode,'D',iproc,nproc,&
                KSwfn%Lzd%Glr%d%n1i,KSwfn%Lzd%Glr%d%n2i,KSwfn%Lzd%Glr%d%n3i,in%ixc,&
                denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
                denspot%rhov,energs%exc,energs%evxc,in%nspin,denspot%rho_C,denspot%V_XC,xcstr,denspot%f_XC)
           call denspot_set_rhov_status(denspot, CHARGE_DENSITY, -1)

           !select the active space if needed

           call tddft_casida(iproc,nproc,atoms,rxyz,&
                denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
                denspot%dpbox%n3p,denspot%dpbox%ngatherarr(0,1),&
                KSwfn%Lzd%Glr,KSwfn%orbs,VTwfn%orbs,denspot%dpbox%i3s+denspot%dpbox%i3xcsh,&
                denspot%f_XC,denspot%pkernelseq,KSwfn%psi,VTwfn%psi)

           i_all=-product(shape(denspot%f_XC))*kind(denspot%f_XC)
           deallocate(denspot%f_XC,stat=i_stat)
           call memocc(i_stat,i_all,'denspot%f_XC',subname)

        end if

        call deallocate_comms(VTwfn%comms,subname)
        call deallocate_orbs(VTwfn%orbs,subname)

        !in the case of band structure calculation, copy the values of the eigenvectors
        !into a new array to write them afterwards
        if (associated(in%kptv)) then
           call dcopy(VTwfn%orbs%norb*nkptv,VTwfn%orbs%eval(1),1,band_structure_eval(1,ikpt),1)
           !increment the value of ikpt
           ikpt=ikpt+in%nkptsv_group(igroup)
        end if

        i_all=-product(shape(VTwfn%orbs%eval))*kind(VTwfn%orbs%eval)
        deallocate(VTwfn%orbs%eval,stat=i_stat)
        call memocc(i_stat,i_all,'eval',subname)

        !if the local analysis has to be performed the deallocation should not be done
        i_all=-product(shape(VTwfn%psi))*kind(VTwfn%psi)
        deallocate(VTwfn%psi,stat=i_stat)
        call memocc(i_stat,i_all,'VTwfn%psi',subname)

     end do

     if (associated(in%kptv)) then
        !dump the band structure eigenvalue on a file and deallocate it
        if (iproc == 0) then
           open(unit=11,file='band_structure.dat',status='unknown')
           do ikpt=1,in%nkptv
              write(11,'(i5,3(f12.6),10000(1pe12.4))')ikpt,&
                   (in%kptv(i,ikpt),i=1,3),(band_structure_eval(i,ikpt),i=1,VTwfn%orbs%norb)
           end do
           !tentative gnuplot string for the band structure file
           write(11,'(a,9999(a,i6,a))')&
                "#plot 'band_structure.dat' u 1:5 w l t ''",&
                (",'' u 1:",5+i-1," w l t ''" ,i=2,VTwfn%orbs%norb)
           close(unit=11)
        end if
        i_all=-product(shape(band_structure_eval))*kind(band_structure_eval)
        deallocate(band_structure_eval,stat=i_stat)
        call memocc(i_stat,i_all,'band_structure_eval',subname)
     end if

  end if


  !perform here the mulliken charge and density of states
  !localise them on the basis of gatom of a number of atoms
  !if (in%gaussian_help .and. DoLastRunThings) then
  if (in%gaussian_help .and. DoLastRunThings .and.&
&    (.not.inputpsi==INPUT_PSI_LINEAR .and. .not.inputpsi==INPUT_PSI_MEMORY_LINEAR)) then
     !here one must check if psivirt should have been kept allocated
     if (.not. DoDavidson) then
        VTwfn%orbs%norb=0
        VTwfn%orbs%norbp=0
     end if
     call local_analysis(iproc,nproc,KSwfn%Lzd%hgrids(1),KSwfn%Lzd%hgrids(2),KSwfn%Lzd%hgrids(3),&
          atoms,rxyz,KSwfn%Lzd%Glr,KSwfn%orbs,VTwfn%orbs,KSwfn%psi,VTwfn%psi)
  else if (DoLastRunThings .and. optLoop%itrpmax /= 1 .and. verbose >= 2) then
     ! Do a full DOS calculation.
     if (iproc == 0) call global_analysis(KSwfn%orbs, in%Tel,in%occopt)
  end if

  i_all=-product(shape(denspot%pkernel))*kind(denspot%pkernel)
  deallocate(denspot%pkernel,stat=i_stat)
  call memocc(i_stat,i_all,'kernel',subname)

  if (((in%exctxpar == 'OP2P' .and. xc_exctXfac() /= 0.0_gp) &
       .or. in%SIC%alpha /= 0.0_gp) .and. nproc >1) then
     i_all=-product(shape(denspot%pkernelseq))*kind(denspot%pkernelseq)
     deallocate(denspot%pkernelseq,stat=i_stat)
     call memocc(i_stat,i_all,'kernelseq',subname)
  else if (nproc == 1 .and. (in%exctxpar == 'OP2P' .or. in%SIC%alpha /= 0.0_gp)) then
     nullify(denspot%pkernelseq)
  end if



  !------------------------------------------------------------------------
  if ((in%rbuf > 0.0_gp) .and. atoms%geocode == 'F' .and. DoLastRunThings ) then
     if (in%SIC%alpha /= 0.0_gp) then
        if (iproc==0)write(*,*)&
             &   'ERROR: Tail correction not admitted with SIC corrections for the moment'
        stop
     end if
     call timing(iproc,'Tail          ','ON')
     !    Calculate energy correction due to finite size effects
     !    ---reformat potential
     allocate(denspot%pot_work(n1i*n2i*n3i*in%nspin+ndebug),stat=i_stat)
     call memocc(i_stat,denspot%pot_work,'denspot%pot_work',subname)

     if (nproc > 1) then
        call MPI_ALLGATHERV(denspot%rhov,n1i*n2i*denspot%dpbox%n3p,&
             &   mpidtypd,denspot%pot_work(1),denspot%dpbox%ngatherarr(0,1),denspot%dpbox%ngatherarr(0,2), & 
             mpidtypd,MPI_COMM_WORLD,ierr)
        !print '(a,2f12.6)','RHOup',sum(abs(rhopot(:,:,:,1))),sum(abs(pot(:,:,:,1)))
        if(in%nspin==2) then
           !print '(a,2f12.6)','RHOdw',sum(abs(rhopot(:,:,:,2))),sum(abs(pot(:,:,:,2)))
           call MPI_ALLGATHERV(denspot%rhov(1+n1i*n2i*denspot%dpbox%n3p),n1i*n2i*denspot%dpbox%n3p,&
                mpidtypd,denspot%pot_work(1+n1i*n2i*n3i),&
                denspot%dpbox%ngatherarr(0,1),denspot%dpbox%ngatherarr(0,2), & 
                mpidtypd,MPI_COMM_WORLD,ierr)
        end if
     else
        call dcopy(n1i*n2i*n3i*in%nspin,denspot%rhov,1,denspot%pot_work,1)
     end if

     call deallocate_denspot_distribution(denspot%dpbox, subname)

     i_all=-product(shape(denspot%rhov))*kind(denspot%rhov)
     deallocate(denspot%rhov,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%rhov',subname)

     i_all=-product(shape(denspot%V_XC))*kind(denspot%V_XC)
     deallocate(denspot%V_XC,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%V_XC',subname)

     !pass hx instead of hgrid since we are only in free BC
     call CalculateTailCorrection(iproc,nproc,atoms,in%rbuf,KSwfn%orbs,&
          KSwfn%Lzd%Glr,nlpspd,in%ncongt,denspot%pot_work,KSwfn%Lzd%hgrids(1),&
          rxyz,radii_cf,in%crmult,in%frmult,in%nspin,&
          proj,KSwfn%psi,(in%output_denspot /= 0),energs%ekin,energs%epot,energs%eproj)

     i_all=-product(shape(denspot%pot_work))*kind(denspot%pot_work)
     deallocate(denspot%pot_work,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%pot_work',subname)

     energs%ebs=energs%ekin+energs%epot+energs%eproj
     energy=energs%ebs-energs%eh+energs%exc-energs%evxc-energs%evsic+energs%eion+energs%edisp

     if (iproc == 0) then
        write( *,'(1x,a,3(1x,1pe18.11))')&
             &   '  Corrected ekin,epot,eproj',energs%ekin,energs%epot,energs%eproj
        write( *,'(1x,a,1x,1pe24.17)')&
             &   'Total energy with tail correction',energy
     endif

     call timing(iproc,'Tail          ','OF')
  else
     !    No tail calculation
     if (nproc > 1) call MPI_BARRIER(MPI_COMM_WORLD,ierr)
     i_all=-product(shape(denspot%rhov))*kind(denspot%rhov)
     deallocate(denspot%rhov,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%rhov',subname)
     i_all=-product(shape(denspot%V_XC))*kind(denspot%V_XC)
     deallocate(denspot%V_XC,stat=i_stat)
     call memocc(i_stat,i_all,'denspot%V_XC',subname)
     call deallocate_denspot_distribution(denspot%dpbox, subname)
  endif
  ! --- End if of tail calculation

  !?!   !Finally, we add the entropic contribution to the energy from non-integer occnums
  !?!   if(orbs%eTS>0_gp) then 
  !?!      energy=energy - orbs%eTS 
  !?! 
  !?!      if (iproc == 0) then
  !?!         write( *,'(1x,a,1(1x,1pe18.11))')&
  !?!              '  Entropic correction due to electronic tempertature',orbs%eTS
  !?!         write( *,'(1x,a,1x,1pe24.17)')&
  !?!              'Free energy (= total energy - T*S)  ',energy
  !?!      endif
  !?!    endif

  call deallocate_before_exiting

contains

  !> Routine which deallocate the pointers and the arrays before exiting 
  subroutine deallocate_before_exiting

    !when this condition is verified we are in the middle of the SCF cycle
    if (infocode /=0 .and. infocode /=1 .and. inputpsi /= INPUT_PSI_EMPTY) then
       i_all=-product(shape(denspot%V_ext))*kind(denspot%V_ext)
       deallocate(denspot%V_ext,stat=i_stat)
       call memocc(i_stat,i_all,'denspot%V_ext',subname)

       if (((in%exctxpar == 'OP2P' .and. xc_exctXfac() /= 0.0_gp) &
            .or. in%SIC%alpha /= 0.0_gp) .and. nproc >1) then
          i_all=-product(shape(denspot%pkernelseq))*kind(denspot%pkernelseq)
          deallocate(denspot%pkernelseq,stat=i_stat)
          call memocc(i_stat,i_all,'kernelseq',subname)
       else if (nproc == 1 .and. (in%exctxpar == 'OP2P' .or. in%SIC%alpha /= 0.0_gp)) then
          nullify(denspot%pkernelseq)
       end if

       i_all=-product(shape(denspot%pkernel))*kind(denspot%pkernel)
       deallocate(denspot%pkernel,stat=i_stat)
       call memocc(i_stat,i_all,'kernel',subname)

       ! calc_tail false
       i_all=-product(shape(denspot%rhov))*kind(denspot%rhov)
       deallocate(denspot%rhov,stat=i_stat)
       call memocc(i_stat,i_all,'denspot%rhov',subname)
       i_all=-product(shape(denspot%V_XC))*kind(denspot%V_XC)
       deallocate(denspot%V_XC,stat=i_stat)
       call memocc(i_stat,i_all,'denspot%V_XC',subname)

       call deallocate_denspot_distribution(denspot%dpbox, subname)

       i_all=-product(shape(fion))*kind(fion)
       deallocate(fion,stat=i_stat)
       call memocc(i_stat,i_all,'fion',subname)
       i_all=-product(shape(fdisp))*kind(fdisp)
       deallocate(fdisp,stat=i_stat)
       call memocc(i_stat,i_all,'fdisp',subname)
    end if

    !free GPU if it is the case
    if (GPUconv .and. .not.(DoDavidson)) then
       call free_gpu(GPU,KSwfn%orbs%norbp)
    else if (OCLconv .and. .not.(DoDavidson)) then
       call free_gpu_OCL(GPU,KSwfn%orbs,in%nspin)
    end if

    ! Free all remaining parts of denspot
    call deallocate_rho_descriptors(denspot%rhod,subname)
    if(associated(denspot%rho_C)) then
       i_all=-product(shape(denspot%rho_C))*kind(denspot%rho_C)
       deallocate(denspot%rho_C,stat=i_stat)
       call memocc(i_stat,i_all,'denspot%rho_C',subname)
    end if

    ! Free all remaining parts of KSwfn
    call deallocate_bounds(KSwfn%Lzd%Glr%geocode,KSwfn%Lzd%Glr%hybrid_on,&
         KSwfn%Lzd%Glr%bounds,subname)
    call deallocate_Lzd_except_Glr(KSwfn%Lzd, subname)
!    i_all=-product(shape(KSwfn%Lzd%Glr%projflg))*kind(KSwfn%Lzd%Glr%projflg)
!    deallocate(KSwfn%Lzd%Glr%projflg,stat=i_stat)
!    call memocc(i_stat,i_all,'Glr%projflg',subname)
    call deallocate_comms(KSwfn%comms,subname)
    call deallocate_orbs(KSwfn%orbs,subname)
    if (inputpsi /= INPUT_PSI_LINEAR .and. inputpsi /= INPUT_PSI_MEMORY_LINEAR) deallocate(KSwfn%confdatarr)

    ! Free radii_cf
    i_all=-product(shape(radii_cf))*kind(radii_cf)
    deallocate(radii_cf,stat=i_stat)
    call memocc(i_stat,i_all,'radii_cf',subname)

    ! Free projectors.
    call deallocate_proj_descr(nlpspd,subname)
    i_all=-product(shape(proj))*kind(proj)
    deallocate(proj,stat=i_stat)
    call memocc(i_stat,i_all,'proj',subname)

    !end of wavefunction minimisation
    call timing(iproc,'LAST','PR')
    call timing(iproc,'              ','RE')
    call cpu_time(tcpu1)
    call system_clock(ncount1,ncount_rate,ncount_max)
    tel=dble(ncount1-ncount0)/dble(ncount_rate)
    if (iproc == 0) &
         &   write( *,'(1x,a,1x,i4,2(1x,f12.2))') 'CPU time/ELAPSED time for root process ', iproc,tel,tcpu1-tcpu0

    ! Stop signals
    if (in%signaling .and. iproc == 0) then
       call bigdft_signals_rm_denspot(in%gmainloop)
       call bigdft_signals_rm_energs(in%gmainloop)
       call bigdft_signals_rm_wf(in%gmainloop)
       call bigdft_signals_rm_optloop(in%gmainloop)
       call localfields_free_wrapper(denspot%c_obj)
       call energs_free_wrapper(energs%c_obj)
       call optloop_free_wrapper(optLoop%c_obj)
       call wf_free_wrapper(KSwfn%c_obj)
    end if

!!$    if(inputpsi ==  INPUT_PSI_LINEAR) then
!!$        i_all=-product(shape(atoms%rloc))*kind(atoms%rloc)
!!$        deallocate(atoms%rloc,stat=i_stat)
!!$        call memocc(i_stat,i_all,'atoms%rloc',subname)
!!$    end if

  END SUBROUTINE deallocate_before_exiting

END SUBROUTINE cluster


subroutine kswfn_optimization_loop(iproc, nproc, opt, &
     & alphamix, idsx, inputpsi, KSwfn, denspot, nlpspd, proj, energs, atoms, rxyz, GPU, xcstr, &
     & in)
  use module_base
  use module_types
  use module_interfaces, except_this_one => kswfn_optimization_loop
  use yaml_output
  use m_ab6_mixing
  implicit none
  real(dp), dimension(6), intent(out) :: xcstr
  integer, intent(in) :: iproc, nproc, idsx, inputpsi
  real(gp), intent(in) :: alphamix
  type(DFT_optimization_loop), intent(inout) :: opt
  type(DFT_wavefunction), intent(inout) :: KSwfn
  type(DFT_local_fields), intent(inout) :: denspot
  type(energy_terms), intent(inout) :: energs
  type(atoms_data), intent(in) :: atoms
  type(GPU_pointers), intent(inout) :: GPU
  type(nonlocal_psp_descriptors), intent(inout) :: nlpspd
  real(kind=8), dimension(:), pointer :: proj
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  type(input_variables), intent(in) :: in !<todo: Remove me

  character(len = *), parameter :: subname = "kswfn_optimization_loop"
  logical :: endloop, scpot, endlooprp, lcs
  integer :: ndiis_sd_sw, idsx_actual_before, linflag, ierr
  real(gp) :: gnrm_zero
  character(len=5) :: final_out

  !number of switching betweed DIIS and SD during self-consistent loop
  ndiis_sd_sw=0
  !previous value of idsx_actual to control if switching has appeared
  idsx_actual_before=KSwfn%diis%idsx

  ! Setup the mixing, if necessary
  call denspot_set_history(denspot,opt%iscf,in%nspin,KSwfn%Lzd%Glr%d%n1i,KSwfn%Lzd%Glr%d%n2i)

  ! allocate arrays necessary for DIIS convergence acceleration
  call allocate_diis_objects(idsx,in%alphadiis,sum(KSwfn%comms%ncntt(0:nproc-1)),&
       KSwfn%orbs%nkptsp,KSwfn%orbs%nspinor,KSwfn%diis,subname)

  gnrm_zero=0.0d0
  opt%gnrm=1.d10
  opt%rpnrm=1.d10
  endlooprp=.false.

  !normal opt%infocode, if everything go through smoothly we should keep this
  opt%infocode=0
  !yaml output
  if (iproc==0) then
     call yaml_indent_map('Ground State Optimization')
  end if
  opt%itrp=1
  rhopot_loop: do
     if (opt%itrp > opt%itrpmax) exit
     !yaml output 
     if (iproc==0) then
        call yaml_sequence_element(advance='no')
        call yaml_map("Hamiltonian Optimization",label='itrp'//adjustl(yaml_toa(opt%itrp,fmt='(i4.4)')))
     end if
     !set the opt%infocode to the value it would have in the case of no convergence
     opt%infocode=1
     opt%itrep=1
     subd_loop: do
        if (opt%itrep > opt%nrepmax) exit
        !yaml output 
        if (iproc==0) then
           call yaml_sequence_element(advance='no')
           call yaml_map("Subspace Optimization",label='itrep'//adjustl(yaml_toa(opt%itrep,fmt='(i4.4)')))
        end if

        !yaml output
        if (iproc==0) then
           call yaml_indent_map("Wavefunctions Iterations")
        end if
        opt%iter=1
        wfn_loop: do
           if (opt%iter > opt%itermax) exit

           !control whether the minimisation iterations should end after the hamiltionian application
           endloop= opt%gnrm <= opt%gnrm_cv .or. opt%iter == opt%itermax

           if (iproc == 0 .and. verbose > 0) then 
              write( *,'(1x,a,i0)') &
                   &   repeat('-',76 - int(log(real(opt%iter))/log(10.))) // ' iter= ', opt%iter
              !test for yaml output

              if (endloop) then
                 call yaml_sequence_element(label='last',advance='no')
                 !write(70,'(a,i5)')repeat(' ',yaml_indent)//'- &last { #iter: ',opt%iter
              else
                 call yaml_sequence_element(advance='no')
                 !write(70,'(a,i5)')repeat(' ',yaml_indent)//'- { #iter: ',opt%iter
              end if
              call yaml_flow_map()
              call yaml_flow_newline()
           endif

           !control how many times the DIIS has switched into SD
           if (KSwfn%diis%idsx /= idsx_actual_before) ndiis_sd_sw=ndiis_sd_sw+1

           !let SD runs if the DIIS did not work the second time
           if (ndiis_sd_sw > 1) then
              KSwfn%diis%switchSD=.false.
           end if

           !stop the partial timing counter if necessary
           if (endloop .and. opt%itrpmax==1) call timing(iproc,'WFN_OPT','PR')
           !logical flag for the self-consistent potential
           scpot=(opt%iscf > SCF_KIND_DIRECT_MINIMIZATION .and. opt%iter==1 .and. opt%itrep==1) .or. & !mixing to be done
                (opt%iscf <= SCF_KIND_DIRECT_MINIMIZATION) .or. & !direct minimisation
                (opt%itrp==1 .and. opt%itrpmax/=1 .and. opt%gnrm > opt%gnrm_startmix)  !startmix condition (hard-coded, always true by default)
           !allocate the potential in the full box
           !temporary, should change the use of flag in full_local_potential2
           linflag = 1                                 
           if(in%linear == 'OFF') linflag = 0
           if(in%linear == 'TMO') linflag = 2
           call psitohpsi(iproc,nproc,atoms,scpot,denspot,opt%itrp,opt%iter,opt%iscf,alphamix,in%ixc,&
                nlpspd,proj,rxyz,linflag,in%unblock_comms,GPU,KSwfn,energs,opt%rpnrm,xcstr)

           endlooprp= (opt%itrp > 1 .and. opt%rpnrm <= opt%rpnrm_cv) .or. opt%itrp == opt%itrpmax

           call total_energies(energs, opt%iter, iproc)

           !check for convergence or whether max. numb. of iterations exceeded
           if (endloop) then
              if (opt%gnrm < opt%gnrm_cv) opt%infocode=0
              exit wfn_loop 
           endif

           !evaluate the functional of the wavefunctions and put it into the diis structure
           !the energy values is printed out in this routine
           call calculate_energy_and_gradient(opt%iter,iproc,nproc,GPU,in%ncong,opt%iscf,&
                energs,KSwfn,opt%gnrm,gnrm_zero)

           !control the previous value of idsx_actual
           idsx_actual_before=KSwfn%diis%idsx

           call hpsitopsi(iproc,nproc,opt%iter,idsx,KSwfn)

           if (inputpsi == INPUT_PSI_LCAO) then
              if ((opt%gnrm > 4.d0 .and. KSwfn%orbs%norbu /= KSwfn%orbs%norbd) .or. &
                   &   (KSwfn%orbs%norbu == KSwfn%orbs%norbd .and. opt%gnrm > 10.d0)) then
                 if (iproc == 0) then
                    write( *,'(1x,a)')&
                         &   'ERROR: the norm of the residue is too large also with input wavefunctions.'
                 end if
                 opt%infocode=3
              end if
           else if (inputpsi == INPUT_PSI_MEMORY_WVL) then
              if (opt%gnrm > 1.d0) then
                 if (iproc == 0) then
                    write( *,'(1x,a)')&
                         &   'The norm of the residue is too large, need to recalculate input wavefunctions'
                 end if
                 opt%infocode=2
              end if
           end if
           !flush all writings on standart output
           if (iproc==0) then
              !yaml output
              call yaml_close_flow_map()
              call yaml_close_sequence_element()
              call bigdft_utils_flush(unit=6)
           end if
           ! Emergency exit case
           if (opt%infocode == 2 .or. opt%infocode == 3) then
              if (nproc > 1) call MPI_BARRIER(MPI_COMM_WORLD,ierr)
              call kswfn_free_scf_data(KSwfn, (nproc > 1))
              if (opt%iscf /= SCF_KIND_DIRECT_MINIMIZATION) then
                 call ab6_mixing_deallocate(denspot%mix)
                 deallocate(denspot%mix)
              end if
              !>todo: change this return into a clean out of the routine, so the YAML is clean.
              return
           end if

           if (opt%c_obj /= 0.) then
              call optloop_emit_iter(opt, OPTLOOP_WAVEFUNCTIONS, energs, iproc, nproc)
           end if

           opt%iter = opt%iter + 1
        end do wfn_loop
        if (opt%c_obj /= 0.) then
           call optloop_emit_done(opt, OPTLOOP_WAVEFUNCTIONS, energs, iproc, nproc)
        end if

        if (iproc == 0) then 
           if (verbose > 1) write( *,'(1x,a,i0,a)')'done. ',opt%iter,' minimization iterations required'
           write( *,'(1x,a)') &
                &   '--------------------------------------------------- End of Wavefunction Optimisation'
           if ((opt%itrpmax >1 .and. endlooprp) .or. opt%itrpmax == 1) then
              write(final_out, "(A5)") "FINAL"
           else
              write(final_out, "(A5)") "final"
           end if
           call write_energies(opt%iter,0,energs,opt%gnrm,gnrm_zero,final_out)
           call yaml_close_flow_map()
           call yaml_close_sequence_element()

           if (opt%itrpmax >1) then
              if ( KSwfn%diis%energy > KSwfn%diis%energy_min) write( *,'(1x,a,2(1pe9.2))')&
                   'WARNING: Found an energy value lower than the ' // final_out // &
                   ' energy, delta:',KSwfn%diis%energy-KSwfn%diis%energy_min
           else
              !write this warning only if the system is closed shell
              call check_closed_shell(KSwfn%orbs,lcs)
              if (lcs) then
                 if ( energs%eKS > KSwfn%diis%energy_min) write( *,'(1x,a,2(1pe9.2))')&
                      'WARNING: Found an energy value lower than the FINAL energy, delta:',&
                      energs%eKS-KSwfn%diis%energy_min
              end if
           end if
        end if

        if (opt%iter == opt%itermax .and. iproc == 0 .and. opt%infocode/=0) &
             &   write( *,'(1x,a)')'No convergence within the allowed number of minimization steps'
        if (iproc==0) call yaml_close_indent_map() !wfn iterations

        call last_orthon(iproc,nproc,opt%iter,KSwfn,energs%evsum,.true.) !never deallocate psit and hpsi

        !exit if the opt%infocode is correct
        if (opt%infocode == 0) then
           if (iproc==0)call yaml_close_sequence_element() !itrep
           !              yaml_indent=yaml_indent-3 !end list element
           exit subd_loop
        else
           if(iproc==0) then
              write(*,*)&
                   &   ' WARNING: Wavefunctions not converged after cycle',opt%itrep
              if (opt%itrep < opt%nrepmax) write(*,*)' restart after diagonalisation'
           end if
           opt%gnrm=1.d10
        end if

        if (opt%itrpmax == 1 .and. in%norbsempty > 0) then
           !recalculate orbitals occupation numbers
           call evaltoocc(iproc,nproc,.false.,in%Tel,KSwfn%orbs,in%occopt)

           opt%gnrm =1.d10
           KSwfn%diis%energy_min=1.d10
           KSwfn%diis%alpha=2.d0
        end if

        if (iproc==0) then
           !yaml output
           call yaml_close_sequence_element() !itrep
           !         write(70,'(a,i5)')repeat(' ',yaml_indent+2)//'#End itrep:',opt%itrep
           !              yaml_indent=yaml_indent-3 !end list element
        end if
        if (opt%c_obj /= 0.) then
           call optloop_emit_iter(opt, OPTLOOP_SUBSPACE, energs, iproc, nproc)
        end if
        
        opt%itrep = opt%itrep + 1
     end do subd_loop
     if (opt%c_obj /= 0.) then
        call optloop_emit_done(opt, OPTLOOP_SUBSPACE, energs, iproc, nproc)
     end if

     if (opt%itrpmax > 1) then
        !stop the partial timing counter if necessary
        if (endlooprp .and. opt%itrpmax >1) then
           call timing(iproc,'WFN_OPT','PR')
           call yaml_close_sequence_element() !opt%itrp
           exit rhopot_loop
        end if

        !recalculate orbitals occupation numbers
        call evaltoocc(iproc,nproc,.false.,in%Tel,KSwfn%orbs,in%occopt)

        opt%gnrm =1.d10
        KSwfn%diis%energy_min=1.d10
        KSwfn%diis%alpha=2.d0
     end if

     if (iproc == 0) then
        !yaml output
        call yaml_close_sequence_element() !opt%itrp
        !           yaml_indent=yaml_indent-2 !end list element
        !reassume the key elements in the opt%itrp element
        !      if (opt%itrp >1) write(70,'(a)')repeat(' ',yaml_indent+2)//'RhoPot Delta: *rpnrm'
        !      write(70,'(a,i5)')repeat(' ',yaml_indent+2)//'Energies: *last  #End opt%itrp:',opt%itrp
     end if
     if (opt%c_obj /= 0.) then
        call optloop_emit_iter(opt, OPTLOOP_HAMILTONIAN, energs, iproc, nproc)
     end if

     opt%itrp = opt%itrp + 1
  end do rhopot_loop
  if (opt%c_obj /= 0.) then
     call optloop_emit_done(opt, OPTLOOP_HAMILTONIAN, energs, iproc, nproc)
  end if

  !yaml output
  if (iproc==0) call yaml_close_indent_map() !Ground State Optimization

  !!do i_all=1,size(rhopot)
  !!    write(10000+iproc,*) rhopot(i_all)
  !!end do
  !!do i_all=1,size(psi)
  !!    write(11000+iproc,*) psi(i_all)
  !!end do
  !!do i_all=1,size(psi)
  !!    write(12000+iproc,*) psi(i_all)
  !!end do

  if (inputpsi /= INPUT_PSI_EMPTY) then
     energs%ebs=energs%ekin+energs%epot+energs%eproj !the potential energy contains also exctX
     if (abs(energs%evsum-energs%ebs) > 1.d-8 .and. iproc==0) write( *,'(1x,a,2(1x,1pe20.13))')&
          &   'Difference:evsum,energybs',energs%evsum,energs%ebs
  end if

  ! Clean KSwfn parts only needed in the SCF loop.
  call kswfn_free_scf_data(KSwfn, (nproc > 1))

  if (opt%iscf > SCF_KIND_DIRECT_MINIMIZATION) then
     call ab6_mixing_deallocate(denspot%mix)
     deallocate(denspot%mix)
  end if
end subroutine kswfn_optimization_loop
