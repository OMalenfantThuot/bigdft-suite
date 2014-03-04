!> @file
!!  Routines to read and print input variables
!! @author
!!    Copyright (C) 2007-2013 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 

!> this function returns a dictionary with all the input variables of a BigDFT run filled
!! this dictionary is constructed from a updated version of the input variables dictionary
!! following the input files as defined  by the user
subroutine read_input_dict_from_files(radical,mpi_env,dict)
  use dictionaries
  use wrapper_MPI
  use module_input_keys
  use module_interfaces, only: merge_input_file_to_dict
  use input_old_text_format
  use yaml_output
  implicit none
  character(len = *), intent(in) :: radical !< the name of the run. use "input" if empty
  type(mpi_environment), intent(in) :: mpi_env !< the environment where the variables have to be updated
  type(dictionary), pointer :: dict !< input dictionary, has to be nullified at input
  !local variables
  integer :: ierr
  logical :: exists_default, exists_user
  character(len = max_field_length) :: fname
  character(len = 100) :: f0

  call f_routine(id='read_input_dict_from_files')

  if (f_err_raise(associated(dict),'The output dictionary should be nullified at input',&
       err_name='BIGDFT_RUNTIME_ERROR')) return

  nullify(dict) !this is however put in the case the dictionary comes undefined

  call dict_init(dict)
  if (trim(radical) /= "" .and. trim(radical) /= "input") &
       & call set(dict // "radical", radical)

  ! Handle error with master proc only.
  if (mpi_env%iproc > 0) call f_err_set_callback(f_err_ignore)

  ! We try first default.yaml
  inquire(file = "default.yaml", exist = exists_default)
  if (exists_default) call merge_input_file_to_dict(dict, "default.yaml", mpi_env)

  ! We try then radical.yaml
  if (len_trim(radical) == 0) then
     fname = "input.yaml"
  else
     fname(1:max_field_length) = trim(radical) // ".yaml"
  end if
  inquire(file = trim(fname), exist = exists_user)
  if (exists_user) call merge_input_file_to_dict(dict, trim(fname), mpi_env)

  ! We fallback on the old text format (to be eliminated in the future)
  if (.not.exists_default .and. .not. exists_user) then
     ! Parse all files.
     call set_inputfile(f0, radical, PERF_VARIABLES)
     call read_perf_from_text_format(mpi_env%iproc,dict//PERF_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, DFT_VARIABLES)
     call read_dft_from_text_format(mpi_env%iproc,dict//DFT_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, KPT_VARIABLES)
     call read_kpt_from_text_format(mpi_env%iproc,dict//KPT_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, GEOPT_VARIABLES)
     call read_geopt_from_text_format(mpi_env%iproc,dict//GEOPT_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, MIX_VARIABLES)
     call read_mix_from_text_format(mpi_env%iproc,dict//MIX_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, SIC_VARIABLES)
     call read_sic_from_text_format(mpi_env%iproc,dict//SIC_VARIABLES, trim(f0))
     call set_inputfile(f0, radical, TDDFT_VARIABLES)
     call read_tddft_from_text_format(mpi_env%iproc,dict//TDDFT_VARIABLES, trim(f0))
  else
     ! We add an overloading input.perf (for automatic test purposes).
     ! This will be changed in far future when only YAML input will be allowed.
     call set_inputfile(f0, radical, PERF_VARIABLES)
     call read_perf_from_text_format(mpi_env%iproc,dict//PERF_VARIABLES, trim(f0))
  end if

  if (mpi_env%iproc > 0) call f_err_severe_restore()

  ! We put a barrier here to be sure that non master proc will be stop
  ! by any issue on the master proc.
  call mpi_barrier(mpi_env%mpi_comm, ierr)

  call f_release_routine()
end subroutine read_input_dict_from_files

!> Routine to read YAML input files and create input dictionary.
subroutine merge_input_file_to_dict(dict, fname, mpi_env)
  use module_base
  use module_input_keys
  use dictionaries
  use yaml_parse
  use wrapper_MPI
  implicit none
  type(dictionary), pointer :: dict
  character(len = *), intent(in) :: fname
  type(mpi_environment), intent(in) :: mpi_env

  integer(kind = 8) :: cbuf, cbuf_len
  integer :: ierr
  character(len = max_field_length) :: val
  character, dimension(:), allocatable :: fbuf
  type(dictionary), pointer :: udict
  
  call f_routine(id='merge_input_file_to_dict')
  if (mpi_env%iproc == 0) then
     call getFileContent(cbuf, cbuf_len, fname, len_trim(fname))
     if (mpi_env%nproc > 1) &
          & call mpi_bcast(cbuf_len, 1, MPI_INTEGER8, 0, mpi_env%mpi_comm, ierr)
  else
     call mpi_bcast(cbuf_len, 1, MPI_INTEGER8, 0, mpi_env%mpi_comm, ierr)
  end if
  fbuf=f_malloc_str(1,int(cbuf_len),id='fbuf')
  fbuf(:) = " "

  if (mpi_env%iproc == 0) then
     call copyCBuffer(fbuf(1), cbuf, cbuf_len)
     call freeCBuffer(cbuf)
     if (mpi_env%nproc > 1) &
          & call mpi_bcast(fbuf(1), int(cbuf_len), MPI_CHARACTER, 0, mpi_env%mpi_comm, ierr)
  else
     call mpi_bcast(fbuf(1), int(cbuf_len), MPI_CHARACTER, 0, mpi_env%mpi_comm, ierr)
  end if

  call f_err_open_try()
  call yaml_parse_from_char_array(udict, fbuf)
  ! Handle with possible partial dictionary.
  call f_free_str(1,fbuf)
  call dict_update(dict, udict // 0)
  call dict_free(udict)

  ierr = 0
  if (f_err_check()) ierr = f_get_last_error(val)
  call f_err_close_try()
  !in the present implementation f_err_check is not cleaned after the close of the try
  if (ierr /= 0) call f_err_throw(err_id = ierr, err_msg = val)
  call f_release_routine()

end subroutine merge_input_file_to_dict

!> Fill the input_variables structure with the information
!! contained in the dictionary dict
!! the dictionary should be completes to fill all the information
subroutine inputs_from_dict(in, atoms, dict, dump)
  use module_types
  use module_defs
  use yaml_output
  use module_interfaces, except => inputs_from_dict
  use dictionaries
  use module_input_keys
  use module_input_dicts
  use dynamic_memory
  use m_profiling, only: ab7_memocc_set_state => memocc_set_state !< abinit module to be removed
  use module_xc
  implicit none
  type(input_variables), intent(out) :: in
  type(atoms_data), intent(out) :: atoms
  type(dictionary), pointer :: dict
  logical, intent(in) :: dump

  !type(dictionary), pointer :: profs
  integer :: ierr, ityp, iproc_node, nproc_node, nelec_up, nelec_down, norb_max
  type(dictionary), pointer :: dict_minimal, var
  character(max_field_length) :: radical

  call f_routine(id='inputs_from_dict')

  ! Atoms case.
  atoms = atoms_null()
  if (.not. has_key(dict, "posinp")) stop "missing posinp"
  call astruct_set_from_dict(dict // "posinp", atoms%astruct)

  ! Input variables case.
  call default_input_variables(in)

  ! Setup radical for output dir.
  write(radical, "(A)") "input"
  if (has_key(dict, "radical")) radical = dict // "radical"
  call standard_inputfile_names(in,trim(radical))
  ! To avoid race conditions where procs create the default file and other test its
  ! presence, we put a barrier here.
  if (bigdft_mpi%nproc > 1) call MPI_BARRIER(bigdft_mpi%mpi_comm, ierr)

  ! Analyse the input dictionary and transfer it to in.
  ! extract also the minimal dictionary which is necessary to do this run
  call input_keys_fill_all(dict,dict_minimal)

  ! Transfer dict values into input_variables structure.
  var => dict_iter(dict // PERF_VARIABLES)
  do while(associated(var))
     call input_set(in, PERF_VARIABLES, var)
     var => dict_next(var)
  end do
  var => dict_iter(dict // DFT_VARIABLES)
  do while(associated(var))
     call input_set(in, DFT_VARIABLES, var)
     var => dict_next(var)
  end do
  var => dict_iter(dict // GEOPT_VARIABLES)
  do while(associated(var))
     call input_set(in, GEOPT_VARIABLES, var)
     var => dict_next(var)
  end do
  var => dict_iter(dict // MIX_VARIABLES)
  do while(associated(var))
     call input_set(in, MIX_VARIABLES, var)
     var => dict_next(var)
  end do
  var => dict_iter(dict // SIC_VARIABLES)
  do while(associated(var))
     call input_set(in, SIC_VARIABLES, var)
     var => dict_next(var)
  end do
  var => dict_iter(dict // TDDFT_VARIABLES)
  do while(associated(var))
     call input_set(in, TDDFT_VARIABLES, var)
     var => dict_next(var)
  end do

  if (.not. in%debug) then
     call ab7_memocc_set_state(1)
     call f_malloc_set_status(output_level=1)
  end if
  call set_cache_size(in%ncache_fft)
  if (in%verbosity == 0 ) then
     call ab7_memocc_set_state(0)
     call f_malloc_set_status(output_level=0)
  end if
  !here the logfile should be opened in the usual way, differentiating between 
  ! logfiles in case of multiple taskgroups
  if (trim(in%writing_directory) /= '.' .or. bigdft_mpi%ngroup > 1) then
     call create_log_file(bigdft_mpi%iproc,in)
  else
     !use stdout, do not crash if unit is present
     if (bigdft_mpi%iproc==0) call yaml_set_stream(record_length=92,istat=ierr)
  end if

  !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
  if (bigdft_mpi%iproc==0 .and. dump) then
     !start writing on logfile
     call yaml_new_document()
     !welcome screen
     call print_logo()
  end if
  if (bigdft_mpi%nproc >1) call processor_id_per_node(bigdft_mpi%iproc,bigdft_mpi%nproc,iproc_node,nproc_node)
  if (bigdft_mpi%iproc ==0 .and. dump) then
     if (bigdft_mpi%nproc >1) call yaml_map('MPI tasks of root process node',nproc_node)
     call print_configure_options()
  end if

  ! Cross check values of input_variables.
  call input_analyze(in)

  ! Initialise XC calculation
!!$  if (in%ixc < 0) then
!!$     call xc_init(in%xcObj, in%ixc, XC_MIXED, in%nspin)
!!$  else
!!$     call xc_init(in%xcObj, in%ixc, XC_ABINIT, in%nspin)
!!$  end if

  ! Shake atoms, if required.
  call astruct_set_displacement(atoms%astruct, in%randdis)
  if (bigdft_mpi%nproc > 1) call MPI_BARRIER(bigdft_mpi%mpi_comm, ierr)
  ! Update atoms with symmetry information
  call astruct_set_symmetries(atoms%astruct, in%disableSym, in%symTol, in%elecfield, in%nspin)

  call kpt_input_analyse(bigdft_mpi%iproc, in, dict//KPT_VARIABLES, &
       & atoms%astruct%sym, atoms%astruct%geocode, atoms%astruct%cell_dim)

  ! Add missing pseudo information.
  do ityp = 1, atoms%astruct%ntypes, 1
     call psp_dict_fill_all(dict, atoms%astruct%atomnames(ityp), in%ixc)
  end do

  ! Update atoms with pseudo information.
  call psp_dict_analyse(dict, atoms)
  call atomic_data_set_from_dict(dict, "Atomic occupation", atoms, in%nspin)

  ! Generate orbital occupation
  call read_n_orbitals(bigdft_mpi%iproc, nelec_up, nelec_down, norb_max, atoms, &
       & in%ncharge, in%nspin, in%mpol, in%norbsempty)
  if (norb_max == 0) norb_max = nelec_up + nelec_down ! electron gas case
  call occupation_set_from_dict(dict, "occupation", &
       & in%gen_norbu, in%gen_norbd, in%gen_occup, &
       & in%gen_nkpt, in%nspin, in%norbsempty, nelec_up, nelec_down, norb_max)
  in%gen_norb = in%gen_norbu + in%gen_norbd
  
  if (bigdft_mpi%iproc == 0 .and. dump) then
     call input_keys_dump(dict)
     if (associated(dict_minimal)) then
        call yaml_set_stream(unit=71,filename=trim(in%writing_directory)//'/input_minimal.yaml',&
             record_length=92,istat=ierr,setdefault=.false.,tabbing=0)
        if (ierr==0) then
           call yaml_comment('Minimal input file',hfill='-',unit=71)
           call yaml_comment('This file indicates the minimal set of input variables which has to be given '//&
                'to perform the run. The code would produce the same output if this file is used as input.',unit=71)
           call yaml_dict_dump(dict_minimal,unit=71)
           call yaml_close_stream(unit=71)
        else
           call yaml_warning('Failed to create input_minimal.yaml, error code='//trim(yaml_toa(ierr)))
        end if
     end if
  end if
  if (associated(dict_minimal)) call dict_free(dict_minimal)

  if (in%gen_nkpt > 1 .and. in%gaussian_help) then
     if (bigdft_mpi%iproc==0) call yaml_warning('Gaussian projection is not implemented with k-point support')
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
  end if
  
  if(in%inputpsiid==100 .or. in%inputpsiid==101 .or. in%inputpsiid==102) &
      DistProjApply=.true.
  if(in%linear /= INPUT_IG_OFF .and. in%linear /= INPUT_IG_LIG) then
     !only on the fly calculation
     DistProjApply=.true.
  end if

  !if other steps are supposed to be done leave the last_run to minus one
  !otherwise put it to one
  if (in%last_run == -1 .and. in%ncount_cluster_x <=1 .or. in%ncount_cluster_x <= 1) then
     in%last_run = 1
  end if

  ! Stop the code if it is trying to run GPU with spin=4
  if (in%nspin == 4 .and. (GPUconv .or. OCLconv)) then
     if (bigdft_mpi%iproc==0) call yaml_warning('GPU calculation not implemented with non-collinear spin')
     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
  end if

  ! Linear scaling (if given)
  !in%lin%fragment_calculation=.false. ! to make sure that if we're not doing a linear calculation we don't read fragment information
  call lin_input_variables_new(bigdft_mpi%iproc,dump .and. (in%inputPsiId == INPUT_PSI_LINEAR_AO .or. &
       & in%inputPsiId == INPUT_PSI_DISK_LINEAR), trim(in%file_lin),in,atoms)

  ! Fragment information (if given)
  call fragment_input_variables(bigdft_mpi%iproc,dump .and. (in%inputPsiId == INPUT_PSI_LINEAR_AO .or. &
       & in%inputPsiId == INPUT_PSI_DISK_LINEAR).and.in%lin%fragment_calculation,trim(in%file_frag),in,atoms)

!!$  ! Stop code for unproper input variables combination.
!!$  if (in%ncount_cluster_x > 0 .and. .not. in%disableSym .and. atoms%geocode == 'S') then
!!$     if (bigdft_mpi%iproc==0) then
!!$        write(*,'(1x,a)') 'Change "F" into "T" in the last line of "input.dft"'   
!!$        write(*,'(1x,a)') 'Forces are not implemented with symmetry support, disable symmetry please (T)'
!!$     end if
!!$     call MPI_ABORT(bigdft_mpi%mpi_comm,0,ierr)
!!$  end if

!!$  if (bigdft_mpi%iproc == 0) then
!!$     profs => input_keys_get_profiles("")
!!$     call yaml_dict_dump(profs)
!!$     call dict_free(profs)
!!$  end if

  !check whether a directory name should be associated for the data storage
  call check_for_data_writing_directory(bigdft_mpi%iproc,in)
  
  !check if an error has been found and raise an exception to be handled
  if (f_err_check()) then
     call f_err_throw('Error in reading input variables from dictionary',&
          err_name='BIGDFT_INPUT_VARIABLES_ERROR')
  end if

  call f_release_routine()

end subroutine inputs_from_dict

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
     call create_dir_output(iproc, in)
     if (iproc==0) call yaml_map('Data Writing directory',trim(in%dir_output))
  else
     if (iproc==0) call yaml_map('Data Writing directory','./')
     in%dir_output=repeat(' ',len(in%dir_output))
  end if
END SUBROUTINE check_for_data_writing_directory

subroutine create_dir_output(iproc, in)
  use yaml_output
  use module_types
  use module_base
  implicit none
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in

  character(len=100) :: dirname
  integer :: i_stat,ierror,ierr

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
END SUBROUTINE create_dir_output

!> Set default values for input variables
subroutine default_input_variables(in)
  use module_base
  use module_types
  use dictionaries
  implicit none

  type(input_variables), intent(inout) :: in

  in%matacc=material_acceleration_null()

  ! Default values.
  in%output_wf_format = WF_FORMAT_NONE
  in%output_denspot_format = output_denspot_FORMAT_CUBE
  nullify(in%gen_kpt)
  nullify(in%gen_wkpt)
  nullify(in%kptv)
  nullify(in%nkptsv_group)
  in%gen_norb = UNINITIALIZED(0)
  in%gen_norbu = UNINITIALIZED(0)
  in%gen_norbd = UNINITIALIZED(0)
  nullify(in%gen_occup)
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
  nullify(in%frag%charge)
END SUBROUTINE default_input_variables

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
  in%mditemp = UNINITIALIZED(in%mditemp)
  in%mdftemp = UNINITIALIZED(in%mdftemp)
  nullify(in%qmass)

END SUBROUTINE geopt_input_variables_default

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

!> Assign default values for TDDFT variables
subroutine tddft_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  in%tddft_approach='NONE'

END SUBROUTINE tddft_input_variables_default

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

  allocate(input_frag%charge(input_frag%nfrag), stat=i_stat)
  call memocc(i_stat, input_frag%charge, 'input_frag%charge', subname)

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

  if(associated(input_frag%charge)) then
     i_all = -product(shape(input_frag%charge))*kind(input_frag%charge)
     deallocate(input_frag%charge,stat=i_stat)
     call memocc(i_stat,i_all,'input_frag%charge',subname)
     nullify(input_frag%charge)
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
  nullify(input_frag%charge)
  !nullify(input_frag%frag_info)
  nullify(input_frag%label)
  nullify(input_frag%dirname)

end subroutine nullifyInputFragParameters

!>  Free all dynamically allocated memory from the kpt input file.
subroutine free_kpt_variables(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_kpt_variables'
  integer :: i_stat, i_all

  if (associated(in%gen_kpt)) then
     i_all=-product(shape(in%gen_kpt))*kind(in%gen_kpt)
     deallocate(in%gen_kpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%gen_kpt',subname)
  end if
  if (associated(in%gen_wkpt)) then
     i_all=-product(shape(in%gen_wkpt))*kind(in%gen_wkpt)
     deallocate(in%gen_wkpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%gen_wkpt',subname)
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
  nullify(in%gen_kpt)
  nullify(in%gen_wkpt)
  nullify(in%kptv)
  nullify(in%nkptsv_group)
end subroutine free_kpt_variables

!>  Free all dynamically allocated memory from the geopt input file.
subroutine free_geopt_variables(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_geopt_variables'
  integer :: i_stat, i_all

  if (associated(in%qmass)) then
     i_all=-product(shape(in%qmass))*kind(in%qmass)
     deallocate(in%qmass,stat=i_stat)
     call memocc(i_stat,i_all,'in%qmass',subname)
  end if
  nullify(in%qmass)
end subroutine free_geopt_variables

!>  Free all dynamically allocated memory from the input variable structure.
subroutine free_input_variables(in)
  use module_base
  use module_types
  use module_xc
  use dynamic_memory, only: f_free_ptr
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_input_variables'

!!$  if(in%linear /= INPUT_IG_OFF .and. in%linear /= INPUT_IG_LIG) &
!!$       & call deallocateBasicArraysInput(in%lin)

  call free_geopt_variables(in)
  call free_kpt_variables(in)
  if (associated(in%gen_occup)) call f_free_ptr(in%gen_occup)
  call deallocateBasicArraysInput(in%lin)
  call deallocateInputFragArrays(in%frag)

  ! Free the libXC stuff if necessary, related to the choice of in%ixc.
!!$  call xc_end(in%xcObj)

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

subroutine input_analyze(in)
  use module_types, only: input_variables
  use module_types, only: output_denspot_FORMAT_CUBE, output_denspot_NONE, WF_FORMAT_NONE
  use module_types, only: bigdft_mpi
  use module_defs, only: gp
  use dynamic_memory
  use module_input_keys, only: input_keys_equal
  implicit none
  type(input_variables), intent(inout) :: in

  integer :: ierr

  call f_routine(id='input_analyze')

  ! the PERF variables -----------------------------------------------------
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

  ! the DFT variables ------------------------------------------------------
  in%SIC%ixc = in%ixc

  in%idsx = min(in%idsx, in%itermax)

  !project however the wavefunction on gaussians if asking to write them on disk
  ! But not if we use linear scaling version (in%inputPsiId >= 100)
  in%gaussian_help=(in%inputPsiId >= 10 .and. in%inputPsiId < 100)

  !switch on the gaussian auxiliary treatment 
  !and the zero of the forces
  if (in%inputPsiId == 10) then
     in%inputPsiId = 0
  else if (in%inputPsiId == 13) then
     in%inputPsiId = 2
  end if
  ! Setup out grid parameters.
  if (in%output_denspot >= 0) then
     in%output_denspot_format = in%output_denspot / 10
  else
     in%output_denspot_format = output_denspot_FORMAT_CUBE
     in%output_denspot = abs(in%output_denspot)
  end if
  in%output_denspot = modulo(in%output_denspot, 10)

  !define whether there should be a last_run after geometry optimization
  !also the mulliken charge population should be inserted
  if ((in%rbuf > 0.0_gp) .or. in%output_wf_format /= WF_FORMAT_NONE .or. &
       in%output_denspot /= output_denspot_NONE .or. in%norbv /= 0) then
     in%last_run=-1 !last run to be done depending of the external conditions
  else
     in%last_run=0
  end if
  
  ! the GEOPT variables ----------------------------------------------------
  !target stress tensor
  in%strtarget(:)=0.0_gp

  if (input_keys_equal(trim(in%geopt_approach), "AB6MD")) then
     if (in%ionmov /= 13) then
        in%nnos=0
        in%qmass = f_malloc_ptr(in%nnos, id = "in%qmass")
     end if
  end if
  call f_release_routine()
END SUBROUTINE input_analyze

subroutine kpt_input_analyse(iproc, in, dict, sym, geocode, alat)
  use module_base
  use module_types
  use defs_basis
  use m_ab6_kpoints
  use yaml_output
  use module_input_keys
  use dictionaries
  implicit none
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  type(dictionary), pointer :: dict
  type(symmetry_data), intent(in) :: sym
  character(len = 1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  real(gp), intent(in) :: alat(3)
  !local variables
  logical :: lstat
  character(len=*), parameter :: subname='kpt_input_analyse'
  integer :: i_stat,ierror,i,nshiftk, ngkpt_(3), ikpt, j, ncount, nseg, iseg_, ngranularity_
  real(gp) :: kptrlen_, shiftk_(3,8), norm, alat_(3)
  character(len = 6) :: method
  
  ! Set default values.
  in%gen_nkpt=1
  in%nkptv=0
  in%ngroups_kptv=1

  call free_kpt_variables(in)
  nullify(in%kptv, in%nkptsv_group)
  nullify(in%gen_kpt, in%gen_wkpt)

  method = dict // KPT_METHOD
  if (input_keys_equal(trim(method), 'auto')) then
     kptrlen_ = dict // KPTRLEN
     if (geocode == 'F') then
        in%gen_nkpt = 1
        allocate(in%gen_kpt(3, in%gen_nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%gen_kpt,'in%gen_kpt',subname)
        in%gen_kpt = 0.
        allocate(in%gen_wkpt(in%gen_nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%gen_wkpt,'in%gen_wkpt',subname)
        in%gen_wkpt = 1.
     else
        call kpoints_get_auto_k_grid(sym%symObj, in%gen_nkpt, in%gen_kpt, in%gen_wkpt, &
             & kptrlen_, ierror)
        if (ierror /= AB6_NO_ERROR) then
           if (iproc==0) &
                & call yaml_warning("ERROR: cannot generate automatic k-point grid." // &
                & " Error code is " // trim(yaml_toa(ierror,fmt='(i0)')))
           stop
        end if
        !assumes that the allocation went through
        call memocc(0,in%gen_kpt,'in%gen_kpt',subname)
        call memocc(0,in%gen_wkpt,'in%gen_wkpt',subname)
     end if
  else if (input_keys_equal(trim(method), 'mpgrid')) then
     !take the points of Monkhorst-pack grid
     ngkpt_(1) = dict // NGKPT // 0
     ngkpt_(2) = dict // NGKPT // 1
     ngkpt_(3) = dict // NGKPT // 2
     if (geocode == 'S') ngkpt_(2) = 1
     !shift
     nshiftk = dict_len(dict//SHIFTK)
     !read the shifts
     shiftk_=0.0_gp
     do i=1,nshiftk
        shiftk_(1,i) = dict // SHIFTK // (i-1) // 0
        shiftk_(2,i) = dict // SHIFTK // (i-1) // 1
        shiftk_(3,i) = dict // SHIFTK // (i-1) // 2
     end do

     !control whether we are giving k-points to Free BC
     if (geocode == 'F') then
        if (iproc==0 .and. (maxval(ngkpt_) > 1 .or. maxval(abs(shiftk_)) > 0.)) &
             & call yaml_warning('Found input k-points with Free Boundary Conditions, reduce run to Gamma point')
        in%gen_nkpt = 1
        allocate(in%gen_kpt(3, in%gen_nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%gen_kpt,'in%gen_kpt',subname)
        in%gen_kpt = 0.
        allocate(in%gen_wkpt(in%gen_nkpt+ndebug),stat=i_stat)
        call memocc(i_stat,in%gen_wkpt,'in%gen_wkpt',subname)
        in%gen_wkpt = 1.
     else
        call kpoints_get_mp_k_grid(sym%symObj, in%gen_nkpt, in%gen_kpt, in%gen_wkpt, &
             & ngkpt_, nshiftk, shiftk_, ierror)
        if (ierror /= AB6_NO_ERROR) then
           if (iproc==0) &
                & call yaml_warning("ERROR: cannot generate MP k-point grid." // &
                & " Error code is " // trim(yaml_toa(ierror,fmt='(i0)')))
           stop
        end if
        !assumes that the allocation went through
        call memocc(0,in%gen_kpt,'in%gen_kpt',subname)
        call memocc(0,in%gen_wkpt,'in%gen_wkpt',subname)
     end if
  else if (input_keys_equal(trim(method), 'manual')) then
     in%gen_nkpt = max(1, dict_len(dict//KPT))
     if (geocode == 'F' .and. in%gen_nkpt > 1) then
        if (iproc==0) call yaml_warning('Found input k-points with Free Boundary Conditions, reduce run to Gamma point')
        in%gen_nkpt = 1
     end if
     allocate(in%gen_kpt(3, in%gen_nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%gen_kpt,'in%gen_kpt',subname)
     allocate(in%gen_wkpt(in%gen_nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%gen_wkpt,'in%gen_wkpt',subname)
     norm=0.0_gp
     do i=1,in%gen_nkpt
        in%gen_kpt(1, i) = dict // KPT // (i-1) // 0
        in%gen_kpt(2, i) = dict // KPT // (i-1) // 1
        in%gen_kpt(3, i) = dict // KPT // (i-1) // 2
        if (geocode == 'S' .and. in%gen_kpt(2,i) /= 0.) then
           in%gen_kpt(2,i) = 0.
           if (iproc==0) call yaml_warning('Surface conditions, supressing k-points along y.')
        end if
        in%gen_wkpt(i) = dict // WKPT // (i-1)
        if (geocode == 'F') then
           in%gen_kpt = 0.
           in%gen_wkpt = 1.
        end if
        norm=norm+in%gen_wkpt(i)
     end do
     ! We normalise the weights.
     in%gen_wkpt(:)=in%gen_wkpt/norm
  else
     if (iproc==0) &
          & call yaml_warning("ERROR: wrong k-point sampling method (" // &
          & trim(method) // ").")
     stop
  end if

  ! Convert reduced coordinates into BZ coordinates.
  alat_ = alat
  if (geocode /= 'P') alat_(2) = 1.0_gp
  if (geocode == 'F') then
     alat_(1)=1.0_gp
     alat_(3)=1.0_gp
  end if
  do i = 1, in%gen_nkpt, 1
     in%gen_kpt(:, i) = in%gen_kpt(:, i) / alat_(:) * two_pi
  end do
 
  in%band_structure_filename=''
  lstat = dict // BANDS
  if (lstat) then
     !calculate the number of groups of for the band structure
     in%nkptv=1
     nseg = dict_len(dict // ISEG)
     do i=1,nseg
        iseg_ = dict // ISEG // (i-1)
        in%nkptv=in%nkptv+iseg_
     end do
     ngranularity_ = dict // NGRANULARITY

     in%ngroups_kptv=&
          ceiling(real(in%nkptv,gp)/real(ngranularity_,gp))

     allocate(in%nkptsv_group(in%ngroups_kptv+ndebug),stat=i_stat)
     call memocc(i_stat,in%nkptsv_group,'in%nkptsv_group',subname)

     ncount=0
     do i=1,in%ngroups_kptv-1
        !if ngranularity is bigger than nkptv  then ngroups is one
        in%nkptsv_group(i)=ngranularity_
        ncount=ncount+ngranularity_
     end do
     !put the rest in the last group
     in%nkptsv_group(in%ngroups_kptv)=in%nkptv-ncount

     allocate(in%kptv(3,in%nkptv+ndebug),stat=i_stat)
     call memocc(i_stat,in%kptv,'in%kptv',subname)

     ikpt = 0
     do i=1,nseg
        iseg_ = dict // ISEG // (i-1)
        ikpt=ikpt+iseg_
        in%kptv(1,ikpt) = dict // KPTV // (ikpt - 1) // 0
        in%kptv(2,ikpt) = dict // KPTV // (ikpt - 1) // 1
        in%kptv(3,ikpt) = dict // KPTV // (ikpt - 1) // 2
        !interpolate the values
        do j=ikpt-iseg_+1,ikpt-1
           in%kptv(:,j)=in%kptv(:,ikpt-iseg_) + &
                (in%kptv(:,ikpt)-in%kptv(:,ikpt-iseg_)) * &
                real(j-ikpt+iseg_,gp)/real(iseg_, gp)
        end do
     end do

     ! Convert reduced coordinates into BZ coordinates.
     do i = 1, in%nkptv, 1
        in%kptv(:, i) = in%kptv(:, i) / alat_(:) * two_pi
     end do

     if (has_key(dict, BAND_STRUCTURE_FILENAME)) then
        in%band_structure_filename = dict // BAND_STRUCTURE_FILENAME
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
  else
     in%nkptv = 0
     allocate(in%kptv(3,in%nkptv+ndebug),stat=i_stat)
     call memocc(i_stat,in%kptv,'in%kptv',subname)
  end if

  if (in%nkptv > 0 .and. geocode == 'F' .and. iproc == 0) &
       & call yaml_warning('Defining a k-point path in free boundary conditions.') 
END SUBROUTINE kpt_input_analyse
