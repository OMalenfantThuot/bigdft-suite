program driver_foe_css
  ! The following module are part of the sparsematrix library
  use sparsematrix_base
  use foe_base, only: foe_data, foe_data_deallocate
  use foe_common, only: init_foe
  use sparsematrix_highlevel, only: sparse_matrix_and_matrices_init_from_file_ccs, &
                                    sparse_matrix_init_from_file_ccs, matrices_init, &
                                    matrices_get_values, matrices_set_values, &
                                    sparse_matrix_init_from_data_ccs, &
                                    ccs_data_from_sparse_matrix, ccs_matrix_write, &
                                    matrix_matrix_multiplication, matrix_fermi_operator_expansion, &
                                    trace_A, trace_AB, sparse_matrix_metadata_init_from_file
  use sparsematrix, only: write_matrix_compressed, transform_sparse_matrix
  use sparsematrix_init, only: matrixindex_in_compressed, write_sparsematrix_info, &
                               get_number_of_electrons
  ! The following module is an auxiliary module for this test
  use utilities, only: get_ccs_data_from_file
  use futile
  implicit none

  ! Variables
  type(sparse_matrix) :: smat_s, smat_h, smat_k
  type(matrices) :: mat_s, mat_h, mat_k, mat_ek
  type(matrices),dimension(1) :: mat_ovrlpminusonehalf
  type(sparse_matrix_metadata) :: smmd
  integer :: nfvctr, nvctr, ierr, iproc, nproc, nthread, ncharge, nfvctr_mult, nvctr_mult
  integer,dimension(:),pointer :: row_ind, col_ptr, row_ind_mult, col_ptr_mult
  real(mp),dimension(:),pointer :: kernel, overlap, overlap_large
  real(mp),dimension(:),allocatable :: charge
  real(mp) :: energy, tr_KS, tr_KS_check
  type(foe_data) :: foe_obj, ice_obj
  real(mp) :: tr
  type(dictionary), pointer :: dict_timing_info
  external :: gather_timings
  !$ integer :: omp_get_max_threads

  ! Initialize flib
  call f_lib_initialize()

  ! MPI initialization; we have:
  ! iproc is the task ID
  ! nproc is the total number of tasks
  call mpiinit()
  iproc=mpirank()
  nproc=mpisize()

  ! Initialize the sparsematrix error handling and timing.
  call sparsematrix_init_errors()
  call sparsematrix_initialize_timing_categories()


  if (iproc==0) then
      call yaml_new_document()
      !call print_logo()
  end if

  !Time initialization
  call f_timing_reset(filename='time.yaml',master=(iproc==0),verbose_mode=.false.)

  if (iproc==0) then
      call yaml_scalar('',hfill='~')
      call yaml_scalar('CHESS FOE TEST DRIVER',hfill='~')
  end if

  if (iproc==0) then
      call yaml_mapping_open('Parallel environment')
      call yaml_map('MPI tasks',nproc)
      nthread = 1
      !$ nthread = omp_get_max_threads()
      call yaml_map('OpenMP threads',nthread)
      call yaml_mapping_close()
  end if


  ! Read from matrix1.dat and create the type containing the sparse matrix descriptors (smat_s) as well as
  ! the type which contains the matrix data (overlap). The matrix element are stored in mat_s%matrix_compr.
  ! Do the same also for matrix2.dat
  if (iproc==0) then
      call yaml_scalar('Initializing overlap matrix',hfill='-')
      call yaml_map('Reading from file','overlap_ccs.dat')
  end if
  call sparse_matrix_and_matrices_init_from_file_ccs('overlap_ccs.dat', &
       iproc, nproc, mpi_comm_world, smat_s, mat_s)

  if (iproc==0) then
      call yaml_scalar('Initializing Hamiltonian matrix',hfill='-')
      call yaml_map('Reading from file','hamiltonian_ccs.dat')
  end if
  call sparse_matrix_and_matrices_init_from_file_ccs('hamiltonian_ccs.dat', &
       iproc, nproc, mpi_comm_world, smat_h, mat_h)

  ! Create another matrix type, this time directly with the CCS format descriptors.
  ! Get these descriptors from an auxiliary routine using matrix3.dat
  if (iproc==0) then
      call yaml_scalar('Initializing Hamiltonian matrix',hfill='-')
      call yaml_map('Reading from file','density_kernel_ccs.dat')
  end if
  call get_ccs_data_from_file('density_kernel_ccs.dat', nfvctr, nvctr, row_ind, col_ptr)
  call get_ccs_data_from_file('density_kernel_matmul_ccs.dat', nfvctr_mult, nvctr_mult, row_ind_mult, col_ptr_mult)
  if (nfvctr_mult/=nfvctr) then
      call f_err_throw('nfvctr_mult/=nfvctr',err_name='SPARSEMATRIX_INITIALIZATION_ERROR')
  end if
  call sparse_matrix_init_from_data_ccs(iproc, nproc, mpi_comm_world, &
       nfvctr, nvctr, row_ind, col_ptr, smat_k, &
       init_matmul=.true., nvctr_mult=nvctr_mult, row_ind_mult=row_ind_mult, col_ptr_mult=col_ptr_mult)
  call f_free_ptr(row_ind)
  call f_free_ptr(col_ptr)
  call f_free_ptr(row_ind_mult)
  call f_free_ptr(col_ptr_mult)

  if (iproc==0) then
      call yaml_mapping_open('Matrix properties')
      call write_sparsematrix_info(smat_s, 'Overlap matrix')
      call write_sparsematrix_info(smat_h, 'Hamiltonian matrix')
      call write_sparsematrix_info(smat_k, 'Density kernel')
      call yaml_mapping_close()
  end if

  call sparse_matrix_metadata_init_from_file('sparsematrix_metadata.bin', smmd)
  call get_number_of_electrons(smmd, ncharge)
  if (iproc==0) then
      call yaml_map('Number of electrons',ncharge)
  end if

  ! Prepares the type containing the matrix data.
  call matrices_init(smat_k, mat_k)
  call matrices_init(smat_k, mat_ek)
  call matrices_init(smat_k, mat_ovrlpminusonehalf(1))

  ! Initialize the opaque object holding the parameters required for the Fermi Operator Expansion.
  ! Only provide the mandatory values and take for the optional values the default ones.
  charge = f_malloc(smat_s%nspin,id='charge')
  charge(:) = real(ncharge,kind=mp)
  call init_foe(iproc, nproc, smat_s%nspin, charge, foe_obj)
  ! Initialize the same object for the calculation of the inverse. Charge does not really make sense here...
  call init_foe(iproc, nproc, smat_s%nspin, charge, ice_obj, evlow=0.5_mp, evhigh=1.5_mp)

  call f_timing_checkpoint(ctr_name='INIT',mpi_comm=mpiworld(),nproc=mpisize(), &
       gather_routine=gather_timings)

  ! Calculate the density kernel for the system described by the pair smat_s/mat_s and smat_h/mat_h and 
  ! store the result in smat_k/mat_k.
  ! Attention: The sparsity pattern of smat_s must be contained within that of smat_h
  ! and the one of smat_h within that of smat_k. It is your responsabilty to assure this, 
  ! the routine does only some minimal checks.
  ! The final result will be contained in mat_k%matrix_compr.
  call matrix_fermi_operator_expansion(iproc, nproc, mpi_comm_world, &
       foe_obj, ice_obj, smat_s, smat_h, smat_k, &
       mat_s, mat_h, mat_ovrlpminusonehalf, mat_k, energy, &
       calculate_minusonehalf=.true., foe_verbosity=1, symmetrize_kernel=.true., &
       calculate_energy_density_kernel=.true., energy_kernel=mat_ek)

  call f_timing_checkpoint(ctr_name='CALC',mpi_comm=mpiworld(),nproc=mpisize(), &
       gather_routine=gather_timings)

  !tr = trace_A(iproc, nproc, mpi_comm_world, smat_k, mat_ek, 1)
  tr = trace_AB(iproc, nproc, mpi_comm_world, smat_s, smat_k, mat_s, mat_ek, 1)
  if (iproc==0) then
      call yaml_map('Energy from FOE',energy)
      call yaml_map('Trace of energy density kernel', tr)
      call yaml_map('Difference',abs(energy-tr))
  end if

  !! Write the result in YAML format to the standard output (required for non-regression tests).
  !if (iproc==0) call write_matrix_compressed('Result of FOE', smat_k, mat_k)

  ! Calculate trace(KS)
  !tr_KS = trace_sparse(iproc, nproc, smat_s, smat_k, mat_s%matrix_compr, mat_k%matrix_compr, 1)
  tr_KS = trace_AB(iproc, nproc, mpi_comm_world, smat_s, smat_k, mat_s, mat_k, 1)

  ! Write the result
  if (iproc==0) call yaml_map('trace(KS)',tr_KS)

  ! Extract the compressed kernel matrix from the data type.
  ! The first routine allocates an array with the correct size, the second one extracts the result.
  kernel = sparsematrix_malloc_ptr(smat_k, iaction=SPARSE_FULL, id='kernel')
  call matrices_get_values(smat_k, mat_k, kernel)

  ! Do the same also for the overlap matrix
  overlap = sparsematrix_malloc_ptr(smat_s, iaction=SPARSE_FULL, id='overlap')
  call matrices_get_values(smat_s, mat_s, overlap)

  ! Transform the overlap matrix to the sparsity pattern of the kernel
  overlap_large = sparsematrix_malloc_ptr(smat_k, iaction=SPARSE_FULL, id='overlap_large')
  call transform_sparse_matrix(iproc, smat_s, smat_k, SPARSE_FULL, 'small_to_large', &
       smat_in=overlap, lmat_out=overlap_large)

  ! Again calculate trace(KS), this time directly with the array holding the data.
  ! Since both matrices are symmetric and have now the same sparsity pattern, this is a simple ddot.
  tr_KS_check = dot(smat_k%nvctr, kernel(1), 1, overlap_large(1), 1)

  ! Write the result
  if (iproc==0) call yaml_map('trace(KS) check',tr_KS_check)

  ! Write the difference to the previous result
  if (iproc==0) call yaml_map('difference',tr_KS-tr_KS_check)

  ! Deallocate the object holding the FOE parameters
  call foe_data_deallocate(foe_obj)
  call foe_data_deallocate(ice_obj)

  ! Deallocate all the sparse matrix descriptors types
  call deallocate_sparse_matrix(smat_s)
  call deallocate_sparse_matrix(smat_h)
  call deallocate_sparse_matrix(smat_k)
  call deallocate_sparse_matrix_metadata(smmd)

  ! Deallocate all the matrix data types
  call deallocate_matrices(mat_s)
  call deallocate_matrices(mat_h)
  call deallocate_matrices(mat_k)
  call deallocate_matrices(mat_ek)
  call deallocate_matrices(mat_ovrlpminusonehalf(1))

  ! Deallocate all the remaining arrays
  call f_free(charge)
  call f_free_ptr(kernel)
  call f_free_ptr(overlap)
  call f_free_ptr(overlap_large)

  call f_timing_checkpoint(ctr_name='LAST',mpi_comm=mpiworld(),nproc=mpisize(), &
       gather_routine=gather_timings)

  call build_dict_info(dict_timing_info)
  call f_timing_stop(mpi_comm=mpi_comm_world,nproc=nproc,&
       gather_routine=gather_timings,dict_info=dict_timing_info)
  call dict_free(dict_timing_info)

  if (iproc==0) then
      call yaml_release_document()
  end if

  ! Finalize MPI
  call mpifinalize()

  ! Finalize flib
  ! SM: I have the impression that every task should call this routine, but if I do so
  ! some things are printed nproc times instead of once.
  if (iproc==0) then
      call f_lib_finalize()
  end if


  contains

    !> construct the dictionary needed for the timing information
    !! SM: This routine should go to a module
    subroutine build_dict_info(dict_info)
      use wrapper_MPI
      use dynamic_memory
      use dictionaries
      implicit none

      type(dictionary), pointer :: dict_info
      !local variables
      integer :: ierr,namelen,nthreads
      character(len=MPI_MAX_PROCESSOR_NAME) :: nodename_local
      character(len=MPI_MAX_PROCESSOR_NAME), dimension(:), allocatable :: nodename
      type(dictionary), pointer :: dict_tmp
      !$ integer :: omp_get_max_threads

      call dict_init(dict_info)
!  bastian: comment out 4 followinf lines for debug purposes (7.12.2014)
      !if (DoLastRunThings) then
         call f_malloc_dump_status(dict_summary=dict_tmp)
         call set(dict_info//'Routines timing and number of calls',dict_tmp)
      !end if
      nthreads = 0
      !$  nthreads=omp_get_max_threads()
      call set(dict_info//'CPU parallelism'//'MPI tasks',nproc)
      if (nthreads /= 0) call set(dict_info//'CPU parallelism'//'OMP threads',&
           nthreads)

      nodename=f_malloc0_str(MPI_MAX_PROCESSOR_NAME,0.to.nproc-1,id='nodename')
      if (nproc>1) then
         call MPI_GET_PROCESSOR_NAME(nodename_local,namelen,ierr)
         !gather the result between all the process
         call MPI_GATHER(nodename_local,MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,&
              nodename(0),MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,0,&
              mpi_comm_world,ierr)
         if (iproc==0) call set(dict_info//'Hostnames',&
                 list_new(.item. nodename))
      end if
      call f_free_str(MPI_MAX_PROCESSOR_NAME,nodename)

    end subroutine build_dict_info

end program driver_foe_css
