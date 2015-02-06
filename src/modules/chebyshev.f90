!> @file
!!  Linear version: Define Chebyshev polynomials
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


module chebyshev

  implicit none

  private

  public :: chebyshev_clean
  public :: chebyshev_fast


  contains
 
    !> Again assuming all matrices have same sparsity, still some tidying to be done
    subroutine chebyshev_clean(iproc, nproc, npl, cc, kernel, ham_compr, &
               invovrlp_compr, calculate_SHS, nsize_polynomial, ncalc, fermi_new, penalty_ev_new, chebyshev_polynomials, &
               emergency_stop)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix, sparsematrix_malloc, assignment(=), &
                                   SPARSE_MATMUL_LARGE, SPARSEMM_SEQ,sparsematrix_malloc0
      use sparsematrix_init, only: matrixindex_in_compressed, get_line_and_column
      use sparsematrix, only: sequential_acces_matrix_fast, sequential_acces_matrix_fast2, &
                              compress_matrix_distributed_wrapper, sparsemm_new
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, npl, nsize_polynomial, ncalc
      real(8),dimension(npl,3,ncalc),intent(in) :: cc
      type(sparse_matrix), intent(in) :: kernel
      real(kind=8),dimension(kernel%nvctrp_tg),intent(in) :: ham_compr
      real(kind=8),dimension(kernel%nvctrp_tg),intent(in) :: invovrlp_compr
      logical,intent(in) :: calculate_SHS
      !!real(kind=8),dimension(kernel%nfvctr,kernel%smmm%nfvctrp,ncalc),intent(out) :: fermi
      !!real(kind=8),dimension(kernel%nfvctr,kernel%smmm%nfvctrp,2),intent(out) :: penalty_ev
      real(kind=8),dimension(kernel%smmm%nvctrp,ncalc),intent(out) :: fermi_new
      real(kind=8),dimension(kernel%smmm%nvctrp,2),intent(out) :: penalty_ev_new
      real(kind=8),dimension(nsize_polynomial,npl),intent(out) :: chebyshev_polynomials
      logical,intent(out) :: emergency_stop
      ! Local variables
      integer :: iorb,iiorb, jorb, ipl, ierr, nseq, nmaxvalk, i, j, iline, icolumn, jj
      integer :: isegstart, isegend, iseg, ii, jjorb, icalc
      character(len=*),parameter :: subname='chebyshev_clean'
      real(8), dimension(:,:,:), allocatable :: vectors
      real(8), dimension(:,:), allocatable :: vectors_new
      real(kind=8),dimension(:),allocatable :: mat_seq, mat_compr
      !!real(kind=8),dimension(:,:),allocatable :: matrix!, fermi_new, penalty_ev_new
      real(kind=8),dimension(:),allocatable :: matrix_new
      real(kind=8) :: tt, ddot
      integer :: jproc
    
      call timing(iproc, 'chebyshev_comp', 'ON')
      call f_routine(id='chebyshev_clean')
    
      !!kernel%nfvctr = kernel%nfvctr
      !!kernel%nfvctrp = kernel%nfvctrp
      !!kernel%isfvctr = kernel%isfvctr

      !!do i=1,size(ham_compr)
      !!    write(800+iproc,*) ham_compr(i)
      !!end do
    
      mat_compr = f_malloc(kernel%nvctrp_tg,id='mat_compr')
    
      if (calculate_SHS) then
          !!matrix = sparsematrix_malloc0(kernel, iaction=DENSE_MATMUL, id='matrix')
          matrix_new = f_malloc0(kernel%smmm%nvctrp,id='matrix')
      end if
      if (kernel%nfvctrp>0) then
    
        
        
          mat_seq = sparsematrix_malloc(kernel, iaction=SPARSEMM_SEQ, id='mat_seq')
        
          if (calculate_SHS) then
              if (kernel%smmm%nvctrp>0) then
                  do i=1,kernel%smmm%nvctrp
                      ii = kernel%smmm%isvctr + i
                      iline = kernel%smmm%line_and_column(1,i)
                      icolumn = kernel%smmm%line_and_column(2,i)
                      jj=matrixindex_in_compressed(kernel, icolumn, iline)
                      if (jj>0) then
                          matrix_new(i) = invovrlp_compr(jj-kernel%isvctrp_tg)
                      else
                          matrix_new(i) = 0.d0
                      end if
                  end do

              end if
          end if
          vectors_new = f_malloc0((/kernel%smmm%nvctrp,4/),id='vectors_new')
      end if
        
      
      if (calculate_SHS) then
      
          if (kernel%smmm%nvctrp>0) then
              call sequential_acces_matrix_fast2(kernel, ham_compr, mat_seq)
              call sparsemm_new(kernel, mat_seq, matrix_new(1), vectors_new(1,1))
              call f_zero(matrix_new)
              call sequential_acces_matrix_fast2(kernel, invovrlp_compr, mat_seq)
              call sparsemm_new(kernel, mat_seq, vectors_new(1,1), matrix_new(1))
          end if
          call compress_matrix_distributed_wrapper(iproc, nproc, kernel, SPARSE_MATMUL_LARGE, &
               matrix_new, mat_compr)
      else
          call vcopy(kernel%nvctrp_tg, ham_compr(1), 1, mat_compr(1), 1)
      end if
      
      if (kernel%smmm%nvctrp>0) then
          call sequential_acces_matrix_fast2(kernel, mat_compr, mat_seq)
      end if
      
        
      if (kernel%smmm%nfvctrp>0) then
        
          ! No need to set to zero the 3rd and 4th entry since they will be overwritten
          ! by copies of the 1st entry.
          if (kernel%smmm%nfvctrp>0) then
              call f_zero(2*kernel%smmm%nvctrp, vectors_new(1,1))
          end if
          do i=1,kernel%smmm%nvctrp
              ii = kernel%smmm%isvctr + i
              iline = kernel%smmm%line_and_column(1,i)
              icolumn = kernel%smmm%line_and_column(2,i)
              if (iline==icolumn) vectors_new(i,1) = 1.d0
          end do
        
          if (kernel%smmm%nvctrp>0) then

              call f_zero(fermi_new)
              call f_zero(penalty_ev_new)
        
              call vcopy(kernel%smmm%nvctrp, vectors_new(1,1), 1, vectors_new(1,3), 1)
              call vcopy(kernel%smmm%nvctrp, vectors_new(1,1), 1, vectors_new(1,4), 1)

              call compress_polynomial_vector_new(iproc, nproc, nsize_polynomial, &
                   kernel%nfvctr, kernel%smmm%nfvctrp, kernel, &
                   vectors_new(1,4), chebyshev_polynomials(1,1))

              do icalc=1,ncalc
                  call daxpy(kernel%smmm%nvctrp, 0.5d0*cc(1,1,icalc), vectors_new(1,4), 1, fermi_new(1,icalc), 1)
              end do
              call daxpy(kernel%smmm%nvctrp, 0.5d0*cc(1,3,1), vectors_new(1,4), 1, penalty_ev_new(1,1), 1)
              call daxpy(kernel%smmm%nvctrp, 0.5d0*cc(1,3,1), vectors_new(1,4), 1, penalty_ev_new(1,2), 1)
            
              call sparsemm_new(kernel, mat_seq, vectors_new(1,3), vectors_new(1,1))
              call vcopy(kernel%smmm%nvctrp, vectors_new(1,1), 1, vectors_new(1,2), 1)
    

              call compress_polynomial_vector_new(iproc, nproc, nsize_polynomial, &
                   kernel%nfvctr, kernel%smmm%nfvctrp, kernel, &
                   vectors_new(1,2), chebyshev_polynomials(1,2))
              do icalc=1,ncalc
                  call daxpy(kernel%smmm%nvctrp, cc(2,1,icalc), vectors_new(1,2), 1, fermi_new(1,icalc), 1)
              end do
              call daxpy(kernel%smmm%nvctrp, cc(2,3,1), vectors_new(1,2), 1, penalty_ev_new(1,1), 1)
              call daxpy(kernel%smmm%nvctrp, -cc(2,3,1), vectors_new(1,2), 1, penalty_ev_new(1,2), 1)
            
            
             !!write(*,*) 'before main_loop, iproc', iproc
              emergency_stop=.false.
              main_loop: do ipl=3,npl
                  !!write(*,*) 'ipl',ipl
                  ! apply (3/2 - 1/2 S) H (3/2 - 1/2 S)
                  !!if (number_of_matmuls==three) then
                  !!    call sparsemm(kernel, invovrlp_compr_seq, vectors(1,1,1), vectors(1,1,2))
                  !!    call sparsemm(kernel, ham_compr_seq, vectors(1,1,2), vectors(1,1,3))
                  !!    call sparsemm(kernel, invovrlp_compr_seq, vectors(1,1,3), vectors(1,1,2))
                  !!else if (number_of_matmuls==one) then
                      !!call sparsemm(kernel, mat_seq, vectors(1,1,1), vectors(1,1,2))
          !!do jproc=0,nproc-1
          !!    if (iproc==jproc) then
                  !!do i=1,size(vectors_new,1)
                  !!    write(5000+100*ipl+iproc,*) vectors_new(i,1)
                  !!end do
                  !!do i=1,size(mat_seq)
                  !!    write(1210+iproc,*) mat_seq(i)
                  !!end do
          !!    end if
          !!    call mpi_barrier(mpi_comm_world, ierr)
          !!end do
                      call sparsemm_new(kernel, mat_seq, vectors_new(1,1), vectors_new(1,2))
          !!do jproc=0,nproc-1
          !!    if (iproc==jproc) then
                  !!do i=1,size(vectors_new,1)
                  !!    write(6000+100*ipl+iproc,*) vectors_new(i,2)
                  !!end do
          !!    end if
          !!    call mpi_barrier(mpi_comm_world, ierr)
          !!end do
                  !!end if
                  !!call axbyz_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                  !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                  !!     2.d0, vectors(1,1,2), -1.d0, vectors(1,1,4), vectors(1,1,3))
                  call axbyz_kernel_vectors_new(kernel, 2.d0, vectors_new(1,2), -1.d0, vectors_new(1,4), vectors_new(1,3))
                  !!call compress_polynomial_vector(iproc, nproc, nsize_polynomial, &
                  !!     kernel%nfvctr, kernel%smmm%nfvctrp, kernel%smmm%isfvctr, kernel, vectors(1,1,3), &
                  !!     chebyshev_polynomials(1,ipl))
                  call compress_polynomial_vector_new(iproc, nproc, nsize_polynomial, &
                       kernel%nfvctr, kernel%smmm%nfvctrp, kernel, &
                       vectors_new(1,3), chebyshev_polynomials(1,ipl))
             !!write(*,*) 'main loop, after first compress, iproc, ipl', iproc, ipl
             !call mpi_barrier(bigdft_mpi%mpi_comm, icalc)
                  do icalc=1,ncalc
                      !!call axpy_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                      !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                      !!     cc(ipl,1,icalc), vectors(1,1,3), fermi(:,1,icalc))
                      call daxpy(kernel%smmm%nvctrp, cc(ipl,1,icalc), vectors_new(1,3), 1, fermi_new(1,icalc), 1)
                      !!tt = sum(fermi_new(:,icalc))
                      !!call mpiallred(tt, 1, mpi_sum, bigdft_mpi%mpi_comm)
                      !!if (iproc==0) write(*,*) 'sum(fermi_new(:,icalc)) 3',tt
                  !!do i=1,kernel%smmm%nfvctrp
                  !!    do j=1,kernel%nfvctr
                  !!        write(800,*) 'i, j, vals', vectors(j,i,4), fermi(j,i,icalc)
                  !!    end do
                  !!end do
                  end do
                  !!call axpy_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                  !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                  !!     cc(ipl,3,1), vectors(1,1,3), penalty_ev(:,1,1))
                  call daxpy(kernel%smmm%nvctrp, cc(ipl,3,1), vectors_new(1,3), 1, penalty_ev_new(1,1), 1)
                  !!write(*,*) 'sum(penalty_ev_new(:,1))',sum(penalty_ev_new(:,1))
             
                  if (mod(ipl,2)==1) then
                      tt=cc(ipl,3,1)
                  else
                      tt=-cc(ipl,3,1)
                  end if
                  !!call axpy_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                  !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                  !!     tt, vectors(1,1,3), penalty_ev(:,1,2))
                  call daxpy(kernel%smmm%nvctrp, tt, vectors_new(1,3), 1, penalty_ev_new(1,2), 1)
                  !!write(*,*) 'sum(penalty_ev_new(:,2))',sum(penalty_ev_new(:,2))
             
                  !!call copy_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                  !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                  !!     vectors(1,1,1), vectors(1,1,4))
                  call vcopy(kernel%smmm%nvctrp, vectors_new(1,1), 1, vectors_new(1,4), 1)
                  !!call copy_kernel_vectors(kernel, kernel%smmm%nfvctrp, kernel%nfvctr, &
                  !!     kernel%smmm%nout, kernel%smmm%onedimindices, &
                  !!     vectors(1,1,3), vectors(1,1,1))
                  call vcopy(kernel%smmm%nvctrp, vectors_new(1,3), 1, vectors_new(1,1), 1)
    
                  ! Check the norm of the columns of the kernel and set a flag if it explodes, which might
                  ! be a consequence of the eigenvalue bounds being to small. Only
                  ! check the first matrix to be calculated.
                  do iorb=1,kernel%smmm%nfvctrp
                      !!tt=ddot(kernel%nfvctr, fermi(1,iorb,1), 1, fermi(1,iorb,1), 1)
                      tt=ddot(kernel%smmm%nvctrp, fermi_new(1,1), 1, fermi_new(1,1), 1)
                      !!write(*,*) 'tt',tt
                      if (abs(tt)>1.d3) then
                          emergency_stop=.true.
                          !!write(*,*) 'exit on task',iproc
                          exit main_loop
                      end if
                  end do
              end do main_loop

             !!write(*,*) 'after main_loop, iproc', iproc
        
          end if
    
     
          !do i=1,kernel%smmm%nvctrp
          !    ii = kernel%smmm%isvctr + i
          !    call get_line_and_column(ii, kernel%smmm%nseg, kernel%smmm%keyv, kernel%smmm%keyg, iline, icolumn)
          !    do icalc=1,ncalc
          !        fermi(icolumn,iline-kernel%smmm%isfvctr,icalc) = fermi_new(i,icalc)
          !    end do
          !    penalty_ev(icolumn,iline-kernel%smmm%isfvctr,1) = penalty_ev_new(i,1)
          !    penalty_ev(icolumn,iline-kernel%smmm%isfvctr,2) = penalty_ev_new(i,2)
          !end do

          !call f_free(fermi_new)
          !call f_free(penalty_ev_new)
        
          if (calculate_SHS .and. kernel%smmm%nfvctrp>0) then
              !!call f_free(matrix)
              call f_free(matrix_new)
          end if
          if (kernel%smmm%nfvctrp>0) then
              call f_free(mat_seq)
              !!call f_free(vectors)
              call f_free(vectors_new)
          end if
          call f_free(mat_compr)
    
      end if
    
      call timing(iproc, 'chebyshev_comp', 'OF')
      call f_release_routine()
    
    end subroutine chebyshev_clean
    
    
    
    !!! Performs z = a*x + b*y
    !!subroutine axbyz_kernel_vectors(smat, norbp, norb, nout, onedimindices, a, x, b, y, z)
    !!  use module_base
    !!  use module_types
    !!  use sparsematrix_init, only: get_line_and_column
    !!  implicit none
    !!
    !!  ! Calling arguments
    !!  type(sparse_matrix),intent(in) :: smat
    !!  integer,intent(in) :: norbp, norb, nout
    !!  integer,dimension(4,nout),intent(in) :: onedimindices
    !!  real(8),intent(in) :: a, b
    !!  real(kind=8),dimension(norb,norbp),intent(in) :: x, y
    !!  real(kind=8),dimension(norb,norbp),intent(out) :: z
    !!
    !!  ! Local variables
    !!  integer :: i, jorb, iorb, ii, iline, icolumn
    !!  real(kind=8),dimension(:),allocatable :: x_compr, y_compr, z_compr

    !!  call f_routine(id='axbyz_kernel_vectors')
    !!
    !!  !!!$omp parallel default(private) shared(nout, onedimindices,a, b, x, y, z)
    !!  !!!$omp do
    !!  !!do i=1,nout
    !!  !!    iorb=onedimindices(1,i)
    !!  !!    jorb=onedimindices(2,i)
    !!  !!    z(jorb,iorb)=a*x(jorb,iorb)+b*y(jorb,iorb)
    !!  !!end do
    !!  !!!$omp end do
    !!  !!!$omp end parallel


    !!  ! @ WRAPPER #######################
    !!  x_compr = f_malloc0(smat%smmm%nvctrp,id='x_compr')
    !!  y_compr = f_malloc0(smat%smmm%nvctrp,id='y_compr')
    !!  z_compr = f_malloc0(smat%smmm%nvctrp,id='z_compr')
    !!  do i=1,smat%smmm%nvctrp
    !!      ii = smat%smmm%isvctr + i
    !!      call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!      if (icolumn<1) then
    !!          write(*,'(a,5i8)') 'iproc, i, ii, iline, icolumn', bigdft_mpi%iproc, i, ii, iline, icolumn
    !!          !stop
    !!      end if
    !!      x_compr(i) = x(icolumn,iline-smat%smmm%isfvctr)
    !!      y_compr(i) = y(icolumn,iline-smat%smmm%isfvctr)
    !!  end do
    !!  do i=1,smat%smmm%nvctrp
    !!      z_compr(i) = a*x_compr(i)+b*y_compr(i)
    !!  end do
    !!  do i=1,smat%smmm%nvctrp
    !!      ii = smat%smmm%isvctr + i
    !!      call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!      z(icolumn,iline-smat%smmm%isfvctr) = z_compr(i)
    !!  end do
    !!  call f_free(x_compr)
    !!  call f_free(y_compr)
    !!  call f_free(z_compr)
    !!  ! @ END WRAPPER ###################

    !!  call f_release_routine()
    !!
    !!end subroutine axbyz_kernel_vectors
    

    ! Performs z = a*x + b*y
    subroutine axbyz_kernel_vectors_new(smat, a, x_compr, b, y_compr, z_compr)
      use module_base
      use module_types
      use sparsematrix_init, only: get_line_and_column
      implicit none
    
      ! Calling arguments
      type(sparse_matrix),intent(in) :: smat
      real(8),intent(in) :: a, b
      real(kind=8),dimension(smat%smmm%nvctrp),intent(in) :: x_compr, y_compr
      real(kind=8),dimension(smat%smmm%nvctrp),intent(out) :: z_compr
    
      ! Local variables
      integer :: i, jorb, iorb, ii, iline, icolumn

      call f_routine(id='axbyz_kernel_vectors_new')
    
      do i=1,smat%smmm%nvctrp
          z_compr(i) = a*x_compr(i)+b*y_compr(i)
      end do

      call f_release_routine()
    
    end subroutine axbyz_kernel_vectors_new
    
    
    
    !!subroutine copy_kernel_vectors(smat, norbp, norb, nout, onedimindices, a, b)
    !!  use module_base
    !!  use module_types
    !!  use sparsematrix_init, only: get_line_and_column
    !!  implicit none
    !!
    !!  ! Calling arguments
    !!  type(sparse_matrix),intent(in) :: smat
    !!  integer,intent(in) :: norbp, norb, nout
    !!  integer,dimension(4,nout),intent(in) :: onedimindices
    !!  real(kind=8),dimension(norb,norbp),intent(in) :: a
    !!  real(kind=8),dimension(norb,norbp),intent(out) :: b
    !!
    !!  ! Local variables
    !!  integer :: i, jorb, iorb, iline, icolumn, ii
    !!  real(kind=8),dimension(:),allocatable :: a_compr, b_compr
    !!
    !!  call f_routine(id='copy_kernel_vectors')
    !!
    !!  !!!$omp parallel default(private) shared(nout, onedimindices,a, b)
    !!  !!!$omp do
    !!  !!do i=1,nout
    !!  !!    iorb=onedimindices(1,i)
    !!  !!    jorb=onedimindices(2,i)
    !!  !!    b(jorb,iorb)=a(jorb,iorb)
    !!  !!end do
    !!  !!!$omp end do
    !!  !!!$omp end parallel


    !!  ! @ WRAPPER #######################
    !!  a_compr = f_malloc0(smat%smmm%nvctrp,id='b_compr')
    !!  b_compr = f_malloc0(smat%smmm%nvctrp,id='b_compr')
    !!  do i=1,smat%smmm%nvctrp
    !!      ii = smat%smmm%isvctr + i
    !!      call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!      if (icolumn<1) then
    !!          write(*,'(a,5i8)') 'iproc, i, ii, iline, icolumn', bigdft_mpi%iproc, i, ii, iline, icolumn
    !!          !stop
    !!      end if
    !!      a_compr(i) = a(icolumn,iline-smat%smmm%isfvctr)
    !!  end do
    !!  call vcopy(smat%smmm%nvctrp, a_compr(1), 1, b_compr(1), 1)
    !!  do i=1,smat%smmm%nvctrp
    !!      ii = smat%smmm%isvctr + i
    !!      call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!      b(icolumn,iline-smat%smmm%isfvctr) = b_compr(i)
    !!  end do
    !!  call f_free(a_compr)
    !!  call f_free(b_compr)
    !!  ! @ END WRAPPER ###################
    !!
    !!  call f_release_routine()
    !!
    !!end subroutine copy_kernel_vectors
    
    
    
    
    !!subroutine axpy_kernel_vectors(smat, norbp, norb, nout, onedimindices, a, x, y)
    !!  use module_base
    !!  use module_types
    !!  use sparsematrix_init, only: get_line_and_column
    !!  implicit none
    !!
    !!  ! Calling arguments
    !!  type(sparse_matrix),intent(in) :: smat
    !!  integer,intent(in) :: norbp, norb, nout
    !!  integer,dimension(4,nout),intent(in) :: onedimindices
    !!  real(kind=8),intent(in) :: a
    !!  real(kind=8),dimension(norb,norbp),intent(in) :: x
    !!  real(kind=8),dimension(norb,norbp),intent(inout) :: y
    !!
    !!  ! Local variables
    !!  integer :: i, jorb, iorb, ii, iline, icolumn
    !!  real(kind=8),dimension(:),allocatable :: x_compr, y_compr

    !!  call f_routine(id='axpy_kernel_vectors')
    !!
    !!  !!!$omp parallel default(private) shared(nout, onedimindices, y, x, a)
    !!  !!!$omp do
    !!  !!do i=1,nout
    !!  !!    iorb=onedimindices(1,i)
    !!  !!    jorb=onedimindices(2,i)
    !!  !!    y(jorb,iorb)=y(jorb,iorb)+a*x(jorb,iorb)
    !!  !!end do
    !!  !!!$omp end do
    !!  !!!$omp end parallel

    !! ! @ WRAPPER #######################
    !! x_compr = f_malloc0(smat%smmm%nvctrp,id='x_compr')
    !! y_compr = f_malloc0(smat%smmm%nvctrp,id='y_compr')
    !! do i=1,smat%smmm%nvctrp
    !!     ii = smat%smmm%isvctr + i
    !!     call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!     if (icolumn<1) then
    !!         write(*,'(a,5i8)') 'iproc, i, ii, iline, icolumn', bigdft_mpi%iproc, i, ii, iline, icolumn
    !!         !stop
    !!     end if
    !!     x_compr(i) = x(icolumn,iline-smat%smmm%isfvctr)
    !!     y_compr(i) = y(icolumn,iline-smat%smmm%isfvctr)
    !! end do
    !! call daxpy(smat%smmm%nvctrp, a, x_compr(1), 1, y_compr(1), 1)
    !! do i=1,smat%smmm%nvctrp
    !!     ii = smat%smmm%isvctr + i
    !!     call get_line_and_column(ii, smat%smmm%nseg, smat%smmm%keyv, smat%smmm%keyg, iline, icolumn)
    !!     y(icolumn,iline-smat%smmm%isfvctr) = y_compr(i)
    !! end do
    !! call f_free(x_compr)
    !! call f_free(y_compr)
    !! ! @ END WRAPPER ###################

    !!
    !!  call f_release_routine()
    !!
    !!end subroutine axpy_kernel_vectors
    
    
    
    subroutine chebyshev_fast(iproc, nproc, nsize_polynomial, npl, &
               norb, norbp, fermi, chebyshev_polynomials, ncalc, cc, kernel_compressed)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix, sparsematrix_malloc, assignment(=),&
           SPARSE_FULL,sparsematrix_malloc0
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nsize_polynomial, npl, norb, norbp, ncalc
      type(sparse_matrix),intent(in) :: fermi
      real(kind=8),dimension(nsize_polynomial,npl),intent(in) :: chebyshev_polynomials
      real(kind=8),dimension(npl,ncalc),intent(in) :: cc
      real(kind=8),dimension(nsize_polynomial,ncalc),intent(out) :: kernel_compressed
    
      ! Local variables
      integer :: ipl, icalc
      !real(kind=8),dimension(:),allocatable :: kernel_compressed
    
      call f_routine(id='chebyshev_fast')
    
      if (nsize_polynomial>0) then
          !!kernel_compressed = sparsematrix_malloc0(fermi, iaction=SPARSE_FULL, id='kernel_compressed')
          call f_zero(kernel_compressed)
    
          !call f_zero(nsize_polynomial,kernel_compressed(1))
          do icalc=1,ncalc
              call daxpy(nsize_polynomial, 0.5d0*cc(1,icalc), chebyshev_polynomials(1,1), 1, kernel_compressed(1,icalc), 1)
              do ipl=2,npl
                  call daxpy(nsize_polynomial, cc(ipl,icalc), chebyshev_polynomials(1,ipl), 1, kernel_compressed(1,icalc), 1)
              end do
              !!call uncompress_polynomial_vector(iproc, nproc, nsize_polynomial, &
              !!     fermi, kernel_compressed, kernelp(1,1,icalc))
          end do
    
    
          !!call f_free(kernel_compressed)
      end if
    
      call f_release_routine()
    
    end subroutine chebyshev_fast

end module chebyshev
