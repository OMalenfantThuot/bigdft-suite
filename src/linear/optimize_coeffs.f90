!> @file
!! Optimize the coefficients
!! @author
!!    Copyright (C) 2011-2012 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
!! NOTES: Coefficients are defined for Ntmb KS orbitals so as to maximize the number
!!        of orthonormality constraints. This should speedup the convergence by
!!        reducing the effective number of degrees of freedom.

subroutine optimize_coeffs(iproc, nproc, orbs, ham, ovrlp, tmb, ldiis_coeff, fnrm)
  use module_base
  use module_types
  use module_interfaces, except_this_one => optimize_coeffs
  implicit none

  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(orbitals_data),intent(in):: orbs
  type(DFT_wavefunction),intent(inout):: tmb
  real(8),dimension(tmb%orbs%norb,tmb%orbs%norb),intent(inout):: ham,ovrlp
  type(localizedDIISParameters),intent(inout):: ldiis_coeff
  real(8),intent(out):: fnrm

  ! Local variables
  integer:: iorb, jorb, korb, lorb, istat, iall, info, iiorb, ierr
  real(8),dimension(:,:),allocatable:: lagmat, rhs, ovrlp_tmp, coeff_tmp, ovrlp_coeff, gradp,coeffp
  integer,dimension(:),allocatable:: ipiv
  real(8):: tt, ddot, mean_alpha, dnrm2
  character(len=*),parameter:: subname='optimize_coeffs'

  allocate(lagmat(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, lagmat, 'lagmat', subname)

  allocate(rhs(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, rhs, 'rhs', subname)

  allocate(gradp(tmb%orbs%norb,tmb%orbs%norbp), stat=istat)
  call memocc(istat, gradp, 'gradp', subname)

  allocate(ipiv(tmb%orbs%norb), stat=istat)
  call memocc(istat, ipiv, 'ipiv', subname)

  allocate(ovrlp_tmp(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, ovrlp_tmp, 'ovrlp_tmp', subname)

  allocate(coeff_tmp(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, coeff_tmp, 'coeff_tmp', subname)

  allocate(ovrlp_coeff(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, ovrlp_coeff, 'ovrlp_coeff', subname)

  call timing(iproc,'dirmin_lagmat1','ON') !lr408t

  !call distribute_coefficients(orbs, tmb)

  ! Calculate the Lagrange multiplier matrix. Use ovrlp_coeff as temporary array.
  do iorb=1,tmb%orbs%norbp
      iiorb=tmb%orbs%isorb+iorb
      do jorb=1,tmb%orbs%norb
          tt=0.d0
          do korb=1,tmb%orbs%norb
              do lorb=1,tmb%orbs%norb
                  tt=tt+tmb%wfnmd%coeff(korb,jorb)*tmb%wfnmd%coeff(lorb,iiorb)*ham(lorb,korb)
              end do
          end do
          ovrlp_coeff(jorb,iorb)=tt
      end do
  end do

  ! Gather together the complete matrix
  if (nproc > 1) then
     call mpi_allgatherv(ovrlp_coeff(1,1), tmb%orbs%norb*tmb%orbs%norbp, mpi_double_precision, lagmat(1,1), &
          tmb%orbs%norb*tmb%orbs%norb_par(:,0), tmb%orbs%norb*tmb%orbs%isorb_par, mpi_double_precision, bigdft_mpi%mpi_comm, ierr)
  else
     call vcopy(tmb%orbs%norb*tmb%orbs%norb,ovrlp_coeff(1,1),1,lagmat(1,1),1)
  end if

  call timing(iproc,'dirmin_lagmat1','OF') !lr408t
  call timing(iproc,'dirmin_lagmat2','ON') !lr408t

! Calculate the right hand side
  rhs=0.d0
  do iorb=1,tmb%orbs%norbp
      iiorb=tmb%orbs%isorb+iorb
      do lorb=1,tmb%orbs%norb
          tt=0.d0
          do korb=1,tmb%orbs%norb
              tt=tt+tmb%wfnmd%coeff(korb,iiorb)*ham(korb,lorb)
          end do
          do jorb=1,tmb%orbs%norb
              do korb=1,tmb%orbs%norb
                  tt=tt-lagmat(jorb,iiorb)*tmb%wfnmd%coeff(korb,jorb)*ovrlp(korb,lorb)
              end do
          end do
          rhs(lorb,iiorb)=tt*orbs%occup(iiorb)
      end do
  end do

  call mpiallred(rhs(1,1), tmb%orbs%norb*tmb%orbs%norb, mpi_sum, bigdft_mpi%mpi_comm, ierr)

  ! Solve the linear system ovrlp*grad=rhs
  call dcopy(tmb%orbs%norb**2, ovrlp(1,1), 1, ovrlp_tmp(1,1), 1)
  call timing(iproc,'dirmin_lagmat2','OF') !lr408t
  call timing(iproc,'dirmin_dgesv','ON') !lr408t

  info = 0 ! needed for when some processors have orbs%orbp=0
  if(tmb%wfnmd%bpo%blocksize_pdsyev<0) then
      if (orbs%norbp>0) then
          call dgesv(tmb%orbs%norb, tmb%orbs%norbp, ovrlp_tmp(1,1), tmb%orbs%norb, ipiv(1), &
               rhs(1,tmb%orbs%isorb+1), tmb%orbs%norb, info)
      end if
  else
      call mpiallred(rhs(1,1), tmb%orbs%norb*tmb%orbs%norb, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call dgesv_parallel(iproc, tmb%wfnmd%bpo%nproc_pdsyev, tmb%wfnmd%bpo%blocksize_pdsyev, bigdft_mpi%mpi_comm, &
           tmb%orbs%norb, tmb%orbs%norb, ovrlp_tmp, tmb%orbs%norb, rhs, tmb%orbs%norb, info)
  end if

  if(info/=0) then
      write(*,'(a,i0)') 'ERROR in dgesv: info=',info
      stop
  end if

  call dcopy(tmb%orbs%norb*tmb%orbs%norbp, rhs(1,tmb%orbs%isorb+1), 1, gradp(1,1), 1)
  call timing(iproc,'dirmin_dgesv','OF') !lr408t

  ! Precondition the gradient (only making things worse...)
  !call precondition_gradient_coeff(tmb%orbs%norb, tmb%orbs%norbp, ham, ovrlp, gradp)

  call timing(iproc,'dirmin_sddiis','ON') !lr408t

  ! Improve the coefficients
  if (ldiis_coeff%isx > 0) then
      ldiis_coeff%mis=mod(ldiis_coeff%is,ldiis_coeff%isx)+1
      ldiis_coeff%is=ldiis_coeff%is+1
  end if  

  if (ldiis_coeff%isx > 1 .and. .false.) then !do DIIS
  !TO DO: make sure DIIS communicates coeff correctly
     call DIIS_coeff(iproc, nproc, orbs, tmb, gradp, tmb%wfnmd%coeff, ldiis_coeff)
  else  !steepest descent
     allocate(coeffp(tmb%orbs%norb,tmb%orbs%norbp),stat=istat)
     call memocc(istat, coeffp, 'coeffp', subname)
     do iorb=1,tmb%orbs%norbp
        iiorb=tmb%orbs%isorb+iorb
        do jorb=1,tmb%orbs%norb
           coeffp(jorb,iorb)=tmb%wfnmd%coeff(jorb,iiorb)-tmb%wfnmd%alpha_coeff(iiorb)*gradp(jorb,iorb)
        end do
     end do
     if(nproc > 1) then 
        call mpi_allgatherv(coeffp(1,1), tmb%orbs%norb*tmb%orbs%norbp, mpi_double_precision, tmb%wfnmd%coeff(1,1), &
           tmb%orbs%norb*tmb%orbs%norb_par(:,0), tmb%orbs%norb*tmb%orbs%isorb_par, mpi_double_precision, bigdft_mpi%mpi_comm, ierr)
     else
        call dcopy(tmb%orbs%norb**2,coeffp(1,1),1,tmb%wfnmd%coeff(1,1),1)
     end if
     iall=-product(shape(coeffp))*kind(coeffp)
     deallocate(coeffp, stat=istat)
     call memocc(istat, iall, 'coeffp', subname)
  end if


  if(iproc==0) write(50,*) tmb%wfnmd%coeff

  !For fnrm, we only sum on the occupied KS orbitals
  tt=0.d0
  do iorb=1,tmb%orbs%norbp
      print *,'norm gradp',iorb+tmb%orbs%isorb, ddot(tmb%orbs%norb, gradp(1,iorb), 1, gradp(1,iorb), 1)
      tt=tt+ddot(tmb%orbs%norb, gradp(1,iorb), 1, gradp(1,iorb), 1)
  end do
  call mpiallred(tt, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
  fnrm=sqrt(tt/dble(tmb%orbs%norb))
  tmb%wfnmd%it_coeff_opt=tmb%wfnmd%it_coeff_opt+1

  if(tmb%wfnmd%it_coeff_opt>1) then
      mean_alpha=0.d0
      do iorb=1,tmb%orbs%norbp
          iiorb=tmb%orbs%isorb+iorb
          tt=ddot(tmb%orbs%norb, gradp(1,iorb), 1, tmb%wfnmd%grad_coeff_old(1,iorb), 1)
          tt=tt/(dnrm2(tmb%orbs%norb, gradp(1,iorb), 1)*dnrm2(tmb%orbs%norb, tmb%wfnmd%grad_coeff_old(1,iorb), 1))
          !if(iproc==0) write(*,*) 'iorb, tt', iorb, tt
          if(tt>.85d0) then
              tmb%wfnmd%alpha_coeff(iiorb)=1.1d0*tmb%wfnmd%alpha_coeff(iiorb)
          else
              tmb%wfnmd%alpha_coeff(iiorb)=0.5d0*tmb%wfnmd%alpha_coeff(iiorb)
          end if
          !print *,'iproc,alpha',iproc,iiorb,tmb%wfnmd%alpha_coeff(iiorb),tt
          mean_alpha=mean_alpha+tmb%wfnmd%alpha_coeff(iiorb)
      end do
      mean_alpha=mean_alpha/dble(tmb%orbs%norb)
      call mpiallred(mean_alpha, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      if(iproc==0) write(*,*) 'mean_alpha',mean_alpha
  end if


  call dcopy(tmb%orbs%norb*tmb%orbs%norbp, gradp(1,1), 1, tmb%wfnmd%grad_coeff_old(1,1), 1)

  call timing(iproc,'dirmin_sddiis','OF') !lr408t


  iall=-product(shape(lagmat))*kind(lagmat)
  deallocate(lagmat, stat=istat)
  call memocc(istat, iall, 'lagmat', subname)

  iall=-product(shape(rhs))*kind(rhs)
  deallocate(rhs, stat=istat)
  call memocc(istat, iall, 'rhs', subname)

  iall=-product(shape(gradp))*kind(gradp)
  deallocate(gradp, stat=istat)
  call memocc(istat, iall, 'gradp', subname)

  iall=-product(shape(ipiv))*kind(ipiv)
  deallocate(ipiv, stat=istat)
  call memocc(istat, iall, 'ipiv', subname)

  iall=-product(shape(ovrlp_tmp))*kind(ovrlp_tmp)
  deallocate(ovrlp_tmp, stat=istat)
  call memocc(istat, iall, 'ovrlp_tmp', subname)

  iall=-product(shape(coeff_tmp))*kind(coeff_tmp)
  deallocate(coeff_tmp, stat=istat)
  call memocc(istat, iall, 'coeff_tmp', subname)

  iall=-product(shape(ovrlp_coeff))*kind(ovrlp_coeff)
  deallocate(ovrlp_coeff, stat=istat)
  call memocc(istat, iall, 'ovrlp_coeff', subname)

end subroutine optimize_coeffs

!Just to test without MPI
!must also change the size of grad_coeff_old from norbp to norb in initAndUtils.f90
subroutine optimize_coeffs2(iproc, nproc, orbs, ham, ovrlp, tmb, ldiis_coeff, fnrm)
  use module_base
  use module_types
  use module_interfaces, except_this_one => optimize_coeffs
  implicit none

  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(orbitals_data),intent(in):: orbs
  type(DFT_wavefunction),intent(inout):: tmb
  real(8),dimension(tmb%orbs%norb,tmb%orbs%norb),intent(in):: ham,ovrlp
  type(localizedDIISParameters),intent(inout):: ldiis_coeff
  real(8),intent(out):: fnrm

  ! Local variables
  integer:: iorb, jorb, istat, iall, info
  integer:: ialpha, ibeta
  real(8),dimension(:,:),allocatable:: lagmat, rhs, ovrlp_tmp, coeff_tmp, ovrlp_coeff, grad
  integer,dimension(:),allocatable:: ipiv
  real(8):: tt, ddot, mean_alpha, dnrm2
  character(len=*),parameter:: subname='optimize_coeffs2'

  allocate(lagmat(orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, lagmat, 'lagmat', subname)

  allocate(rhs(tmb%orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, rhs, 'rhs', subname)

  allocate(grad(tmb%orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, grad, 'grad', subname)


  allocate(ovrlp_tmp(tmb%orbs%norb,tmb%orbs%norb), stat=istat)
  call memocc(istat, ovrlp_tmp, 'ovrlp_tmp', subname)

  allocate(coeff_tmp(tmb%orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, coeff_tmp, 'coeff_tmp', subname)

  allocate(ovrlp_coeff(orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, ovrlp_coeff, 'ovrlp_coeff', subname)


  call timing(iproc,'dirmin_lagmat1','ON') !lr408t

  ! Calculate the Lagrange multiplier matrix. Use ovrlp_coeff as temporary array.
  do iorb=1,orbs%norb
      do jorb=1,orbs%norb
          tt=0.d0
          do ialpha=1,tmb%orbs%norb
              do ibeta=1,tmb%orbs%norb
                  tt=tt+tmb%wfnmd%coeff(ialpha,jorb)*tmb%wfnmd%coeff(ibeta,iorb)*ham(ialpha,ibeta)
              end do
          end do
          ovrlp_coeff(jorb,iorb)=tt
      end do
  end do

  call vcopy(orbs%norb*orbs%norb,ovrlp_coeff(1,1),1,lagmat(1,1),1)

  call timing(iproc,'dirmin_lagmat1','OF') !lr408t
  call timing(iproc,'dirmin_lagmat2','ON') !lr408t

  ! Calculate the right hand side
  rhs=0.d0
  do iorb=1,orbs%norb
      do ialpha=1,tmb%orbs%norb
          tt=0.d0
          do ibeta=1,tmb%orbs%norb
              tt=tt+tmb%wfnmd%coeff(ibeta,iorb)*ham(ibeta,ialpha)
          end do
          do jorb=1,orbs%norb
              do ibeta=1,tmb%orbs%norb
                  tt=tt-lagmat(jorb,iorb)*tmb%wfnmd%coeff(ibeta,jorb)*ovrlp(ibeta,ialpha)
              end do
          end do
          rhs(ialpha,iorb)=tt*orbs%occup(iorb)
      end do
  end do

  ! Solve the linear system ovrlp*grad=rhs
  call dcopy(tmb%orbs%norb**2, ovrlp(1,1), 1, ovrlp_tmp(1,1), 1)

  call timing(iproc,'dirmin_lagmat2','OF') !lr408t
  call timing(iproc,'dirmin_dgesv','ON') !lr408t

  info = 0 ! needed for when some processors have orbs%orbp=0
  if(tmb%wfnmd%bpo%blocksize_pdsyev<0) then
     allocate(ipiv(tmb%orbs%norb), stat=istat)
     call memocc(istat, ipiv, 'ipiv', subname)
     call dgesv(tmb%orbs%norb, orbs%norb, ovrlp_tmp(1,1), tmb%orbs%norb, ipiv(1), &
          rhs(1,1), tmb%orbs%norb, info)
     iall=-product(shape(ipiv))*kind(ipiv)
     deallocate(ipiv, stat=istat)
     call memocc(istat, iall, 'ipiv', subname)
  else
     call dgesv_parallel(iproc, tmb%wfnmd%bpo%nproc_pdsyev, tmb%wfnmd%bpo%blocksize_pdsyev, bigdft_mpi%mpi_comm, &
          tmb%orbs%norb, orbs%norb, ovrlp_tmp, tmb%orbs%norb, rhs, tmb%orbs%norb, info)
  end if

  if(info/=0) then
      write(*,'(a,i0)') 'ERROR in dgesv: info=',info
      stop
  end if

  call dcopy(tmb%orbs%norb*orbs%norb, rhs(1,1), 1, grad(1,1), 1)
  call timing(iproc,'dirmin_dgesv','OF') !lr408t

  ! Precondition the gradient (only making things worse...)
  !call precondition_gradient_coeff(tmb%orbs%norb, orbs%norbp, ham, ovrlp, gradp)

  call timing(iproc,'dirmin_sddiis','ON') !lr408t

  ! Improve the coefficients
  if (ldiis_coeff%isx > 0) then
      ldiis_coeff%mis=mod(ldiis_coeff%is,ldiis_coeff%isx)+1
      ldiis_coeff%is=ldiis_coeff%is+1
  end if  

  if (.false. .and. ldiis_coeff%isx > 1) then !do DIIS, must change this for non parallel
     call DIIS_coeff(iproc, nproc, orbs, tmb, grad, tmb%wfnmd%coeff, ldiis_coeff)
  else  !steepest descent
     do iorb=1,orbs%norb
        do ialpha=1,tmb%orbs%norb
           tmb%wfnmd%coeff(ialpha,iorb)=tmb%wfnmd%coeff(ialpha,iorb)-tmb%wfnmd%alpha_coeff(iorb)*grad(ialpha,iorb)
        end do
     end do
  end if

  tt=0.d0
  do iorb=1,orbs%norb
      print *,'norm gradp',iorb+tmb%orbs%isorb, ddot(tmb%orbs%norb, grad(1,iorb), 1, grad(1,iorb), 1)
      tt=tt+ddot(tmb%orbs%norb, grad(1,iorb), 1, grad(1,iorb), 1)
  end do
  fnrm=sqrt(tt/dble(orbs%norb))

  tmb%wfnmd%it_coeff_opt=tmb%wfnmd%it_coeff_opt+1
  if(tmb%wfnmd%it_coeff_opt>1) then
      mean_alpha=0.d0
      do iorb=1,orbs%norb
          tt=ddot(tmb%orbs%norb, grad(1,iorb), 1, tmb%wfnmd%grad_coeff_old(1,iorb), 1)
          tt=tt/(dnrm2(tmb%orbs%norb, grad(1,iorb), 1)*dnrm2(tmb%orbs%norb, tmb%wfnmd%grad_coeff_old(1,iorb), 1))
          if(tt>.85d0) then
              tmb%wfnmd%alpha_coeff(iorb)=1.1d0*tmb%wfnmd%alpha_coeff(iorb)
          else
              tmb%wfnmd%alpha_coeff(iorb)=0.5d0*tmb%wfnmd%alpha_coeff(iorb)
          end if
          mean_alpha=mean_alpha+tmb%wfnmd%alpha_coeff(iorb)
      end do
      mean_alpha=mean_alpha/dble(orbs%norb)
      if(iproc==0) write(*,*) 'mean_alpha',mean_alpha
  end if

  call dcopy(tmb%orbs%norb*orbs%norb, grad(1,1), 1, tmb%wfnmd%grad_coeff_old(1,1), 1)

  call timing(iproc,'dirmin_sddiis','OF') !lr408t
  call timing(iproc,'dirmin_lowdin1','ON') !lr408t
  
  ! Normalize the coefficients (Loewdin)
  ! Calculate the overlap matrix among the coefficients with resct to ovrlp. Use lagmat as temporary array.
  call dgemm('n', 'n', tmb%orbs%norb, orbs%norb, tmb%orbs%norb, 1.d0, ovrlp(1,1), tmb%orbs%norb, &
       tmb%wfnmd%coeff(1,1), tmb%orbs%norb, 0.d0, coeff_tmp(1,1), tmb%orbs%norb)
  do iorb=1,orbs%norb
      do jorb=1,orbs%norb
          lagmat(jorb,iorb)=ddot(tmb%orbs%norb, tmb%wfnmd%coeff(1,jorb), 1, coeff_tmp(1,iorb), 1)
      end do
  end do
  call timing(iproc,'dirmin_lowdin1','OF') !lr408t
  call timing(iproc,'dirmin_lowdin2','ON') !lr408t
  call vcopy(orbs%norb*orbs%norb,lagmat(1,1),1,ovrlp_coeff(1,1),1)

  call timing(iproc,'dirmin_lowdin2','OF') !lr408t
  call overlapPowerMinusOneHalf_old(iproc, nproc, bigdft_mpi%mpi_comm, 0, -8, -8, &
       orbs%norb, orbs%norbp, orbs%isorb, ovrlp_coeff)

  call timing(iproc,'dirmin_lowdin1','ON') !lr408t
  ! Build the new linear combinations
  call dgemm('n', 'n', tmb%orbs%norb, orbs%norb, orbs%norb, 1.d0, tmb%wfnmd%coeff(1,1), tmb%orbs%norb, &
       ovrlp_coeff(1,1), orbs%norb, 0.d0, coeff_tmp(1,1), tmb%orbs%norb)
  ! Gather together the results partial results.
  call timing(iproc,'dirmin_lowdin1','OF') !lr408t
  call timing(iproc,'dirmin_lowdin2','ON') !lr408t
  call dcopy(tmb%orbs%norb*orbs%norb, coeff_tmp(1,1), 1, tmb%wfnmd%coeff(1,1), 1)
  call timing(iproc,'dirmin_lowdin2','OF') !lr408t

  iall=-product(shape(lagmat))*kind(lagmat)
  deallocate(lagmat, stat=istat)
  call memocc(istat, iall, 'lagmat', subname)

  iall=-product(shape(rhs))*kind(rhs)
  deallocate(rhs, stat=istat)
  call memocc(istat, iall, 'rhs', subname)

  iall=-product(shape(grad))*kind(grad)
  deallocate(grad, stat=istat)
  call memocc(istat, iall, 'grad', subname)

  iall=-product(shape(ovrlp_tmp))*kind(ovrlp_tmp)
  deallocate(ovrlp_tmp, stat=istat)
  call memocc(istat, iall, 'ovrlp_tmp', subname)

  iall=-product(shape(coeff_tmp))*kind(coeff_tmp)
  deallocate(coeff_tmp, stat=istat)
  call memocc(istat, iall, 'coeff_tmp', subname)

  iall=-product(shape(ovrlp_coeff))*kind(ovrlp_coeff)
  deallocate(ovrlp_coeff, stat=istat)
  call memocc(istat, iall, 'ovrlp_coeff', subname)

end subroutine optimize_coeffs2

subroutine precondition_gradient_coeff(ntmb, norb, ham, ovrlp, grad)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: ntmb, norb
  real(8),dimension(ntmb,ntmb),intent(in):: ham, ovrlp
  real(8),dimension(ntmb,norb),intent(inout):: grad
  
  ! Local variables
  integer:: iorb, itmb, jtmb, info, istat, iall
  complex(8),dimension(:,:),allocatable:: mat
  complex(8),dimension(:,:),allocatable:: rhs
  integer,dimension(:),allocatable:: ipiv
  character(len=*),parameter:: subname='precondition_gradient_coeff'
  
  allocate(mat(ntmb,ntmb), stat=istat)
  !call memocc(istat, mat, 'mat', subname)
  allocate(rhs(ntmb,norb), stat=istat)
  !call memocc(istat, mat, 'mat', subname)
  
  ! Build the matrix to be inverted
  do itmb=1,ntmb
      do jtmb=1,ntmb
          mat(jtmb,itmb) = cmplx(ham(jtmb,itmb)+.5d0*ovrlp(jtmb,itmb),0.d0,kind=8)
      end do
      mat(itmb,itmb)=mat(itmb,itmb)+cmplx(0.d0,-1.d-1,kind=8)
      !mat(itmb,itmb)=mat(itmb,itmb)-cprec
  end do
  do iorb=1,norb
      do itmb=1,ntmb
          rhs(itmb,iorb)=cmplx(grad(itmb,iorb),0.d0,kind=8)
      end do
  end do
  
  
  allocate(ipiv(ntmb), stat=istat)
  call memocc(istat, ipiv, 'ipiv', subname)
  
  call zgesv(ntmb, norb, mat(1,1), ntmb, ipiv, rhs(1,1), ntmb, info)
  if(info/=0) then
      stop 'ERROR in dgesv'
  end if
  !call dcopy(nel, rhs(1), 1, grad(1), 1)
  do iorb=1,norb
      do itmb=1,ntmb
          grad(itmb,iorb)=real(rhs(itmb,iorb))
      end do
  end do
  
  iall=-product(shape(ipiv))*kind(ipiv)
  deallocate(ipiv, stat=istat)
  call memocc(istat, iall, 'ipiv', subname)
  
  iall=-product(shape(mat))*kind(mat)
  deallocate(mat, stat=istat)
  !call memocc(istat, iall, 'mat', subname)
  
  iall=-product(shape(rhs))*kind(rhs)
  deallocate(rhs, stat=istat)
  !call memocc(istat, iall, 'rhs', subname)

end subroutine precondition_gradient_coeff



subroutine DIIS_coeff(iproc, nproc, orbs, tmb, grad, coeff, ldiis)
  use module_base
  use module_types
  use module_interfaces, except_this_one => DIIS_coeff
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(orbitals_data),intent(in):: orbs
  type(DFT_wavefunction),intent(in):: tmb
  real(8),dimension(tmb%orbs%norb*tmb%orbs%norbp),intent(in):: grad
  real(8),dimension(tmb%orbs%norb*tmb%orbs%norb),intent(inout):: coeff
  type(localizedDIISParameters),intent(inout):: ldiis
  
  ! Local variables
  integer:: iorb, jorb, ist, ncount, jst, i, j, mi, ist1, ist2, istat, lwork, info
  integer:: mj, jj, k, jjst, isthist, iall
  real(8):: ddot
  real(8),dimension(:,:),allocatable:: mat
  real(8),dimension(:),allocatable:: rhs, work
  integer,dimension(:),allocatable:: ipiv
  character(len=*),parameter:: subname='DIIS_coeff'
  
  !!call timing(iproc,'optimize_DIIS ','ON')
  
  ! Allocate the local arrays.
  allocate(mat(ldiis%isx+1,ldiis%isx+1), stat=istat)
  call memocc(istat, mat, 'mat', subname)
  allocate(rhs(ldiis%isx+1), stat=istat)
  call memocc(istat, rhs, 'rhs', subname)
  allocate(ipiv(ldiis%isx+1), stat=istat)
  call memocc(istat, ipiv, 'ipiv', subname)
  
  mat=0.d0
  rhs=0.d0
  call to_zero((ldiis%isx+1)**2, mat(1,1))
  call to_zero(ldiis%isx+1, rhs(1))
  
  ! Copy coeff and grad to history.
  ist=1
  do iorb=1,tmb%orbs%norbp
      jst=1
      do jorb=1,iorb-1
          ncount=tmb%orbs%norb
          jst=jst+ncount*ldiis%isx
      end do
      ncount=tmb%orbs%norb
      jst=jst+(ldiis%mis-1)*ncount
      call dcopy(ncount, coeff(ist+tmb%orbs%isorb*tmb%orbs%norb), 1, ldiis%phiHist(jst), 1)
      call dcopy(ncount, grad(ist), 1, ldiis%hphiHist(jst), 1)
      ist=ist+ncount
  end do
  
  do iorb=1,tmb%orbs%norbp
      ! Shift the DIIS matrix left up if we reached the maximal history length.
      if(ldiis%is>ldiis%isx) then
         do i=1,ldiis%isx-1
            do j=1,i
               ldiis%mat(j,i,iorb)=ldiis%mat(j+1,i+1,iorb)
            end do
         end do
      end if
  end do
  
  do iorb=1,tmb%orbs%norbp
      ! Calculate a new line for the matrix.
      i=max(1,ldiis%is-ldiis%isx+1)
      jst=1
      ist1=1
      do jorb=1,iorb-1
          ncount=tmb%orbs%norb
          jst=jst+ncount*ldiis%isx
          ist1=ist1+ncount
      end do
      ncount=tmb%orbs%norb
      do j=i,ldiis%is
         mi=mod(j-1,ldiis%isx)+1
         ist2=jst+(mi-1)*ncount
         if(ist2>size(ldiis%hphiHist)) then
             write(*,'(a,7i8)') 'ERROR ist2: iproc, iorb, ldiis%is, mi, ncount, ist2, size(ldiis%hphiHist)', iproc, iorb, ldiis%is,&
                                 mi, ncount, ist2, size(ldiis%hphiHist)
         end if
         ldiis%mat(j-i+1,min(ldiis%isx,ldiis%is),iorb)=ddot(ncount, grad(ist1), 1, ldiis%hphiHist(ist2), 1)
         ist2=ist2+ncount
      end do
  end do
  
  
  ist=1+tmb%orbs%isorb*tmb%orbs%norb
  do iorb=1,tmb%orbs%norbp
      
      ! Copy the matrix to an auxiliary array and fill with the zeros and ones.
      do i=1,min(ldiis%isx,ldiis%is)
          mat(i,min(ldiis%isx,ldiis%is)+1)=1.d0
          rhs(i)=0.d0
          do j=i,min(ldiis%isx,ldiis%is)
              mat(i,j)=ldiis%mat(i,j,iorb)
          end do
      end do
      mat(min(ldiis%isx,ldiis%is)+1,min(ldiis%isx,ldiis%is)+1)=0.d0
      rhs(min(ldiis%isx,ldiis%is)+1)=1.d0
  
  
      ! Solve the linear system
      !!do istat=1,ldiis%isx+1
          !!do iall=1,ldiis%isx+1
              !!if(iproc==0) write(500,*) istat, iall, mat(iall,istat)
          !!end do
      !!end do

      if(ldiis%is>1) then
         lwork=-1   !100*ldiis%isx
         allocate(work(1000), stat=istat)
         call memocc(istat, work, 'work', subname)
         call dsysv('u', min(ldiis%isx,ldiis%is)+1, 1, mat, ldiis%isx+1,  & 
              ipiv, rhs(1), ldiis%isx+1, work, lwork, info)
         lwork=work(1)
         iall=-product(shape(work))*kind(work)
         deallocate(work,stat=istat)
         call memocc(istat,iall,'work',subname)
         allocate(work(lwork), stat=istat)
         call memocc(istat, work, 'work', subname)
         call dsysv('u', min(ldiis%isx,ldiis%is)+1, 1, mat, ldiis%isx+1,  & 
              ipiv, rhs(1), ldiis%isx+1, work, lwork, info)
         iall=-product(shape(work))*kind(work)
         deallocate(work, stat=istat)
         call memocc(istat, iall, 'work', subname)
         
         if (info /= 0) then
            write(*,'(a,i0)') 'ERROR in dsysv (DIIS_coeff), info=', info
            stop
         end if
      else
         rhs(1)=1.d0
      endif
  
  
      ! Make a new guess for the orbital.
      ncount=tmb%orbs%norb
      call razero(ncount, coeff(ist))
      isthist=max(1,ldiis%is-ldiis%isx+1)
      jj=0
      jst=0
      do jorb=1,iorb-1
          ncount=tmb%orbs%norb
          jst=jst+ncount*ldiis%isx
      end do
      do j=isthist,ldiis%is
          jj=jj+1
          mj=mod(j-1,ldiis%isx)+1
          ncount=tmb%orbs%norb
          jjst=jst+(mj-1)*ncount
          do k=1,ncount
              coeff(ist+k-1) = coeff(ist+k-1) + rhs(jj)*(ldiis%phiHist(jjst+k)-ldiis%hphiHist(jjst+k))
          end do
      end do
  
      ncount=tmb%orbs%norb
      ist=ist+ncount
  end do
  
  
  iall=-product(shape(mat))*kind(mat)
  deallocate(mat, stat=istat)
  call memocc(istat, iall, 'mat', subname)
  
  iall=-product(shape(rhs))*kind(rhs)
  deallocate(rhs, stat=istat)
  call memocc(istat, iall, 'rhs', subname)
  
  
  iall=-product(shape(ipiv))*kind(ipiv)
  deallocate(ipiv, stat=istat)
  call memocc(istat, iall, 'ipiv', subname)
  
  !!call timing(iproc,'optimize_DIIS ','OF')


end subroutine DIIS_coeff



subroutine initialize_DIIS_coeff(isx, ldiis)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: isx
  type(localizedDIISParameters),intent(inout):: ldiis
  
  ! Local variables
  character(len=*),parameter:: subname='initialize_DIIS_coeff'
  
  
  ldiis%isx=isx
  ldiis%is=0
  ldiis%switchSD=.false.
  ldiis%trmin=1.d100
  ldiis%trold=1.d100

end subroutine initialize_DIIS_coeff


subroutine allocate_DIIS_coeff(tmb, ldiis)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(DFT_wavefunction),intent(in):: tmb
  type(localizedDIISParameters),intent(out):: ldiis
  
  ! Local variables
  integer:: iorb, ii, istat
  character(len=*),parameter:: subname='allocate_DIIS_coeff'

  allocate(ldiis%mat(ldiis%isx,ldiis%isx,tmb%orbs%norbp),stat=istat)
  call memocc(istat, ldiis%mat, 'ldiis%mat', subname)

  ii=ldiis%isx*tmb%orbs%norb*tmb%orbs%norbp
  allocate(ldiis%phiHist(ii), stat=istat)
  call memocc(istat, ldiis%phiHist, 'ldiis%phiHist', subname)
  allocate(ldiis%hphiHist(ii), stat=istat)
  call memocc(istat, ldiis%hphiHist, 'ldiis%hphiHist', subname)

end subroutine allocate_DIIS_coeff

