!> @file
!! Copy the different type used by linear version
!! @author
!!    Copyright (C) 2011-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Currently incomplete - need to add comms arrays etc
subroutine copy_tmbs(iproc, tmbin, tmbout, subname)
  use module_base
  use module_types
  use module_interfaces
  implicit none

  integer,intent(in) :: iproc
  type(DFT_wavefunction), intent(in) :: tmbin
  type(DFT_wavefunction), intent(out) :: tmbout
  character(len=*),intent(in):: subname

  call f_routine(id='copy_tmbs')

  call nullify_orbitals_data(tmbout%orbs)
  call copy_orbitals_data(tmbin%orbs, tmbout%orbs, subname)
  call nullify_local_zone_descriptors(tmbout%lzd)
  call copy_old_supportfunctions(iproc,tmbin%orbs,tmbin%lzd,tmbin%psi,tmbout%lzd,tmbout%psi)

  tmbout%npsidim_orbs = tmbin%npsidim_orbs

  if (associated(tmbin%coeff)) then !(in%lin%scf_mode/=LINEAR_FOE) then ! should move this check to copy_old_coeffs
      call copy_old_coefficients(tmbin%orbs%norb, tmbin%linmat%l%nfvctr, tmbin%coeff, tmbout%coeff)
  else
      nullify(tmbout%coeff)
  end if

  ! Parts of tmbout%lzd have been allocated in copy_old_supportfunctions, so deallocate everything and reallocate everything
  ! properly. Of course this is a very bad solution.
  call deallocate_local_zone_descriptors(tmbout%lzd)
  call copy_local_zone_descriptors(tmbin%lzd, tmbout%lzd, subname)

  call copy_linear_matrices(tmbin%linmat, tmbout%linmat)

  call copy_comms_linear(tmbin%collcom, tmbout%collcom)

  ! should technically copy these across as well but not needed for restart and will eventually be removing wfnmd as a type
  !nullify(tmbout%linmat%denskern%matrix_compr)
  !nullify(tmbout%linmat%denskern_large%matrix_compr)

  ! should also copy/nullify p2pcomms etc

  !call copy_old_inwhichlocreg(tmbin%orbs%norb, tmbin%orbs%inwhichlocreg, tmbout%orbs%inwhichlocreg, &
  !     tmbin%orbs%onwhichatom, tmbout%orbs%onwhichatom)
  !call allocate_and_copy(tmbin%psi, tmbout%psi, id='tmbout%psi')
  !already donetmbout%psi=f_malloc_ptr(src_ptr=tmbin%psi,id='tmbout%psi')

  ! Not necessary to copy these arrays
  !call allocate_and_copy(tmbin%hpsi, tmbout%hpsi, id='tmbout%hpsi')
  !call allocate_and_copy(tmbin%psit, tmbout%psit, id='tmbout%psit')
  !call allocate_and_copy(tmbin%psit_c, tmbout%psit_c, id='tmbout%psit_c')
  !call allocate_and_copy(tmbin%psit_f, tmbout%psit_f, id='tmbout%psit_f')

  call f_release_routine()

end subroutine copy_tmbs

subroutine copy_orbitals_data(orbsin, orbsout, subname)
use module_base
use module_types, only: orbitals_data

implicit none

! Calling arguments
type(orbitals_data),intent(in):: orbsin
type(orbitals_data),intent(inout):: orbsout
character(len=*),intent(in):: subname

! Local variables
integer:: iis1, iie1, iis2, iie2, i1, i2

orbsout%norb = orbsin%norb
orbsout%norbp = orbsin%norbp
orbsout%norbu = orbsin%norbu
orbsout%norbd = orbsin%norbd
orbsout%nspin = orbsin%nspin
orbsout%nspinor = orbsin%nspinor
orbsout%isorb = orbsin%isorb
orbsout%npsidim_orbs = orbsin%npsidim_orbs
orbsout%npsidim_comp = orbsin%npsidim_comp
orbsout%nkpts = orbsin%nkpts
orbsout%nkptsp = orbsin%nkptsp
orbsout%iskpts = orbsin%iskpts
orbsout%efermi = orbsin%efermi

orbsout%norb_par  = f_malloc_ptr(src_ptr=orbsin%norb_par,id='orbsout%norb_par')
orbsout%norbu_par = f_malloc_ptr(src_ptr=orbsin%norbu_par,id='orbsout%norbu_par')
orbsout%norbd_par = f_malloc_ptr(src_ptr=orbsin%norbd_par,id='orbsout%norbd_par')
orbsout%iokpt     = f_malloc_ptr(src_ptr=orbsin%iokpt,id='orbsout%iokpt')
orbsout%ikptproc  = f_malloc_ptr(src_ptr=orbsin%ikptproc,id='orbsout%ikptproc')
orbsout%inwhichlocreg = f_malloc_ptr(src_ptr=orbsin%inwhichlocreg,id='orbsout%inwhichlocreg')
orbsout%onwhichatom = f_malloc_ptr(src_ptr=orbsin%onwhichatom,id='orbsout%onwhichatom')
orbsout%isorb_par = f_malloc_ptr(src_ptr=orbsin%isorb_par,id='orbsout%isorb_par')
orbsout%eval = f_malloc_ptr(src_ptr=orbsin%eval,id='orbsout%eval')
orbsout%occup = f_malloc_ptr(src_ptr=orbsin%occup,id='orbsout%occup')
orbsout%spinsgn = f_malloc_ptr(src_ptr=orbsin%spinsgn,id='orbsout%spinsgn')
orbsout%kwgts = f_malloc_ptr(src_ptr=orbsin%kwgts,id='orbsout%kwgts')
orbsout%kpts = f_malloc_ptr(src_ptr=orbsin%kpts,id='orbsout%kpts')
orbsout%ispot = f_malloc_ptr(src_ptr=orbsin%ispot,id='orbsout%ispot')

end subroutine copy_orbitals_data


subroutine copy_local_zone_descriptors(lzd_in, lzd_out, subname)
  use locregs
  use module_types, only: local_zone_descriptors
  implicit none

  ! Calling arguments
  type(local_zone_descriptors),intent(in):: lzd_in
  type(local_zone_descriptors),intent(inout):: lzd_out
  character(len=*),intent(in):: subname

  ! Local variables
  integer:: istat, i1, iis1, iie1

  lzd_out%linear=lzd_in%linear
  lzd_out%nlr=lzd_in%nlr
  lzd_out%lintyp=lzd_in%lintyp
  lzd_out%ndimpotisf=lzd_in%ndimpotisf
  lzd_out%hgrids=lzd_in%hgrids

  call nullify_locreg_descriptors(lzd_out%glr)
  call copy_locreg_descriptors(lzd_in%glr, lzd_out%glr)

  if(associated(lzd_out%llr)) then
      deallocate(lzd_out%llr, stat=istat)
  end if
  if(associated(lzd_in%llr)) then
      iis1=lbound(lzd_in%llr,1)
      iie1=ubound(lzd_in%llr,1)
      allocate(lzd_out%llr(iis1:iie1), stat=istat)
      do i1=iis1,iie1
          call nullify_locreg_descriptors(lzd_out%llr(i1))
          call copy_locreg_descriptors(lzd_in%llr(i1), lzd_out%llr(i1))
      end do
  end if

end subroutine copy_local_zone_descriptors




!!!!only copying sparsity pattern here, not copying whole matrix (assuming matrices not allocated)
!!!subroutine sparse_copy_pattern(sparseMat_in, sparseMat_out, iproc, subname)
!!!  use module_base
!!!  use module_types
!!!  use sparsematrix_base, only: sparse_matrix
!!!  implicit none
!!!
!!!  ! Calling arguments
!!!  type(sparse_matrix),intent(in):: sparseMat_in
!!!  type(sparse_matrix),intent(inout):: sparseMat_out
!!!  integer, intent(in) :: iproc
!!!  character(len=*),intent(in):: subname
!!!
!!!  ! Local variables
!!!  integer:: iis1, iie1, iis2, iie2, i1, i2
!!!
!!!  call timing(iproc,'sparse_copy','ON')
!!!
!!!  sparsemat_out%nseg = sparsemat_in%nseg
!!!  sparsemat_out%store_index = sparsemat_in%store_index
!!!  sparsemat_out%nvctr = sparsemat_in%nvctr
!!!  sparsemat_out%nvctrp = sparsemat_in%nvctrp
!!!  sparsemat_out%isvctr = sparsemat_in%isvctr
!!!  sparsemat_out%nfvctr = sparsemat_in%nfvctr
!!!  sparsemat_out%nfvctrp = sparsemat_in%nfvctrp
!!!  sparsemat_out%isfvctr = sparsemat_in%isfvctr
!!!  sparsemat_out%nspin = sparsemat_in%nspin
!!!  sparsemat_out%parallel_compression = sparsemat_in%parallel_compression
!!!
!!!  if(associated(sparsemat_out%nvctr_par)) then
!!!     call f_free_ptr(sparsemat_out%nvctr_par)
!!!  end if
!!!  if(associated(sparsemat_in%nvctr_par)) then
!!!     iis1=lbound(sparsemat_in%nvctr_par,1)
!!!     iie1=ubound(sparsemat_in%nvctr_par,1)
!!!     sparsemat_out%nvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%nvctr_par')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%nvctr_par(i1) = sparsemat_in%nvctr_par(i1)
!!!     end do
!!!  end if
!!!  if(associated(sparsemat_out%isvctr_par)) then
!!!     call f_free_ptr(sparsemat_out%isvctr_par)
!!!  end if
!!!  if(associated(sparsemat_in%isvctr_par)) then
!!!     iis1=lbound(sparsemat_in%isvctr_par,1)
!!!     iie1=ubound(sparsemat_in%isvctr_par,1)
!!!     sparsemat_out%isvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%isvctr_par')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%isvctr_par(i1) = sparsemat_in%isvctr_par(i1)
!!!     end do
!!!  end if
!!!  if(associated(sparsemat_out%nfvctr_par)) then
!!!     call f_free_ptr(sparsemat_out%nfvctr_par)
!!!  end if
!!!  if(associated(sparsemat_in%nfvctr_par)) then
!!!     iis1=lbound(sparsemat_in%nfvctr_par,1)
!!!     iie1=ubound(sparsemat_in%nfvctr_par,1)
!!!     sparsemat_out%nfvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%nfvctr_par')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%nfvctr_par(i1) = sparsemat_in%nfvctr_par(i1)
!!!     end do
!!!  end if
!!!  if(associated(sparsemat_out%isfvctr_par)) then
!!!     call f_free_ptr(sparsemat_out%isfvctr_par)
!!!  end if
!!!  if(associated(sparsemat_in%isfvctr_par)) then
!!!     iis1=lbound(sparsemat_in%isfvctr_par,1)
!!!     iie1=ubound(sparsemat_in%isfvctr_par,1)
!!!     sparsemat_out%isfvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%isfvctr_par')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%isfvctr_par(i1) = sparsemat_in%isfvctr_par(i1)
!!!     end do
!!!  end if
!!!
!!!  !!nullify(sparsemat_out%matrix)
!!!  !!nullify(sparsemat_out%matrix_compr)
!!!  !!nullify(sparsemat_out%matrixp)
!!!  !!nullify(sparsemat_out%matrix_comprp)
!!!
!!!  if(associated(sparsemat_out%keyv)) then
!!!     call f_free_ptr(sparsemat_out%keyv)
!!!  end if
!!!  if(associated(sparsemat_in%keyv)) then
!!!     iis1=lbound(sparsemat_in%keyv,1)
!!!     iie1=ubound(sparsemat_in%keyv,1)
!!!     sparsemat_out%keyv=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%keyv')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%keyv(i1) = sparsemat_in%keyv(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%nsegline)) then
!!!     call f_free_ptr(sparsemat_out%nsegline)
!!!  end if
!!!  if(associated(sparsemat_in%nsegline)) then
!!!     iis1=lbound(sparsemat_in%nsegline,1)
!!!     iie1=ubound(sparsemat_in%nsegline,1)
!!!     sparsemat_out%nsegline=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%nsegline')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%nsegline(i1) = sparsemat_in%nsegline(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%istsegline)) then
!!!     call f_free_ptr(sparsemat_out%istsegline)
!!!  end if
!!!  if(associated(sparsemat_in%istsegline)) then
!!!     iis1=lbound(sparsemat_in%istsegline,1)
!!!     iie1=ubound(sparsemat_in%istsegline,1)
!!!     sparsemat_out%istsegline=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%istsegline')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%istsegline(i1) = sparsemat_in%istsegline(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%keyg)) then
!!!     call f_free_ptr(sparsemat_out%keyg)
!!!  end if
!!!  if(associated(sparsemat_in%keyg)) then
!!!     iis1=lbound(sparsemat_in%keyg,1)
!!!     iie1=ubound(sparsemat_in%keyg,1)
!!!     iis2=lbound(sparsemat_in%keyg,2)
!!!     iie2=ubound(sparsemat_in%keyg,2)
!!!     sparsemat_out%keyg=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),id='sparsemat_out%keyg')
!!!     do i1=iis1,iie1
!!!        do i2 = iis2,iie2
!!!           sparsemat_out%keyg(i1,i2) = sparsemat_in%keyg(i1,i2)
!!!        end do
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%matrixindex_in_compressed_arr)) then
!!!     call f_free_ptr(sparsemat_out%matrixindex_in_compressed_arr)
!!!  end if
!!!  if(associated(sparsemat_in%matrixindex_in_compressed_arr)) then
!!!     iis1=lbound(sparsemat_in%matrixindex_in_compressed_arr,1)
!!!     iie1=ubound(sparsemat_in%matrixindex_in_compressed_arr,1)
!!!     iis2=lbound(sparsemat_in%matrixindex_in_compressed_arr,2)
!!!     iie2=ubound(sparsemat_in%matrixindex_in_compressed_arr,2)
!!!     sparsemat_out%matrixindex_in_compressed_arr=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),&
!!!         id='sparsemat_out%matrixindex_in_compressed_ar')
!!!     do i1=iis1,iie1
!!!        do i2 = iis2,iie2
!!!           sparsemat_out%matrixindex_in_compressed_arr(i1,i2) = sparsemat_in%matrixindex_in_compressed_arr(i1,i2)
!!!        end do
!!!     end do
!!!  end if
!!!
!!!  !!if(associated(sparsemat_out%orb_from_index)) then
!!!  !!   call f_free_ptr(sparsemat_out%orb_from_index)
!!!  !!end if
!!!  !!if(associated(sparsemat_in%orb_from_index)) then
!!!  !!   iis1=lbound(sparsemat_in%orb_from_index,1)
!!!  !!   iie1=ubound(sparsemat_in%orb_from_index,1)
!!!  !!   iis2=lbound(sparsemat_in%orb_from_index,2)
!!!  !!   iie2=ubound(sparsemat_in%orb_from_index,2)
!!!  !!   sparsemat_out%orb_from_index=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),id='sparsemat_out%orb_from_index')
!!!  !!   do i1=iis1,iie1
!!!  !!      do i2 = iis2,iie2
!!!  !!         sparsemat_out%orb_from_index(i1,i2) = sparsemat_in%orb_from_index(i1,i2)
!!!  !!      end do
!!!  !!   end do
!!!  !!end if
!!!
!!!  if(associated(sparsemat_out%matrixindex_in_compressed_fortransposed)) then
!!!     call f_free_ptr(sparsemat_out%matrixindex_in_compressed_fortransposed)
!!!  end if
!!!  if(associated(sparsemat_in%matrixindex_in_compressed_fortransposed)) then
!!!     iis1=lbound(sparsemat_in%matrixindex_in_compressed_fortransposed,1)
!!!     iie1=ubound(sparsemat_in%matrixindex_in_compressed_fortransposed,1)
!!!     iis2=lbound(sparsemat_in%matrixindex_in_compressed_fortransposed,2)
!!!     iie2=ubound(sparsemat_in%matrixindex_in_compressed_fortransposed,2)
!!!     sparsemat_out%matrixindex_in_compressed_fortransposed=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),&
!!!         id='sparsemat_out%matrixindex_in_compressed_fortransposed')
!!!     do i1=iis1,iie1
!!!        do i2 = iis2,iie2
!!!           sparsemat_out%matrixindex_in_compressed_fortransposed(i1,i2) = &
!!!                sparsemat_in%matrixindex_in_compressed_fortransposed(i1,i2)
!!!        end do
!!!     end do
!!!  end if
!!!
!!!
!!!  sparsemat_out%smmm%nout = sparsemat_in%smmm%nout
!!!  sparsemat_out%smmm%nseq = sparsemat_in%smmm%nseq
!!!  sparsemat_out%smmm%nseg = sparsemat_in%smmm%nseg
!!!  
!!!  if(associated(sparsemat_out%smmm%ivectorindex)) then
!!!     call f_free_ptr(sparsemat_out%smmm%ivectorindex)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%ivectorindex)) then
!!!     iis1=lbound(sparsemat_in%smmm%ivectorindex,1)
!!!     iie1=ubound(sparsemat_in%smmm%ivectorindex,1)
!!!     sparsemat_out%smmm%ivectorindex=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%smmm%ivectorindex')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%smmm%ivectorindex(i1) = sparsemat_in%smmm%ivectorindex(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%smmm%nsegline)) then
!!!     call f_free_ptr(sparsemat_out%smmm%nsegline)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%nsegline)) then
!!!     iis1=lbound(sparsemat_in%smmm%nsegline,1)
!!!     iie1=ubound(sparsemat_in%smmm%nsegline,1)
!!!     sparsemat_out%smmm%nsegline=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%smmm%nsegline')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%smmm%nsegline(i1) = sparsemat_in%smmm%nsegline(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%smmm%istsegline)) then
!!!     call f_free_ptr(sparsemat_out%smmm%istsegline)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%istsegline)) then
!!!     iis1=lbound(sparsemat_in%smmm%istsegline,1)
!!!     iie1=ubound(sparsemat_in%smmm%istsegline,1)
!!!     sparsemat_out%smmm%istsegline=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%smmm%istsegline')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%smmm%istsegline(i1) = sparsemat_in%smmm%istsegline(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%smmm%indices_extract_sequential)) then
!!!     call f_free_ptr(sparsemat_out%smmm%indices_extract_sequential)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%indices_extract_sequential)) then
!!!     iis1=lbound(sparsemat_in%smmm%indices_extract_sequential,1)
!!!     iie1=ubound(sparsemat_in%smmm%indices_extract_sequential,1)
!!!     sparsemat_out%smmm%indices_extract_sequential=f_malloc_ptr(iis1.to.iie1,id='sparsemat_out%smmm%indices_extract_sequential')
!!!     do i1=iis1,iie1
!!!        sparsemat_out%smmm%indices_extract_sequential(i1) = sparsemat_in%smmm%indices_extract_sequential(i1)
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%smmm%onedimindices)) then
!!!     call f_free_ptr(sparsemat_out%smmm%onedimindices)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%onedimindices)) then
!!!     iis1=lbound(sparsemat_in%smmm%onedimindices,1)
!!!     iie1=ubound(sparsemat_in%smmm%onedimindices,1)
!!!     iis2=lbound(sparsemat_in%smmm%onedimindices,2)
!!!     iie2=ubound(sparsemat_in%smmm%onedimindices,2)
!!!     sparsemat_out%smmm%onedimindices=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),&
!!!         id='sparsemat_out%smmm%onedimindices')
!!!     do i1=iis1,iie1
!!!        do i2 = iis2,iie2
!!!           sparsemat_out%smmm%onedimindices(i1,i2) = &
!!!                sparsemat_in%smmm%onedimindices(i1,i2)
!!!        end do
!!!     end do
!!!  end if
!!!
!!!  if(associated(sparsemat_out%smmm%keyg)) then
!!!     call f_free_ptr(sparsemat_out%smmm%keyg)
!!!  end if
!!!  if(associated(sparsemat_in%smmm%keyg)) then
!!!     iis1=lbound(sparsemat_in%smmm%keyg,1)
!!!     iie1=ubound(sparsemat_in%smmm%keyg,1)
!!!     iis2=lbound(sparsemat_in%smmm%keyg,2)
!!!     iie2=ubound(sparsemat_in%smmm%keyg,2)
!!!     sparsemat_out%smmm%keyg=f_malloc_ptr((/iis1.to.iie1,iis2.to.iie2/),&
!!!         id='sparsemat_out%smmm%keyg')
!!!     do i1=iis1,iie1
!!!        do i2 = iis2,iie2
!!!           sparsemat_out%smmm%keyg(i1,i2) = &
!!!                sparsemat_in%smmm%keyg(i1,i2)
!!!        end do
!!!     end do
!!!  end if
!!!
!!!
!!!  call timing(iproc,'sparse_copy','OF')
!!!
!!!end subroutine sparse_copy_pattern



subroutine copy_linear_matrices(linmat_in, linmat_out)
  use module_types
  use sparsematrix_base, only: sparse_matrix_null
  implicit none

  ! Calling arguments
  type(linear_matrices),intent(in) :: linmat_in
  type(linear_matrices),intent(out) :: linmat_out

  ! Local variables
  integer :: ispin

  call copy_sparse_matrix(linmat_in%s, linmat_out%s)
  call copy_sparse_matrix(linmat_in%m, linmat_out%m)
  call copy_sparse_matrix(linmat_in%l, linmat_out%l)
  if (associated(linmat_in%ks)) then
      allocate(linmat_out%ks(linmat_in%l%nspin))
      do ispin=1,linmat_in%l%nspin
          linmat_out%ks(ispin) = sparse_matrix_null()
          call copy_sparse_matrix(linmat_in%ks(ispin), linmat_out%ks(ispin))
      end do
  else
      nullify(linmat_out%ks)
  end if
  if (associated(linmat_in%ks_e)) then
      allocate(linmat_out%ks_e(linmat_in%l%nspin))
      do ispin=1,linmat_in%l%nspin
          linmat_out%ks_e(ispin) = sparse_matrix_null()
          call copy_sparse_matrix(linmat_in%ks_e(ispin), linmat_out%ks_e(ispin))
      end do
  else
      nullify(linmat_out%ks_e)
  end if
  call copy_matrices(linmat_in%ham_, linmat_out%ham_)
  call copy_matrices(linmat_in%ovrlp_, linmat_out%ovrlp_)
  call copy_matrices(linmat_in%kernel_, linmat_out%kernel_)

end subroutine copy_linear_matrices


subroutine copy_sparse_matrix(smat_in, smat_out)
  use sparsematrix_base, only: sparse_matrix
  use wrapper_MPI, only: mpi_environment_null
  use dynamic_memory
  implicit none

  ! Calling arguments
  type(sparse_matrix),intent(in) :: smat_in
  type(sparse_matrix),intent(out) :: smat_out

  ! Local variables
  integer :: i, is, ie


  smat_out%nvctr = smat_in%nvctr
  smat_out%nseg = smat_in%nseg
  smat_out%nvctrp = smat_in%nvctrp
  smat_out%isvctr = smat_in%isvctr
  smat_out%parallel_compression = smat_in%parallel_compression
  smat_out%nfvctr = smat_in%nfvctr
  smat_out%nfvctrp = smat_in%nfvctrp
  smat_out%isfvctr = smat_in%isfvctr
  smat_out%nspin = smat_in%nspin
  smat_out%offset_matrixindex_in_compressed_fortransposed = smat_in%offset_matrixindex_in_compressed_fortransposed
  smat_out%store_index = smat_in%store_index
  smat_out%can_use_dense = smat_in%can_use_dense
  smat_out%ntaskgroup = smat_in%ntaskgroup
  smat_out%ntaskgroupp = smat_in%ntaskgroupp
  smat_out%istartendseg_t(1:2) = smat_in%istartendseg_t(1:2)
  smat_out%istartend_t(1:2) = smat_in%istartend_t(1:2)
  smat_out%nvctrp_tg = smat_in%nvctrp_tg
  smat_out%isvctrp_tg = smat_in%isvctrp_tg
  smat_out%iseseg_tg(1:2) = smat_in%iseseg_tg(1:2)
  smat_out%istartend_local(1:2) = smat_in%istartend_local(1:2)
  smat_out%istartendseg_local(1:2) = smat_in%istartendseg_local(1:2)


!!converted  call allocate_and_copy(smat_in%keyv,       smat_out%keyv, id='smat_out%')
       smat_out%keyv=f_malloc_ptr(src_ptr=smat_in%keyv, id='smat_out%')
!!converted  call allocate_and_copy(smat_in%nsegline,   smat_out%nsegline, id='smat_out%nsegline')
   smat_out%nsegline=f_malloc_ptr(src_ptr=smat_in%nsegline, id='smat_out%nsegline')
!!converted  call allocate_and_copy(smat_in%istsegline, smat_out%istsegline, id='smat_out%istsegline')
 smat_out%istsegline=f_malloc_ptr(src_ptr=smat_in%istsegline, id='smat_out%istsegline')
!!converted  call allocate_and_copy(smat_in%isvctr_par, smat_out%isvctr_par, id='smat_out%isvctr_par')
 smat_out%isvctr_par=f_malloc_ptr(src_ptr=smat_in%isvctr_par, id='smat_out%isvctr_par')
!!converted  call allocate_and_copy(smat_in%nvctr_par,  smat_out%nvctr_par, id='smat_out%nvctr_par')
  smat_out%nvctr_par=f_malloc_ptr(src_ptr=smat_in%nvctr_par, id='smat_out%nvctr_par')
!!converted  call allocate_and_copy(smat_in%isfvctr_par,smat_out%isfvctr_par, id='smat_out%isfvctr_par')
smat_out%isfvctr_par=f_malloc_ptr(src_ptr=smat_in%isfvctr_par, id='smat_out%isfvctr_par')
!!converted  call allocate_and_copy(smat_in%nfvctr_par, smat_out%nfvctr_par, id='smat_out%nfvctr_par')
 smat_out%nfvctr_par=f_malloc_ptr(src_ptr=smat_in%nfvctr_par, id='smat_out%nfvctr_par')

!!converted  call allocate_and_copy(smat_in%keyg,       smat_out%keyg, id='smat_out%keyg')
       smat_out%keyg=f_malloc_ptr(src_ptr=smat_in%keyg, id='smat_out%keyg')
!!converted  call allocate_and_copy(smat_in%matrixindex_in_compressed_arr, smat_out%matrixindex_in_compressed_arr, &
 smat_out%matrixindex_in_compressed_arr=f_malloc_ptr(src_ptr=smat_in%matrixindex_in_compressed_arr, &
                         id='smat_out%matrixindex_in_compressed_arr')
!!converted  call allocate_and_copy(smat_in%matrixindex_in_compressed_fortransposed, smat_out%matrixindex_in_compressed_fortransposed, &
 smat_out%matrixindex_in_compressed_fortransposed=f_malloc_ptr(src_ptr=smat_in%matrixindex_in_compressed_fortransposed, &
                         id='smat_out%matrixindex_in_compressed_fortransposed')
!!converted  call allocate_and_copy(smat_in%taskgroup_startend, smat_out%taskgroup_startend, id='smat_out%taskgroup_startend')
 smat_out%taskgroup_startend=f_malloc_ptr(src_ptr=smat_in%taskgroup_startend, id='smat_out%taskgroup_startend')
!!converted  call allocate_and_copy(smat_in%taskgroupid, smat_out%taskgroupid, id='smat_out%taskgroupid')
 smat_out%taskgroupid=f_malloc_ptr(src_ptr=smat_in%taskgroupid, id='smat_out%taskgroupid')
!!converted  call allocate_and_copy(smat_in%inwhichtaskgroup, smat_out%inwhichtaskgroup, id='smat_out%inwhichtaskgroup')
 smat_out%inwhichtaskgroup=f_malloc_ptr(src_ptr=smat_in%inwhichtaskgroup, id='smat_out%inwhichtaskgroup')
!!converted  call allocate_and_copy(smat_in%tgranks, smat_out%tgranks, id='smat_out%tgranks')
 smat_out%tgranks=f_malloc_ptr(src_ptr=smat_in%tgranks, id='smat_out%tgranks')
!!converted  call allocate_and_copy(smat_in%nranks, smat_out%nranks, id='smat_out%nranks')
 smat_out%nranks=f_malloc_ptr(src_ptr=smat_in%nranks, id='smat_out%nranks')
!!converted  call allocate_and_copy(smat_in%luccomm, smat_out%luccomm, id='smat_out%luccomm')
 smat_out%luccomm=f_malloc_ptr(src_ptr=smat_in%luccomm, id='smat_out%luccomm')
!!converted  call allocate_and_copy(smat_in%on_which_atom, smat_out%on_which_atom, id='smat_out%on_which_atom')
 smat_out%on_which_atom=f_malloc_ptr(src_ptr=smat_in%on_which_atom, id='smat_out%on_which_atom')

  call copy_sparse_matrix_matrix_multiplication(smat_in%smmm, smat_out%smmm)

  if (associated(smat_in%mpi_groups)) then
      is = lbound(smat_in%mpi_groups,1)
      ie = ubound(smat_in%mpi_groups,1)
      if (associated(smat_out%mpi_groups)) then
          deallocate(smat_out%mpi_groups)
      end if
      allocate(smat_out%mpi_groups(is:ie))
      do i=is,ie
          smat_out%mpi_groups(i) = mpi_environment_null()
          call copy_mpi_environment(smat_in%mpi_groups(i), smat_out%mpi_groups(i))
      end do
  else
      nullify(smat_out%mpi_groups)
  end if

end subroutine copy_sparse_matrix


subroutine copy_sparse_matrix_matrix_multiplication(smmm_in, smmm_out)
  use sparsematrix_base, only: sparse_matrix_matrix_multiplication
  !use copy_utils, only: allocate_and_copy
  use dynamic_memory
  implicit none

  ! Calling arguments
  type(sparse_matrix_matrix_multiplication),intent(in) :: smmm_in
  type(sparse_matrix_matrix_multiplication),intent(out) :: smmm_out
  smmm_out%nout = smmm_in%nout
  smmm_out%nseq = smmm_in%nseq
  smmm_out%nseg = smmm_in%nseg
  smmm_out%nfvctrp = smmm_in%nfvctrp
  smmm_out%isfvctr = smmm_in%isfvctr
  smmm_out%nvctrp_mm = smmm_in%nvctrp_mm
  smmm_out%isvctr_mm = smmm_in%isvctr_mm
  smmm_out%isseg = smmm_in%isseg
  smmm_out%ieseg = smmm_in%ieseg
  smmm_out%nccomm_smmm = smmm_in%nccomm_smmm
  smmm_out%nvctrp = smmm_in%nvctrp
  smmm_out%isvctr = smmm_in%isvctr
  smmm_out%nconsecutive_max = smmm_in%nconsecutive_max
  smmm_out%istartendseg_mm(1:2) = smmm_in%istartendseg_mm(1:2)
  smmm_out%istartend_mm(1:2) = smmm_in%istartend_mm(1:2)
  smmm_out%istartend_mm_dj(1:2) = smmm_in%istartend_mm_dj(1:2)

!!converted  call allocate_and_copy(smmm_in%keyv, smmm_out%keyv, id='smmm_out%keyv')
 smmm_out%keyv=f_malloc_ptr(src_ptr=smmm_in%keyv, id='smmm_out%keyv')
!!converted  call allocate_and_copy(smmm_in%keyg, smmm_out%keyg, id='smmm_out%keyg')
 smmm_out%keyg=f_malloc_ptr(src_ptr=smmm_in%keyg, id='smmm_out%keyg')
!!converted  call allocate_and_copy(smmm_in%isvctr_mm_par, smmm_out%isvctr_mm_par, id='smmm_out%isvctr_mm_par')
 smmm_out%isvctr_mm_par=f_malloc_ptr(src_ptr=smmm_in%isvctr_mm_par, id='smmm_out%isvctr_mm_par')
!!converted  call allocate_and_copy(smmm_in%nvctr_mm_par, smmm_out%nvctr_mm_par, id='smmm_out%nvctr_mm_par')
 smmm_out%nvctr_mm_par=f_malloc_ptr(src_ptr=smmm_in%nvctr_mm_par, id='smmm_out%nvctr_mm_par')
!!converted  call allocate_and_copy(smmm_in%ivectorindex, smmm_out%ivectorindex, id='smmm_out%ivectorindex')
 smmm_out%ivectorindex=f_malloc_ptr(src_ptr=smmm_in%ivectorindex, id='smmm_out%ivectorindex')
!!converted  call allocate_and_copy(smmm_in%ivectorindex_new, smmm_out%ivectorindex_new, id='smmm_out%ivectorindex_new')
 smmm_out%ivectorindex_new=f_malloc_ptr(src_ptr=smmm_in%ivectorindex_new, id='smmm_out%ivectorindex_new')
!!converted  call allocate_and_copy(smmm_in%nsegline, smmm_out%nsegline, id='smmm_out%segline')
 smmm_out%nsegline=f_malloc_ptr(src_ptr=smmm_in%nsegline, id='smmm_out%segline')
!!converted  call allocate_and_copy(smmm_in%istsegline, smmm_out%istsegline, id='smmm_out%istsegline')
 smmm_out%istsegline=f_malloc_ptr(src_ptr=smmm_in%istsegline, id='smmm_out%istsegline')
!!converted  call allocate_and_copy(smmm_in%indices_extract_sequential, smmm_out%indices_extract_sequential, &
 smmm_out%indices_extract_sequential=f_malloc_ptr(src_ptr=smmm_in%indices_extract_sequential, &
       id='smmm_out%ndices_extract_sequential')
!!converted  call allocate_and_copy(smmm_in%onedimindices, smmm_out%onedimindices, id='smmm_out%onedimindices')
 smmm_out%onedimindices=f_malloc_ptr(src_ptr=smmm_in%onedimindices, id='smmm_out%onedimindices')
!!converted  call allocate_and_copy(smmm_in%onedimindices_new, smmm_out%onedimindices_new, id='smmm_out%onedimindices_new')
 smmm_out%onedimindices_new=f_malloc_ptr(src_ptr=smmm_in%onedimindices_new, id='smmm_out%onedimindices_new')
!!converted  call allocate_and_copy(smmm_in%line_and_column_mm, smmm_out%line_and_column_mm, id='smmm_out%line_and_column_mm')
 smmm_out%line_and_column_mm=f_malloc_ptr(src_ptr=smmm_in%line_and_column_mm, id='smmm_out%line_and_column_mm')
!!converted  call allocate_and_copy(smmm_in%line_and_column, smmm_out%line_and_column, id='smmm_out%line_and_column')
 smmm_out%line_and_column=f_malloc_ptr(src_ptr=smmm_in%line_and_column, id='smmm_out%line_and_column')
!!converted  call allocate_and_copy(smmm_in%luccomm_smmm, smmm_out%luccomm_smmm, id='smmm_out%luccomm_smmm')
 smmm_out%luccomm_smmm=f_malloc_ptr(src_ptr=smmm_in%luccomm_smmm, id='smmm_out%luccomm_smmm')
!!converted  call allocate_and_copy(smmm_in%isvctr_par, smmm_out%isvctr_par, id='smmm_out%isvctr_par')
 smmm_out%isvctr_par=f_malloc_ptr(src_ptr=smmm_in%isvctr_par, id='smmm_out%isvctr_par')
!!converted  call allocate_and_copy(smmm_in%nvctr_par, smmm_out%nvctr_par, id='smmm_out%nvctr_par')
 smmm_out%nvctr_par=f_malloc_ptr(src_ptr=smmm_in%nvctr_par, id='smmm_out%nvctr_par')
!!converted  call allocate_and_copy(smmm_in%consecutive_lookup, smmm_out%consecutive_lookup, id='smmm_out%consecutive_lookup')
 smmm_out%consecutive_lookup=f_malloc_ptr(src_ptr=smmm_in%consecutive_lookup, id='smmm_out%consecutive_lookup')
  !!call allocate_and_copy(smmm_in%keyg, smmm_out%keyg, id='smmm_out%keyg')
end subroutine copy_sparse_matrix_matrix_multiplication


subroutine copy_matrices(mat_in, mat_out)
  use sparsematrix_base, only: matrices
  !use copy_utils, only: allocate_and_copy
  use dynamic_memory
  implicit none

  ! Calling arguments
  type(matrices),intent(in) :: mat_in
  type(matrices),intent(out) :: mat_out


!!converted  call allocate_and_copy(mat_in%matrix_compr, mat_out%matrix_compr, id='mat_out%matrix_compr')
 mat_out%matrix_compr=f_malloc_ptr(src_ptr=mat_in%matrix_compr, id='mat_out%matrix_compr')
!!converted  call allocate_and_copy(mat_in%matrix_comprp, mat_out%matrix_comprp, id='mat_out%matrix_comprp')
 mat_out%matrix_comprp=f_malloc_ptr(src_ptr=mat_in%matrix_comprp, id='mat_out%matrix_comprp')

!!converted  call allocate_and_copy(mat_in%matrix, mat_out%matrix, id='mat_out%matrix')
 mat_out%matrix=f_malloc_ptr(src_ptr=mat_in%matrix, id='mat_out%matrix')
!!converted  call allocate_and_copy(mat_in%matrixp, mat_out%matrixp, id='mat_out%matrixp')
 mat_out%matrixp=f_malloc_ptr(src_ptr=mat_in%matrixp, id='mat_out%matrixp')

end subroutine copy_matrices


subroutine copy_comms_linear(comms_in, comms_out)
  use communications_base, only: comms_linear
  use dynamic_memory
  implicit none

  ! Calling arguments
  type(comms_linear),intent(in) :: comms_in
  type(comms_linear),intent(out) :: comms_out


    comms_out%nptsp_c = comms_in%nptsp_c
    comms_out%ndimpsi_c = comms_in%ndimpsi_c
    comms_out%ndimind_c = comms_in%ndimind_c
    comms_out%ndimind_f = comms_in%ndimind_f
    comms_out%nptsp_f = comms_in%nptsp_f
    comms_out%ndimpsi_f = comms_in%ndimpsi_f
    comms_out%ncomms_repartitionrho = comms_in%ncomms_repartitionrho
    comms_out%window = comms_in%window
    comms_out%imethod_overlap = comms_in%imethod_overlap

!!converted    call allocate_and_copy(comms_in%nsendcounts_c, comms_out%nsendcounts_c, id='comms_out%nsendcounts_c')
 comms_out%nsendcounts_c=f_malloc_ptr(src_ptr=comms_in%nsendcounts_c, id='comms_out%nsendcounts_c')
!!converted    call allocate_and_copy(comms_in%nsenddspls_c, comms_out%nsenddspls_c, id='comms_out%nsenddspls_c')
 comms_out%nsenddspls_c=f_malloc_ptr(src_ptr=comms_in%nsenddspls_c, id='comms_out%nsenddspls_c')
!!converted    call allocate_and_copy(comms_in%nrecvcounts_c, comms_out%nrecvcounts_c, id='comms_out%nrecvcounts_c')
 comms_out%nrecvcounts_c=f_malloc_ptr(src_ptr=comms_in%nrecvcounts_c, id='comms_out%nrecvcounts_c')
!!converted    call allocate_and_copy(comms_in%nrecvdspls_c, comms_out%nrecvdspls_c, id='comms_out%nrecvdspls_c')
 comms_out%nrecvdspls_c=f_malloc_ptr(src_ptr=comms_in%nrecvdspls_c, id='comms_out%nrecvdspls_c')
!!converted    call allocate_and_copy(comms_in%isendbuf_c, comms_out%isendbuf_c, id='comms_out%isendbuf_c')
 comms_out%isendbuf_c=f_malloc_ptr(src_ptr=comms_in%isendbuf_c, id='comms_out%isendbuf_c')
!!converted    call allocate_and_copy(comms_in%iextract_c, comms_out%iextract_c, id='comms_out%iextract_c')
 comms_out%iextract_c=f_malloc_ptr(src_ptr=comms_in%iextract_c, id='comms_out%iextract_c')
!!converted    call allocate_and_copy(comms_in%iexpand_c, comms_out%iexpand_c, id='comms_out%iexpand_c')
 comms_out%iexpand_c=f_malloc_ptr(src_ptr=comms_in%iexpand_c, id='comms_out%iexpand_c')
!!converted    call allocate_and_copy(comms_in%irecvbuf_c, comms_out%irecvbuf_c, id='comms_out%irecvbuf_c')
 comms_out%irecvbuf_c=f_malloc_ptr(src_ptr=comms_in%irecvbuf_c, id='comms_out%irecvbuf_c')
!!converted    call allocate_and_copy(comms_in%norb_per_gridpoint_c, comms_out%norb_per_gridpoint_c, id='comms_out%norb_per_gridpoint_c')
 comms_out%norb_per_gridpoint_c=f_malloc_ptr(src_ptr=comms_in%norb_per_gridpoint_c, id='comms_out%norb_per_gridpoint_c')
!!converted    call allocate_and_copy(comms_in%indexrecvorbital_c, comms_out%indexrecvorbital_c, id='comms_out%indexrecvorbital_c')
 comms_out%indexrecvorbital_c=f_malloc_ptr(src_ptr=comms_in%indexrecvorbital_c, id='comms_out%indexrecvorbital_c')
!!converted    call allocate_and_copy(comms_in%nsendcounts_f, comms_out%nsendcounts_f, id='comms_out%nsendcounts_f')
 comms_out%nsendcounts_f=f_malloc_ptr(src_ptr=comms_in%nsendcounts_f, id='comms_out%nsendcounts_f')
!!converted    call allocate_and_copy(comms_in%nsenddspls_f, comms_out%nsenddspls_f, id='comms_out%nsenddspls_f')
 comms_out%nsenddspls_f=f_malloc_ptr(src_ptr=comms_in%nsenddspls_f, id='comms_out%nsenddspls_f')
!!converted    call allocate_and_copy(comms_in%nrecvcounts_f, comms_out%nrecvcounts_f, id='comms_out%nrecvcounts_f')
 comms_out%nrecvcounts_f=f_malloc_ptr(src_ptr=comms_in%nrecvcounts_f, id='comms_out%nrecvcounts_f')
!!converted    call allocate_and_copy(comms_in%nrecvdspls_f, comms_out%nrecvdspls_f, id='comms_out%nrecvdspls_f')
 comms_out%nrecvdspls_f=f_malloc_ptr(src_ptr=comms_in%nrecvdspls_f, id='comms_out%nrecvdspls_f')
!!converted    call allocate_and_copy(comms_in%isendbuf_f, comms_out%isendbuf_f, id='comms_out%isendbuf_f')
 comms_out%isendbuf_f=f_malloc_ptr(src_ptr=comms_in%isendbuf_f, id='comms_out%isendbuf_f')
!!converted    call allocate_and_copy(comms_in%iextract_f, comms_out%iextract_f, id='comms_out%iextract_f')
 comms_out%iextract_f=f_malloc_ptr(src_ptr=comms_in%iextract_f, id='comms_out%iextract_f')
!!converted    call allocate_and_copy(comms_in%iexpand_f, comms_out%iexpand_f, id='comms_out%iexpand_f')
 comms_out%iexpand_f=f_malloc_ptr(src_ptr=comms_in%iexpand_f, id='comms_out%iexpand_f')
!!converted    call allocate_and_copy(comms_in%irecvbuf_f, comms_out%irecvbuf_f, id='comms_out%irecvbuf_f')
 comms_out%irecvbuf_f=f_malloc_ptr(src_ptr=comms_in%irecvbuf_f, id='comms_out%irecvbuf_f')
!!converted    call allocate_and_copy(comms_in%norb_per_gridpoint_f, comms_out%norb_per_gridpoint_f, id='ncomms_out%orb_per_gridpoint_f')
 comms_out%norb_per_gridpoint_f=f_malloc_ptr(src_ptr=comms_in%norb_per_gridpoint_f, id='ncomms_out%orb_per_gridpoint_f')
!!converted    call allocate_and_copy(comms_in%indexrecvorbital_f, comms_out%indexrecvorbital_f, id='comms_out%indexrecvorbital_f')
 comms_out%indexrecvorbital_f=f_malloc_ptr(src_ptr=comms_in%indexrecvorbital_f, id='comms_out%indexrecvorbital_f')
!!converted    call allocate_and_copy(comms_in%isptsp_c, comms_out%isptsp_c, id='comms_out%isptsp_c')
 comms_out%isptsp_c=f_malloc_ptr(src_ptr=comms_in%isptsp_c, id='comms_out%isptsp_c')
!!converted    call allocate_and_copy(comms_in%isptsp_f, comms_out%isptsp_f, id='comms_out%isptsp_f')
 comms_out%isptsp_f=f_malloc_ptr(src_ptr=comms_in%isptsp_f, id='comms_out%isptsp_f')
!!converted    call allocate_and_copy(comms_in%nsendcounts_repartitionrho, comms_out%nsendcounts_repartitionrho, &
 comms_out%nsendcounts_repartitionrho=f_malloc_ptr(src_ptr=comms_in%nsendcounts_repartitionrho, &
                           id='comms_out%nsendcounts_repartitionrho')
!!converted    call allocate_and_copy(comms_in%nrecvcounts_repartitionrho, comms_out%nrecvcounts_repartitionrho, &
 comms_out%nrecvcounts_repartitionrho=f_malloc_ptr(src_ptr=comms_in%nrecvcounts_repartitionrho, &
                           id='comms_out%nrecvcounts_repartitionrho')
!!converted    call allocate_and_copy(comms_in%nsenddspls_repartitionrho, comms_out%nsenddspls_repartitionrho, &
 comms_out%nsenddspls_repartitionrho=f_malloc_ptr(src_ptr=comms_in%nsenddspls_repartitionrho, &
                           id='comms_out%nsenddspls_repartitionrho')
!!converted    call allocate_and_copy(comms_in%nrecvdspls_repartitionrho, comms_out%nrecvdspls_repartitionrho, &
 comms_out%nrecvdspls_repartitionrho=f_malloc_ptr(src_ptr=comms_in%nrecvdspls_repartitionrho, &
                           id='comms_out%nrecvdspls_repartitionrho')

!!converted    call allocate_and_copy(comms_in%commarr_repartitionrho, comms_out%commarr_repartitionrho, id='comms_in%commarr_repartitionrho')
 comms_out%commarr_repartitionrho=f_malloc_ptr(src_ptr=comms_in%commarr_repartitionrho, id='comms_in%commarr_repartitionrho')

!!converted    call allocate_and_copy(comms_in%psit_c, comms_out%psit_c, id='comms_out%psit_c')
 comms_out%psit_c=f_malloc_ptr(src_ptr=comms_in%psit_c, id='comms_out%psit_c')
!!converted    call allocate_and_copy(comms_in%psit_f, comms_out%psit_f, id='comms_out%psit_f')
 comms_out%psit_f=f_malloc_ptr(src_ptr=comms_in%psit_f, id='comms_out%psit_f')

end subroutine copy_comms_linear


subroutine copy_mpi_environment(mpi_in, mpi_out)
  use module_base
  use wrapper_MPI, only: mpi_environment
  implicit none
  ! Calling arguments
  type(mpi_environment),intent(in) :: mpi_in
  type(mpi_environment),intent(out) :: mpi_out
  ! Local variables
  integer :: ierr

  if (mpi_in%mpi_comm/=MPI_COMM_NULL) then
      call mpi_comm_dup(mpi_in%mpi_comm, mpi_out%mpi_comm, ierr)
      call mpi_comm_size(mpi_out%mpi_comm, mpi_out%nproc, ierr)
      call mpi_comm_rank(mpi_out%mpi_comm, mpi_out%nproc, ierr)
  end if
  mpi_out%igroup = mpi_in%igroup
  mpi_out%ngroup = mpi_in%ngroup

end subroutine copy_mpi_environment
