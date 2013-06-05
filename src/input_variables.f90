!!> @file
!!  Routines to read and print input variables
!! @author
!!    Copyright (C) 2007-2013 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!> Do all initialisation for all different files of BigDFT. 
!! Set default values if not any.
!! Initialize memocc
!! @todo
!!   Should be better for debug purpose to read input.perf before
subroutine bigdft_set_input(radical,posinp,rxyz,in,atoms)
  use module_base
  use module_types
  use module_interfaces, except_this_one => bigdft_set_input
  !use yaml_output
  implicit none

  !Arguments
  character(len=*),intent(in) :: posinp
  character(len=*),intent(in) :: radical
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(out) :: atoms
  real(gp), dimension(:,:), pointer :: rxyz 

  character(len=*), parameter :: subname='bigdft_set_input'
!!$  logical :: exist_list
!!$  integer :: group_size,ierr

  atoms=atoms_null()

  ! initialize mpi environment (this shouldn't be done twice)
!  call mpi_environment_set(bigdft_mpi,iproc,nproc,MPI_COMM_WORLD,nproc)
  !standard names
  call standard_inputfile_names(in,trim(radical), bigdft_mpi%nproc)

  !call yaml_open_map('Representation of the input files')
  ! Read all parameters and update atoms and rxyz.
  call read_input_parameters(bigdft_mpi%iproc,in,.true.)

  !call yaml_close_map()

!!$  ! find out which input files will be used
!!$  inquire(file="list_posinp",exist=exist_list)

!!$  if (in%mpi_groupsize >0 .and. (.not. exist_list)) then
!!$     group_size=in%mpi_groupsize
!!$  else
!!$     group_size=nproc
!!$  endif
!!$  call mpi_environment_set(bigdft_mpi,iproc,nproc,MPI_COMM_WORLD,group_size)
!!$  !reset standard names (this should be avoided) 
!!$  call standard_inputfile_names(in, radical, bigdft_mpi%nproc)

  ! Read atomic file
  call read_atomic_file(trim(posinp),bigdft_mpi%iproc,atoms%astruct)
  call allocate_atoms_nat(atoms, subname)
  call allocate_atoms_ntypes(atoms, subname)
  call read_input_parameters2(bigdft_mpi%iproc,in,atoms,atoms%astruct%rxyz)

  rxyz=>atoms%astruct%rxyz
  ! Read associated pseudo files.
  call init_atomic_values((bigdft_mpi%iproc == 0), atoms, in%ixc)
  call read_atomic_variables(atoms, trim(in%file_igpop),in%nspin)

  ! Start the signaling loop in a thread if necessary.
  if (in%signaling .and. bigdft_mpi%iproc == 0) then
     call bigdft_signals_init(in%gmainloop, 2, in%domain, len(trim(in%domain)))
     call bigdft_signals_start(in%gmainloop, in%signalTimeout)
  end if

  if (bigdft_mpi%iproc == 0) then
     call print_general_parameters(bigdft_mpi%nproc,in,atoms)
     !call write_input_parameters(inputs,atoms)
  end if

  !if other steps are supposed to be done leave the last_run to minus one
  !otherwise put it to one
  if (in%last_run == -1 .and. in%ncount_cluster_x <=1 .or. in%ncount_cluster_x <= 1) then
     in%last_run = 1
  end if

END SUBROUTINE bigdft_set_input


subroutine bigdft_free_input(in)
  use module_base
  use module_types
  use yaml_output
  type(input_variables), intent(inout) :: in
  
  call free_input_variables(in)
  call f_lib_finalize()
  !finalize memory counting
  !call memocc(0,0,'count','stop')
  !free all yaml_streams active
  call yaml_close_all_streams()

end subroutine bigdft_free_input


!> Read the options in the command line using get_command statement
subroutine command_line_information(mpi_groupsize,posinp_file,run_id,ierr)
  use module_types
  implicit none
  integer, intent(out) :: mpi_groupsize
  character(len=*), intent(out) :: posinp_file !< file for list of radicals
  character(len=*), intent(out) :: run_id !< file for radical name
  integer, intent(out) :: ierr !< error code
  !local variables
  integer :: ncommands,icommands
  character(len=256) :: command

  ierr=BIGDFT_SUCCESS
  posinp_file=repeat(' ',len(posinp_file))
  run_id=repeat(' ',len(run_id))
  !traditional scheme
  !if (ncommands == 0) then
     run_id='input'
  !end if

  mpi_groupsize=0
  
  !first see how many arguments are present
  ncommands=COMMAND_ARGUMENT_COUNT()

  do icommands=1,ncommands
     command=repeat(' ',len(command))
     call get_command_argument(icommands,value=command,status=ierr)
     if (ierr /= 0) return
     !print *,'test',ncommands,icommands,command
     call find_command()
     if (ierr /= 0) return
  end do



contains

  subroutine find_command()
    implicit none
    integer :: ipos
    integer, external :: bigdft_error_ret

    if (index(command,'--taskgroup-size=') > 0) then
       if (mpi_groupsize /= 0) then
          ierr=bigdft_error_ret(BIGDFT_INVALID,'taskgroup size specified twice')
       end if
       ipos=index(command,'=')
       read(command(ipos+1:len(command)),*)mpi_groupsize
    else if (index(command,'--run-id=') > 0) then
       if (len_trim(run_id) > 0) then
          ierr=bigdft_error_ret(BIGDFT_INVALID,'run_id specified twice')
       end if
       ipos=index(command,'=')
       read(command(ipos+1:len(command)),*)run_id
    else if (index(command,'--runs-file=') > 0) then
       if (len_trim(posinp_file) > 0 .or. len_trim(run_id) >0) then
          ierr=bigdft_error_ret(BIGDFT_INVALID,'posinp_file specified twice or run_id already known')
       end if
       ipos=index(command,'=')
       read(command(ipos+1:len(command)),*)posinp_file
    else if (index(command,'--') > 0 .and. icommands==1) then
       !help screen
       call help_screen()
       stop
    else if (icommands==1) then
       read(command,*,iostat=ierr)run_id
    else
       call help_screen()
       stop
    end if
  end subroutine find_command

  subroutine help_screen()
    write(*,*)' Usage of the command line instruction'
    write(*,*)' --taskgroup-size=<mpi_groupsize>'
    write(*,*)' --runs-file=<list_posinp filename>'
    write(*,*)' --run-id=<name of the run>: it can be also specified as unique argument'
    write(*,*)' --help : prints this help screen'
  end subroutine help_screen


end subroutine command_line_information


!> Set and check the input file
subroutine set_inputfile(filename, radical, ext)
  implicit none
  character(len = 100), intent(out) :: filename
  character(len = *), intent(in) :: radical, ext
  
  logical :: exists

  write(filename, "(A)") ""
  if (trim(radical) == "") then
     write(filename, "(A,A,A)") "input", ".", trim(ext)
  else
     write(filename, "(A,A,A)") trim(radical), ".", trim(ext)
  end if

  inquire(file=trim(filename),exist=exists)
  if (.not. exists .and. (trim(radical) /= "input" .and. trim(radical) /= "")) &
       & write(filename, "(A,A,A)") "default", ".", trim(ext)
end subroutine set_inputfile


!> Define the name of the input files
subroutine standard_inputfile_names(in, radical, nproc)
  use module_types
  use module_base
  use yaml_output
  implicit none
  type(input_variables), intent(inout) :: in
  character(len = *), intent(in) :: radical
  integer, intent(in) :: nproc
  integer :: ierr

  !set prefix name of the run (as input by defaut for input.dft)
  in%run_name=repeat(' ',len(in%run_name))
  if (trim(radical) /= 'input') in%run_name=trim(radical)

  call set_inputfile(in%file_dft, radical,    "dft")
  call set_inputfile(in%file_geopt, radical,  "geopt")
  call set_inputfile(in%file_kpt, radical,    "kpt")
  call set_inputfile(in%file_perf, radical,   "perf")
  call set_inputfile(in%file_tddft, radical,  "tddft")
  call set_inputfile(in%file_mix, radical,    "mix")
  call set_inputfile(in%file_sic, radical,    "sic")
  call set_inputfile(in%file_occnum, radical, "occ")
  call set_inputfile(in%file_igpop, radical,  "occup")
  call set_inputfile(in%file_lin, radical,    "lin")
  call set_inputfile(in%file_frag, radical,    "frag")

  if (trim(radical) == "input") then
        in%dir_output="data" // trim(bigdft_run_id_toa())
  else
        in%dir_output="data-"//trim(radical)!//trim(bigdft_run_id_toa())
  end if

  in%files = INPUTS_NONE

  ! To avoid race conditions where procs create the default file and other test its
  ! presence, we put a barrier here.
  if (nproc > 1) call MPI_BARRIER(bigdft_mpi%mpi_comm, ierr)
END SUBROUTINE standard_inputfile_names


!> Do initialisation for all different calculation parameters of BigDFT. 
!! Set default values if not any. Atomic informations are updated  by
!! symmetries if necessary and by geometry input parameters.
subroutine read_input_parameters(iproc,in,dump)
  use module_base
  use module_types
  use module_interfaces, except_this_one => read_input_parameters
  use yaml_output

  implicit none

  !Arguments
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  logical, intent(in) :: dump
  !Local variables
  ! Default for inputs (should not be necessary if all the variables comes from the parsing)
  call default_input_variables(in)
  ! Read linear variables
  ! Parse all input files, independent from atoms.
  call inputs_parse_params(in, iproc, dump)
  if(in%inputpsiid==100 .or. in%inputpsiid==101 .or. in%inputpsiid==102) &
      DistProjApply=.true.
  if(in%linear /= INPUT_IG_OFF .and. in%linear /= INPUT_IG_LIG) then
     !only on the fly calculation
     DistProjApply=.true.
  end if

END SUBROUTINE read_input_parameters


subroutine read_input_parameters2(iproc,in,atoms,rxyz)
  use module_base
  use module_types
  use module_interfaces, except_this_one => read_input_parameters2
  use module_input
  use yaml_strings
  use yaml_output

  implicit none

  !Arguments
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(3,atoms%astruct%nat), intent(inout) :: rxyz
  !Local variables
  integer :: ierr
!!$  integer :: ierror
  !character(len=500) :: logfile,logfile_old,logfile_dir
  !logical :: exists
!!$  print *,'hereAAA',iproc
  ! Shake atoms, if required.
  call atoms_set_displacement(atoms, rxyz, in%randdis)
!!$  print *,'hello21',atoms%astruct%ntypes,'ciaoAAA',bigdft_mpi%iproc
  call mpi_barrier(mpi_comm_world,ierr)

  ! Update atoms with symmetry information
  call atoms_set_symmetries(atoms, rxyz, in%disableSym, in%symTol, in%elecfield)
!!$  print *,'hello22',atoms%astruct%ntypes,'ciaoAAA',bigdft_mpi%iproc
!!$call mpi_barrier(mpi_comm_world,ierr)

  ! Parse input files depending on atoms.
  call inputs_parse_add(in, atoms, iproc, .true.)
!!$
!!$  print *,'hello23',atoms%astruct%ntypes,'ciaoAAA',bigdft_mpi%iproc
!!$  call mpi_barrier(mpi_comm_world,ierr)


  ! Stop the code if it is trying to run GPU with non-periodic boundary conditions
!  if (atoms%astruct%geocode /= 'P' .and. (GPUconv .or. OCLconv)) then
!     if (iproc==0) call yaml_warning('GPU calculation allowed only in periodic boundary conditions')
!     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
!  end if

  ! Stop the code if it is trying to run GPU with spin=4
  if (in%nspin == 4 .and. (GPUconv .or. OCLconv)) then
     if (iproc==0) call yaml_warning('GPU calculation not implemented with non-collinear spin')
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
  end if

!!$  ! Stop code for unproper input variables combination.
!!$  if (in%ncount_cluster_x > 0 .and. .not. in%disableSym .and. atoms%astruct%geocode == 'S') then
!!$     if (iproc==0) then
!!$        write(*,'(1x,a)') 'Change "F" into "T" in the last line of "input.dft"'   
!!$        write(*,'(1x,a)') 'Forces are not implemented with symmetry support, disable symmetry please (T)'
!!$     end if
!!$     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
!!$  end if
  if (in%nkpt > 1 .and. in%gaussian_help) then
     if (iproc==0) call yaml_warning('Gaussian projection is not implemented with k-point support')
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
  end if

  !check whether a directory name should be associated for the data storage
  call check_for_data_writing_directory(iproc,in)

!!$  print *,'hello24',atoms%astruct%ntypes,'ciaoAAA',bigdft_mpi%iproc
!!$  call mpi_barrier(mpi_comm_world,ierr)


END SUBROUTINE read_input_parameters2


!> Check the directory of data (create if not present)
subroutine check_for_data_writing_directory(iproc,in)
  use module_base
  use module_types
  use yaml_output
  implicit none
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  !local variables
  logical :: shouldwrite
  integer :: i_stat,ierror,ierr
  character(len=100) :: dirname

  if (iproc==0) call yaml_comment('|',hfill='-')

  !initialize directory name
  shouldwrite=.false.

  shouldwrite=shouldwrite .or. &
       in%output_wf_format /= WF_FORMAT_NONE .or. &    !write wavefunctions
       in%output_denspot /= output_denspot_NONE .or. & !write output density
       in%ncount_cluster_x > 1 .or. &                  !write posouts or posmds
       in%inputPsiId == 2 .or. &                       !have wavefunctions to read
       in%inputPsiId == 12 .or.  &                     !read in gaussian basis
       in%gaussian_help .or. &                         !Mulliken and local density of states
       in%writing_directory /= '.' .or. &              !have an explicit local output directory
       bigdft_mpi%ngroup > 1   .or. &                  !taskgroups have been inserted
       in%lin%plotBasisFunctions > 0 .or. &            !dumping of basis functions for locreg runs
       in%inputPsiId == 102                            !reading of basis functions

  !here you can check whether the etsf format is compiled

  if (shouldwrite) then
     ! Create a directory to put the files in.
     dirname=repeat(' ',len(dirname))
     if (iproc == 0) then
        call getdir(in%dir_output, len_trim(in%dir_output), dirname, 100, i_stat)
        if (i_stat /= 0) then
           call yaml_warning("Cannot create output directory '" // trim(in%dir_output) // "'.")
           call MPI_ABORT(bigdft_mpi%mpi_comm,ierror,ierr)
        end if
     end if
     call MPI_BCAST(dirname,len(dirname),MPI_CHARACTER,0,bigdft_mpi%mpi_comm,ierr)
     in%dir_output=dirname
     if (iproc==0) call yaml_map('Data Writing directory',trim(in%dir_output))
  else
     if (iproc==0) call yaml_map('Data Writing directory','./')
     in%dir_output=repeat(' ',len(in%dir_output))
  end if

END SUBROUTINE check_for_data_writing_directory


!> Set default values for input variables
subroutine default_input_variables(in)
  use module_base
  use module_types
  implicit none

  type(input_variables), intent(inout) :: in

  ! Default values.
  in%output_wf_format = WF_FORMAT_NONE
  in%output_denspot_format = output_denspot_FORMAT_CUBE
  nullify(in%kpt)
  nullify(in%wkpt)
  nullify(in%kptv)
  nullify(in%nkptsv_group)
  ! Default abscalc variables
  call abscalc_input_variables_default(in)
  ! Default frequencies variables
  call frequencies_input_variables_default(in)
  ! Default values for geopt.
  call geopt_input_variables_default(in) 
  ! Default values for mixing procedure
  call mix_input_variables_default(in) 
  ! Default values for tddft
  call tddft_input_variables_default(in)
  !Default for Self-Interaction Correction variables
  call sic_input_variables_default(in)
  ! Default for signaling
  in%gmainloop = 0.d0
  ! Default for lin.
  nullify(in%lin%potentialPrefac_lowaccuracy)
  nullify(in%lin%potentialPrefac_highaccuracy)
  nullify(in%lin%potentialPrefac_ao)
  nullify(in%lin%norbsPerType)
  nullify(in%lin%locrad)
  nullify(in%lin%locrad_lowaccuracy)
  nullify(in%lin%locrad_highaccuracy)
  nullify(in%lin%locrad_type)
  nullify(in%lin%kernel_cutoff)
  !nullify(in%frag%frag_info)
  nullify(in%frag%label)
  nullify(in%frag%dirname)
  nullify(in%frag%frag_index)
END SUBROUTINE default_input_variables


subroutine dft_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  type(input_variables), intent(inout) :: in
  !local variables
  logical :: exists
  integer :: ierror
  real(gp), dimension(2), parameter :: hgrid_rng=(/0.0_gp,2.0_gp/)
  real(gp), dimension(2), parameter :: xrmult_rng=(/0.0_gp,100.0_gp/)

  !dft parameters, needed for the SCF part
  call input_set_file(iproc,dump,trim(filename),exists,'DFT Calculation Parameters')  
  if (exists) in%files = in%files + INPUTS_DFT
  !call the variable, its default value, the line ends if there is a comment

  !grid spacings
  call input_var(in%hx,'0.45',ranges=hgrid_rng)
  call input_var(in%hy,'0.45',ranges=hgrid_rng)
  call input_var(in%hz,'0.45',ranges=hgrid_rng,comment='hx,hy,hz: grid spacing in the three directions')

  !coarse and fine radii around atoms
  call input_var(in%crmult,'5.0',ranges=xrmult_rng)
  call input_var(in%frmult,'8.0',ranges=xrmult_rng,&
       comment='c(f)rmult: c(f)rmult*radii_cf(:,1(2))=coarse(fine) atom-based radius')

  !XC functional (ABINIT XC codes)
  call input_var(in%ixc,'1',comment='ixc: exchange-correlation parameter (LDA=1,PBE=11)')

  !charge and electric field
  call input_var(in%ncharge,'0',ranges=(/-500,500/))
  call input_var(in%elecfield(1),'0.')
  call input_var(in%elecfield(2),'0.')
  call input_var(in%elecfield(3),'0.',comment='charge of the system, Electric field (Ex,Ey,Ez)')
  !call input_var(in%elecfield(3),'0.',comment='ncharge: charge of the system, Electric field (Ex,Ey,Ez)')

  !spin and polarization
  call input_var(in%nspin,'1',exclusive=(/1,2,4/))
  call input_var(in%mpol,'0',comment='nspin=1 non-spin polarization, mpol=total magnetic moment')

  !XC functional (ABINIT XC codes)
  call input_var(in%gnrm_cv,'1.e-4',ranges=(/1.e-20_gp,1.0_gp/),&
       comment='gnrm_cv: convergence criterion gradient')

  !convergence parameters
  call input_var(in%itermax,'50',ranges=(/0,10000/))
  call input_var(in%nrepmax,'1',ranges=(/0,1000/),&
       comment='itermax,nrepmax: max. # of wfn. opt. steps and of re-diag. runs')

  !convergence parameters
  call input_var(in%ncong,'6',ranges=(/0,20/))
  call input_var(in%idsx,'6',ranges=(/0,15/),&
       comment='ncong, idsx: # of CG it. for preconditioning eq., wfn. diis history')
  !does not make sense a DIIS history longer than the number of iterations
  !only if the iscf is not particular
  in%idsx = min(in%idsx, in%itermax)

  !dispersion parameter
  call input_var(in%dispersion,'0',ranges=(/0,5/),&
       comment='dispersion correction potential (values 1,2,3,4,5), 0=none')
    
  ! Now the variables which are to be used only for the last run
  call input_var(in%inputPsiId,'0',exclusive=(/-2,-1,0,2,10,12,13,100,101,102/),input_iostat=ierror)
  ! Validate inputPsiId value (Can be added via error handling exception)
  if (ierror /=0 .and. iproc == 0) then
     write( *,'(1x,a,I0,a)')'ERROR: illegal value of inputPsiId (', in%inputPsiId, ').'
     call input_psi_help()
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierror)
  end if

  call input_var(in%output_wf_format,'0',exclusive=(/0,1,2,3/),input_iostat=ierror)
  ! Validate output_wf value.
  if (ierror /=0 .and. iproc == 0) then
     write( *,'(1x,a,I0,a)')'ERROR: illegal value of output_wf (', in%output_wf_format, ').'
     call output_wf_format_help()
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierror)
  end if

  call input_var(in%output_denspot,'0',exclusive=(/0,1,2,10,11,12,20,21,22/),&
       comment='InputPsiId, output_wf, output_denspot')

  !project however the wavefunction on gaussians if asking to write them on disk
  ! But not if we use linear scaling version (in%inputPsiId >= 100)
  in%gaussian_help=(in%inputPsiId >= 10 .and. in%inputPsiId < 100)

  !switch on the gaussian auxiliary treatment 
  !and the zero of the forces
  if (in%inputPsiId == 10) then
     in%inputPsiId=0
  else if (in%inputPsiId == 13) then
     in%inputPsiId=2
  end if
  ! Setup out grid parameters.
  if (in%output_denspot >= 0) then
     in%output_denspot_format = in%output_denspot / 10
  else
     in%output_denspot_format = output_denspot_FORMAT_CUBE
     in%output_denspot = abs(in%output_denspot)
  end if
  in%output_denspot = modulo(in%output_denspot, 10)

  ! Tail treatment.
  call input_var(in%rbuf,'0.0',ranges=(/0.0_gp,10.0_gp/))
  call input_var(in%ncongt,'30',ranges=(/1,50/),&
       comment='rbuf, ncongt: length of the tail (AU),# tail CG iterations')

  !in%calc_tail=(in%rbuf > 0.0_gp)

  !davidson treatment
  ! Now the variables which are to be used only for the last run
  call input_var(in%norbv,'0',ranges=(/-9999,9999/))
  call input_var(in%nvirt,'0',ranges=(/0,abs(in%norbv)/))
  call input_var(in%nplot,'0',ranges=(/0,abs(in%norbv)/),&
       comment='Davidson subspace dim., # of opt. orbs, # of plotted orbs')

  !in%nvirt = min(in%nvirt, in%norbv) commented out

  ! Line to disable automatic behaviours (currently only symmetries).
  call input_var(in%disableSym,'F',comment='disable the symmetry detection')

  !define whether there should be a last_run after geometry optimization
  !also the mulliken charge population should be inserted
  if ((in%rbuf > 0.0_gp) .or. in%output_wf_format /= WF_FORMAT_NONE .or. &
       in%output_denspot /= output_denspot_NONE .or. in%norbv /= 0) then
     in%last_run=-1 !last run to be done depending of the external conditions
  else
     in%last_run=0
  end if

  call input_free((iproc == 0) .and. dump)

end subroutine dft_input_variables_new


!> Assign default values for mixing variables
subroutine mix_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  !mixing treatement (hard-coded values)
  in%iscf=0
  in%itrpmax=1
  in%alphamix=0.0_gp
  in%rpnrm_cv=1.e-4_gp
  in%gnrm_startmix=0.0_gp
  in%norbsempty=0
  in%Tel=0.0_gp
  in%occopt=SMEARING_DIST_ERF
  in%alphadiis=2.d0

END SUBROUTINE mix_input_variables_default


!> Read the input variables needed for the geometry optimisation
!!    Every argument should be considered as mandatory
subroutine mix_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  !Arguments
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  !local variables
  !n(c) character(len=*), parameter :: subname='mix_input_variables'
  logical :: exists

  !Mix parameters, needed for the SCF poart with Davidson
  call input_set_file(iproc,dump,trim(filename),exists,'Mixing Parameters')  
  if (exists) in%files = in%files + INPUTS_MIX
  !call the variable, its default value, the line ends if there is a comment

  !Controls the self-consistency: 0 direct minimisation otherwise ABINIT convention
  call input_var(in%iscf,'0',exclusive=(/-1,0,1,2,3,4,5,7,12,13,14,15,17/),&
       comment="Mixing parameters")
  call input_var(in%itrpmax,'1',ranges=(/0,10000/),&
       comment="Maximum number of diagonalisation iterations")
  call input_var(in%rpnrm_cv,'1.e-4',ranges=(/0.0_gp,10.0_gp/),&
       comment="Stop criterion on the residue of potential or density")
  call input_var(in%norbsempty,'0',ranges=(/0,10000/))
  call input_var(in%Tel,'0.0',ranges=(/0.0_gp,1.0e6_gp/)) 
  call input_var(in%occopt,'1',ranges=(/1,5/),&
       comment="No. of additional bands, elec. temperature, smearing method")
  call input_var(in%alphamix,'0.0',ranges=(/0.0_gp,1.0_gp/))
  call input_var(in%alphadiis,'2.0',ranges=(/0.0_gp,10.0_gp/),&
       comment="Multiplying factors for the mixing and the electronic DIIS")

  call input_free((iproc == 0) .and. dump)

  !put the startmix if the mixing has to be done
  if (in%iscf >  SCF_KIND_DIRECT_MINIMIZATION) in%gnrm_startmix=1.e300_gp

END SUBROUTINE mix_input_variables_new


!> Assign default values for GEOPT variables
subroutine geopt_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  !put some fake values for the geometry optimsation case
  in%geopt_approach='SDCG'
  in%ncount_cluster_x=0
  in%frac_fluct=1.0_gp
  in%forcemax=0.0_gp
  in%randdis=0.0_gp
  in%betax=2.0_gp
  in%history = 1
  in%wfn_history = 1
  in%ionmov = -1
  in%dtion = 0.0_gp
  in%strtarget(:)=0.0_gp
  nullify(in%qmass)

END SUBROUTINE geopt_input_variables_default


!> Read the input variables needed for the geometry optimisation
!! Every argument should be considered as mandatory
subroutine geopt_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  !local variables
  character(len=*), parameter :: subname='geopt_input_variables'
  integer :: i_stat,i
  logical :: exists

  !target stress tensor
  in%strtarget(:)=0.0_gp

  !geometry input parameters
  call input_set_file(iproc,dump,trim(filename),exists,'Geometry Parameters')  
  if (exists) in%files = in%files + INPUTS_GEOPT
  !call the variable, its default value, the line ends if there is a comment
!  if (.not. exists) then
!     in%ncount_cluster_x=0
!     return
!  end if

  call input_var(in%geopt_approach,"BFGS",exclusive=(/'SDCG ','VSSD ','LBFGS','BFGS ','PBFGS','AB6MD','DIIS ','FIRE '/),&
       comment="Geometry optimisation method")
  call input_var(in%ncount_cluster_x,'1',ranges=(/0,2000/),&
       comment="Maximum number of force evaluations")
  !here the parsing of the wavefunction history should be added
  in%wfn_history=1

  call input_var(in%frac_fluct,'1.0',ranges=(/0.0_gp,10.0_gp/))
  call input_var(in%forcemax,'0.0',ranges=(/0.0_gp,10.0_gp/),&
       comment="fract_fluct,forcemax")
  call input_var(in%randdis,'0.0',ranges=(/0.0_gp,10.0_gp/),&
       comment="random displacement amplitude")

  if (case_insensitive_equiv(trim(in%geopt_approach),"AB6MD")) then
     in%nnos=0
     call input_var(in%ionmov,'6',exclusive=(/6,7,8,9,12,13/),&
          comment="AB6MD: movement ion method")
     call input_var(in%dtion,'20.670689',ranges=(/0.0_gp,1.e3_gp/),&
          comment="Time step for molecular dynamics - Atomic Units (20.670689 AU=0.5 fs)")
     if (in%ionmov == 6) then
        call input_var(in%mditemp,'300',ranges=(/0.0_gp,1.0e9_gp/),&
             comment="Temperature of molecular dynamics")
     elseif (in%ionmov > 7) then
        call input_var(in%mditemp,'300',ranges=(/0.0_gp,1.0e9_gp/))
        call input_var(in%mdftemp,'300',ranges=(/0.0_gp,1.0e9_gp/),&
             comment="Initial and Final Temperatures of molecular dynamics")
     end if

     if (in%ionmov == 8) then
        call input_var(in%noseinert,'1.e5',ranges=(/0.0_gp,1.0e9_gp/),&
             comment="Thermostat inertia coefficient for Nose_Hoover dynamics")
     else if (in%ionmov == 9) then
        call input_var(in%friction,'1.e-3',&
             comment="Friction coefficient for Langevin dynamics")
        call input_var(in%mdwall,'1.e4',ranges=(/0.0_gp,1.e5_gp/),&
             comment="Distance in bohr where atoms can bounce for Langevin dynamics")
     else if (in%ionmov == 13) then
        call input_var(in%nnos,'0',ranges=(/0,100/),&
             comment="Number of Thermostat (isothermal/isenthalpic ensemble)")
        allocate(in%qmass(in%nnos+ndebug),stat=i_stat)
        call memocc(i_stat,in%qmass,'in%qmass',subname)
        do i=1,in%nnos-1
           call input_var(in%qmass(i),'0.0',ranges=(/0.0_gp,1.e9_gp/))
        end do
        if (in%nnos > 0) call input_var(in%qmass(in%nnos),'0.0',ranges=(/0.0_gp,1.e9_gp/),&
           comment="Mass of each thermostat (isothermal/isenthalpic ensemble)")
        call input_var(in%bmass,'10',ranges=(/0.0_gp,1.0e9_gp/))
        call input_var(in%vmass,'1.0',ranges=(/0.0_gp,1.0e9_gp/),&
             comment="Barostat masses (isothermal/isenthalpic ensemble)")
     end if

     if (in%ionmov /= 13) then
        !the allocation of this pointer should be done in any case
        allocate(in%qmass(in%nnos+ndebug),stat=i_stat)
        call memocc(i_stat,in%qmass,'in%qmass',subname)
     end if

  else if (case_insensitive_equiv(trim(in%geopt_approach),"DIIS")) then
     call input_var(in%betax,'2.0',ranges=(/0.0_gp,100.0_gp/))
     call input_var(in%history,'4',ranges=(/0,1000/),&
          comment="Stepsize and history for DIIS method")
  else
     call input_var(in%betax,'4.0',ranges=(/0.0_gp,100.0_gp/),&
          comment="Stepsize for the geometry optimisation")
  end if
  if (case_insensitive_equiv(trim(in%geopt_approach),"FIRE")) then
        call input_var(in%dtinit,'0.75',ranges=(/0.0_gp,1.e4_gp/))
        call input_var(in%dtmax, '1.5',ranges=(/in%dtinit,1.e4_gp/),&
             comment="initial and maximal time step for the FIRE method")
  endif

  call input_free((iproc == 0) .and. dump)

END SUBROUTINE geopt_input_variables_new


!> Assign default values for self-interaction correction variables
subroutine sic_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  in%SIC%approach='NONE'
  in%SIC%alpha=0.0_gp
  in%SIC%fref=0.0_gp

END SUBROUTINE sic_input_variables_default


!> Read Self-Interaction Correction (SIC) input parameters
subroutine sic_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  !local variables
  logical :: exists
  !n(c) character(len=*), parameter :: subname='sic_input_variables'

  !Self-Interaction Correction input parameters
  call input_set_file(iproc,dump,trim(filename),exists,'SIC Parameters')  
  if (exists) in%files = in%files + INPUTS_SIC

  call input_var(in%SIC%approach,'NONE',exclusive=(/'NONE','PZ  ','NK  '/),comment='SIC method: NONE, PZ, NK')
  call input_var(in%SIC%alpha,'0.0',ranges=(/0.0_gp,1.0_gp/),comment='SIC downscaling parameter')
  call input_var(in%SIC%fref,'0.0',ranges=(/0.0_gp,1.0_gp/),comment='Reference occupation fref (NK case only)')
  in%SIC%ixc=in%ixc
  call input_free((iproc == 0) .and. dump)

END SUBROUTINE sic_input_variables_new


!> Read linear input parameters
subroutine lin_input_variables_new(iproc,dump,filename,in,atoms)
  use module_base
  use module_types
  use module_input
  implicit none
  integer, intent(in) :: iproc
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(inout) :: atoms
  logical, intent(in) :: dump
  !local variables
  logical :: exists
  character(len=*), parameter :: subname='lin_input_variables'
  character(len=256) :: comments
  logical,dimension(atoms%astruct%ntypes) :: parametersSpecified
  logical :: found
  character(len=20):: atomname
  integer :: itype, jtype, ios, ierr, iat, npt, iiorb, iorb, nlr, istat
  real(gp):: ppao, ppl, pph, lrl, lrh, kco
  real(gp),dimension(atoms%astruct%ntypes) :: locradType, locradType_lowaccur, locradType_highaccur

  !Linear input parameters
  call input_set_file(iproc,dump,trim(filename),exists,'Linear Parameters')  
  if (exists) in%files = in%files + INPUTS_LIN

  ! number of accuracy levels: either 2 (for low/high accuracy) or 1 (for hybrid mode)
  comments='number of accuracy levels: either 2 (for low/high accuracy) or 1 (for hybrid mode)'
  call input_var(in%lin%nlevel_accuracy,'2',ranges=(/1,2/),comment=comments)

  ! number of iterations
  comments = 'outer loop iterations (low, high)'
  call input_var(in%lin%nit_lowaccuracy,'15',ranges=(/0,100000/))
  call input_var(in%lin%nit_highaccuracy,'1',ranges=(/0,100000/),comment=comments)

  comments = 'basis iterations (low, high)'
  call input_var(in%lin%nItBasis_lowaccuracy,'12',ranges=(/0,100000/))
  call input_var(in%lin%nItBasis_highaccuracy,'50',ranges=(/0,100000/),comment=comments)

  comments = 'kernel iterations (low, high)'
  call input_var(in%lin%nItSCCWhenFixed_lowaccuracy,'15',ranges=(/0,1000/))
  call input_var(in%lin%nItSCCWhenFixed_highaccuracy,'15',ranges=(/0,1000/),comment=comments)

  ! DIIS history lengths
  comments = 'DIIS history for basis (low, high)'
  call input_var(in%lin%DIIS_hist_lowaccur,'5',ranges=(/0,100/))
  call input_var(in%lin%DIIS_hist_highaccur,'0',ranges=(/0,100/),comment=comments)

  comments = 'DIIS history for kernel (low, high)'
  call input_var(in%lin%mixHist_lowaccuracy,'0',ranges=(/0,100/))
  call input_var(in%lin%mixHist_highaccuracy,'0',ranges=(/0,100/),comment=comments)

  ! mixing parameters
  comments = 'density mixing parameter (low, high)'
  call input_var(in%lin%alpha_mix_lowaccuracy,'.5d0',ranges=(/0.d0,1.d0/))
  call input_var(in%lin%alpha_mix_highaccuracy,'.5d0',ranges=(/0.d0,1.d0/),comment=comments)

  ! Convergence criteria
  comments = 'outer loop convergence (low, high)'
  call input_var(in%lin%lowaccuracy_conv_crit,'1.d-8',ranges=(/0.d0,1.d0/))
  call input_var(in%lin%highaccuracy_conv_crit,'1.d-12',ranges=(/0.d0,1.d0/),comment=comments)

  comments = 'basis convergence (low, high)'
  call input_var(in%lin%convCrit_lowaccuracy,'1.d-3',ranges=(/0.0_gp,1.0_gp/))
  call input_var(in%lin%convCrit_highaccuracy,'1.d-5',ranges=(/0.0_gp,1.0_gp/),comment=comments)
  
  comments = 'multiplier to (exit one TMB optimization, fix TMB completely). Only used for hybrid mode'
  call input_var(in%lin%deltaenergy_multiplier_TMBexit,'1.d0',ranges=(/1.d-5,1.d1/))
  call input_var(in%lin%deltaenergy_multiplier_TMBfix,'1.d0',ranges=(/1.d-5,1.d1/),comment=comments)

  comments = 'factor to reduce the confinement. Only used for hybrid mode.'
  call input_var(in%lin%reduce_confinement_factor,'0.5d0',ranges=(/-1.d100,1.d0/),comment=comments)

  comments = 'kernel convergence (low, high)'
  call input_var(in%lin%convCritMix_lowaccuracy,'1.d-13',ranges=(/0.d0,1.d0/))
  call input_var(in%lin%convCritMix_highaccuracy,'1.d-13',ranges=(/0.d0,1.d0/),comment=comments)

  comments = 'convergence criterion on density to fix TMBS'
  call input_var(in%lin%support_functions_converged,'1.d-10',ranges=(/0.d0,1.d0/),comment=comments)

  ! Miscellaneous
  comments='mixing method: 100 (direct minimization), 101 (simple dens mixing), 102 (simple pot mixing), 103 (FOE)'
  call input_var(in%lin%scf_mode,'100',ranges=(/100,103/),comment=comments)

  comments = 'initial step size for basis optimization (DIIS, SD)' ! DELETE ONE
  call input_var(in%lin%alphaDIIS,'1.d0',ranges=(/0.0_gp,10.0_gp/))
  call input_var(in%lin%alphaSD,'1.d0',ranges=(/0.0_gp,10.0_gp/),comment=comments)

  comments = 'lower and upper bound for the eigenvalue spectrum (FOE). Will be adjusted automatically if chosen too small'
  call input_var(in%lin%evlow,'-.5d0',ranges=(/-10.d0,-1.d-10/))
  call input_var(in%lin%evhigh,'-.5d0',ranges=(/1.d-10,10.d0/),comment=comments)

  comments='number of iterations in the preconditioner'
  call input_var(in%lin%nItPrecond,'5',ranges=(/1,100/),comment=comments)
  
  comments = '0-> exact Loewdin, 1-> taylor expansion; &
             &in orthoconstraint: correction for non-orthogonality (0) or no correction (1)'
  call input_var(in%lin%methTransformOverlap,'1',ranges=(/-1,1/))
  call input_var(in%lin%correctionOrthoconstraint,'1',ranges=(/0,1/),comment=comments)

  comments='fscale: length scale over which complementary error function decays from 1 to 0'
  call input_var(in%lin%fscale,'1.d-2',ranges=(/0.d0,1.d0/),comment=comments)

  !plot basis functions: true or false
  comments='Output basis functions: 0 no output, 1 formatted output, 2 Fortran bin, 3 ETSF ;'//&
           'calculate dipole ; pulay correction'
  call input_var(in%lin%plotBasisFunctions,'0',ranges=(/0,3/))
  call input_var(in%lin%calc_dipole,'F')
  call input_var(in%lin%pulay_correction,'T',comment=comments)

  !fragment calculation and transfer integrals: true or false
  comments='fragment calculation; calculate transfer_integrals'
  call input_var(in%lin%fragment_calculation,'F')
  call input_var(in%lin%calc_transfer_integrals,'F',comment=comments)

  ! Allocate lin pointers and atoms%rloc
  call nullifyInputLinparameters(in%lin)
  call allocateBasicArraysInputLin(in%lin, atoms%astruct%ntypes)
  
  ! Now read in the parameters specific for each atom type.
  comments = 'Atom name, number of basis functions per atom, prefactor for confinement potential,'//&
             'localization radius, kernel cutoff'
  parametersSpecified=.false.
  itype = 1
  do
     !Check at the beginning to permit natom=0
     if (itype > atoms%astruct%ntypes) exit
     if (exists) then
        call input_var(atomname,'C',input_iostat=ios)
        if (ios /= 0) exit
     else
        call input_var(atomname,trim(atoms%astruct%atomnames(itype)))
        itype = itype + 1
     end if
     call input_var(npt,'1',ranges=(/1,100/),input_iostat=ios)
     call input_var(ppao,'1.2d-2',ranges=(/0.0_gp,1.0_gp/),input_iostat=ios)
     call input_var(ppl,'1.2d-2',ranges=(/0.0_gp,1.0_gp/),input_iostat=ios)
     call input_var(pph,'5.d-5',ranges=(/0.0_gp,1.0_gp/),input_iostat=ios)
     call input_var(lrl,'10.d0',ranges=(/1.0_gp,10000.0_gp/),input_iostat=ios)
     call input_var(lrh,'10.d0',ranges=(/1.0_gp,10000.0_gp/),input_iostat=ios)
     call input_var(kco,'20.d0',ranges=(/1.0_gp,10000.0_gp/),input_iostat=ios,comment=comments)
     ! The reading was successful. Check whether this atom type is actually present.
     found=.false.
     do jtype=1,atoms%astruct%ntypes
        if(trim(atomname)==trim(atoms%astruct%atomnames(jtype))) then
           found=.true.
           parametersSpecified(jtype)=.true.
           in%lin%norbsPerType(jtype)=npt
           in%lin%potentialPrefac_ao(jtype)=ppao
           in%lin%potentialPrefac_lowaccuracy(jtype)=ppl
           in%lin%potentialPrefac_highaccuracy(jtype)=pph
           locradType(jtype)=lrl
           in%lin%locrad_type(jtype)=lrl
           locradType_lowaccur(jtype)=lrl
           locradType_highaccur(jtype)=lrh
           atoms%rloc(jtype,:)=locradType(jtype)
           in%lin%kernel_cutoff(jtype)=kco
        end if
     end do
     if(.not.found) then
        if(iproc==0 .and. dump) write(*,'(1x,3a)') "WARNING: you specified informations about the atomtype '",trim(atomname), &
             "', which is not present in the file containing the atomic coordinates."
     end if
  end do
  found  = .true.
  do jtype=1,atoms%astruct%ntypes
     found = found .and. parametersSpecified(jtype)
  end do
  if (.not. found) then
     ! The parameters were not specified for all atom types.
     if(iproc==0) then
        write(*,'(1x,a)',advance='no') "ERROR: the file 'input.lin' does not contain the parameters&
             & for the following atom types:"
        do jtype=1,atoms%astruct%ntypes
           if(.not.parametersSpecified(jtype)) write(*,'(1x,a)',advance='no') trim(atoms%astruct%atomnames(jtype))
        end do
     end if
     call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
     stop
  end if

  nlr=0
  do iat=1,atoms%astruct%nat
      itype=atoms%astruct%iatype(iat)
      nlr=nlr+in%lin%norbsPerType(itype)
  end do
  allocate(in%lin%locrad(nlr),stat=istat)
  call memocc(istat,in%lin%locrad,'in%lin%locrad',subname)
  allocate(in%lin%locrad_lowaccuracy(nlr),stat=istat)
  call memocc(istat,in%lin%locrad_lowaccuracy,'in%lin%locrad_lowaccuracy',subname)
  allocate(in%lin%locrad_highaccuracy(nlr),stat=istat)
  call memocc(istat,in%lin%locrad_highaccuracy,'in%lin%locrad_highaccuracy',subname)

  
  ! Assign the localization radius to each atom.
  iiorb=0
  do iat=1,atoms%astruct%nat
      itype=atoms%astruct%iatype(iat)
      do iorb=1,in%lin%norbsPerType(itype)
          iiorb=iiorb+1
          in%lin%locrad(iiorb)=locradType(itype)
          in%lin%locrad_lowaccuracy(iiorb)=locradType_lowaccur(itype)
          in%lin%locrad_highaccuracy(iiorb)=locradType_highaccur(itype)
      end do
  end do
  

  call input_free((iproc == 0) .and. dump)

END SUBROUTINE lin_input_variables_new


!> Assign default values for TDDFT variables
subroutine tddft_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  in%tddft_approach='NONE'

END SUBROUTINE tddft_input_variables_default


subroutine tddft_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  !local variables
  logical :: exists
  !n(c) character(len=*), parameter :: subname='tddft_input_variables'

  !TD-DFT parameters
  call input_set_file(iproc,dump,trim(filename),exists,'TD-DFT Parameters')  
  if (exists) in%files = in%files + INPUTS_TDDFT
  !call the variable, its default value, the line ends if there is a comment

  call input_var(in%tddft_approach,"NONE",exclusive=(/'NONE','TDA '/),&
       comment="TDDFT Method")
  call input_free((iproc == 0) .and. dump)

END SUBROUTINE tddft_input_variables_new

subroutine kpt_input_variables_new(iproc,dump,filename,in,sym,geocode,alat)
  use module_base
  use module_types
  use defs_basis
  use m_ab6_kpoints
  use module_input
  use yaml_output
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  type(input_variables), intent(inout) :: in
  type(symmetry_data), intent(in) :: sym
  character(len = 1), intent(in) :: geocode
  real(gp), intent(in) :: alat(3)
  !local variables
  logical :: exists
  character(len=*), parameter :: subname='kpt_input_variables_new'
  character(len = 6) :: type
  integer :: i_stat,ierror,i,nshiftk, ngkpt(3), nseg, ikpt, j, i_all,ngranularity,ncount,ierror1
  real(gp) :: kptrlen, shiftk(3,8), norm, alat_(3)
  integer, allocatable :: iseg(:)

  ! Set default values.
  in%nkpt=1
  in%nkptv=0
  in%ngroups_kptv=1

  nullify(in%kpt,in%wkpt,in%kptv,in%nkptsv_group)
  call free_kpt_variables(in)

  !dft parameters, needed for the SCF part
  call input_set_file(iproc,dump,trim(filename),exists,'Brillouin Zone Sampling Parameters')  
  if (exists) in%files = in%files + INPUTS_KPT
  !call the variable, its default value, the line ends if there is a comment

  !if the file does not exists, put the default values
  if (.not. exists) then
     
!!$     ! Set only the gamma point.
!!$     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
!!$     call memocc(i_stat,in%kpt,'in%kpt',subname)
!!$     in%kpt(:, 1) = (/ 0., 0., 0. /)
!!$     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
!!$     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
!!$     in%wkpt(1) = 1.0_gp
     !return
  end if

  call input_var(type,'manual',exclusive=(/'auto  ','mpgrid','manual'/),&
       comment='K-point sampling method')

  if (case_insensitive_equiv(trim(type),'auto')) then
     call input_var(kptrlen,'0.0',ranges=(/0.0_gp,1.e4_gp/),&
          comment='Equivalent length of K-space resolution (Bohr)')
     if (geocode == 'F') then
        in%nkpt = 1
        allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%kpt,'in%kpt',subname)
        allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%wkpt,'in%wkpt',subname)
        in%kpt = 0.
        in%wkpt = 1.
     else
        call kpoints_get_auto_k_grid(sym%symObj, in%nkpt, in%kpt, in%wkpt, &
             & kptrlen, ierror)
        if (ierror /= AB6_NO_ERROR) then
           if (iproc==0) &
                & call yaml_warning("ERROR: cannot generate automatic k-point grid." // &
                & " Error code is " // trim(yaml_toa(ierror,fmt='(i0)')))
           stop
        end if
        !assumes that the allocation went through
        call memocc(0,in%kpt,'in%kpt',subname)
        call memocc(0,in%wkpt,'in%wkpt',subname)
     end if
  else if (case_insensitive_equiv(trim(type),'mpgrid')) then
     !take the points of Monckorst-pack grid
     call input_var(ngkpt(1),'1',ranges=(/1,10000/))
     call input_var(ngkpt(2),'1',ranges=(/1,10000/))
     call input_var(ngkpt(3),'1',ranges=(/1,10000/), &
          & comment='No. of Monkhorst-Pack grid points')
     if (geocode == 'S') ngkpt(2) = 1
     !shift
     call input_var(nshiftk,'1',ranges=(/1,8/),comment='No. of different shifts')
     !read the shifts
     shiftk=0.0_gp
     do i=1,nshiftk
        call input_var(shiftk(1,i),'0.')
        call input_var(shiftk(2,i),'0.')
        call input_var(shiftk(3,i),'0.',comment=' ')
     end do

     !control whether we are giving k-points to Free BC
     if (geocode == 'F') then
        if (iproc==0 .and. (maxval(ngkpt) > 1 .or. maxval(abs(shiftk)) > 0.)) &
             & call yaml_warning('Found input k-points with Free Boundary Conditions, reduce run to Gamma point')
        in%nkpt = 1
        allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%kpt,'in%kpt',subname)
        allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%wkpt,'in%wkpt',subname)
        in%kpt = 0.
        in%wkpt = 1.
     else
        call kpoints_get_mp_k_grid(sym%symObj, in%nkpt, in%kpt, in%wkpt, &
             & ngkpt, nshiftk, shiftk, ierror)
        if (ierror /= AB6_NO_ERROR) then
           if (iproc==0) &
                & call yaml_warning("ERROR: cannot generate MP k-point grid." // &
                & " Error code is " // trim(yaml_toa(ierror,fmt='(i0)')))
           stop
        end if
        !assumes that the allocation went through
        call memocc(0,in%kpt,'in%kpt',subname)
        call memocc(0,in%wkpt,'in%wkpt',subname)
     end if
  else if (case_insensitive_equiv(trim(type),'manual')) then
     call input_var(in%nkpt,'1',ranges=(/1,10000/),&
          comment='Number of K-points')
     if (geocode == 'F' .and. in%nkpt > 1) then
        if (iproc==0) call yaml_warning('Found input k-points with Free Boundary Conditions, reduce run to Gamma point')
        in%nkpt = 1
     end if
     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%kpt,'in%kpt',subname)
     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
     norm=0.0_gp
     do i=1,in%nkpt
        call input_var( in%kpt(1,i),'0.')
        if (geocode == 'S') then
           call input_var( in%kpt(2,i),'0.',ranges=(/0._gp,0._gp/))
        else
           call input_var( in%kpt(2,i),'0.')
        end if
        call input_var( in%kpt(3,i),'0.')
        call input_var( in%wkpt(i),'1.',comment='K-pt coords, K-pt weight')
        if (geocode == 'F') then
           in%kpt = 0.
           in%wkpt = 1.
        end if
        norm=norm+in%wkpt(i)
     end do
     ! We normalise the weights.
     in%wkpt(:)=in%wkpt/norm
  end if

  ! Now read the band structure definition. do it only if the file exists
  !nullify the kptv pointers
  nullify(in%kptv,in%nkptsv_group)
  if (exists .and. geocode /= 'F') then
     call input_var(type,'bands',exclusive=(/'bands'/),&
          comment='For doing band structure calculation',&
          input_iostat=ierror)
     if (ierror==0) then
        call input_var(nseg,'1',ranges=(/1,1000/),&
             comment='# of segments of the BZ path')
        allocate(iseg(nseg+ndebug),stat=i_stat)
        call memocc(i_stat,iseg,'iseg',subname)
        !number of points for each segment, parallel granularity
        do i=1,nseg
           call input_var(iseg(i),'1',ranges=(/1,1000/))
        end do
        call input_var(ngranularity,'1',ranges=(/1,1000/),&
             comment='points for each segment, # of points done for each group')
        !calculate the number of groups of for the band structure
        in%nkptv=1
        do i=1,nseg
           in%nkptv=in%nkptv+iseg(i)
        end do
        in%ngroups_kptv=&
             ceiling(real(in%nkptv,gp)/real(ngranularity,gp))
        
        allocate(in%nkptsv_group(in%ngroups_kptv+ndebug),stat=i_stat)
        call memocc(i_stat,in%nkptsv_group,'in%nkptsv_group',subname)
        
        ncount=0
        do i=1,in%ngroups_kptv-1
           !if ngranularity is bigger than nkptv  then ngroups is one
           in%nkptsv_group(i)=ngranularity 
           ncount=ncount+ngranularity
        end do
        !put the rest in the last group
        in%nkptsv_group(in%ngroups_kptv)=in%nkptv-ncount
        
        allocate(in%kptv(3,in%nkptv+ndebug),stat=i_stat)
        call memocc(i_stat,in%kptv,'in%kptv',subname)
        
        ikpt=1
        call input_var(in%kptv(1,ikpt),'0.')
        call input_var(in%kptv(2,ikpt),'0.')
        call input_var(in%kptv(3,ikpt),'0.',comment=' ')
        do i=1,nseg
           ikpt=ikpt+iseg(i)
           call input_var(in%kptv(1,ikpt),'0.5')
           call input_var(in%kptv(2,ikpt),'0.5')
           call input_var(in%kptv(3,ikpt),'0.5.',comment=' ')
           !interpolate the values
           do j=ikpt-iseg(i)+1,ikpt-1
              in%kptv(:,j)=in%kptv(:,ikpt-iseg(i)) + &
                   (in%kptv(:,ikpt)-in%kptv(:,ikpt-iseg(i))) * &
                   real(j-ikpt+iseg(i),gp)/real(iseg(i), gp)
           end do
        end do
        i_all=-product(shape(iseg))*kind(iseg)
        deallocate(iseg,stat=i_stat)
        call memocc(i_stat,i_all,'iseg',subname)
        
        !read an optional line to see if there is a file associated
        call input_var(in%band_structure_filename,' ',&
             comment=' ',input_iostat=ierror1)
        if (ierror1 /=0) then
           in%band_structure_filename=''
        else
           !since a file for the local potential is already given, do not perform ground state calculation
           if (iproc==0) then
              write(*,'(1x,a)')'Local Potential read from file, '//trim(in%band_structure_filename)//&
                   ', do not optimise GS wavefunctions'
           end if
           in%nrepmax=0
           in%itermax=0
           in%itrpmax=0
           in%inputPsiId=-1000 !allocate empty wavefunctions
           in%output_denspot=0
        end if
     end if
  end if
  
  !Dump the input file
  call input_free((iproc == 0) .and. dump)

  ! Convert reduced coordinates into BZ coordinates.
  alat_ = alat
  if (geocode /= 'P') alat_(2) = 1.0_gp
  if (geocode == 'F') then
     alat_(1)=1.0_gp
     alat_(3)=1.0_gp
  end if
  do i = 1, in%nkpt, 1
     in%kpt(:, i) = in%kpt(:, i) / alat_ * two_pi
  end do
  do i = 1, in%nkptv, 1
     in%kptv(:, i) = in%kptv(:, i) / alat_ * two_pi
  end do
 
end subroutine kpt_input_variables_new


!> Read the input variables needed for the k points generation
subroutine kpt_input_variables(iproc,filename,in,atoms)
  use module_base
  use module_types
  use defs_basis
  use m_ab6_kpoints
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(in) :: atoms
  !local variables
  logical :: exists
  character(len=*), parameter :: subname='kpt_input_variables'
  character(len = 6) :: type
  character(len=100) :: line
  integer :: i_stat,ierror,iline,i,nshiftk, ngkpt(3), nseg, ikpt, j, i_all,ngranularity,ncount
  real(gp) :: kptrlen, shiftk(3,8), norm, alat(3)
  integer, allocatable :: iseg(:)

  ! Set default values.
  in%nkpt = 1
  in%nkptv = 0
  in%ngroups_kptv=1

  inquire(file=trim(filename),exist=exists)

  if (.not. exists) then
     ! Set only the gamma point.
     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%kpt,'in%kpt',subname)
     in%kpt(:, 1) = (/ 0., 0., 0. /)
     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
     in%wkpt(1) = 1.
     return
  !and control whether we are giving k-points to Free BC
  else if (atoms%astruct%geocode == 'F') then
     if (iproc==0) write(*,*)&
          ' NONSENSE: Trying to use k-points with Free Boundary Conditions!'
     stop
  end if

  ! Real generation of k-point set.
  open(unit=1,file=filename,status='old')

  !line number, to control the input values
  iline=0

  read(1,*,iostat=ierror) type
  call check()
  
  if (trim(type) == "auto" .or. trim(type) == "Auto" .or. trim(type) == "AUTO") then
     read(1,*,iostat=ierror) kptrlen
     call check()
     call kpoints_get_auto_k_grid(atoms%astruct%sym%symObj, in%nkpt, in%kpt, in%wkpt, &
          & kptrlen, ierror)
     if (ierror /= AB6_NO_ERROR) then
        if (iproc==0) write(*,*) " ERROR in symmetry library. Error code is ", ierror
        stop
     end if
     ! in%kpt and in%wkpt will be allocated by ab6_symmetry routine.
     call memocc(0,in%kpt,'in%kpt',subname)
     call memocc(0,in%wkpt,'in%wkpt',subname)
  else if (trim(type) == "MPgrid" .or. trim(type) == "mpgrid") then
     read(1,*,iostat=ierror) ngkpt
     call check()
     read(1,*,iostat=ierror) nshiftk
     call check()
     do i = 1, min(nshiftk, 8), 1
        read(1,*,iostat=ierror) shiftk(:, i)
        call check()
     end do
     if (atoms%astruct%geocode == 'S') ngkpt(2) = 1
     if (atoms%astruct%geocode == 'F') ngkpt = 1
     call kpoints_get_mp_k_grid(atoms%astruct%sym%symObj, in%nkpt, in%kpt, in%wkpt, &
          & ngkpt, nshiftk, shiftk, ierror)
     if (ierror /= AB6_NO_ERROR) then
        if (iproc==0) write(*,*) " ERROR in symmetry library. Error code is ", ierror
        stop
     end if
     ! in%kpt and in%wkpt will be allocated by ab6_symmetry routine.
     call memocc(0,in%kpt,'in%kpt',subname)
     call memocc(0,in%wkpt,'in%wkpt',subname)
  else if (trim(type) == "manual" .or. trim(type) == "Manual") then
     read(1,*,iostat=ierror) in%nkpt
     call check()
     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%kpt,'in%kpt',subname)
     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
     norm=0.0_gp
     do i = 1, in%nkpt
        read(1,*,iostat=ierror) in%kpt(:, i), in%wkpt(i)
        norm=norm+in%wkpt(i)
        call check()
     end do
     
     ! We normalise the weights.
     in%wkpt(:) = in%wkpt / norm
  end if
  ! Now read the band structure definition.
  read(1,*,iostat=ierror) type
  if (ierror == 0 .and. (trim(type) == "bands" .or. trim(type) == "Bands" .or. &
       & trim(type) == "BANDS")) then
     read(1,*,iostat=ierror) nseg
     call check()
     allocate(iseg(nseg+ndebug),stat=i_stat)
     call memocc(i_stat,iseg,'iseg',subname)
     read(1,*,iostat=ierror) iseg, ngranularity
     call check()
     !calculate the number of groups of for the band structure
     in%nkptv=1
     do i=1,nseg
        in%nkptv=in%nkptv+iseg(i)
     end do
     in%ngroups_kptv=ceiling(real(in%nkptv,gp)/real(ngranularity,gp))

     allocate(in%nkptsv_group(in%ngroups_kptv+ndebug),stat=i_stat)
     call memocc(i_stat,in%nkptsv_group,'in%nkptsv_group',subname)
     ncount=0
     do i=1,in%ngroups_kptv-1
        in%nkptsv_group(i)=ngranularity !if ngranularity is bigger than nkptv  then ngroups is one
        ncount=ncount+ngranularity
     end do
     !put the rest in the last group
     in%nkptsv_group(in%ngroups_kptv)=in%nkptv-ncount

     allocate(in%kptv(3,in%nkptv+ndebug),stat=i_stat)
     call memocc(i_stat,in%kptv,'in%kptv',subname)
     ikpt = 1
     read(1,*,iostat=ierror) in%kptv(:, ikpt)
     call check()
     do i = 1, nseg
        ikpt = ikpt + iseg(i)
        read(1,*,iostat=ierror) in%kptv(:, ikpt)
        call check()
        do j = ikpt - iseg(i) + 1, ikpt - 1
           in%kptv(:, j) = in%kptv(:, ikpt - iseg(i)) + &
                & (in%kptv(:, ikpt) - in%kptv(:, ikpt - iseg(i))) * &
                & real(j - ikpt + iseg(i), gp) / real(iseg(i), gp)
        end do
     end do
     
     i_all=-product(shape(iseg))*kind(iseg)
     deallocate(iseg,stat=i_stat)
     call memocc(i_stat,i_all,'iseg',subname)

     !read an optional line to see if there is a file associated
     read(1,'(a100)',iostat=ierror)line
     if (ierror /=0) then
        !last line missing, put an empty line
        line=''
        in%band_structure_filename=''
     else
        read(line,*,iostat=ierror) in%band_structure_filename
        call check()
        !since a file for the local potential is already given, do not perform ground state calculation
        if (iproc==0) then
           write(*,'(1x,a)')'Local Potential read from file, '//trim(in%band_structure_filename)//&
                ', do not optimise GS wavefunctions'
        end if
        in%nrepmax=0
        in%itermax=0
        in%itrpmax=0
        in%inputPsiId=-1000 !allocate empty wavefunctions
        in%output_denspot=0
     end if
  end if
  close(unit=1,iostat=ierror)

  ! Convert reduced coordinates into BZ coordinates.
  alat = atoms%astruct%cell_dim
  if (atoms%astruct%geocode == 'S') alat(2) = 1.d0
  do i = 1, in%nkpt, 1
     in%kpt(:, i) = in%kpt(:, i) / alat * two_pi
  end do
  do i = 1, in%nkptv, 1
     in%kptv(:, i) = in%kptv(:, i) / alat * two_pi
  end do

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       !if (iproc == 0) 
            write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE kpt_input_variables


!> Read the input variables which can be used for performances
subroutine perf_input_variables(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  use yaml_strings
  use yaml_output
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  type(input_variables), intent(inout) :: in
  !local variables
  !n(c) character(len=*), parameter :: subname='perf_input_variables'
  logical :: exists
  integer :: ierr,blocks(2),ipos,i,iproc_node,nproc_node

  call input_set_file(iproc, dump, filename, exists,'Performance Options')
  if (exists) in%files = in%files + INPUTS_PERF
  !Use Linear scaling methods
  in%linear=INPUT_IG_OFF

  in%matacc=material_acceleration_null()

  call input_var("debug", .false., "Debug option", in%debug)
  call input_var("fftcache", 8*1024, "Cache size for the FFT", in%ncache_fft)
  call input_var("accel", 7, "NO     ", &
       (/ "NO     ", "CUDAGPU", "OCLGPU ", "OCLCPU ", "OCLACC " /), &
       & "Acceleration", in%matacc%iacceleration)

  !determine desired OCL platform which is used for acceleration
  call input_var("OCL_platform",repeat(' ',len(in%matacc%OCL_platform)), &
       & "Chosen OCL platform", in%matacc%OCL_platform)
  ipos=min(len(in%matacc%OCL_platform),len(trim(in%matacc%OCL_platform))+1)
  do i=ipos,len(in%matacc%OCL_platform)
     in%matacc%OCL_platform(i:i)=achar(0)
  end do
  call input_var("OCL_devices",repeat(' ',len(in%matacc%OCL_devices)), &
       & "Chosen OCL devices", in%matacc%OCL_devices)
  ipos=min(len(in%matacc%OCL_devices),len(trim(in%matacc%OCL_devices))+1)
  do i=ipos,len(in%matacc%OCL_devices)
     in%matacc%OCL_devices(i:i)=achar(0)
  end do

  !!@TODO to relocate
  call input_var("blas", .false., "CUBLAS acceleration", GPUblas)
  call input_var("projrad", 15.0d0, &
       & "Radius of the projector as a function of the maxrad", in%projrad)
  call input_var("exctxpar", "OP2P", &
       & "Exact exchange parallelisation scheme", in%exctxpar)
  call input_var("ig_diag", .true., &
       & "Input guess: (T:Direct, F:Iterative) diag. of Ham.", &
       & in%orthpar%directDiag)
  call input_var("ig_norbp", 5, &
       & "Input guess: Orbitals per process for iterative diag.", &
       & in%orthpar%norbpInguess)
  call input_var("ig_blocks", (/ 300, 800 /), &
       & "Input guess: Block sizes for orthonormalisation", blocks)
  call input_var("ig_tol", 1d-4, &
       & "Input guess: Tolerance criterion", in%orthpar%iguessTol)
  call input_var("methortho", 0, (/ 0, 1, 2 /), &
       & "Orthogonalisation (0=Cholesky,1=GS/Chol,2=Loewdin)", in%orthpar%methOrtho)
  call input_var("rho_commun", "DEF","Density communication scheme (DBL, RSC, MIX)",&
       in%rho_commun)
  call input_var("psolver_groupsize",0, "Size of Poisson Solver taskgroups (0=nproc)", in%PSolver_groupsize)
  call input_var("psolver_accel",0, "Acceleration of the Poisson Solver (0=none, 1=CUDA)", in%matacc%PSolver_igpu)
  call input_var("unblock_comms", "OFF", "Overlap Communications of fields (OFF,DEN,POT)",&
       in%unblock_comms)
  call input_var("linear", 3, 'OFF', (/ "OFF", "LIG", "FUL", "TMO" /), &
       & "Linear Input Guess approach",in%linear)
  call input_var("tolsym", 1d-8, "Tolerance for symmetry detection",in%symTol)
  call input_var("signaling", .false., "Expose calculation results on Network",in%signaling)
  call input_var("signalTimeout", 0, "Time out on startup for signal connection",in%signalTimeout)  
  call input_var("domain", "", "Domain to add to the hostname to find the IP", in%domain)
  call input_var("inguess_geopt", 0,(/0,1/),"0= wavlet input guess, 1= real space input guess",in%inguess_geopt)
  !verbosity of the output
  call input_var("verbosity", 2,(/0,1,2,3/), &
     & "verbosity of the output 0=low, 2=high",in%verbosity)
  in%writing_directory=repeat(' ',len(in%writing_directory))
  call input_var("outdir", ".","Writing directory", in%writing_directory)

  !If false, apply the projectors in the once-and-for-all scheme, otherwise on-the-fly
  call input_var("psp_onfly", .true., &
       & "Calculate pseudopotential projectors on the fly",DistProjApply)
 
  !block size for pdsyev/pdsygv, pdgemm (negative -> sequential)
  call input_var("pdsyev_blocksize",-8,"SCALAPACK linear scaling blocksize",in%lin%blocksize_pdsyev) !ranges=(/-100,1000/)
  call input_var("pdgemm_blocksize",-8,"SCALAPACK linear scaling blocksize",in%lin%blocksize_pdgemm) !ranges=(/-100,1000/)
  
  !max number of process uses for pdsyev/pdsygv, pdgemm
  call input_var("maxproc_pdsyev",4,"SCALAPACK linear scaling max num procs",in%lin%nproc_pdsyev) !ranges=(/1,100000/)
  call input_var("maxproc_pdgemm",4,"SCALAPACK linear scaling max num procs",in%lin%nproc_pdgemm) !ranges=(/1,100000/)

  !FOE: if the determinant of the interpolation matrix to find the Fermi energy
  !is smaller than this value, switch from cubic to linear interpolation.
  call input_var("ef_interpol_det",1.d-20,"FOE: max determinant of cubic interpolation matrix",&
       in%lin%ef_interpol_det)
  call input_var("ef_interpol_chargediff",10.d0,"FOE: max charge difference for interpolation",&
       in%lin%ef_interpol_chargediff)

  !determines whether a mixing step shall be preformed after the input guess !(linear version)
  call input_var("mixing_after_inputguess",.true.,"mixing step after linear input guess (T/F)",&
       in%lin%mixing_after_inputguess)

  !determines whether the input guess support functions are orthogonalized iteratively (T) or in the standard way (F)
  call input_var("iterative_orthogonalization",.false.,"iterative_orthogonalization for input guess orbitals",&
       in%lin%iterative_orthogonalization)

!  call input_var("mpi_groupsize",0, "number of MPI processes for BigDFT run (0=nproc)", in%mpi_groupsize)
  if (in%verbosity == 0 ) then
     call f_malloc_set_status(output_level=0)
     !call memocc_set_state(0)
  end if

  !here the logfile should be opened in the usual way, differentiating between 
  ! logfiles in case of multiple taskgroups
  if (trim(in%writing_directory) /= '.' .or. bigdft_mpi%ngroup > 1) then
     call create_log_file(iproc,in)
  else
     !use stdout, do not crash if unit is present
     if (iproc==0) call yaml_set_stream(record_length=92,istat=ierr)
  end if
  !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
  if (iproc==0) then
     !start writing on logfile
     call yaml_new_document()
     !welcome screen
     if (dump) call print_logo()
  end if
  if (bigdft_mpi%nproc >1) call processor_id_per_node(bigdft_mpi%iproc,bigdft_mpi%nproc,iproc_node,nproc_node)
  if (iproc ==0 .and. dump) then
     if (bigdft_mpi%nproc >1) call yaml_map('MPI tasks of root process node',nproc_node)
     call print_configure_options()
  end if
  !call input_free((iproc == 0) .and. dump)

  call input_free(iproc==0)

  !Block size used for the orthonormalization
  in%orthpar%bsLow = blocks(1)
  in%orthpar%bsUp  = blocks(2)
  
  ! Set performance variables
  if (.not. in%debug) then
     call f_malloc_set_status(output_level=1)
     !call memocc_set_state(1)
  end if
  call set_cache_size(in%ncache_fft)

  !Check after collecting all values
  if(.not.in%orthpar%directDiag .or. in%orthpar%methOrtho==1) then 
     write(*,'(1x,a)') 'Input Guess: Block size used for the orthonormalization (ig_blocks)'
     if(in%orthpar%bsLow==in%orthpar%bsUp) then
        write(*,'(5x,a,i0)') 'Take block size specified by user: ',in%orthpar%bsLow
     else if(in%orthpar%bsLow<in%orthpar%bsUp) then
        write(*,'(5x,2(a,i0))') 'Choose block size automatically between ',in%orthpar%bsLow,' and ',in%orthpar%bsUp
     else
        write(*,'(1x,a)') "ERROR: invalid values of inputs%bsLow and inputs%bsUp. Change them in 'inputs.perf'!"
        call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
     end if
     write(*,'(5x,a)') 'This values will be adjusted if it is larger than the number of orbitals.'
  end if
END SUBROUTINE perf_input_variables

!> Read fragment input parameters
subroutine fragment_input_variables(iproc,dump,filename,in,atoms)
  use module_base
  use module_types
  use module_input
  implicit none
  integer, intent(in) :: iproc
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(inout) :: atoms
  logical, intent(in) :: dump
  !local variables
  logical :: exists
  character(len=*), parameter :: subname='fragment_input_variables'
  character(len=256) :: comments
  character(len=20):: atomname
  integer :: ifrag, frag_num, ios, ierr, istat

  !Linear input parameters
  call input_set_file(iproc,dump,trim(filename),exists,'Fragment Parameters')  
  if (exists) in%files = in%files + INPUTS_FRAG

  if (.not. exists .and. in%lin%fragment_calculation) then ! we should be doing a fragment calculation, so this is a problem
     write(*,'(1x,a)',advance='no') "ERROR: the file 'input.frag' is missing and fragment calculation was specified"
     call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
     stop
  end if

  ! number of reference fragments
  comments='# number of fragments in reference system, number of fragments in current system'
  call input_var(in%frag%nfrag_ref,'1',ranges=(/1,100000/))
  call input_var(in%frag%nfrag,'1',ranges=(/1,100000/),comment=comments)
  
  ! Allocate fragment pointers
  call nullifyInputFragParameters(in%frag)
  call allocateInputFragArrays(in%frag)

  !comments = '# reference fragment number i, number of atoms in reference fragment i, '//&
  !           'number of atoms in corresponding environment'
  !do ifrag=1,in%frag%nfrag_ref
  !  call input_var(frag_num,'1',ranges=(/1,in%frag%nfrag_ref/))
  !  if (frag_num/=ifrag) then
  !      write(*,'(1x,a)',advance='no') "ERROR: the file 'input.frag' has an error when specifying&
  !           & the reference fragments"
  !     call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
  !     stop
  !  end if
  !  call input_var(in%frag%frag_info(frag_num,1),'1',ranges=(/1,100000/))
  !  call input_var(in%frag%frag_info(frag_num,2),'0',ranges=(/0,100000/),comment=comments)
  !end do

  ! ADD A SENSIBLE DEFAULT AND ALLOW FOR USER NOT TO SPECIFY FRAGMENT NAMES
  comments = '#  reference fragment number i, fragment label'
  do ifrag=1,in%frag%nfrag_ref
    call input_var(frag_num,'1',ranges=(/1,in%frag%nfrag_ref/))
    if (frag_num/=ifrag) then
        write(*,'(1x,a)',advance='no') "ERROR: the file 'input.frag' has an error when specifying&
             & the reference fragments"
       call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
       stop
    end if
    call input_var(in%frag%label(frag_num),' ',comment=comments)
    in%frag%label(frag_num)=trim(in%frag%label(frag_num))
    ! keep dirname blank if this isn't a fragment calculation
    if (len(trim(in%frag%label(frag_num)))>1) then
       in%frag%dirname(frag_num)='data-'//trim(in%frag%label(frag_num))//'/'
    else
       in%frag%dirname(frag_num)=''
    end if
  end do

  comments = '# fragment number j, reference fragment i this corresponds to'
  do ifrag=1,in%frag%nfrag
    call input_var(frag_num,'1',ranges=(/1,in%frag%nfrag/))
    if (frag_num/=ifrag) then
        write(*,'(1x,a)',advance='no') "ERROR: the file 'input.frag' has an error when specifying&
             & the system fragments"
       call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
       stop
    end if
    call input_var(in%frag%frag_index(frag_num),'1',ranges=(/0,100000/),comment=comments)
  end do

  call input_free((iproc == 0) .and. dump)

END SUBROUTINE fragment_input_variables

  subroutine allocateInputFragArrays(input_frag)
    use module_types
    implicit none
  
    ! Calling arguments
    type(fragmentInputParameters),intent(inout) :: input_frag
  
    ! Local variables
    integer :: i_stat
    character(len=*),parameter :: subname='allocateInputFragArrays'
 
    allocate(input_frag%frag_index(input_frag%nfrag), stat=i_stat)
    call memocc(i_stat, input_frag%frag_index, 'input_frag%frag_index', subname)

    !allocate(input_frag%frag_info(input_frag%nfrag_ref,2), stat=i_stat)
    !call memocc(i_stat, input_frag%frag_info, 'input_frag%frag_info', subname)

    allocate(input_frag%label(input_frag%nfrag_ref), stat=i_stat)
    call memocc(i_stat, input_frag%label, 'input_frag%label', subname)

    allocate(input_frag%dirname(input_frag%nfrag_ref), stat=i_stat)
    call memocc(i_stat, input_frag%dirname, 'input_frag%dirname', subname)

  end subroutine allocateInputFragArrays

  subroutine deallocateInputFragArrays(input_frag)
    use module_types
    implicit none
  
    ! Calling arguments
    type(fragmentInputParameters),intent(inout) :: input_frag
  
    ! Local variables
    integer :: i_stat,i_all
    character(len=*),parameter :: subname='deallocateInputFragArrays'
 
    !if(associated(input_frag%frag_info)) then
    !  i_all = -product(shape(input_frag%frag_info))*kind(input_frag%frag_info)
    !  deallocate(input_frag%frag_info,stat=i_stat)
    !  call memocc(i_stat,i_all,'input_frag%frag_info',subname)
    !  nullify(input_frag%frag_info)
    !end if 
 
    if(associated(input_frag%frag_index)) then
      i_all = -product(shape(input_frag%frag_index))*kind(input_frag%frag_index)
      deallocate(input_frag%frag_index,stat=i_stat)
      call memocc(i_stat,i_all,'input_frag%frag_index',subname)
      nullify(input_frag%frag_index)
    end if 

    if(associated(input_frag%label)) then
      i_all = -product(shape(input_frag%label))*kind(input_frag%label)
      deallocate(input_frag%label,stat=i_stat)
      call memocc(i_stat,i_all,'input_frag%label',subname)
      nullify(input_frag%label)
    end if 

    if(associated(input_frag%dirname)) then
      i_all = -product(shape(input_frag%dirname))*kind(input_frag%dirname)
      deallocate(input_frag%dirname,stat=i_stat)
      call memocc(i_stat,i_all,'input_frag%dirname',subname)
      nullify(input_frag%dirname)
    end if 

  end subroutine deallocateInputFragArrays


  subroutine nullifyInputFragParameters(input_frag)
    use module_types
    implicit none

    ! Calling arguments
    type(fragmentInputParameters),intent(inout) :: input_frag

    nullify(input_frag%frag_index)
    !nullify(input_frag%frag_info)
    nullify(input_frag%label)
    nullify(input_frag%dirname)

  end subroutine nullifyInputFragParameters


subroutine create_log_file(iproc,inputs)

  use module_base
  use module_types
  use module_input
  use yaml_strings
  use yaml_output

  implicit none
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: inputs
  !local variables
  integer :: ierr,ierror,lgt
  logical :: exists
  character(len=500) :: logfile,logfile_old,logfile_dir

  logfile=repeat(' ',len(logfile))
  logfile_old=repeat(' ',len(logfile_old))
  logfile_dir=repeat(' ',len(logfile_dir))
  !open the logfile if needed, and set stdout
  !if (trim(in%writing_directory) /= '.') then
  if (.true.) then
     !add the output directory in the directory name
     if (iproc == 0 .and. trim(inputs%writing_directory) /= '.') then
        call getdir(inputs%writing_directory,&
             len_trim(inputs%writing_directory),logfile,len(logfile),ierr)
        if (ierr /= 0) then
           write(*,*) "ERROR: cannot create writing directory '"&
                //trim(inputs%writing_directory) // "'."
           call MPI_ABORT(bigdft_mpi%mpi_comm,ierror,ierr)
        end if
     end if
     call MPI_BCAST(logfile,len(logfile),MPI_CHARACTER,0,bigdft_mpi%mpi_comm,ierr)
     lgt=min(len(inputs%writing_directory),len(logfile))
     inputs%writing_directory(1:lgt)=logfile(1:lgt)
     lgt=0
     call buffer_string(inputs%dir_output,len(inputs%dir_output),&
          trim(logfile),lgt,back=.true.)
     if (iproc ==0) then
        logfile=repeat(' ',len(logfile))
        if (len_trim(inputs%run_name) >0) then
!           logfile='log-'//trim(inputs%run_name)//trim(bigdft_run_id_toa())//'.yaml'
           logfile='log-'//trim(inputs%run_name)//'.yaml'
        else
           logfile='log'//trim(bigdft_run_id_toa())//'.yaml'
        end if
        !inquire for the existence of a logfile
        call yaml_map('<BigDFT> log of the run will be written in logfile',&
             trim(inputs%writing_directory)//trim(logfile),unit=6)
        inquire(file=trim(inputs%writing_directory)//trim(logfile),exist=exists)
        if (exists) then
           logfile_old=trim(inputs%writing_directory)//'logfiles'
           call getdir(logfile_old,&
                len_trim(logfile_old),logfile_dir,len(logfile_dir),ierr)
           if (ierr /= 0) then
              write(*,*) "ERROR: cannot create writing directory '" //trim(logfile_dir) // "'."
              call MPI_ABORT(bigdft_mpi%mpi_comm,ierror,ierr)
           end if
           logfile_old=trim(logfile_dir)//trim(logfile)
           logfile=trim(inputs%writing_directory)//trim(logfile)
           !change the name of the existing logfile
           lgt=index(logfile_old,'.yaml')
           call buffer_string(logfile_old,len(logfile_old),&
                trim(adjustl(yaml_time_toa()))//'.yaml',lgt)
           call movefile(trim(logfile),len_trim(logfile),trim(logfile_old),len_trim(logfile_old),ierr)
           if (ierr /= 0) then
              write(*,*) "ERROR: cannot move logfile '"//trim(logfile)
              write(*,*) '                      into '//trim(logfile_old)// "'."
              call MPI_ABORT(bigdft_mpi%mpi_comm,ierror,ierr)
           end if
           call yaml_map('<BigDFT> Logfile existing, renamed into',&
                trim(logfile_old),unit=6)

        else
           logfile=trim(inputs%writing_directory)//trim(logfile)
        end if
        !Create stream and logfile
        call yaml_set_stream(unit=70,filename=trim(logfile),record_length=92,istat=ierr)
        !create that only if the stream is not already present, otherwise print a warning
        if (ierr == 0) then
           call input_set_stdout(unit=70)
           call f_malloc_set_status(unit=70,logfile_name=trim(inputs%dir_output)//'malloc.prc')
           !call memocc_set_stdout(unit=70)
        else
           call yaml_warning('Logfile '//trim(logfile)//' cannot be created, stream already present. Ignoring...')
        end if
     end if
  else
     !use stdout, do not crash if unit is present
     if (iproc==0) call yaml_set_stream(record_length=92,istat=ierr)
  end if
    
END SUBROUTINE create_log_file


!>  Free all dynamically allocated memory from the kpt input file.
subroutine free_kpt_variables(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_kpt_variables'
  integer :: i_stat, i_all
  if (associated(in%kpt)) then
     i_all=-product(shape(in%kpt))*kind(in%kpt)
     deallocate(in%kpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%kpt',subname)
  end if
  if (associated(in%wkpt)) then
     i_all=-product(shape(in%wkpt))*kind(in%wkpt)
     deallocate(in%wkpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%wkpt',subname)
  end if
  if (associated(in%kptv)) then
     i_all=-product(shape(in%kptv))*kind(in%kptv)
     deallocate(in%kptv,stat=i_stat)
     call memocc(i_stat,i_all,'in%kptv',subname)
  end if
  if (associated(in%nkptsv_group)) then
     i_all=-product(shape(in%nkptsv_group))*kind(in%nkptsv_group)
     deallocate(in%nkptsv_group,stat=i_stat)
     call memocc(i_stat,i_all,'in%nkptsv_group',subname)
  end if
  nullify(in%kpt)
  nullify(in%wkpt)
  nullify(in%kptv)
  nullify(in%nkptsv_group)
end subroutine free_kpt_variables

!>  Free all dynamically allocated memory from the input variable structure.
subroutine free_input_variables(in)
  use module_base
  use module_types
  use module_xc
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_input_variables'
  integer :: i_stat, i_all

  if(in%linear /= INPUT_IG_OFF .and. in%linear /= INPUT_IG_LIG) &
       & call deallocateBasicArraysInput(in%lin)


  if (associated(in%qmass)) then
     i_all=-product(shape(in%qmass))*kind(in%qmass)
     deallocate(in%qmass,stat=i_stat)
     call memocc(i_stat,i_all,'in%qmass',subname)
  end if
  call free_kpt_variables(in)
  call deallocateBasicArraysInput(in%lin)
  call deallocateInputFragArrays(in%frag)

  ! Free the libXC stuff if necessary, related to the choice of in%ixc.
  call xc_end()

!!$  if (associated(in%Gabs_coeffs) ) then
!!$     i_all=-product(shape(in%Gabs_coeffs))*kind(in%Gabs_coeffs)
!!$     deallocate(in%Gabs_coeffs,stat=i_stat)
!!$     call memocc(i_stat,i_all,'in%Gabs_coeffs',subname)
!!$  end if

  ! Stop the signaling stuff.
  !Destroy C wrappers on Fortran objects,
  ! and stop the GMainLoop.
  if (in%gmainloop /= 0.d0) then
     call bigdft_signals_free(in%gmainloop)
  end if
END SUBROUTINE free_input_variables


!> Assign default values for ABSCALC variables
subroutine abscalc_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(out) :: in

  in%c_absorbtion=.false.
  in%potshortcut=0
  in%iat_absorber=0
  in%abscalc_bottomshift=0
  in%abscalc_S_do_cg=.false.
  in%abscalc_Sinv_do_cg=.false.
END SUBROUTINE abscalc_input_variables_default


!> Read the input variables needed for the ABSCALC
!! Every argument should be considered as mandatory
subroutine abscalc_input_variables(iproc,filename,in)
  use module_base
  use module_types
  implicit none
  !Arguments
  type(input_variables), intent(inout) :: in
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  !Local variables
  integer, parameter :: iunit = 112
  integer :: ierror,iline, i

  character(len=*), parameter :: subname='abscalc_input_variables'
  integer :: i_stat

  ! Read the input variables.
  open(unit=iunit,file=filename,status='old')

  !line number, to control the input values
  iline=0

  !x-absorber treatment (in progress)

  read(iunit,*,iostat=ierror) in%iabscalc_type
  call check()


  read(iunit,*,iostat=ierror)  in%iat_absorber
  call check()
  read(iunit,*,iostat=ierror)  in%L_absorber
  call check()

  allocate(in%Gabs_coeffs(2*in%L_absorber +1+ndebug),stat=i_stat)
  call memocc(i_stat,in%Gabs_coeffs,'Gabs_coeffs',subname)

  read(iunit,*,iostat=ierror)  (in%Gabs_coeffs(i), i=1,2*in%L_absorber +1 )
  call check()

  read(iunit,*,iostat=ierror)  in%potshortcut
  call check()
  
  read(iunit,*,iostat=ierror)  in%nsteps
  call check()

  if( iand( in%potshortcut,4)>0) then
     read(iunit,'(a100)',iostat=ierror) in%extraOrbital
  end if
  
  read(iunit,*,iostat=ierror) in%abscalc_bottomshift
  if(ierror==0) then
  else
     in%abscalc_bottomshift=0
  endif

 

  read(iunit, '(a100)' ,iostat=ierror) in%xabs_res_prefix
  if(ierror==0) then
  else
     in%xabs_res_prefix=""
  endif


  read(iunit,*,iostat=ierror) in%abscalc_alterpot, in%abscalc_eqdiff 
  !!, &
  !!     in%abscalc_S_do_cg ,in%abscalc_Sinv_do_cg
  if(ierror==0) then
  else
     in%abscalc_alterpot=.false.
     in%abscalc_eqdiff =.false.
  endif



  in%c_absorbtion=.true.

  close(unit=iunit)

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       if (iproc == 0) write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE abscalc_input_variables


!> Assign default values for frequencies variables
!!    freq_alpha: frequencies step for finite difference = alpha*hx, alpha*hy, alpha*hz
!!    freq_order; order of the finite difference (2 or 3 i.e. 2 or 4 points)
!!    freq_method: 1 - systematic moves of atoms over each direction
subroutine frequencies_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(out) :: in

  in%freq_alpha=1.d0/real(64,kind(1.d0))
  in%freq_order=2
  in%freq_method=1

END SUBROUTINE frequencies_input_variables_default


!> Read the input variables needed for the frequencies calculation.
!! Every argument should be considered as mandatory.
subroutine frequencies_input_variables_new(iproc,dump,filename,in)
  use module_base
  use module_types
  use module_input
  implicit none
  !Arguments
  type(input_variables), intent(inout) :: in
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  logical, intent(in) :: dump
  !Local variables
  logical :: exists
  !n(c) integer, parameter :: iunit=111

  !Frequencies parameters
  call input_set_file(iproc,dump,trim(filename),exists,'Frequencies Parameters')  
  if (exists) in%files = in%files + INPUTS_FREQ
  !call the variable, its default value, the line ends if there is a comment

  !Read in%freq_alpha (possible 1/64)
  call input_var(in%freq_alpha,'1/64',ranges=(/0.0_gp,1.0_gp/),&
       comment="Step size factor (alpha*hgrid)")
  !Read the order of finite difference scheme

  call input_var(in%freq_order,'2',exclusive=(/-1,1,2,3/),&
       comment="Order of the difference scheme")
  !Read the index of the method

  call input_var(in%freq_method,'1',exclusive=(/1/),&
       comment="Method used (only possible value=1)")
  call input_free((iproc == 0) .and. dump)

END SUBROUTINE frequencies_input_variables_new


!> Fill the arrays occup and spinsgn
!! if iunit /=0 this means that the file 'input.occ' does exist and it opens
subroutine occupation_input_variables(verb,iunit,nelec,norb,norbu,norbuempty,norbdempty,nspin,occup,spinsgn)
  use module_base
  use module_input
  use yaml_output
  implicit none
  ! Arguments
  logical, intent(in) :: verb
  integer, intent(in) :: nelec,nspin,norb,norbu,iunit,norbuempty,norbdempty
  real(gp), dimension(norb), intent(out) :: occup,spinsgn
  ! Local variables
  integer :: iorb,nt,ne,it,ierror,iorb1,i
  real(gp) :: rocc
  character(len=20) :: string
  character(len=100) :: line

  do iorb=1,norb
     spinsgn(iorb)=1.0_gp
  end do
  if (nspin/=1) then
     do iorb=1,norbu
        spinsgn(iorb)=1.0_gp
     end do
     do iorb=norbu+1,norb
        spinsgn(iorb)=-1.0_gp
     end do
  end if
  ! write(*,'(1x,a,5i4,30f6.2)')'Spins: ',norb,norbu,norbd,norbup,norbdp,(spinsgn(iorb),iorb=1,norb)

  ! First fill the occupation numbers by default
  nt=0
  if (nspin==1) then
     ne=(nelec+1)/2
     do iorb=1,ne
        it=min(2,nelec-nt)
        occup(iorb)=real(it,gp)
        nt=nt+it
     enddo
     do iorb=ne+1,norb
        occup(iorb)=0._gp
     end do
  else
     if (norbuempty+norbdempty == 0) then
        if (norb > nelec) then
           do iorb=1,min(norbu,norb/2+1)
              it=min(1,nelec-nt)
              occup(iorb)=real(it,gp)
              nt=nt+it
           enddo
           do iorb=min(norbu,norb/2+1)+1,norbu
              occup(iorb)=0.0_gp
           end do
           do iorb=norbu+1,norbu+min(norb-norbu,norb/2+1)
              it=min(1,nelec-nt)
              occup(iorb)=real(it,gp)
              nt=nt+it
           enddo
           do iorb=norbu+min(norb-norbu,norb/2+1)+1,norb
              occup(iorb)=0.0_gp
           end do
        else
           do iorb=1,norb
              occup(iorb)=1.0_gp
           end do
        end if
     else
        do iorb=1,norbu-norbuempty
           occup(iorb)=1.0_gp
        end do
        do iorb=norbu-norbuempty+1,norbu
           occup(iorb)=0.0_gp
        end do
        do iorb=1,norb-norbu-norbdempty
           occup(norbu+iorb)=1.0_gp
        end do
        do iorb=norb-norbu-norbdempty+1,norb-norbu
           occup(norbu+iorb)=0.0_gp
        end do
     end if
  end if
  ! Then read the file "input.occ" if does exist
  if (iunit /= 0) then
     nt=0
     do
        read(unit=iunit,fmt='(a100)',iostat=ierror) line
        if (ierror /= 0) then
           exit
        end if
        !Transform the line in case there are slashes (to ease the parsing)
        do i=1,len(line)
           if (line(i:i) == '/') then
              line(i:i) = ':'
           end if
        end do
        read(line,*,iostat=ierror) iorb,string
        call read_fraction_string(string,rocc,ierror) 
        if (ierror /= 0) then
           exit
        end if

        if (ierror/=0) then
           exit
        else
           nt=nt+1
           if (iorb<0 .or. iorb>norb) then
              !if (iproc==0) then
              write(*,'(1x,a,i0,a)') 'ERROR in line ',nt+1,' of the file "[name].occ"'
              write(*,'(10x,a,i0,a)') 'The orbital index ',iorb,' is incorrect'
              !end if
              stop
           elseif (rocc<0._gp .or. rocc>2._gp) then
              !if (iproc==0) then
              write(*,'(1x,a,i0,a)') 'ERROR in line ',nt+1,' of the file "[name].occ"'
              write(*,'(10x,a,f5.2,a)') 'The occupation number ',rocc,' is not between 0. and 2.'
              !end if
              stop
           else
              occup(iorb)=rocc
           end if
        end if
     end do
     if (verb) then
        call yaml_comment('('//adjustl(trim(yaml_toa(nt)))//'lines read)')
        !write(*,'(1x,a,i0,a)') &
        !     'The occupation numbers are read from the file "[name].occ" (',nt,' lines read)'
     end if
     close(unit=iunit)

     if (nspin/=1) then
!!!        !Check if the polarisation is respected (mpol)
!!!        rup=sum(occup(1:norbu))
!!!        rdown=sum(occup(norbu+1:norb))
!!!        if (abs(rup-rdown-real(norbu-norbd,gp))>1.e-6_gp) then
!!!           if (iproc==0) then
!!!              write(*,'(1x,a,f13.6,a,i0)') 'From the file "input.occ", the polarization ',rup-rdown,&
!!!                             ' is not equal to ',norbu-norbd
!!!           end if
!!!           stop
!!!        end if
        !Fill spinsgn
        do iorb=1,norbu
           spinsgn(iorb)=1.0_gp
        end do
        do iorb=norbu+1,norb
           spinsgn(iorb)=-1.0_gp
        end do
     end if
  end if
  if (verb) then 
     call yaml_sequence(advance='no')
     call yaml_open_map('Occupation Numbers',flow=.true.)
     !write(*,'(1x,a,t28,i8)') 'Total Number of Orbitals',norb
     iorb1=1
     rocc=occup(1)
     do iorb=1,norb
        if (occup(iorb) /= rocc) then
           if (iorb1 == iorb-1) then
              call yaml_map('Orbital No.'//trim(yaml_toa(iorb1)),rocc,fmt='(f6.4)')
              !write(*,'(1x,a,i0,a,f6.4)') 'occup(',iorb1,')= ',rocc
           else
           call yaml_map('Orbitals No.'//trim(yaml_toa(iorb1))//'-'//&
                adjustl(trim(yaml_toa(iorb-1))),rocc,fmt='(f6.4)')
           !write(*,'(1x,a,i0,a,i0,a,f6.4)') 'occup(',iorb1,':',iorb-1,')= ',rocc
           end if
           rocc=occup(iorb)
           iorb1=iorb
        end if
     enddo
     if (iorb1 == norb) then
        call yaml_map('Orbital No.'//trim(yaml_toa(norb)),occup(norb),fmt='(f6.4)')
        !write(*,'(1x,a,i0,a,f6.4)') 'occup(',norb,')= ',occup(norb)
     else
        call yaml_map('Orbitals No.'//trim(yaml_toa(iorb1))//'-'//&
             adjustl(trim(yaml_toa(norb))),occup(norb),fmt='(f6.4)')
        !write(*,'(1x,a,i0,a,i0,a,f6.4)') 'occup(',iorb1,':',norb,')= ',occup(norb)
     end if
     call yaml_close_map()
  endif

  !Check if sum(occup)=nelec
  rocc=sum(occup)
  if (abs(rocc-real(nelec,gp))>1.e-6_gp) then
     call yaml_warning('ERROR in determining the occupation numbers: the total number of electrons ' &
        & // trim(yaml_toa(rocc,fmt='(f13.6)')) // ' is not equal to' // trim(yaml_toa(nelec)))
     !if (iproc==0) then
     !write(*,'(1x,a,f13.6,a,i0)') 'ERROR in determining the occupation numbers: the total number of electrons ',rocc,&
     !     ' is not equal to ',nelec
     !end if
     stop
  end if

END SUBROUTINE occupation_input_variables


module position_files
   implicit none
   contains
   subroutine directGetLine(line, ifile, eof)
      !Arguments
      integer, intent(in) :: ifile
      character(len=150), intent(out) :: line
      logical, intent(out) :: eof
      !Local variables
      integer :: i_stat

      eof = .false.
      read(ifile,'(a150)', iostat = i_stat) line
      if (i_stat /= 0) eof = .true.
   END SUBROUTINE directGetLine

   subroutine archiveGetLine(line, ifile, eof)
      !Arguments
      integer, intent(in) :: ifile
      character(len=150), intent(out) :: line
      logical, intent(out) :: eof
      !Local variables
      integer :: i_stat
      !The argument ifile is not used but it is used as argument routine
      !eof = .false.
      eof = (ifile /= ifile)
      call extractNextLine(line, i_stat)
      if (i_stat /= 0) eof = .true.
   END SUBROUTINE archiveGetLine
end module position_files

!> Read atomic file
subroutine read_atomic_file(file,iproc,astruct,status,comment,energy,fxyz)
   use module_base
   use module_types
   use module_interfaces, except_this_one => read_atomic_file
   use m_ab6_symmetry
   use position_files
   implicit none
   character(len=*), intent(in) :: file
   integer, intent(in) :: iproc
   type(atomic_structure), intent(inout) :: astruct
   integer, intent(out), optional :: status
   real(gp), intent(out), optional :: energy
   real(gp), dimension(:,:), pointer, optional :: fxyz
   character(len = *), intent(out), optional :: comment
   !Local variables
   character(len=*), parameter :: subname='read_atomic_file'
   integer :: l, extract, i_all, i_stat
   logical :: file_exists, archive
   character(len = 128) :: filename
   character(len = 15) :: arFile
   character(len = 6) :: ext
   real(gp) :: energy_
   real(gp), dimension(:,:), pointer :: fxyz_
   character(len = 1024) :: comment_

   file_exists = .false.
   archive = .false.
   if (present(status)) status = 0
   nullify(fxyz_)

   ! Extract from archive
   if (index(file, "posout_") == 1 .or. index(file, "posmd_") == 1) then
      write(arFile, "(A)") "posout.tar.bz2"
      if (index(file, "posmd_") == 1) write(arFile, "(A)") "posmd.tar.bz2"
      inquire(FILE = trim(arFile), EXIST = file_exists)
      if (file_exists) then
         !!$     call extractNextCompress(trim(arFile), len(trim(arFile)), &
         !!$          & trim(file), len(trim(file)), extract, ext)
         call openNextCompress(trim(arFile), len(trim(arFile)), &
         & trim(file), len(trim(file)), extract, ext)
         if (extract == 0) then
            write(*,*) "Can't find '", file, "' in archive."
            if (present(status)) then
               status = 1
               return
            else
               stop
            end if
         end if
         archive = .true.
         write(filename, "(A)") file//'.'//trim(ext)
         write(astruct%inputfile_format, "(A)") trim(ext)
      end if
   end if

   ! Test posinp.xyz
   if (.not. file_exists) then
      inquire(FILE = file//'.xyz', EXIST = file_exists)
      if (file_exists) then
         write(filename, "(A)") file//'.xyz'!"posinp.xyz"
         write(astruct%inputfile_format, "(A)") "xyz"
         open(unit=99,file=trim(filename),status='old')
      end if
   end if
   ! Test posinp.ascii
   if (.not. file_exists) then
      inquire(FILE = file//'.ascii', EXIST = file_exists)
      if (file_exists) then
         write(filename, "(A)") file//'.ascii'!"posinp.ascii"
         write(astruct%inputfile_format, "(A)") "ascii"
         open(unit=99,file=trim(filename),status='old')
      end if
   end if
   ! Test posinp.yaml
   if (.not. file_exists) then
      inquire(FILE = file//'.yaml', EXIST = file_exists)
      if (file_exists) then
         write(filename, "(A)") file//'.yaml'!"posinp.ascii"
         write(astruct%inputfile_format, "(A)") "yaml"
      end if
   end if
   ! Test the name directly
   if (.not. file_exists) then
      inquire(FILE = file, EXIST = file_exists)
      if (file_exists) then
         write(filename, "(A)") file
         l = len(file)
         if (file(l-3:l) == ".xyz") then
            write(astruct%inputfile_format, "(A)") "xyz"
         else if (file(l-5:l) == ".ascii") then
            write(astruct%inputfile_format, "(A)") "ascii"
         else if (file(l-4:l) == ".yaml") then
            write(astruct%inputfile_format, "(A)") "yaml"
         else
            write(*,*) "Atomic input file '" // trim(file) // "', format not recognised."
            write(*,*) " File should be *.yaml, *.ascii or *.xyz."
            if (present(status)) then
               status = 1
               return
            else
               stop
            end if
         end if
         if (trim(astruct%inputfile_format) /= "yaml") then
            open(unit=99,file=trim(filename),status='old')
         end if
      end if
   end if

   if (.not. file_exists) then
      write(*,*) "Atomic input file not found."
      write(*,*) " Files looked for were '"//file//".yaml', '"//file//".ascii', '"//file//".xyz' and '"//file//"'."
      if (present(status)) then
         status = 1
         return
      else
         stop 
      end if
   end if

   if (astruct%inputfile_format == "xyz") then
      !read atomic positions
      if (.not.archive) then
         call read_xyz_positions(iproc,99,astruct,comment_,energy_,fxyz_,directGetLine)
      else
         call read_xyz_positions(iproc,99,astruct,comment_,energy_,fxyz_,archiveGetLine)
      end if
   else if (astruct%inputfile_format == "ascii") then
      !read atomic positions
      if (.not.archive) then
         call read_ascii_positions(iproc,99,astruct,comment_,energy_,fxyz_,directGetLine)
      else
         call read_ascii_positions(iproc,99,astruct,comment_,energy_,fxyz_,archiveGetLine)
      end if
   else if (astruct%inputfile_format == "yaml") then
      !read atomic positions
      if (.not.archive) then
         call read_yaml_positions(trim(filename),astruct,comment_,energy_,fxyz_)
      else
         write(*,*) "Atomic input file in YAML not yet supported in archive file."
         stop
      end if
   end if

   !Check the number of atoms
   if (astruct%nat < 0) then
      write(*,'(1x,3a,i0,a)') "In the file '",trim(filename),&
           &  "', the number of atoms (",astruct%nat,") < 0 (should be >= 0)."
      if (present(status)) then
         status = 1
         return
      else
         stop 
      end if
   end if

   !control atom positions
   call check_atoms_positions(iproc,astruct)

   ! We delay the calculation of the symmetries.
!this should be already in the atoms_null routine
   astruct%sym=symm_null()
!   astruct%sym%symObj = -1
!   nullify(astruct%sym%irrzon)
!   nullify(astruct%sym%phnons)

   ! close open file.
   if (.not.archive .and. trim(astruct%inputfile_format) /= "yaml") then
      close(99)
      !!$  else
      !!$     call unlinkExtract(trim(filename), len(trim(filename)))
   end if
   
   ! We transfer optionals.
   if (present(energy)) then
      energy = energy_
   end if
   if (present(comment)) then
      write(comment, "(A)") comment_
   end if
   if (present(fxyz)) then
      fxyz => fxyz_
   else if (associated(fxyz_)) then
      i_all=-product(shape(fxyz_))*kind(fxyz_)
      deallocate(fxyz_,stat=i_stat)
      call memocc(i_stat,i_all,'fxyz_',subname)
   end if
END SUBROUTINE read_atomic_file

!> Write an atomic file
!Yaml output included
subroutine write_atomic_file(filename,energy,rxyz,atoms,comment,forces)
  use module_base
  use module_types
  use yaml_output
  implicit none
  character(len=*), intent(in) :: filename,comment
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(in) :: energy
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: rxyz
  real(gp), dimension(3,atoms%astruct%nat), intent(in), optional :: forces
  !local variables
  character(len = 15) :: arFile

  open(unit=9,file=trim(filename)//'.'//trim(atoms%astruct%inputfile_format))
  if (atoms%astruct%inputfile_format == "xyz") then
     call wtxyz(9,energy,rxyz,atoms,comment)
     if (present(forces)) call wtxyz_forces(9,forces,atoms)
  else if (atoms%astruct%inputfile_format == "ascii") then
     call wtascii(9,energy,rxyz,atoms,comment)
     if (present(forces)) call wtascii_forces(9,forces,atoms)
  else if (atoms%astruct%inputfile_format == 'yaml') then
     if (present(forces)) then
        call wtyaml(9,energy,rxyz,atoms,comment,.true.,forces)
     else
        call wtyaml(9,energy,rxyz,atoms,comment,.false.,rxyz)
     end if
  else
     write(*,*) "Error, unknown file format."
     stop
  end if
  close(unit=9)

  ! Add to archive
  if (index(filename, "posout_") == 1 .or. index(filename, "posmd_") == 1) then
     write(arFile, "(A)") "posout.tar.bz2"
     if (index(filename, "posmd_") == 1) write(arFile, "(A)") "posmd.tar.bz2"
     call addToCompress(trim(arFile), len(trim(arFile)), &
          & trim(filename)//'.'//trim(atoms%astruct%inputfile_format), &
          & len(trim(filename)//'.'//trim(atoms%astruct%inputfile_format)))
  end if
END SUBROUTINE write_atomic_file

!>Calculate the coefficient for moving atoms following the ifrztyp
subroutine frozen_alpha(ifrztyp,ixyz,alpha,alphai)
  use module_base
  implicit none
  integer, intent(in) :: ifrztyp,ixyz
  real(gp), intent(in) :: alpha
  real(gp), intent(out) :: alphai
  !local variables
  logical :: move_this_coordinate

  if (move_this_coordinate(ifrztyp,ixyz)) then
     alphai=alpha
  else
     alphai=0.0_gp
  end if
 
END SUBROUTINE frozen_alpha

!>Routine for moving atomic positions, takes into account the 
!!   frozen atoms and the size of the cell
!!   synopsis: rxyz=txyz+alpha*sxyz
!!   all the shift are inserted into the box if there are periodic directions
!!   if the atom are frozen they are not moved
subroutine atomic_axpy(atoms,txyz,alpha,sxyz,rxyz)
  use module_base
  use module_types
  implicit none
  real(gp), intent(in) :: alpha
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: txyz,sxyz
  real(gp), dimension(3,atoms%astruct%nat), intent(inout) :: rxyz
  !local variables
  integer :: iat
  real(gp) :: alphax,alphay,alphaz

  do iat=1,atoms%astruct%nat
     !adjust the moving of the atoms following the frozen direction
     call frozen_alpha(atoms%astruct%ifrztyp(iat),1,alpha,alphax)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),2,alpha,alphay)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),3,alpha,alphaz)

     if (atoms%astruct%geocode == 'P') then
        rxyz(1,iat)=modulo(txyz(1,iat)+alphax*sxyz(1,iat),atoms%astruct%cell_dim(1))
        rxyz(2,iat)=modulo(txyz(2,iat)+alphay*sxyz(2,iat),atoms%astruct%cell_dim(2))
        rxyz(3,iat)=modulo(txyz(3,iat)+alphaz*sxyz(3,iat),atoms%astruct%cell_dim(3))
     else if (atoms%astruct%geocode == 'S') then
        rxyz(1,iat)=modulo(txyz(1,iat)+alphax*sxyz(1,iat),atoms%astruct%cell_dim(1))
        rxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
        rxyz(3,iat)=modulo(txyz(3,iat)+alphaz*sxyz(3,iat),atoms%astruct%cell_dim(3))
     else
        rxyz(1,iat)=txyz(1,iat)+alphax*sxyz(1,iat)
        rxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
        rxyz(3,iat)=txyz(3,iat)+alphaz*sxyz(3,iat)
     end if
  end do

END SUBROUTINE atomic_axpy


!>Routine for moving atomic positions, takes into account the 
!!   frozen atoms and the size of the cell
!!   synopsis: fxyz=txyz+alpha*sxyz
!!   update the forces taking into account the frozen atoms
!!   do not apply the modulo operation on forces 
subroutine atomic_axpy_forces(atoms,txyz,alpha,sxyz,fxyz)
  use module_base
  use module_types
  implicit none
  real(gp), intent(in) :: alpha
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: txyz,sxyz
  real(gp), dimension(3,atoms%astruct%nat), intent(inout) :: fxyz
  !local variables
  integer :: iat
  real(gp) :: alphax,alphay,alphaz
  
  do iat=1,atoms%astruct%nat
     !adjust the moving of the forces following the frozen direction
     call frozen_alpha(atoms%astruct%ifrztyp(iat),1,alpha,alphax)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),2,alpha,alphay)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),3,alpha,alphaz)

     fxyz(1,iat)=txyz(1,iat)+alphax*sxyz(1,iat)
     fxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
     fxyz(3,iat)=txyz(3,iat)+alphaz*sxyz(3,iat)
  end do
  
END SUBROUTINE atomic_axpy_forces


!>Calculate the scalar product between atomic positions by considering
!!   only non-blocked atoms
subroutine atomic_dot(atoms,x,y,scpr)
  use module_base
  use module_types
  implicit none
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: x,y
  real(gp), intent(out) :: scpr
  !local variables
  integer :: iat
  real(gp) :: scpr1,scpr2,scpr3
  real(gp) :: alphax,alphay,alphaz

  scpr=0.0_gp

  do iat=1,atoms%astruct%nat
     call frozen_alpha(atoms%astruct%ifrztyp(iat),1,1.0_gp,alphax)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),2,1.0_gp,alphay)
     call frozen_alpha(atoms%astruct%ifrztyp(iat),3,1.0_gp,alphaz)
     scpr1=alphax*x(1,iat)*y(1,iat)
     scpr2=alphay*x(2,iat)*y(2,iat)
     scpr3=alphaz*x(3,iat)*y(3,iat)
     scpr=scpr+scpr1+scpr2+scpr3
  end do
  
END SUBROUTINE atomic_dot


!>z=alpha*A*x + beta* y
subroutine atomic_gemv(atoms,m,alpha,A,x,beta,y,z)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: m
  real(gp), intent(in) :: alpha,beta
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: x
  real(gp), dimension(m), intent(in) :: y
  real(gp), dimension(m,3,atoms%astruct%nat), intent(in) :: A
  real(gp), dimension(m), intent(out) :: z
  !local variables
  integer :: iat,i,j
  real(gp) :: mv,alphai
  
  do i=1,m
     mv=0.0_gp
     do iat=1,atoms%astruct%nat
        do j=1,3
           call frozen_alpha(atoms%astruct%ifrztyp(iat),j,A(i,j,iat),alphai)
           mv=mv+alphai*x(j,iat)
        end do
     end do
     z(i)=alpha*mv+beta*y(i)
  end do

END SUBROUTINE atomic_gemv


!>  The function which controls all the moving positions
function move_this_coordinate(ifrztyp,ixyz)
  use module_base
  implicit none
  integer, intent(in) :: ixyz,ifrztyp
  logical :: move_this_coordinate
  
  move_this_coordinate= &
       ifrztyp == 0 .or. &
       (ifrztyp == 2 .and. ixyz /=2) .or. &
       (ifrztyp == 3 .and. ixyz ==2)
       
END FUNCTION move_this_coordinate


!> rxyz=txyz+alpha*sxyz
subroutine atomic_coordinate_axpy(atoms,ixyz,iat,t,alphas,r)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: ixyz,iat
  real(gp), intent(in) :: t,alphas
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(out) :: r
  !local variables
  logical :: periodize
  real(gp) :: alat,alphai

  if (ixyz == 1) then
     alat=atoms%astruct%cell_dim(1)
  else if (ixyz == 2) then
     alat=atoms%astruct%cell_dim(2)
  else if (ixyz == 3) then
     alat=atoms%astruct%cell_dim(3)
  else
     alat = -1
     write(0,*) "Internal error"
     stop
  end if
  
  periodize= atoms%astruct%geocode == 'P' .or. &
       (atoms%astruct%geocode == 'S' .and. ixyz /= 2)

  call frozen_alpha(atoms%astruct%ifrztyp(iat),ixyz,alphas,alphai)

  if (periodize) then
     r=modulo(t+alphai,alat)
  else
     r=t+alphai
  end if

END SUBROUTINE atomic_coordinate_axpy


!> Initialization of acceleration (OpenCL)
subroutine init_material_acceleration(iproc,matacc,GPU)
  use module_base
  use module_types
  use yaml_output
  implicit none
  integer, intent(in):: iproc
  type(material_acceleration), intent(in) :: matacc
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: iconv,iblas,initerror,ierror,useGPU,mproc,ierr,nproc_node

  if (matacc%iacceleration == 1) then
     call MPI_COMM_SIZE(bigdft_mpi%mpi_comm,mproc,ierr)
     !initialize the id_proc per node
     call processor_id_per_node(iproc,mproc,GPU%id_proc,nproc_node)
     call sg_init(GPUshare,useGPU,iproc,nproc_node,initerror)
     if (useGPU == 1) then
        iconv = 1
        iblas = 1
     else
        iconv = 0
        iblas = 0
     end if
     if (initerror == 1) then
        call yaml_warning('(iproc=' // trim(yaml_toa(iproc,fmt='(i0)')) // &
        &    ') S_GPU library init failed, aborting...')
        !write(*,'(1x,a)')'**** ERROR: S_GPU library init failed, aborting...'
        call MPI_ABORT(bigdft_mpi%mpi_comm,initerror,ierror)
     end if

     if (iconv == 1) then
        !change the value of the GPU convolution flag defined in the module_base
        GPUconv=.true.
     end if
     if (iblas == 1) then
        !change the value of the GPU convolution flag defined in the module_base
        GPUblas=.true.
     end if

     if (iproc == 0) then
        call yaml_map('Material acceleration','CUDA',advance='no')
        call yaml_comment('iproc=0')
       ! write(*,'(1x,a)') 'CUDA support activated (iproc=0)'
    end if

  else if (matacc%iacceleration >= 2) then
     ! OpenCL convolutions are activated
     ! use CUBLAS for the linear algebra for the moment
     if (.not. OCLconv) then
        call MPI_COMM_SIZE(bigdft_mpi%mpi_comm,mproc,ierr)
        !initialize the id_proc per node
        call processor_id_per_node(iproc,mproc,GPU%id_proc,nproc_node)
        !initialize the opencl context for any process in the node
        !call MPI_GET_PROCESSOR_NAME(nodename_local,namelen,ierr)
        !do jproc=0,mproc-1
        !   call MPI_BARRIER(bigdft_mpi%mpi_comm,ierr)
        !   if (iproc == jproc) then
        !      print '(a,a,i4,i4)','Initializing for node: ',trim(nodename_local),iproc,GPU%id_proc
        call init_acceleration_OCL(matacc,GPU)
        !   end if
        !end do
        GPU%ndevices=min(GPU%ndevices,nproc_node)
        if (iproc == 0) then
           call yaml_map('Material acceleration','OpenCL',advance='no')
           call yaml_comment('iproc=0')
           call yaml_open_map('Number of OpenCL devices per node',flow=.true.)
           call yaml_map('used',trim(yaml_toa(min(GPU%ndevices,nproc_node),fmt='(i0)')))
           call yaml_map('available',trim(yaml_toa(GPU%ndevices,fmt='(i0)')))
           !write(*,'(1x,a,i5,i5)') 'OpenCL support activated, No. devices per node (used, available):',&
           !     min(GPU%ndevices,nproc_node),GPU%ndevices
           call yaml_close_map()
        end if
        !the number of devices is the min between the number of processes per node
        GPU%ndevices=min(GPU%ndevices,nproc_node)
        OCLconv=.true.
     end if

  else
     if (iproc == 0) then
        call yaml_map('Material acceleration',.false.,advance='no')
        call yaml_comment('iproc=0')
        ! write(*,'(1x,a)') 'No material acceleration (iproc=0)'
     end if
  end if

END SUBROUTINE init_material_acceleration


subroutine release_material_acceleration(GPU)
  use module_base
  use module_types
  implicit none
  type(GPU_pointers), intent(out) :: GPU
  
  if (GPUconv) then
     call sg_end()
  end if

  if (OCLconv) then
     call release_acceleration_OCL(GPU)
     OCLconv=.false.
  end if

END SUBROUTINE release_material_acceleration


!> Give the number of MPI processes per node (nproc_node) and before iproc (iproc_node)
subroutine processor_id_per_node(iproc,nproc,iproc_node,nproc_node)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,nproc
  integer, intent(out) :: iproc_node,nproc_node
  !local variables
  character(len=*), parameter :: subname='processor_id_per_node'
  integer :: ierr,namelen,i_stat,i_all,jproc
  character(len=MPI_MAX_PROCESSOR_NAME) :: nodename_local
  character(len=MPI_MAX_PROCESSOR_NAME), dimension(:), allocatable :: nodename

  if (nproc == 1) then
     iproc_node=0
     nproc_node=1
  else
     allocate(nodename(0:nproc-1+ndebug),stat=i_stat)
     call memocc(i_stat,nodename,'nodename',subname)
     
     !initalise nodenames
     do jproc=0,nproc-1
        nodename(jproc)=repeat(' ',MPI_MAX_PROCESSOR_NAME)
     end do

     call MPI_GET_PROCESSOR_NAME(nodename_local,namelen,ierr)

     !gather the result between all the process
     call MPI_ALLGATHER(nodename_local,MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,&
          nodename(0),MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,&
          bigdft_mpi%mpi_comm,ierr)

     !found the processors which belong to the same node
     !before the processor iproc
     iproc_node=0
     do jproc=0,iproc-1
        if (trim(nodename(jproc)) == trim(nodename(iproc))) then
           iproc_node=iproc_node+1
        end if
     end do
     nproc_node=iproc_node
     do jproc=iproc,nproc-1
        if (trim(nodename(jproc)) == trim(nodename(iproc))) then
           nproc_node=nproc_node+1
        end if
     end do
     
     i_all=-product(shape(nodename))*kind(nodename)
     deallocate(nodename,stat=i_stat)
     call memocc(i_stat,i_all,'nodename',subname)
  end if
END SUBROUTINE processor_id_per_node


!> this routine does the same operations as
!! read_atomic_file but uses inputs from memory
!! as input positions instead of inputs from file
!! Useful for QM/MM implementation of BigDFT-ART
!! @author Written by Laurent K Beland 2011 UdeM
subroutine initialize_atomic_file(iproc,atoms,rxyz)
  use module_base
  use module_types
  use module_interfaces, except_this_one => initialize_atomic_file
  use m_ab6_symmetry
  use yaml_output
  implicit none
  integer, intent(in) :: iproc
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(:,:), pointer :: rxyz
  !local variables
  character(len=*), parameter :: subname='initialize_atomic_file'
  integer :: i_stat
  integer :: iat,i,ierr

  allocate(atoms%amu(atoms%astruct%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%amu,'atoms%amu',subname)

  if (atoms%astruct%geocode=='S') then 
        atoms%astruct%cell_dim(2)=0.0_gp
  else if (atoms%astruct%geocode=='F') then !otherwise free bc    
        atoms%astruct%cell_dim(1)=0.0_gp
        atoms%astruct%cell_dim(2)=0.0_gp
        atoms%astruct%cell_dim(3)=0.0_gp
  else
        atoms%astruct%cell_dim(1)=0.0_gp
        atoms%astruct%cell_dim(2)=0.0_gp
        atoms%astruct%cell_dim(3)=0.0_gp
  end if

  !reduced coordinates are possible only with periodic units
  if (atoms%astruct%units == 'reduced' .and. atoms%astruct%geocode == 'F') then
     if (iproc==0) write(*,'(1x,a)')&
          'ERROR: Reduced coordinates are not allowed with isolated BC'
  end if

   !convert the values of the cell sizes in bohr
  if (atoms%astruct%units=='angstroem' .or. atoms%astruct%units=='angstroemd0') then
     ! if Angstroem convert to Bohr
     atoms%astruct%cell_dim(1)=atoms%astruct%cell_dim(1)/Bohr_Ang
     atoms%astruct%cell_dim(2)=atoms%astruct%cell_dim(2)/Bohr_Ang
     atoms%astruct%cell_dim(3)=atoms%astruct%cell_dim(3)/Bohr_Ang
  else if (atoms%astruct%units == 'reduced') then
     !assume that for reduced coordinates cell size is in bohr
     atoms%astruct%cell_dim(1)=real(atoms%astruct%cell_dim(1),gp)
     atoms%astruct%cell_dim(2)=real(atoms%astruct%cell_dim(2),gp)
     atoms%astruct%cell_dim(3)=real(atoms%astruct%cell_dim(3),gp)
  else
     call yaml_warning('Length units in input file unrecognized')
     call yaml_warning('recognized units are angstroem or atomic = bohr')
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
  endif
  
  do iat=1,atoms%astruct%nat
     !xyz input file, allow extra information
     
     if (atoms%astruct%units == 'reduced') then !add treatment for reduced coordinates
        rxyz(1,iat)=modulo(rxyz(1,iat),1.0_gp)
        if (atoms%astruct%geocode == 'P') rxyz(2,iat)=modulo(rxyz(2,iat),1.0_gp)
        rxyz(3,iat)=modulo(rxyz(3,iat),1.0_gp)
     else if (atoms%astruct%geocode == 'P') then
        rxyz(1,iat)=modulo(rxyz(1,iat),atoms%astruct%cell_dim(1))
        rxyz(2,iat)=modulo(rxyz(2,iat),atoms%astruct%cell_dim(2))
        rxyz(3,iat)=modulo(rxyz(3,iat),atoms%astruct%cell_dim(3))
     else if (atoms%astruct%geocode == 'S') then
        rxyz(1,iat)=modulo(rxyz(1,iat),atoms%astruct%cell_dim(1))
        rxyz(3,iat)=modulo(rxyz(3,iat),atoms%astruct%cell_dim(3))
     end if
 
     if (atoms%astruct%units=='angstroem' .or. atoms%astruct%units=='angstroemd0') then
        ! if Angstroem convert to Bohr
        do i=1,3 
           rxyz(i,iat)=rxyz(i,iat)/Bohr_Ang
        enddo
     else if (atoms%astruct%units == 'reduced') then 
        rxyz(1,iat)=rxyz(1,iat)*atoms%astruct%cell_dim(1)
        if (atoms%astruct%geocode == 'P') rxyz(2,iat)=rxyz(2,iat)*atoms%astruct%cell_dim(2)
        rxyz(3,iat)=rxyz(3,iat)*atoms%astruct%cell_dim(3)
     endif
  enddo

  !control atom positions
  call check_atoms_positions(iproc,atoms)

  ! We delay the calculation of the symmetries.
  atoms%astruct%sym%symObj = -1
  nullify(atoms%astruct%sym%irrzon)
  nullify(atoms%astruct%sym%phnons)

END SUBROUTINE initialize_atomic_file
