!> @file
!!  Linear version: Define Chebyshev polynomials
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 

 
!> Again assuming all matrices have same sparsity, still some tidying to be done
subroutine chebyshev_clean(iproc, nproc, npl, cc, orbs, foe_obj, kernel, ham_compr, &
           ovrlp_compr, calculate_SHS, nsize_polynomial, SHS, fermi, penalty_ev, chebyshev_polynomials, &
           emergency_stop)
  use module_base
  use module_types
  use module_interfaces, except_this_one => chebyshev_clean
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nproc, npl, nsize_polynomial
  real(8),dimension(npl,3),intent(in) :: cc
  type(orbitals_data),intent(in) :: orbs
  type(foe_data),intent(in) :: foe_obj
  type(sparse_matrix), intent(in) :: kernel
  real(kind=8),dimension(kernel%nvctr),intent(in) :: ham_compr, ovrlp_compr
  logical,intent(in) :: calculate_SHS
  real(kind=8),dimension(kernel%nvctr),intent(inout) :: SHS
  real(kind=8),dimension(orbs%norb,orbs%norbp),intent(out) :: fermi
  real(kind=8),dimension(orbs%norb,orbs%norbp,2),intent(out) :: penalty_ev
  real(kind=8),dimension(nsize_polynomial,npl),intent(out) :: chebyshev_polynomials
  logical,intent(out) :: emergency_stop
  ! Local variables
  integer :: iorb,iiorb, jorb, ipl,norb,norbp,isorb, ierr, nseq, nmaxsegk, nmaxvalk
  integer :: isegstart, isegend, iseg, ii, jjorb, nout
  character(len=*),parameter :: subname='chebyshev_clean'
  real(8), dimension(:,:,:), allocatable :: vectors
  real(kind=8),dimension(:),allocatable :: ham_compr_seq, ovrlp_compr_seq, SHS_seq
  real(kind=8),dimension(:,:),allocatable :: matrix
  real(kind=8) :: tt, ddot
  integer,dimension(:,:,:),allocatable :: istindexarr
  integer,dimension(:),allocatable :: ivectorindex
  integer,parameter :: one=1, three=3
  integer,parameter :: number_of_matmuls=one
  integer,dimension(:,:),pointer :: onedimindices

  call timing(iproc, 'chebyshev_comp', 'ON')

  norb = orbs%norb
  norbp = orbs%norbp
  isorb = orbs%isorb

  if (norbp>0) then

    
      ham_compr_seq = f_malloc(kernel%smmm%nseq,id='ham_compr_seq')
      ovrlp_compr_seq = f_malloc(kernel%smmm%nseq,id='ovrlp_compr_seq')
    
    
      if (number_of_matmuls==one) then
          matrix = f_malloc((/ orbs%norb, orbs%norbp /),id='matrix')
          SHS_seq = f_malloc(kernel%smmm%nseq,id='SHS_seq')
    
          if (norbp>0) then
              call to_zero(norb*norbp, matrix(1,1))
          end if
          !write(*,*) 'WARNING CHEBYSHEV: MODIFYING MATRIX MULTIPLICATION'
          if (orbs%norbp>0) then
              isegstart=kernel%istsegline(orbs%isorb_par(iproc)+1)
              if (orbs%isorb+orbs%norbp<orbs%norb) then
                  isegend=kernel%istsegline(orbs%isorb_par(iproc+1)+1)-1
              else
                  isegend=kernel%nseg
              end if
              do iseg=isegstart,isegend
                  ii=kernel%keyv(iseg)-1
                  do jorb=kernel%keyg(1,iseg),kernel%keyg(2,iseg)
                      ii=ii+1
                      iiorb = (jorb-1)/orbs%norb + 1
                      jjorb = jorb - (iiorb-1)*orbs%norb
                      matrix(jjorb,iiorb-orbs%isorb)=ovrlp_compr(ii)
                      !if (jjorb==iiorb) then
                      !    matrix(jjorb,iiorb-orbs%isorb)=1.d0
                      !else
                      !    matrix(jjorb,iiorb-orbs%isorb)=0.d0
                      !end if
                  end do
              end do
          end if
      end if
    
      !!call sequential_acces_matrix(norb, norbp, isorb, kernel%smmm%nseg, &
      !!     kernel%smmm%nsegline, kernel%smmm%istsegline, kernel%smmm%keyg, &
      !!     kernel, ham_compr, kernel%smmm%nseq, kernel%smmm%nmaxsegk, kernel%smmm%nmaxvalk, &
      !!     ham_compr_seq)
      call sequential_acces_matrix_fast(kernel%smmm%nseq, kernel%nvctr, &
           kernel%smmm%indices_extract_sequential, ham_compr, ham_compr_seq)
    
    
      !!call sequential_acces_matrix(norb, norbp, isorb, kernel%smmm%nseg, &
      !!     kernel%smmm%nsegline, kernel%smmm%istsegline, kernel%smmm%keyg, &
      !!     kernel, ovrlp_compr, kernel%smmm%nseq, kernel%smmm%nmaxsegk, kernel%smmm%nmaxvalk, &
      !!     ovrlp_compr_seq)
      call sequential_acces_matrix_fast(kernel%smmm%nseq, kernel%nvctr, &
           kernel%smmm%indices_extract_sequential, ovrlp_compr, ovrlp_compr_seq)

    
      vectors = f_malloc((/ norb, norbp, 4 /),id='vectors')
      if (norbp>0) then
          call to_zero(norb*norbp, vectors(1,1,1))
      end if
    
  end if
    
  if (number_of_matmuls==one) then
  
      if (calculate_SHS) then
  
          if (norbp>0) then
              call sparsemm(kernel%smmm%nseq, ham_compr_seq, matrix(1,1), vectors(1,1,1), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              call to_zero(norbp*norb, matrix(1,1))
              call sparsemm(kernel%smmm%nseq, ovrlp_compr_seq, vectors(1,1,1), matrix(1,1), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              !call to_zero(kernel%nvctr, SHS(1))
          end if
          call to_zero(kernel%nvctr, SHS(1))
          
          if (orbs%norbp>0) then
              isegstart=kernel%istsegline(orbs%isorb_par(iproc)+1)
              if (orbs%isorb+orbs%norbp<orbs%norb) then
                  isegend=kernel%istsegline(orbs%isorb_par(iproc+1)+1)-1
              else
                  isegend=kernel%nseg
              end if
              do iseg=isegstart,isegend
                  ii=kernel%keyv(iseg)-1
                  do jorb=kernel%keyg(1,iseg),kernel%keyg(2,iseg)
                      ii=ii+1
                      iiorb = (jorb-1)/orbs%norb + 1
                      jjorb = jorb - (iiorb-1)*orbs%norb
                      SHS(ii)=matrix(jjorb,iiorb-orbs%isorb)
                  end do
              end do
          end if
  
          call mpiallred(SHS(1), kernel%nvctr, mpi_sum, bigdft_mpi%mpi_comm)
  
      end if
  
      if (orbs%norbp>0) then
          !!call sequential_acces_matrix(norb, norbp, isorb, kernel%smmm%nseg, &
          !!     kernel%smmm%nsegline, kernel%smmm%istsegline, kernel%smmm%keyg, &
          !!     kernel, SHS, kernel%smmm%nseq, kernel%smmm%nmaxsegk, &
          !!     kernel%smmm%nmaxvalk, SHS_seq)
          call sequential_acces_matrix_fast(kernel%smmm%nseq, kernel%nvctr, &
               kernel%smmm%indices_extract_sequential, SHS, SHS_seq)
      end if
  
  end if

  !!if (iproc==0) then
  !!    do istat=1,kernel%nvctr
  !!        write(300,*) ham_compr(istat), SHS(istat)
  !!    end do
  !!end if
    
  if (norbp>0) then
    
      ! No need to set to zero the 3rd and 4th entry since they will be overwritten
      ! by copies of the 1st entry.
      if (norbp>0) then
          call to_zero(2*norb*norbp, vectors(1,1,1))
      end if
      do iorb=1,norbp
          iiorb=isorb+iorb
          vectors(iiorb,iorb,1)=1.d0
      end do
    
      if (norbp>0) then
    
          call vcopy(norb*norbp, vectors(1,1,1), 1, vectors(1,1,3), 1)
          call vcopy(norb*norbp, vectors(1,1,1), 1, vectors(1,1,4), 1)
        
          ! apply(3/2 - 1/2 S) H (3/2 - 1/2 S)
          if (number_of_matmuls==three) then
              call sparsemm(kernel%smmm%nseq, ovrlp_compr_seq, vectors(1,1,3), vectors(1,1,1), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              call sparsemm(kernel%smmm%nseq, ham_compr_seq, vectors(1,1,1), vectors(1,1,3), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              call sparsemm(kernel%smmm%nseq, ovrlp_compr_seq, vectors(1,1,3), vectors(1,1,1), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
          else if (number_of_matmuls==one) then
              call sparsemm(kernel%smmm%nseq, SHS_seq, vectors(1,1,3), vectors(1,1,1), &
                   norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
          end if
        
        
          call vcopy(norb*norbp, vectors(1,1,1), 1, vectors(1,1,2), 1)
        
          !initialize fermi
          call to_zero(norbp*norb, fermi(1,1))
          call to_zero(2*norb*norbp, penalty_ev(1,1,1))
          call compress_polynomial_vector(iproc, nsize_polynomial, orbs, kernel, &
               vectors(1,1,4), chebyshev_polynomials(1,1))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               0.5d0*cc(1,1), vectors(1,1,4), fermi(:,1))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               0.5d0*cc(1,3), vectors(1,1,4), penalty_ev(:,1,1))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               0.5d0*cc(1,3), vectors(1,1,4), penalty_ev(:,1,2))
          call compress_polynomial_vector(iproc, nsize_polynomial, orbs, kernel, vectors(1,1,2), chebyshev_polynomials(1,2))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               cc(2,1), vectors(1,1,2), fermi(:,1))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               cc(2,3), vectors(1,1,2), penalty_ev(:,1,1))
          call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
               -cc(2,3), vectors(1,1,2), penalty_ev(:,1,2))
        
        
          emergency_stop=.false.
          main_loop: do ipl=3,npl
              ! apply (3/2 - 1/2 S) H (3/2 - 1/2 S)
              if (number_of_matmuls==three) then
                  call sparsemm(kernel%smmm%nseq, ovrlp_compr_seq, vectors(1,1,1), vectors(1,1,2), &
                       norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
                  call sparsemm(kernel%smmm%nseq, ham_compr_seq, vectors(1,1,2), vectors(1,1,3), &
                       norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
                  call sparsemm(kernel%smmm%nseq, ovrlp_compr_seq, vectors(1,1,3), vectors(1,1,2), &
                       norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              else if (number_of_matmuls==one) then
                  call sparsemm(kernel%smmm%nseq, SHS_seq, vectors(1,1,1), vectors(1,1,2), &
                       norb, norbp, kernel%smmm%ivectorindex, kernel%smmm%nout, kernel%smmm%onedimindices)
              end if
              call axbyz_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   2.d0, vectors(1,1,2), -1.d0, vectors(1,1,4), vectors(1,1,3))
              call compress_polynomial_vector(iproc, nsize_polynomial, orbs, kernel, vectors(1,1,3), &
                   chebyshev_polynomials(1,ipl))
              call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   cc(ipl,1), vectors(1,1,3), fermi(:,1))
              call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   cc(ipl,3), vectors(1,1,3), penalty_ev(:,1,1))
         
              if (mod(ipl,2)==1) then
                  tt=cc(ipl,3)
              else
                  tt=-cc(ipl,3)
              end if
              call axpy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   tt, vectors(1,1,3), penalty_ev(:,1,2))
         
              call copy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   vectors(1,1,1), vectors(1,1,4))
              call copy_kernel_vectors(norbp, norb, kernel%smmm%nout, kernel%smmm%onedimindices, &
                   vectors(1,1,3), vectors(1,1,1))

              ! Check the norm of the columns of the kernel and set a flag if it explodes, which might
              ! be a consequence of the eigenvalue bounds being to small.
              do iorb=1,norbp
                  tt=ddot(norb, fermi(1,iorb), 1, fermi(1,iorb), 1)
                  if (abs(tt)>1.d3) then
                      emergency_stop=.true.
                      exit main_loop
                  end if
              end do
          end do main_loop
    
      end if

 
    
      call f_free(vectors)
      call f_free(ham_compr_seq)
      call f_free(ovrlp_compr_seq)
    
      if (number_of_matmuls==one) then
          call f_free(matrix)
          call f_free(SHS_seq)
      end if

  end if

  call timing(iproc, 'chebyshev_comp', 'OF')

end subroutine chebyshev_clean



! Performs z = a*x + b*y
subroutine axbyz_kernel_vectors(norbp, norb, nout, onedimindices, a, x, b, y, z)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer,intent(in) :: norbp, norb, nout
  integer,dimension(4,nout),intent(in) :: onedimindices
  real(8),intent(in) :: a, b
  real(kind=8),dimension(norb,norbp),intent(in) :: x, y
  real(kind=8),dimension(norb,norbp),intent(out) :: z

  ! Local variables
  integer :: i, jorb, iorb

  !$omp parallel default(private) shared(nout, onedimindices,a, b, x, y, z)
  !$omp do
  do i=1,nout
      iorb=onedimindices(1,i)
      jorb=onedimindices(2,i)
      z(jorb,iorb)=a*x(jorb,iorb)+b*y(jorb,iorb)
  end do
  !$omp end do
  !$omp end parallel

end subroutine axbyz_kernel_vectors



subroutine sparsemm(nseq, a_seq, b, c, norb, norbp, ivectorindex, nout, onedimindices)
  use module_base
  use module_types

  implicit none

  !Calling Arguments
  integer, intent(in) :: norb,norbp,nseq
  real(kind=8), dimension(norb,norbp),intent(in) :: b
  real(kind=8), dimension(nseq),intent(in) :: a_seq
  real(kind=8), dimension(norb,norbp), intent(out) :: c
  integer,dimension(nseq),intent(in) :: ivectorindex
  integer,intent(in) :: nout
  integer,dimension(4,nout) :: onedimindices

  !Local variables
  !character(len=*), parameter :: subname='sparsemm'
  integer :: i,jorb,jjorb,m,mp1
  integer :: iorb, ii0, ii2, ilen, jjorb0, jjorb1, jjorb2, jjorb3, jjorb4, jjorb5, jjorb6, iout
  real(kind=8) :: tt

  call timing(bigdft_mpi%iproc, 'sparse_matmul ', 'IR')

  !$omp parallel default(private) shared(ivectorindex, a_seq, b, c, onedimindices, nout)
  !$omp do
  do iout=1,nout
      i=onedimindices(1,iout)
      iorb=onedimindices(2,iout)
      ilen=onedimindices(3,iout)
      ii0=onedimindices(4,iout)
      ii2=0
      tt=0.d0

      m=mod(ilen,7)
      if (m/=0) then
          do jorb=1,m
             jjorb=ivectorindex(ii0+ii2)
             tt = tt + b(jjorb,i)*a_seq(ii0+ii2)
             ii2=ii2+1
          end do
      end if
      mp1=m+1
      do jorb=mp1,ilen,7

         jjorb0=ivectorindex(ii0+ii2+0)
         tt = tt + b(jjorb0,i)*a_seq(ii0+ii2+0)

         jjorb1=ivectorindex(ii0+ii2+1)
         tt = tt + b(jjorb1,i)*a_seq(ii0+ii2+1)

         jjorb2=ivectorindex(ii0+ii2+2)
         tt = tt + b(jjorb2,i)*a_seq(ii0+ii2+2)

         jjorb3=ivectorindex(ii0+ii2+3)
         tt = tt + b(jjorb3,i)*a_seq(ii0+ii2+3)

         jjorb4=ivectorindex(ii0+ii2+4)
         tt = tt + b(jjorb4,i)*a_seq(ii0+ii2+4)

         jjorb5=ivectorindex(ii0+ii2+5)
         tt = tt + b(jjorb5,i)*a_seq(ii0+ii2+5)

         jjorb6=ivectorindex(ii0+ii2+6)
         tt = tt + b(jjorb6,i)*a_seq(ii0+ii2+6)

         ii2=ii2+7
      end do
      c(iorb,i)=tt
  end do 
  !$omp end do
  !$omp end parallel

  call timing(bigdft_mpi%iproc, 'sparse_matmul ', 'RS')
    
end subroutine sparsemm



subroutine copy_kernel_vectors(norbp, norb, nout, onedimindices, a, b)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer,intent(in) :: norbp, norb, nout
  integer,dimension(4,nout),intent(in) :: onedimindices
  real(kind=8),dimension(norb,norbp),intent(in) :: a
  real(kind=8),dimension(norb,norbp),intent(out) :: b

  ! Local variables
  integer :: i, jorb, iorb


  !$omp parallel default(private) shared(nout, onedimindices,a, b)
  !$omp do
  do i=1,nout
      iorb=onedimindices(1,i)
      jorb=onedimindices(2,i)
      b(jorb,iorb)=a(jorb,iorb)
  end do
  !$omp end do
  !$omp end parallel


end subroutine copy_kernel_vectors




subroutine axpy_kernel_vectors(norbp, norb, nout, onedimindices, a, x, y)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer,intent(in) :: norbp, norb, nout
  integer,dimension(4,nout),intent(in) :: onedimindices
  real(kind=8),intent(in) :: a
  real(kind=8),dimension(norb,norbp),intent(in) :: x
  real(kind=8),dimension(norb,norbp),intent(inout) :: y

  ! Local variables
  integer :: i, jorb, iorb

  !$omp parallel default(private) shared(nout, onedimindices, y, x, a)
  !$omp do
  do i=1,nout
      iorb=onedimindices(1,i)
      jorb=onedimindices(2,i)
      y(jorb,iorb)=y(jorb,iorb)+a*x(jorb,iorb)
  end do
  !$omp end do
  !$omp end parallel


end subroutine axpy_kernel_vectors




subroutine determine_sequential_length(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, &
           sparsemat, nseq, nmaxsegk, nmaxvalk)
  use module_base
  use module_types
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  type(sparse_matrix),intent(in) :: sparsemat
  integer,intent(out) :: nseq, nmaxsegk, nmaxvalk

  ! Local variables
  integer :: i,iseg,jorb,iorb,jseg,ii
  integer :: isegoffset, istart, iend

  nseq=0
  nmaxsegk=0
  nmaxvalk=0
  do i = 1,norbp
     ii=isorb+i
     nmaxsegk=max(nmaxsegk,nsegline(ii))
     isegoffset=istsegline(ii)-1
     do iseg=1,nsegline(ii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          ! keyg is defined in terms of "global coordinates", so get the
          ! coordinate on a given line by using the mod function
          istart=mod(istart-1,norb)+1
          iend=mod(iend-1,norb)+1
          nmaxvalk=max(nmaxvalk,iend-istart+1)
          do iorb=istart,iend
              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                  do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                      nseq=nseq+1
                  end do
              end do
          end do
     end do
  end do 

end subroutine determine_sequential_length


subroutine get_nout(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, nout)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  integer,intent(out) :: nout

  ! Local variables
  integer :: i, iii, iseg, iorb, ii
  integer :: isegoffset, istart, iend

  nout=0
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          do iorb=istart,iend
              nout=nout+1
          end do
      end do
  end do

end subroutine get_nout



subroutine init_onedimindices(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, sparsemat, nout, onedimindices)
  use module_base
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  type(sparse_matrix),intent(in) :: sparsemat
  integer,intent(out) :: nout
  integer,dimension(:,:),pointer :: onedimindices

  ! Local variables
  integer :: i, iii, iseg, iorb, ii, jseg, ilen, itot
  integer :: isegoffset, istart, iend


  nout=0
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          do iorb=istart,iend
              nout=nout+1
          end do
      end do
  end do

  onedimindices = f_malloc_ptr((/ 4, nout /),id='onedimindices')

  ii=0
  itot=1
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          ! keyg is defined in terms of "global coordinates", so get the
          ! coordinate on a given line by using the mod function
          istart=mod(istart-1,norb)+1
          iend=mod(iend-1,norb)+1
          do iorb=istart,iend
              ii=ii+1
              onedimindices(1,ii)=i
              onedimindices(2,ii)=iorb
              ilen=0
              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                  ilen=ilen+sparsemat%keyg(2,jseg)-sparsemat%keyg(1,jseg)+1
              end do
              onedimindices(3,ii)=ilen
              onedimindices(4,ii)=itot
              itot=itot+ilen
          end do
      end do
  end do

end subroutine init_onedimindices



subroutine init_onedimindices_new(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, sparsemat, nout, onedimindices)
  use module_base
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  type(sparse_matrix),intent(in) :: sparsemat
  integer,intent(in) :: nout
  integer,dimension(4,nout) :: onedimindices

  ! Local variables
  integer :: i, iii, iseg, iorb, ii, jseg, ilen, itot
  integer :: isegoffset, istart, iend


  ii=0
  itot=1
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          ! keyg is defined in terms of "global coordinates", so get the
          ! coordinate on a given line by using the mod function
          istart=mod(istart-1,norb)+1
          iend=mod(iend-1,norb)+1
          do iorb=istart,iend
              ii=ii+1
              onedimindices(1,ii)=i
              onedimindices(2,ii)=iorb
              ilen=0
              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                  ilen=ilen+sparsemat%keyg(2,jseg)-sparsemat%keyg(1,jseg)+1
              end do
              onedimindices(3,ii)=ilen
              onedimindices(4,ii)=itot
              itot=itot+ilen
          end do
      end do
  end do

end subroutine init_onedimindices_new




subroutine get_arrays_for_sequential_acces(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, sparsemat, nseq, nmaxsegk, nmaxvalk, &
           ivectorindex)
  use module_base
  use module_types
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg, nseq, nmaxsegk, nmaxvalk
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  type(sparse_matrix),intent(in) :: sparsemat
  integer,dimension(nseq),intent(out) :: ivectorindex

  ! Local variables
  integer :: i,iseg,jorb,jjorb,iorb,jseg,ii,iii
  integer :: isegoffset, istart, iend


  ii=1
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          ! keyg is defined in terms of "global coordinates", so get the
          ! coordinate on a given line by using the mod function
          istart=mod(istart-1,norb)+1
          iend=mod(iend-1,norb)+1
          do iorb=istart,iend
              !!istindexarr(iorb-istart+1,iseg,i)=ii
              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                  do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                      jjorb = jorb - (iorb-1)*norb
                      ivectorindex(ii)=jjorb
                      ii = ii+1
                  end do
              end do
          end do
     end do
  end do 

end subroutine get_arrays_for_sequential_acces




!!subroutine sequential_acces_matrix(norb, norbp, isorb, nseg, &
!!           nsegline, istsegline, keyg, sparsemat, a, nseq, nmaxsegk, nmaxvalk, &
!!           a_seq)
!!  use module_base
!!  use module_types
!!  use sparsematrix_base, only: sparse_matrix
!!  implicit none
!!
!!  ! Calling arguments
!!  integer,intent(in) :: norb, norbp, isorb, nseg, nseq, nmaxsegk, nmaxvalk
!!  integer,dimension(norb),intent(in) :: nsegline, istsegline
!!  integer,dimension(2,nseg),intent(in) :: keyg
!!  type(sparse_matrix),intent(in) :: sparsemat
!!  real(kind=8),dimension(sparsemat%nvctr),intent(in) :: a
!!  real(kind=8),dimension(nseq),intent(out) :: a_seq
!!
!!  ! Local variables
!!  integer :: i,iseg,jorb,jj,iorb,jseg,ii,iii
!!  integer :: isegoffset, istart, iend
!!
!!
!!  ii=1
!!  do i = 1,norbp
!!     iii=isorb+i
!!     isegoffset=istsegline(iii)-1
!!     do iseg=1,nsegline(iii)
!!          istart=keyg(1,isegoffset+iseg)
!!          iend=keyg(2,isegoffset+iseg)
!!          ! keyg is defined in terms of "global coordinates", so get the
!!          ! coordinate on a given line by using the mod function
!!          istart=mod(istart-1,norb)+1
!!          iend=mod(iend-1,norb)+1
!!          do iorb=istart,iend
!!              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
!!                  jj=1
!!                  do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
!!                      a_seq(ii)=a(sparsemat%keyv(jseg)+jj-1)
!!                      jj = jj+1
!!                      ii = ii+1
!!                  end do
!!              end do
!!          end do
!!     end do
!!  end do 
!!
!!end subroutine sequential_acces_matrix



subroutine sequential_acces_matrix_fast(nseq, nvctr, indices_extract_sequential, a, a_seq)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in) :: nseq, nvctr
  integer,dimension(nseq),intent(in) :: indices_extract_sequential
  real(kind=8),dimension(nvctr),intent(in) :: a
  real(kind=8),dimension(nseq),intent(out) :: a_seq

  ! Local variables
  integer :: iseq, ii

  !$omp parallel do default(none) private(iseq, ii) &
  !$omp shared(nseq, indices_extract_sequential, a_seq, a)
  do iseq=1,nseq
      ii=indices_extract_sequential(iseq)
      a_seq(iseq)=a(ii)
  end do
  !$omp end parallel do

end subroutine sequential_acces_matrix_fast


subroutine init_sequential_acces_matrix(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, sparsemat, nseq, nmaxsegk, nmaxvalk, &
           indices_extract_sequential)
  use module_base
  use module_types
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: norb, norbp, isorb, nseg, nseq, nmaxsegk, nmaxvalk
  integer,dimension(norb),intent(in) :: nsegline, istsegline
  integer,dimension(2,nseg),intent(in) :: keyg
  type(sparse_matrix),intent(in) :: sparsemat
  integer,dimension(nseq),intent(out) :: indices_extract_sequential

  ! Local variables
  integer :: i,iseg,jorb,jj,iorb,jseg,ii,iii
  integer :: isegoffset, istart, iend


  ii=1
  do i = 1,norbp
     iii=isorb+i
     isegoffset=istsegline(iii)-1
     do iseg=1,nsegline(iii)
          istart=keyg(1,isegoffset+iseg)
          iend=keyg(2,isegoffset+iseg)
          ! keyg is defined in terms of "global coordinates", so get the
          ! coordinate on a given line by using the mod function
          istart=mod(istart-1,norb)+1
          iend=mod(iend-1,norb)+1
          do iorb=istart,iend
              do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                  jj=1
                  do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                      indices_extract_sequential(ii)=sparsemat%keyv(jseg)+jj-1
                      jj = jj+1
                      ii = ii+1
                  end do
              end do
          end do
     end do
  end do 

end subroutine init_sequential_acces_matrix


subroutine chebyshev_fast(iproc, nsize_polynomial, npl, orbs, fermi, chebyshev_polynomials, cc, kernelp)
  use module_base
  use module_types
  use sparsematrix_base, only: sparse_matrix
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nsize_polynomial, npl
  type(orbitals_data),intent(in) :: orbs
  type(sparse_matrix),intent(in) :: fermi
  real(kind=8),dimension(nsize_polynomial,npl),intent(in) :: chebyshev_polynomials
  real(kind=8),dimension(npl),intent(in) :: cc
  real(kind=8),dimension(orbs%norb,orbs%norbp),intent(out) :: kernelp

  ! Local variables
  integer :: ipl, iall
  real(kind=8),dimension(:),allocatable :: kernel_compressed


  if (nsize_polynomial>0) then
      kernel_compressed = f_malloc(nsize_polynomial,id='kernel_compressed')

      call to_zero(nsize_polynomial,kernel_compressed(1))
      !write(*,*) 'ipl, first element', 1, chebyshev_polynomials(1,1)
      call daxpy(nsize_polynomial, 0.5d0*cc(1), chebyshev_polynomials(1,1), 1, kernel_compressed(1), 1)
      do ipl=2,npl
      !write(*,*) 'ipl, first element', ipl, chebyshev_polynomials(1,ipl)
          call daxpy(nsize_polynomial, cc(ipl), chebyshev_polynomials(1,ipl), 1, kernel_compressed(1), 1)
      end do

      call uncompress_polynomial_vector(iproc, nsize_polynomial, orbs, fermi, kernel_compressed, kernelp)

      call f_free(kernel_compressed)
  end if

end subroutine chebyshev_fast
