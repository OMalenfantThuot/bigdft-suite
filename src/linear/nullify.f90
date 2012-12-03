subroutine nullifyInputLinparameters(lin)
  use module_base
  use module_types
  use module_interfaces
  implicit none

  ! Calling arguments
  type(linearInputParameters),intent(inout):: lin

  nullify(lin%locrad)
  nullify(lin%potentialPrefac)
  nullify(lin%potentialPrefac_lowaccuracy)
  nullify(lin%potentialPrefac_highaccuracy)
  nullify(lin%norbsPerType)

end subroutine nullifyInputLinparameters


subroutine nullify_p2pComms(p2pcomm)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_p2pComms
  implicit none

  ! Calling argument
  type(p2pComms),intent(inout):: p2pcomm

  nullify(p2pcomm%noverlaps)
  !!nullify(p2pcomm%overlaps)
  nullify(p2pcomm%sendBuf)
  nullify(p2pcomm%recvBuf)
  nullify(p2pcomm%comarr)
  nullify(p2pcomm%ise)
  nullify(p2pcomm%requests)
  nullify(p2pcomm%mpi_datatypes)

end subroutine nullify_p2pComms



subroutine nullify_overlapParameters(op)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_overlapParameters
  implicit none

  ! Calling argument
  type(overlapParameters),intent(out):: op

  nullify(op%noverlaps)
  nullify(op%overlaps)
  !!nullify(op%indexInRecvBuf)
  !!nullify(op%indexInSendBuf)
  !!nullify(op%wfd_overlap)

end subroutine nullify_overlapParameters




subroutine nullify_matrixDescriptors(mad)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_matrixDescriptors
  implicit none

  ! Calling argument
  type(matrixDescriptors),intent(out):: mad

  nullify(mad%keyv)
  !!nullify(mad%keyvmatmul)
  nullify(mad%nsegline)
  nullify(mad%keyg)
  !!nullify(mad%keygmatmul)
  nullify(mad%keygline)
  nullify(mad%kernel_locreg)
  nullify(mad%istsegline)
  nullify(mad%kernel_nseg)
  nullify(mad%kernel_segkeyg)

end subroutine nullify_matrixDescriptors



subroutine nullify_local_zone_descriptors(lzd)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_local_zone_descriptors
  implicit none

  ! Calling arguments
  type(local_zone_descriptors),intent(out):: lzd
 
  call nullify_locreg_descriptors(lzd%glr)
  nullify(lzd%llr)
  nullify(lzd%doHamAppl)
 
end subroutine nullify_local_zone_descriptors



subroutine nullify_orbitals_data(orbs)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(orbitals_data),intent(out):: orbs
  
  nullify(orbs%norb_par)
  nullify(orbs%iokpt)
  nullify(orbs%ikptproc)
  nullify(orbs%inwhichlocreg)
  nullify(orbs%onwhichatom)
  nullify(orbs%onWhichMPI)
  nullify(orbs%isorb_par)
  nullify(orbs%eval)
  nullify(orbs%occup)
  nullify(orbs%spinsgn)
  nullify(orbs%kwgts)
  nullify(orbs%kpts)
  nullify(orbs%ispot)
  orbs%npsidim_orbs=1
  orbs%npsidim_comp=1

end subroutine nullify_orbitals_data


subroutine nullify_communications_arrays(comms)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(communications_arrays),intent(out):: comms

  nullify(comms%ncntd)
  nullify(comms%ncntt)
  nullify(comms%ndspld)
  nullify(comms%ndsplt)
  nullify(comms%nvctr_par)
  
end subroutine nullify_communications_arrays


subroutine nullify_locreg_descriptors(lr)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_locreg_descriptors
  implicit none

  ! Calling arguments
  type(locreg_descriptors),intent(out):: lr

  call nullify_wavefunctions_descriptors(lr%wfd)
  call nullify_convolutions_bounds(lr%bounds)

end subroutine nullify_locreg_descriptors


subroutine nullify_wavefunctions_descriptors(wfd)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(wavefunctions_descriptors),intent(out):: wfd

  nullify(wfd%keygloc)
  nullify(wfd%keyglob)
  nullify(wfd%keyvloc)
  nullify(wfd%keyvglob)

end subroutine nullify_wavefunctions_descriptors


subroutine nullify_convolutions_bounds(bounds)
  use module_base
  use module_types
  use module_interfaces, exceptThisOne => nullify_convolutions_bounds
  implicit none

  ! Calling arguments
  type(convolutions_bounds),intent(out):: bounds

  call nullify_kinetic_bounds(bounds%kb)
  call nullify_shrink_bounds(bounds%sb)
  call nullify_grow_bounds(bounds%gb)
  nullify(bounds%ibyyzz_r)

end subroutine nullify_convolutions_bounds



subroutine nullify_kinetic_bounds(kb)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(kinetic_bounds),intent(out):: kb

  nullify(kb%ibyz_c)
  nullify(kb%ibxz_c)
  nullify(kb%ibxy_c)
  nullify(kb%ibyz_f)
  nullify(kb%ibxz_f)
  nullify(kb%ibxy_f)

end subroutine nullify_kinetic_bounds



subroutine nullify_shrink_bounds(sb)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(shrink_bounds),intent(out):: sb

  nullify(sb%ibzzx_c)
  nullify(sb%ibyyzz_c)
  nullify(sb%ibxy_ff)
  nullify(sb%ibzzx_f)
  nullify(sb%ibyyzz_f)

end subroutine nullify_shrink_bounds



subroutine nullify_grow_bounds(gb)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(grow_bounds),intent(out):: gb

  nullify(gb%ibzxx_c)
  nullify(gb%ibxxyy_c)
  nullify(gb%ibyz_ff)
  nullify(gb%ibzxx_f)
  nullify(gb%ibxxyy_f)

end subroutine nullify_grow_bounds





subroutine nullify_collective_comms(collcom)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(collective_comms),intent(inout):: collcom

  ! Local variables
  nullify(collcom%nsendcounts_c)
  nullify(collcom%nsenddspls_c)
  nullify(collcom%nrecvcounts_c)
  nullify(collcom%nrecvdspls_c)
  nullify(collcom%isendbuf_c)
  nullify(collcom%iextract_c)
  nullify(collcom%iexpand_c)
  nullify(collcom%irecvbuf_c)
  nullify(collcom%norb_per_gridpoint_c)
  nullify(collcom%indexrecvorbital_c)
  nullify(collcom%isptsp_c)
  nullify(collcom%psit_c)
  nullify(collcom%nsendcounts_f)
  nullify(collcom%nsenddspls_f)
  nullify(collcom%nrecvcounts_f)
  nullify(collcom%nrecvdspls_f)
  nullify(collcom%isendbuf_f)
  nullify(collcom%iextract_f)
  nullify(collcom%iexpand_f)
  nullify(collcom%irecvbuf_f)
  nullify(collcom%norb_per_gridpoint_f)
  nullify(collcom%indexrecvorbital_f)
  nullify(collcom%isptsp_f)
  nullify(collcom%psit_f)
  nullify(collcom%nsendcounts_repartitionrho)
  nullify(collcom%nrecvcounts_repartitionrho)
  nullify(collcom%nsenddspls_repartitionrho)
  nullify(collcom%nrecvdspls_repartitionrho)
  nullify(collcom%matrixindex_in_compressed)

end subroutine nullify_collective_comms
