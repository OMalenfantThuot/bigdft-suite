program driver_random
  use sparsematrix_base
  use sparsematrix_types, only: sparse_matrix
  use sparsematrix_init, only: generate_random_symmetric_sparsity_pattern, &
                               matrixindex_in_compressed, write_sparsematrix_info
  use sparsematrix, only: symmetrize_matrix, check_deviation_from_unity_sparse, &
                          matrix_power_dense_lapack, get_minmax_eigenvalues
  use sparsematrix_highlevel, only: matrix_chebyshev_expansion, matrices_init, &
                                    matrix_matrix_multiplication
  use sparsematrix_io, only: write_dense_matrix, write_sparse_matrix
  use random, only: builtin_rand
  use foe_base, only: foe_data, foe_data_deallocate
  use foe_common, only: init_foe
  implicit none

  ! Variables
  integer :: iproc, nproc, iseg, ierr, idum, ii, i, nthread, nfvctr, nvctr, nbuf_large, nbuf_mult
  type(sparse_matrix) :: smats
  type(sparse_matrix),dimension(1) :: smatl
  real(kind=4) :: tt_real
  real(mp) :: tt, tt_rel, eval_min, eval_max
  type(matrices) :: mat1, mat2
  type(matrices),dimension(3) :: mat3
  real(mp) :: condition_number, expo, max_error, mean_error, max_error_rel, mean_error_rel
  real(mp),dimension(:),allocatable :: charge_fake
  type(foe_data) :: ice_obj
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

  call f_malloc_set_status(memory_limit=0.e0,iproc=iproc)

  ! Initialize the sparse matrix errors and timings.
  call sparsematrix_init_errors
  call sparsematrix_initialize_timing_categories()

  ! Timing initialization
  call f_timing_reset(filename='time.yaml', master=(iproc==0), verbose_mode=.false.)

  if (iproc==0) then
      call yaml_scalar('',hfill='~')
      call yaml_scalar('DRIVER FOR THE CHEBYSHEV MATRIX EXPANSION',hfill='~')
  end if

  if (iproc==0) then
      call yaml_mapping_open('Parallel environment')
      call yaml_map('MPI tasks',nproc)
      nthread = 1
      !$ nthread = omp_get_max_threads()
      call yaml_map('OpenMP threads',nthread)
      call yaml_mapping_close()
  end if

  ! Read in the parameters for the run and print them.
  if (iproc==0) then
      call yaml_comment('Required input: nfvctr, nvctr, nbuf_large, nbuf_mult, condition_number, expo')
      read(*,*) nfvctr
      read(*,*) nvctr
      read(*,*) nbuf_large
      read(*,*) nbuf_mult
      read(*,*) condition_number
      read(*,*) expo
      call yaml_mapping_open('Input parameters')
      call yaml_map('Matrix dimension',nfvctr)
      call yaml_map('Number of non-zero entries',nvctr)
      call yaml_map('Buffer for large matrix',nbuf_large)
      call yaml_map('Buffer for sparse multiplications',nbuf_mult)
      call yaml_map('Condition number',condition_number)
      call yaml_map('Exponent for the matrix power calculation',expo)
      call yaml_mapping_close()
  end if

  ! Send the input parameters to all MPI tasks
  call mpibcast(nfvctr, root=0, comm=mpi_comm_world)
  call mpibcast(nvctr, root=0, comm=mpi_comm_world)
  call mpibcast(nbuf_large, root=0, comm=mpi_comm_world)
  call mpibcast(nbuf_mult, root=0, comm=mpi_comm_world)
  call mpibcast(condition_number, root=0, comm=mpi_comm_world)
  call mpibcast(expo, root=0, comm=mpi_comm_world)



  ! Generate a random sparsity pattern
  call generate_random_symmetric_sparsity_pattern(iproc, nproc, mpi_comm_world, &
       nfvctr, nvctr, nbuf_mult, .false., smats, &
       1, (/nbuf_large/), (/.true./), smatl)

  ! Write a summary of the sparse matrix layout 
  if (iproc==0) then
      call yaml_mapping_open('Matrix properties')
      call write_sparsematrix_info(smats, 'Random matrix')
      call write_sparsematrix_info(smatl(1), 'Large random matrix')
      call yaml_mapping_close()
  end if


  ! Initialize an object which holds some parameters for the Chebyshev expansion.
  ! It would also work without (then always the default values are taken), but when this
  ! object is provided some informations are stored between calls to the Chebyshev expansion,
  ! in this way improving the performance.
  ! Should maybe go to a wrapper.
  charge_fake = f_malloc0(1,id='charge_fake')
  call init_foe(iproc, nproc, 1, charge_fake, ice_obj, evlow=0.5_mp, evhigh=1.5_mp)
  call f_free(charge_fake)


  ! Allocate the matrices
  call matrices_init(smats, mat1)
  call matrices_init(smats, mat2)
  call matrices_init(smatl(1), mat3(1))
  call matrices_init(smatl(1), mat3(2))
  call matrices_init(smatl(1), mat3(3))

  ! Fill the matrix with random entries
  idum = 0
  tt_real = builtin_rand(idum, reset=.true.)
  do i=1,smats%nvctr
      tt_real = builtin_rand(idum)
      mat1%matrix_compr(i) = real(tt_real,kind=8)
  end do

  ! Symmetrize the matrix
  call symmetrize_matrix(smats, 'plus', mat1%matrix_compr, mat2%matrix_compr)

  ! By construction, all elements lie between 0 and 1. If we thus scale the
  ! matrix by the inverse of nfvctr (i.e. its dimension), then the sum of each line
  ! is between 0 and 1.
  call dscal(smats%nvctr, 1.0_mp/real(smats%nfvctr,kind=8), mat2%matrix_compr(1), 1)

  ! By construction, the sum of each line is between 0 and 1. If we thus set the diagonal
  ! to 1, we get a diagonally dominant matrix, which is positive definite.
  ! Additionally, we add to the diagonal elements a random number between 0 and the condition number.
  do i=1,smats%nfvctr
      ii = matrixindex_in_compressed(smats, i, i)
      tt_real = builtin_rand(idum)
      tt = real(tt_real,kind=8)*condition_number
      mat2%matrix_compr(ii) = 1.0_mp + tt
  end do

  ! Scale the matrix by the condition number, which should move down the largest
  ! eigenvalue of the order of 1.
  call dscal(smats%nvctr, 1.0_mp/condition_number, mat2%matrix_compr(1), 1)

  ! Initialization part done
  !call timing(mpi_comm_world,'INIT','PR')
  call f_timing_checkpoint(ctr_name='INIT',mpi_comm=mpiworld(),nproc=mpisize(),&
       gather_routine=gather_timings)

  ! Calculate the minimal and maximal eigenvalue, to determine the condition number
  call get_minmax_eigenvalues(iproc, smats, mat2, eval_min, eval_max)
  if (iproc==0) then
      call yaml_mapping_open('Eigenvalue properties')
      call yaml_map('Minimal',eval_min)
      call yaml_map('Maximal',eval_max)
      call yaml_map('Condition number',eval_max/eval_min)
      call yaml_mapping_close()
  end if

  call write_dense_matrix(iproc, nproc, mpi_comm_world, smats, mat2, 'randommatrix.dat', binary=.false.)
  call write_sparse_matrix(iproc, nproc, mpi_comm_world, smats, mat2, 'randommatrix_sparse.dat')

  call f_timing_checkpoint(ctr_name='INFO',mpi_comm=mpiworld(),nproc=mpisize(),&
       gather_routine=gather_timings)


  ! Calculate the desired matrix power
  if (iproc==0) then
      call yaml_comment('Calculating mat^x',hfill='~')
  end if
  call matrix_chebyshev_expansion(iproc, nproc, mpi_comm_world, &
       1, (/expo/), smats, smatl(1), mat2, mat3(1), ice_obj=ice_obj)

  ! Calculation part done
  !call timing(mpi_comm_world,'CALC','PR')
  call f_timing_checkpoint(ctr_name='CALC',mpi_comm=mpiworld(),nproc=mpisize(),&
       gather_routine=gather_timings)


  ! Calculate the inverse of the desired matrix power
  if (iproc==0) then
      call yaml_comment('Calculating mat^-x',hfill='~')
  end if
  call matrix_chebyshev_expansion(iproc, nproc, mpi_comm_world, &
       1, (/-expo/), smats, smatl(1), mat2, mat3(2), ice_obj=ice_obj)

  ! Multiply the two resulting matrices.
  if (iproc==0) then
      call yamL_comment('Calculating mat^x*mat^-x',hfill='~')
  end if
  call matrix_matrix_multiplication(iproc, nproc, smatl(1), mat3(1), mat3(2), mat3(3))

  ! Check the result
  call check_deviation_from_unity_sparse(iproc, smatl(1), mat3(3), max_error, mean_error)
  if (iproc==0) then
      call yaml_mapping_open('Check the deviation from unity of the operation mat^x*mat^-x')
      call yaml_map('max_error',max_error,fmt='(es10.3)')
      call yaml_map('mean_error',mean_error,fmt='(es10.3)')
      call yaml_mapping_close()
  end if

  !call timing(mpi_comm_world,'CHECK_LINEAR','PR')
  call f_timing_checkpoint(ctr_name='CHECK_LINEAR',mpi_comm=mpiworld(),nproc=mpisize(),&
       gather_routine=gather_timings)


  ! Do the operation using exact LAPACK and the dense matrices
  if (iproc==0) then
      call yaml_comment('Do the same calculation using dense LAPACK',hfill='~')
  end if
  !call operation_using_dense_lapack(iproc, nproc, smats_in, mat_in)
  call matrix_power_dense_lapack(iproc, nproc, expo, smats, smatl(1), mat2, mat3(3))
  call write_dense_matrix(iproc, nproc, mpi_comm_world, smatl(1), mat3(1), 'resultchebyshev.dat', binary=.false.)
  call write_dense_matrix(iproc, nproc, mpi_comm_world, smatl(1), mat3(3), 'resultlapack.dat', binary=.false.)
  max_error = 0.0_mp
  mean_error = 0.0_mp
  max_error_rel = 0.0_mp
  mean_error_rel = 0.0_mp
  do i=1,smatl(1)%nvctr
      tt = abs(mat3(1)%matrix_compr(i)-mat3(3)%matrix_compr(i))
      tt_rel = tt/abs(mat3(3)%matrix_compr(i))
      mean_error = mean_error + tt
      max_error = max(max_error,tt)
      mean_error_rel = mean_error_rel + tt_rel
      max_error_rel = max(max_error_rel,tt_rel)
  end do
  mean_error = mean_error/real(smatl(1)%nvctr,kind=8)
  mean_error_rel = mean_error_rel/real(smatl(1)%nvctr,kind=8)
  if (iproc==0) then
      call yaml_mapping_open('Check the deviation from the exact result using BLAS (only within the sparsity pattern)')
      call yaml_map('max error',max_error,fmt='(es10.3)')
      call yaml_map('mean error',mean_error,fmt='(es10.3)')
      call yaml_map('max error relative',max_error_rel,fmt='(es10.3)')
      call yaml_map('mean error relative',mean_error_rel,fmt='(es10.3)')
      call yaml_mapping_close()
  end if

  !call timing(mpi_comm_world,'CHECK_CUBIC','PR')
  call f_timing_checkpoint(ctr_name='CHECK_CUBIC',mpi_comm=mpiworld(),nproc=mpisize(),&
       gather_routine=gather_timings)


  ! Deallocate the sparse matrix descriptors type
  call deallocate_sparse_matrix(smats)
  call deallocate_sparse_matrix(smatl(1))

  ! Deallocat the sparse matrices
  call deallocate_matrices(mat1)
  call deallocate_matrices(mat2)
  call deallocate_matrices(mat3(1))
  call deallocate_matrices(mat3(2))
  call deallocate_matrices(mat3(3))

  ! Deallocate the object holding the parameters
  call foe_data_deallocate(ice_obj)

  ! Gather the timings
  call build_dict_info(iproc, nproc, dict_timing_info)
  call f_timing_stop(mpi_comm=mpi_comm_world, nproc=nproc, &
       gather_routine=gather_timings, dict_info=dict_timing_info)
  call dict_free(dict_timing_info)

  if (iproc==0) then
      call yaml_release_document()
  end if

  ! Finalize MPI
  call mpifinalize()

  ! Finalize flib
  call f_lib_finalize()



  !!!SM: This routine should go to a module
  !!contains
  !! !> construct the dictionary needed for the timing information
  !!  subroutine build_dict_info(dict_info)
  !!    !use module_base
  !!    use dynamic_memory
  !!    use dictionaries
  !!    implicit none
  !!    include 'mpif.h'
  !!    type(dictionary), pointer :: dict_info
  !!    !local variables
  !!    integer :: ierr,namelen,nthreads
  !!    character(len=MPI_MAX_PROCESSOR_NAME) :: nodename_local
  !!    character(len=MPI_MAX_PROCESSOR_NAME), dimension(:), allocatable :: nodename
  !!    type(dictionary), pointer :: dict_tmp
  !!    !$ integer :: omp_get_max_threads

  !!    call dict_init(dict_info)
! !! bastian: comment out 4 followinf lines for debug purposes (7.12.2014)
  !!    !if (DoLastRunThings) then
  !!       call f_malloc_dump_status(dict_summary=dict_tmp)
  !!       call set(dict_info//'Routines timing and number of calls',dict_tmp)
  !!    !end if
  !!    nthreads = 0
  !!    !$  nthreads=omp_get_max_threads()
  !!    call set(dict_info//'CPU parallelism'//'MPI tasks',nproc)
  !!    if (nthreads /= 0) call set(dict_info//'CPU parallelism'//'OMP threads',&
  !!         nthreads)

  !!    nodename=f_malloc0_str(MPI_MAX_PROCESSOR_NAME,0.to.nproc-1,id='nodename')
  !!    if (nproc>1) then
  !!       call MPI_GET_PROCESSOR_NAME(nodename_local,namelen,ierr)
  !!       !gather the result between all the process
  !!       call MPI_GATHER(nodename_local,MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,&
  !!            nodename(0),MPI_MAX_PROCESSOR_NAME,MPI_CHARACTER,0,&
  !!            mpi_comm_world,ierr)
  !!       if (iproc==0) call set(dict_info//'Hostnames',&
  !!               list_new(.item. nodename))
  !!    end if
  !!    call f_free_str(MPI_MAX_PROCESSOR_NAME,nodename)

  !!  end subroutine build_dict_info

end program driver_random
