subroutine checkLinearParameters(iproc, nproc, lin)
!
! Purpose:
! ========
!  Checks some values contained in the variable lin on errors.
!
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc
type(linearParameters),intent(inout):: lin

! Local variables
integer:: norbTarget, nprocIG, ierr


  if(lin%DIISHistMin>lin%DIISHistMax) then
      if(iproc==0) write(*,'(1x,a,i0,a,i0,a)') 'ERROR: DIISHistMin must not be larger than &
      & DIISHistMax, but you chose ', lin%DIISHistMin, ' and ', lin%DIISHistMax, '!'
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  !!if(trim(lin%getCoeff)/='min' .and. trim(lin%getCoeff)/='diag') then
  !!    if(iproc==0) write(*,'(1x,a,a,a)') "ERROR: lin%getCoeff can have the values 'diag' or 'min', &
  !!        & but we found '", trim(lin%getCoeff), "'!"
  !!    call mpi_barrier(mpi_comm_world, ierr)
  !!    stop
  !!end if

  if(lin%methTransformOverlap<0 .or. lin%methTransformOverlap>2) then
      if(iproc==0) write(*,'(1x,a,i0,a)') 'ERROR: lin%methTransformOverlap must be 0,1 or 2, but you specified ', &
                               lin%methTransformOverlap,'.'
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  !!if(trim(lin%getCoeff)=='diag') then
  !!    if(trim(lin%diagMethod)/='seq' .and. trim(lin%diagMethod)/='par') then
  !!        if(iproc==0) write(*,'(1x,a,a,a)') "ERROR: lin%diagMethod can have the values 'seq' or 'par', &
  !!            & but we found '", trim(lin%diagMethod), "'!"
  !!        call mpi_barrier(mpi_comm_world, ierr)
  !!        stop
  !!    end if
  !!end if

  if(lin%confPotOrder/=4 .and. lin%confPotOrder/=6) then
      if(iproc==0) write(*,'(1x,a,i0,a)') 'ERROR: lin%confPotOrder can have the values 4 or 6, &
          & but we found ', lin%confPotOrder, '!'
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if


  ! Determine the number of processes we need for the minimization of the trace in the input guess.
  if(lin%norbsPerProcIG>lin%orbs%norb) then
      norbTarget=lin%orbs%norb
  else
      norbTarget=lin%norbsperProcIG
  end if
  nprocIG=ceiling(dble(lin%orbs%norb)/dble(norbTarget))
  nprocIG=min(nprocIG,nproc)

  if( nprocIG/=nproc .and. ((lin%methTransformOverlap==0 .and. (lin%blocksize_pdsyev>0 .or. lin%blocksize_pdgemm>0)) .or. &
      (lin%methTransformOverlap==1 .and. lin%blocksize_pdgemm>0)) ) then
      if(iproc==0) then
          write(*,'(1x,a)') 'ERROR: You want to use some routines from scalapack. This is only possible if all processes are &
                     &involved in these calls, which is not the case here.'
          write(*,'(1x,a)') 'To avoid this problem you have several possibilities:'
          write(*,'(3x,a,i0,a)') "-set 'lin%norbsperProcIG' to a value not greater than ",floor(dble(lin%orbs%norb)/dble(nproc)), &
              ' (recommended; probably only little influence on performance)'
          write(*,'(3x,a)') "-if you use 'lin%methTransformOverlap==1': set 'lin%blocksize_pdgemm' to a negative value &
              &(may heavily affect performance)"
          write(*,'(3x,a)') "-if you use 'lin%methTransformOverlap==0': set 'lin%blocksize_pdsyev' and 'lin%blocksize_pdsyev' &
              &to negative values (may very heavily affect performance)"
      end if
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  if(lin%nproc_pdsyev>nproc) then
      if(iproc==0) write(*,'(1x,a)') 'ERROR: lin%nproc_pdsyev can not be larger than nproc'
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  if(lin%nproc_pdgemm>nproc) then
      if(iproc==0) write(*,'(1x,a)') 'ERROR: lin%nproc_pdgemm can not be larger than nproc'
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  if(lin%locregShape/='c' .and. lin%locregShape/='s') then
      if(iproc==0) write(*,*) "ERROR: lin%locregShape must be 's' or 'c'!"
      call mpi_barrier(mpi_comm_world, ierr)
      stop
  end if

  if(lin%mixedmode .and. .not.lin%useDerivativeBasisFunctions) then
      if(iproc==0) write(*,*) 'WARNING: will set lin%useDerivativeBasisFunctions to true, &
                               &since this is required if lin%mixedmode is true!'
      lin%useDerivativeBasisFunctions=.true.
  end if



end subroutine checkLinearParameters

subroutine deallocateLinear(iproc, lin, lphi, coeff)
!
! Purpose:
! ========
!   Deallocates all array related to the linear scaling version which have not been 
!   deallocated so far.
!
! Calling arguments:
! ==================
!
use module_base
use module_types
use module_interfaces, exceptThisOne => deallocateLinear
implicit none

! Calling arguments
integer,intent(in):: iproc
type(linearParameters),intent(inout):: lin
real(8),dimension(:),pointer,intent(inout):: lphi
real(8),dimension(:,:),pointer,intent(inout):: coeff

! Local variables
integer:: istat, iall
character(len=*),parameter:: subname='deallocateLinear'


  iall=-product(shape(lphi))*kind(lphi)
  deallocate(lphi, stat=istat)
  call memocc(istat, iall, 'lphi', subname)

  iall=-product(shape(coeff))*kind(coeff)
  deallocate(coeff, stat=istat)
  call memocc(istat, iall, 'coeff', subname)

  call deallocate_linearParameters(lin, subname)

end subroutine deallocateLinear







subroutine initializeCommsSumrho(iproc,nproc,nscatterarr,lzd,orbs,tag,comsr)
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: iproc,nproc
integer,dimension(0:nproc-1,4),intent(in):: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
type(local_zone_descriptors),intent(in):: lzd
type(orbitals_data),intent(in):: orbs
integer,intent(inout):: tag
!type(p2pCommsSumrho),intent(out):: comsr
type(p2pComms),intent(out):: comsr

! Local variables
integer:: istat,jproc,is,ie,ioverlap,i3s,i3e,ilr,iorb,is3ovrlp,n3ovrlp
integer:: i1s, i1e, i2s, i2e, ii, jlr, iiorb, istri, jorb, jjorb, istrj
integer:: nbl1,nbr1,nbl2,nbr2,nbl3,nbr3
character(len=*),parameter:: subname='initializeCommsSumrho'

! Buffer sizes 
call ext_buffers(lzd%Glr%geocode /= 'F',nbl1,nbr1)
call ext_buffers(lzd%Glr%geocode == 'P',nbl2,nbr2)
call ext_buffers(lzd%Glr%geocode /= 'F',nbl3,nbr3)

! First count the number of overlapping orbitals for each slice.
allocate(comsr%noverlaps(0:nproc-1),stat=istat)
call memocc(istat,comsr%noverlaps,'comsr%noverlaps',subname)
do jproc=0,nproc-1
    is=nscatterarr(jproc,3) 
    ie=is+nscatterarr(jproc,1)-1
    ioverlap=0
    do iorb=1,orbs%norb
        ilr=orbs%inWhichLocreg(iorb)
        i3s=lzd%Llr(ilr)%nsi3 
        i3e=i3s+lzd%Llr(ilr)%d%n3i-1
        if(i3s<=ie .and. i3e>=is) then
            ioverlap=ioverlap+1        
        end if
        !For periodicity
        if(i3e > Lzd%Glr%nsi3 + Lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F') then
          i3s = Lzd%Glr%nsi3
          i3e = mod(i3e,Lzd%Glr%d%n3i+1) + Lzd%Glr%nsi3
          if(i3s<=ie .and. i3e>=is) then
              ioverlap=ioverlap+1
          end if
        end if
    end do
    comsr%noverlaps(jproc)=ioverlap
end do

! Do the initialization concerning the calculation of the charge density.
allocate(comsr%istarr(0:nproc-1),stat=istat)
call memocc(istat,comsr%istarr,'comsr%istarr',subname)
!allocate(comsr%istrarr(comsr%noverlaps(iproc)),stat=istat)
allocate(comsr%istrarr(0:nproc-1),stat=istat)
call memocc(istat,comsr%istrarr,'comsr%istrarr',subname)
allocate(comsr%overlaps(comsr%noverlaps(iproc)),stat=istat)
call memocc(istat,comsr%overlaps,'comsr%overlaps',subname)

allocate(comsr%comarr(9,maxval(comsr%noverlaps),0:nproc-1),stat=istat)
call memocc(istat,comsr%comarr,'coms%commsSumrho',subname)
allocate(comsr%startingindex(comsr%noverlaps(iproc),2), stat=istat)
call memocc(istat, comsr%startingindex, 'comsr%startingindex', subname)

comsr%istarr=1
comsr%istrarr=1
comsr%nrecvBuf=0
do jproc=0,nproc-1
   is=nscatterarr(jproc,3)
   ie=is+nscatterarr(jproc,1)-1
   ioverlap=0
   do iorb=1,orbs%norb
      ilr=orbs%inWhichLocreg(iorb)
      i3s=lzd%Llr(ilr)%nsi3
      i3e=i3s+lzd%Llr(ilr)%d%n3i-1
      if(i3s<=ie .and. i3e>=is) then
         ioverlap=ioverlap+1
         tag=tag+1
         is3ovrlp=max(is,i3s) !start of overlapping zone in z direction
         n3ovrlp=min(ie,i3e)-max(is,i3s)+1  !extent of overlapping zone in z direction
         is3ovrlp=is3ovrlp-lzd%Llr(ilr)%nsi3+1
         if(jproc == iproc) then
            comsr%startingindex(ioverlap,1) = max(is,i3s) 
            comsr%startingindex(ioverlap,2) = min(ie,i3e)
         end if
         call setCommunicationInformation2(jproc, iorb, is3ovrlp, n3ovrlp, comsr%istrarr(jproc), &
              tag, lzd%nlr, lzd%Llr,&
              orbs%inWhichLocreg, orbs, comsr%comarr(1,ioverlap,jproc))
         if(iproc==jproc) then
            comsr%nrecvBuf = comsr%nrecvBuf + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
            comsr%overlaps(ioverlap)=iorb
         end if
         comsr%istrarr(jproc) = comsr%istrarr(jproc) + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
      end if
      !For periodicity
      if(i3e > Lzd%Glr%nsi3 + Lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F') then
         i3s = Lzd%Glr%nsi3
         i3e = mod(i3e,Lzd%Glr%d%n3i+1) + Lzd%Glr%nsi3
         if(i3s<=ie .and. i3e>=is) then
            ioverlap=ioverlap+1
            tag=tag+1
            is3ovrlp=max(is,i3s) !start of overlapping zone in z direction
            n3ovrlp=min(ie,i3e)-max(is,i3s)+1  !extent of overlapping zone in z direction
            is3ovrlp=is3ovrlp + lzd%Glr%d%n3i-lzd%Llr(ilr)%nsi3+1 !should I put -nbl3 here
            if(jproc == iproc) then
               comsr%startingindex(ioverlap,1) = max(is,i3s) 
               comsr%startingindex(ioverlap,2) = min(ie,i3e)
            end if
            call setCommunicationInformation2(jproc, iorb, is3ovrlp, n3ovrlp, comsr%istrarr(jproc), &
                 tag, lzd%nlr, lzd%Llr,&
                 orbs%inWhichLocreg, orbs, comsr%comarr(1,ioverlap,jproc))
            if(iproc==jproc) then
               comsr%nrecvBuf = comsr%nrecvBuf + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
               comsr%overlaps(ioverlap)=iorb
            end if
            comsr%istrarr(jproc) = comsr%istrarr(jproc) + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
         end if
         !For periodicity
         if(i3e > Lzd%Glr%nsi3 + Lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F') then
            i3s = Lzd%Glr%nsi3
            i3e = mod(i3e,Lzd%Glr%d%n3i+1) + Lzd%Glr%nsi3
            if(i3s<=ie .and. i3e>=is) then
               ioverlap=ioverlap+1
               tag=tag+1
               is3ovrlp=max(is,i3s) !start of overlapping zone in z direction
               n3ovrlp=min(ie,i3e)-max(is,i3s)+1  !extent of overlapping zone in z direction
               is3ovrlp=is3ovrlp + lzd%Glr%d%n3i-lzd%Llr(ilr)%nsi3+1 !should I put -nbl3 here
               if(jproc == iproc) then
                  comsr%startingindex(ioverlap,1) = max(is,i3s) 
                  comsr%startingindex(ioverlap,2) = min(ie,i3e)
               end if
               call setCommunicationInformation2(jproc, iorb, is3ovrlp, n3ovrlp, comsr%istrarr(jproc), &
                    tag, lzd%nlr, lzd%Llr,&
                    orbs%inWhichLocreg, orbs, comsr%comarr(1,ioverlap,jproc))
               if(iproc==jproc) then
                  comsr%nrecvBuf = comsr%nrecvBuf + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
                  comsr%overlaps(ioverlap)=iorb
               end if
               comsr%istrarr(jproc) = comsr%istrarr(jproc) + lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*n3ovrlp
            end if
         end if
      end if
   end do
end do

! To avoid allocations with size 0.
comsr%nrecvbuf=max(comsr%nrecvbuf,1)


allocate(comsr%communComplete(maxval(comsr%noverlaps(:)),0:nproc-1), stat=istat)
call memocc(istat, comsr%communComplete, 'comsr%communComplete', subname)
allocate(comsr%computComplete(maxval(comsr%noverlaps(:)),0:nproc-1), stat=istat)
call memocc(istat, comsr%computComplete, 'comsr%computComplete', subname)

!!is=nscatterarr(iproc,3) 
!!ie=is+nscatterarr(iproc,1)-1
!!do ioverlap = 1, comsr%noverlaps(iproc)
!!   iorb = comsr%overlaps(ioverlap) 
!!   ilr = orbs%inWhichLocreg(iorb)
!!   i3s=lzd%Llr(ilr)%nsi3  
!!   i3e=i3s+lzd%Llr(ilr)%d%n3i-1
!!   if(i3s<=ie .and. i3e>=is) then
!!   end if
!!   if(i3e > Lzd%Glr%nsi3 + Lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F') then
!!      i3s = Lzd%Glr%nsi3
!!      i3e = mod(i3e,Lzd%Glr%d%n3i+1) + Lzd%Glr%nsi3
!!      if(i3s<=ie .and. i3e>=is) then
!!         comsr%startingindex(ioverlap,1) = max(is,i3s) 
!!         comsr%startingindex(ioverlap,2) = min(ie,i3e)
!!      end if
!!   end if
!!end do


! Calculate the dimension of the wave function for each process.
! Do it for both the compressed ('npsidim') and for the uncompressed real space
! ('npsidimr') case.
comsr%nsendBuf=0
do iorb=1,orbs%norbp
    ilr=orbs%inWhichLocreg(orbs%isorb+iorb)
    comsr%nsendBuf=comsr%nsendBuf+lzd%Llr(ilr)%d%n1i*lzd%Llr(ilr)%d%n2i*lzd%Llr(ilr)%d%n3i*orbs%nspinor
end do

!!allocate(comsr%sendBuf(comsr%nsendBuf), stat=istat)
!!call memocc(istat, comsr%sendBuf, 'comsr%sendBuf', subname)
!!call razero(comsr%nSendBuf, comsr%sendBuf)
!!
!!allocate(comsr%recvBuf(comsr%nrecvBuf), stat=istat)
!!call memocc(istat, comsr%recvBuf, 'comsr%recvBuf', subname)
!!call razero(comsr%nrecvBuf, comsr%recvBuf)


! Determine the size of the auxiliary array
!!allocate(comsr%startingindex(comsr%noverlaps(iproc),comsr%noverlaps(iproc)), stat=istat)
!!call memocc(istat, comsr%startingindex, 'comsr%startingindex', subname)
!!
!!! Bounds of the slice in global coordinates.
!!comsr%nauxarray=0
!!is=nscatterarr(iproc,3) ! should I put -nbl3
!!ie=is+nscatterarr(iproc,1)-1
!!do iorb=1,comsr%noverlaps(iproc)
!!    iiorb=comsr%overlaps(iorb) !global index of orbital iorb
!!    ilr=comsr%comarr(4,iorb,iproc) !localization region of orbital iorb
!!    istri=comsr%comarr(6,iorb,iproc)-1 !starting index of orbital iorb in the receive buffer
!!    !do jorb=1,comsr%noverlaps(iproc)
!!    do jorb=iorb,comsr%noverlaps(iproc)
!!        jjorb=comsr%overlaps(jorb) !global indes of orbital jorb
!!        jlr=comsr%comarr(4,jorb,iproc) !localization region of orbital jorb
!!        istrj=comsr%comarr(6,jorb,iproc)-1 !starting index of orbital jorb in the receive buffer
!!        ! Bounds of the overlap of orbital iorb and jorb in global coordinates.
!!        i1s=max(lzd%llr(ilr)%nsi1,lzd%llr(jlr)%nsi1)
!!        i1e=min(lzd%llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i-1,lzd%llr(jlr)%nsi1+lzd%llr(jlr)%d%n1i-1)
!!        i2s=max(lzd%llr(ilr)%nsi2,lzd%llr(jlr)%nsi2)
!!        i2e=min(lzd%llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i-1,lzd%llr(jlr)%nsi2+lzd%llr(jlr)%d%n2i-1)
!!        i3s=max(lzd%llr(ilr)%nsi3,lzd%llr(jlr)%nsi3,is)
!!        i3e=min(lzd%llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i-1,lzd%llr(jlr)%nsi3+lzd%llr(jlr)%d%n3i-1,ie)
!!
!!        comsr%startingindex(jorb,iorb)=comsr%nauxarray+1
!!        ii=(i1e-i1s+1)*(i2e-i2s+1)*(i3e-i3s+1)
!!        comsr%nauxarray = comsr%nauxarray + ii
!!    end do
!!end do

end subroutine initializeCommsSumrho






subroutine allocateBasicArrays(lin, ntypes)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(linearParameters),intent(inout):: lin
  integer, intent(in) :: ntypes
  
  ! Local variables
  integer:: istat
  character(len=*),parameter:: subname='allocateBasicArrays'
  
  allocate(lin%norbsPerType(ntypes), stat=istat)
  call memocc(istat, lin%norbsPerType, 'lin%norbsPerType', subname)
  
  allocate(lin%potentialPrefac(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac, 'lin%potentialPrefac', subname)

  allocate(lin%potentialPrefac_lowaccuracy(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac_lowaccuracy, 'lin%potentialPrefac_lowaccuracy', subname)

  allocate(lin%potentialPrefac_highaccuracy(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac_highaccuracy, 'lin%potentialPrefac_highaccuracy', subname)

  allocate(lin%locrad(lin%nlr),stat=istat)
  call memocc(istat,lin%locrad,'lin%locrad',subname)

end subroutine allocateBasicArrays

subroutine deallocateBasicArrays(lin)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(linearParameters),intent(inout):: lin
  
  ! Local variables
  integer:: i_stat,i_all
  character(len=*),parameter:: subname='deallocateBasicArrays'
 
  if(associated(lin%potentialPrefac)) then
    !print *,'lin%potentialPrefac',associated(lin%potentialPrefac)
    i_all = -product(shape(lin%potentialPrefac))*kind(lin%potentialPrefac)
    !print *,'i_all',i_all
    deallocate(lin%potentialPrefac,stat=i_stat)
    call memocc(i_stat,i_all,'lin%potentialPrefac',subname)
    nullify(lin%potentialPrefac)
  end if 
  if(associated(lin%norbsPerType)) then
    !print *,'lin%norbsPerType',associated(lin%norbsPerType)
    i_all = -product(shape(lin%norbsPerType))*kind(lin%norbsPerType)
    deallocate(lin%norbsPerType,stat=i_stat)
    call memocc(i_stat,i_all,'lin%norbsPerType',subname)
    nullify(lin%norbsPerType)
  end if 
  if(associated(lin%locrad)) then
    !print *,'lin%locrad',associated(lin%locrad)
    i_all = -product(shape(lin%locrad))*kind(lin%locrad)
    deallocate(lin%locrad,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad',subname)
    nullify(lin%locrad)
  end if 

end subroutine deallocateBasicArrays


subroutine allocateBasicArraysInputLin(lin, ntypes, nat)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer:: nlr
  type(linearInputParameters),intent(inout):: lin
  integer, intent(in) :: ntypes, nat
  
  ! Local variables
  integer:: istat
  character(len=*),parameter:: subname='allocateBasicArrays'
  
  allocate(lin%norbsPerType(ntypes), stat=istat)
  call memocc(istat, lin%norbsPerType, 'lin%norbsPerType', subname)
  
  allocate(lin%potentialPrefac(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac, 'lin%potentialPrefac', subname)

  allocate(lin%potentialPrefac_lowaccuracy(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac_lowaccuracy, 'lin%potentialPrefac_lowaccuracy', subname)

  allocate(lin%potentialPrefac_highaccuracy(ntypes), stat=istat)
  call memocc(istat, lin%potentialPrefac_highaccuracy, 'lin%potentialPrefac_highaccuracy', subname)

  !!allocate(lin%locrad(nlr),stat=istat)
  !!call memocc(istat,lin%locrad,'lin%locrad',subname)

end subroutine allocateBasicArraysInputLin

subroutine deallocateBasicArraysInput(lin)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(linearinputParameters),intent(inout):: lin
  
  ! Local variables
  integer:: i_stat,i_all
  character(len=*),parameter:: subname='deallocateBasicArrays'
 
  if(associated(lin%potentialPrefac)) then
!    print *,'lin%potentialPrefac',associated(lin%potentialPrefac)
    i_all = -product(shape(lin%potentialPrefac))*kind(lin%potentialPrefac)
    !print *,'i_all',i_all
    deallocate(lin%potentialPrefac,stat=i_stat)
    call memocc(i_stat,i_all,'lin%potentialPrefac',subname)
    nullify(lin%potentialPrefac)
  end if 
  if(associated(lin%potentialPrefac_lowaccuracy)) then
!    print *,'lin%potentialPrefac_lowaccuracy',associated(lin%potentialPrefac_lowaccuracy)
    i_all = -product(shape(lin%potentialPrefac_lowaccuracy))*kind(lin%potentialPrefac_lowaccuracy)
    !print *,'i_all',i_all
    deallocate(lin%potentialPrefac_lowaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%potentialPrefac_lowaccuracy',subname)
    nullify(lin%potentialPrefac_lowaccuracy)
  end if 
  if(associated(lin%potentialPrefac_highaccuracy)) then
!    print *,'lin%potentialPrefac_highaccuracy',associated(lin%potentialPrefac_highaccuracy)
    i_all = -product(shape(lin%potentialPrefac_highaccuracy))*kind(lin%potentialPrefac_highaccuracy)
    !print *,'i_all',i_all
    deallocate(lin%potentialPrefac_highaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%potentialPrefac_highaccuracy',subname)
    nullify(lin%potentialPrefac_highaccuracy)
  end if 

  if(associated(lin%norbsPerType)) then
!    print *,'lin%norbsPerType',associated(lin%norbsPerType)
    i_all = -product(shape(lin%norbsPerType))*kind(lin%norbsPerType)
    deallocate(lin%norbsPerType,stat=i_stat)
    call memocc(i_stat,i_all,'lin%norbsPerType',subname)
    nullify(lin%norbsPerType)
  end if 
  if(associated(lin%locrad)) then
!    print *,'lin%locrad',associated(lin%locrad)
    i_all = -product(shape(lin%locrad))*kind(lin%locrad)
    deallocate(lin%locrad,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad',subname)
    nullify(lin%locrad)
  end if 

  if(associated(lin%locrad_lowaccuracy)) then
    i_all = -product(shape(lin%locrad_lowaccuracy))*kind(lin%locrad_lowaccuracy)
    deallocate(lin%locrad_lowaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad_lowaccuracy',subname)
    nullify(lin%locrad_lowaccuracy)
  end if 

  if(associated(lin%locrad_highaccuracy)) then
    i_all = -product(shape(lin%locrad_highaccuracy))*kind(lin%locrad_highaccuracy)
    deallocate(lin%locrad_highaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad_highaccuracy',subname)
    nullify(lin%locrad_highaccuracy)
  end if 


  if(associated(lin%locrad_lowaccuracy)) then
    i_all = -product(shape(lin%locrad_lowaccuracy))*kind(lin%locrad_lowaccuracy)
    deallocate(lin%locrad_lowaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad_lowaccuracy',subname)
    nullify(lin%locrad_lowaccuracy)
  end if 

  if(associated(lin%locrad_highaccuracy)) then
    i_all = -product(shape(lin%locrad_highaccuracy))*kind(lin%locrad_highaccuracy)
    deallocate(lin%locrad_highaccuracy,stat=i_stat)
    call memocc(i_stat,i_all,'lin%locrad_highaccuracy',subname)
    nullify(lin%locrad_highaccuracy)
  end if 


end subroutine deallocateBasicArraysInput




!> Does the same as initLocregs, but has as argumenst lzd instead of lin, i.e. all quantities are
!! are assigned to lzd%Llr etc. instead of lin%Llr. Can probably completely replace initLocregs.
!subroutine initLocregs2(iproc, nat, rxyz, lzd, input, Glr, locrad, phi, lphi)
subroutine initLocregs(iproc, nproc, nlr, rxyz, hx, hy, hz, lzd, orbs, Glr, locrad, locregShape, lborbs)
use module_base
use module_types
use module_interfaces, exceptThisOne => initLocregs
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc, nlr
real(8),dimension(3,nlr),intent(in):: rxyz
real(8),intent(in):: hx, hy, hz
type(local_zone_descriptors),intent(inout):: lzd
type(orbitals_data),intent(in):: orbs
type(locreg_descriptors),intent(in):: Glr
real(8),dimension(lzd%nlr),intent(in):: locrad
character(len=1),intent(in):: locregShape
type(orbitals_data),optional,intent(in):: lborbs

!real(8),dimension(:),pointer:: phi, lphi

! Local variables
integer:: istat, npsidim, npsidimr, iorb, ilr, jorb, jjorb, jlr, iall
character(len=*),parameter:: subname='initLocregs'
logical,dimension(:),allocatable:: calculateBounds

! Allocate the array of localisation regions
allocate(lzd%Llr(lzd%nlr),stat=istat)

do ilr=1,lzd%nlr
    call nullify_locreg_descriptors(lzd%Llr(ilr))
end do
!! ATTENTION: WHAT ABOUT OUTOFZONE??


 allocate(calculateBounds(lzd%nlr), stat=istat)
 call memocc(istat, calculateBounds, 'calculateBounds', subname)
 calculateBounds=.false.
 do ilr=1,lzd%nlr
     do jorb=1,orbs%norbp
         jjorb=orbs%isorb+jorb
         jlr=orbs%inWhichLocreg(jjorb)
         if(jlr==ilr) then
             calculateBounds(ilr)=.true.
             exit
         end if
     end do
     if(present(lborbs)) then
         do jorb=1,lborbs%norbp
             jjorb=lborbs%isorb+jorb
             jlr=lborbs%inWhichLocreg(jjorb)
             if(jlr==ilr) then
                 calculateBounds(ilr)=.true.
                 exit
             end if
         end do
     end if
     lzd%llr(ilr)%locrad=locrad(ilr)
     lzd%llr(ilr)%locregCenter=rxyz(:,ilr)
 end do

 if(locregShape=='c') then
     call determine_locreg_periodic(iproc, lzd%nlr, rxyz, locrad, hx, hy, hz, Glr, lzd%Llr, calculateBounds)
 else if(locregShape=='s') then
     !!call determine_locregSphere(iproc, lzd%nlr, rxyz, locrad, hx, hy, hz, &
     !!     Glr, lzd%Llr, calculateBounds)
     call determine_locregSphere_parallel(iproc, nproc, lzd%nlr, rxyz, locrad, hx, hy, hz, &
          Glr, lzd%Llr, calculateBounds)
 end if


 iall=-product(shape(calculateBounds))*kind(calculateBounds)
 deallocate(calculateBounds, stat=istat)
 call memocc(istat, iall, 'calculateBounds', subname)

!do ilr=1,lin%nlr
!    if(iproc==0) write(*,'(1x,a,i0)') '>>>>>>> zone ', ilr
!    if(iproc==0) write(*,'(3x,a,4i10)') 'nseg_c, nseg_f, nvctr_c, nvctr_f', lin%Llr(ilr)%wfd%nseg_c, lin%Llr(ilr)%wfd%nseg_f, lin%Llr(ilr)%wfd%nvctr_c, lin%Llr(ilr)%wfd%nvctr_f
!    if(iproc==0) write(*,'(3x,a,3i8)') 'lin%Llr(ilr)%d%n1i, lin%Llr(ilr)%d%n2i, lin%Llr(ilr)%d%n3i', lin%Llr(ilr)%d%n1i, lin%Llr(ilr)%d%n2i, lin%Llr(ilr)%d%n3i
!    if(iproc==0) write(*,'(a,6i8)') 'lin%Llr(ilr)%d%nfl1,lin%Llr(ilr)%d%nfu1,lin%Llr(ilr)%d%nfl2,lin%Llr(ilr)%d%nfu2,lin%Llr(ilr)%d%nfl3,lin%Llr(ilr)%d%nfu3',&
!    lin%Llr(ilr)%d%nfl1,lin%Llr(ilr)%d%nfu1,lin%Llr(ilr)%d%nfl2,lin%Llr(ilr)%d%nfu2,lin%Llr(ilr)%d%nfl3,lin%Llr(ilr)%d%nfu3
!end do


lzd%linear=.true.

!!!! Calculate the dimension of the wave function for each process.
!!!! Do it for both the compressed ('npsidim') and for the uncompressed real space
!!!! ('npsidimr') case.
!!!npsidim=0
!!!do iorb=1,orbs%norbp
!!!    !ilr=orbs%inWhichLocregp(iorb)
!!!    ilr=orbs%inWhichLocreg(orbs%isorb+iorb)
!!!    npsidim = npsidim + (lzd%Llr(ilr)%wfd%nvctr_c+7*lzd%Llr(ilr)%wfd%nvctr_f)*orbs%nspinor
!!!end do
!!!!! WARNING: CHECHK THIS
!!!orbs%npsidim_orbs=max(npsidim,1)


end subroutine initLocregs


!> Allocate the coefficients for the linear combinations of the  orbitals and initialize
!! them at random.
!! Do this only on the root, since the calculations to determine coeff are not yet parallelized.
subroutine initCoefficients(iproc, orbs, lin, coeff)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc
  type(orbitals_data),intent(in):: orbs
  type(linearParameters),intent(in):: lin
  real(8),dimension(:,:),pointer,intent(out):: coeff
  
  ! Local variables
  integer:: iorb, jorb, istat
  real:: ttreal
  character(len=*),parameter:: subname='initCoefficients'
  
  
  allocate(coeff(lin%lb%orbs%norb,orbs%norb), stat=istat)
  call memocc(istat, coeff, 'coeff', subname)
  
  call initRandomSeed(0, 1)
  if(iproc==0) then
      do iorb=1,orbs%norb
         do jorb=1,lin%lb%orbs%norb
            call random_number(ttreal)
            coeff(jorb,iorb)=real(ttreal,kind=8)
         end do
      end do
  end if

end subroutine initCoefficients





function megabytes(bytes)
  implicit none
  
  integer,intent(in):: bytes
  integer:: megabytes
  
  megabytes=nint(dble(bytes)/1048576.d0)
  
end function megabytes






subroutine initMatrixCompression(iproc, nproc, nlr, orbs, noverlaps, overlaps, mad)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, nlr
  type(orbitals_data),intent(in):: orbs
  !integer,dimension(nlr),intent(in):: noverlaps
  integer,dimension(orbs%norb),intent(in):: noverlaps
  !integer,dimension(maxval(noverlaps(:)),nlr),intent(in):: overlaps
  integer,dimension(maxval(noverlaps(:)),orbs%norb),intent(in):: overlaps
  type(matrixDescriptors),intent(out):: mad
  
  ! Local variables
  integer:: jproc, iorb, jorb, iiorb, jjorb, ijorb, jjorbold, istat, iseg, nseg, ii, irow, irowold, isegline, ilr
  character(len=*),parameter:: subname='initMatrixCompressionForInguess'
  
  call nullify_matrixDescriptors(mad)
  
  mad%nseg=0
  mad%nvctr=0
  jjorbold=-1
  irowold=0
  allocate(mad%nsegline(orbs%norb), stat=istat)
  call memocc(istat, mad%nsegline, 'mad%nsegline', subname)
  mad%nsegline=0
  do jproc=0,nproc-1
      do iorb=1,orbs%norb_par(jproc,0)
          iiorb=orbs%isorb_par(jproc)+iorb
          ilr=orbs%inWhichLocreg(iiorb)
          ijorb=(iiorb-1)*orbs%norb
          !do jorb=1,noverlaps(iiorb)
          !do jorb=1,noverlaps(ilr)
          do jorb=1,noverlaps(iiorb)
              jjorb=overlaps(jorb,iiorb)+ijorb
              !jjorb=overlaps(jorb,ilr)+ijorb
              ! Entry (iiorb,jjorb) is not zero.
              !if(iproc==0) write(300,*) iiorb,jjorb
              if(jjorb==jjorbold+1) then
                  ! There was no zero element in between, i.e. we are in the same segment.
                  jjorbold=jjorb
                  mad%nvctr=mad%nvctr+1

                  ! Segments for each row
                  irow=(jjorb-1)/orbs%norb+1
                  if(irow/=irowold) then
                      ! We are in a new line
                      mad%nsegline(irow)=mad%nsegline(irow)+1
                      irowold=irow
                  end if

              else
                  ! There was a zero segment in between, i.e. we are in a new segment
                  mad%nseg=mad%nseg+1
                  mad%nvctr=mad%nvctr+1
                  jjorbold=jjorb
                  
                  ! Segments for each row
                  irow=(jjorb-1)/orbs%norb+1
                  mad%nsegline(irow)=mad%nsegline(irow)+1
                  irowold=irow
              end if
          end do
      end do
  end do

  !if(iproc==0) write(*,*) 'mad%nseg, mad%nvctr',mad%nseg, mad%nvctr
  mad%nseglinemax=0
  do iorb=1,orbs%norb
      if(mad%nsegline(iorb)>mad%nseglinemax) then
          mad%nseglinemax=mad%nsegline(iorb)
      end if
  end do

  allocate(mad%keyv(mad%nseg), stat=istat)
  call memocc(istat, mad%keyv, 'mad%keyv', subname)
  allocate(mad%keyg(2,mad%nseg), stat=istat)
  call memocc(istat, mad%keyg, 'mad%keyg', subname)
  allocate(mad%keygline(2,mad%nseglinemax,orbs%norb), stat=istat)
  call memocc(istat, mad%keygline, 'mad%keygline', subname)


  nseg=0
  mad%keyv=0
  jjorbold=-1
  irow=0
  isegline=0
  irowold=0
  mad%keygline=0
  mad%keyg=0
  do jproc=0,nproc-1
      do iorb=1,orbs%norb_par(jproc,0)
          iiorb=orbs%isorb_par(jproc)+iorb
          ilr=orbs%inWhichLocreg(iiorb)
          ijorb=(iiorb-1)*orbs%norb
          !do jorb=1,noverlaps(iiorb)
          !do jorb=1,noverlaps(ilr)
          do jorb=1,noverlaps(iiorb)
              jjorb=overlaps(jorb,iiorb)+ijorb
              !jjorb=overlaps(jorb,ilr)+ijorb
              ! Entry (iiorb,jjorb) is not zero.
              !!if(iproc==0) write(300,'(a,8i12)') 'nseg, iiorb, jorb, ilr, noverlaps(ilr), overlaps(jorb,iiorb), ijorb, jjorb',&
              !!              nseg, iiorb, jorb, ilr, noverlaps(ilr), overlaps(jorb,iiorb), ijorb, jjorb
              if(jjorb==jjorbold+1) then
                  ! There was no zero element in between, i.e. we are in the same segment.
                  mad%keyv(nseg)=mad%keyv(nseg)+1

                  ! Segments for each row
                  irow=(jjorb-1)/orbs%norb+1
                  if(irow/=irowold) then
                      ! We are in a new line, so close the last segment and start the new one
                      mad%keygline(2,isegline,irowold)=mod(jjorbold-1,orbs%norb)+1
                      isegline=1
                      mad%keygline(1,isegline,irow)=mod(jjorb-1,orbs%norb)+1
                      irowold=irow
                  end if
                  jjorbold=jjorb
              else
                  ! There was a zero segment in between, i.e. we are in a new segment.
                  ! First determine the end of the previous segment.
                  if(jjorbold>0) then
                      mad%keyg(2,nseg)=jjorbold
                      mad%keygline(2,isegline,irowold)=mod(jjorbold-1,orbs%norb)+1
                  end if
                  ! Now add the new segment.
                  nseg=nseg+1
                  mad%keyg(1,nseg)=jjorb
                  jjorbold=jjorb
                  mad%keyv(nseg)=mad%keyv(nseg)+1

                  ! Segments for each row
                  irow=(jjorb-1)/orbs%norb+1
                  if(irow/=irowold) then
                      ! We are in a new line
                      isegline=1
                      mad%keygline(1,isegline,irow)=mod(jjorb-1,orbs%norb)+1
                      irowold=irow
                  else
                      ! We are in the same line
                      isegline=isegline+1
                      mad%keygline(1,isegline,irow)=mod(jjorb-1,orbs%norb)+1
                      irowold=irow
                  end if
              end if
          end do
      end do
  end do
  ! Close the last segment
  mad%keyg(2,nseg)=jjorb
  mad%keygline(2,isegline,orbs%norb)=mod(jjorb-1,orbs%norb)+1

  !!if(iproc==0) then
  !!    do iorb=1,orbs%norb
  !!        write(*,'(a,2x,i0,2x,i0,3x,100i4)') 'iorb, mad%nsegline(iorb), mad%keygline(1,:,iorb)', iorb, mad%nsegline(iorb), mad%keygline(1,:,iorb)
  !!        write(*,'(a,2x,i0,2x,i0,3x,100i4)') 'iorb, mad%nsegline(iorb), mad%keygline(2,:,iorb)', iorb, mad%nsegline(iorb), mad%keygline(2,:,iorb)
  !!    end do
  !!end if

  !!if(iproc==0) then
  !!    do iseg=1,mad%nseg
  !!        write(*,'(a,4i8)') 'iseg, mad%keyv(iseg), mad%keyg(1,iseg), mad%keyg(2,iseg)', iseg, mad%keyv(iseg), mad%keyg(1,iseg), mad%keyg(2,iseg)
  !!    end do
  !!end if

  ! Some checks
  ii=0
  do iseg=1,mad%nseg
      ii=ii+mad%keyv(iseg)
  end do
  if(ii/=mad%nvctr) then
      write(*,'(a,2(2x,i0))') 'ERROR: ii/=mad%nvctr',ii,mad%nvctr
      stop
  end if



end subroutine initMatrixCompression










subroutine getCommunArraysMatrixCompression(iproc, nproc, orbs, mad, sendcounts, displs)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(orbitals_data),intent(in):: orbs
  type(matrixDescriptors),intent(in):: mad
  integer,dimension(0:nproc-1),intent(out):: sendcounts, displs
  
  ! Local variables
  integer:: iseg, jj, jorb, iiorb, jjorb, jjproc, jjprocold, ncount
  
  sendcounts=0
  displs=0
  
  jj=0
  ncount=0
  jjprocold=0
  displs(0)=0
  do iseg=1,mad%nseg
      do jorb=mad%keyg(1,iseg),mad%keyg(2,iseg)
          jj=jj+1
          ncount=ncount+1
          jjorb=(jorb-1)/orbs%norb+1
          jjproc=orbs%onWhichMPI(jjorb)
          if(jjproc>jjprocold) then
              ! This part of the matrix is calculated by a new MPI process.
              sendcounts(jjproc-1)=ncount-1
              displs(jjproc)=displs(jjproc-1)+sendcounts(jjproc-1)
              ncount=1
              jjprocold=jjproc
          end if
      end do
  end do
  sendcounts(nproc-1)=ncount
  if(jj/=mad%nvctr) then
      write(*,'(a,2(2x,i0))') 'ERROR in compressMatrix: jj/=mad%nvctr',jj,mad%nvctr
      stop
  end if

  if(sum(sendcounts)/=mad%nvctr) then
      write(*,'(a,2(2x,i0))') 'ERROR in compressMatrix2: sum(sendcounts)/=mad%nvctr',sum(sendcounts),mad%nvctr
      stop
  end if

  
end subroutine getCommunArraysMatrixCompression





subroutine initCommsCompression(iproc, nproc, orbs, mad, mat, lmat, sendcounts, displs)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(orbitals_data),intent(in):: orbs
  type(matrixDescriptors),intent(in):: mad
  real(8),dimension(orbs%norb**2),intent(in):: mat
  real(8),dimension(mad%nvctr),intent(out):: lmat
  integer,dimension(0:nproc-1),intent(out):: sendcounts, displs
  
  ! Local variables
  integer:: iseg, jj, jorb, iiorb, jjorb, jjproc, jjprocold, ncount
  
  sendcounts=0
  displs=0
  
  jj=0
  ncount=0
  jjprocold=0
  displs(0)=0
  do iseg=1,mad%nseg
      do jorb=mad%keyg(1,iseg),mad%keyg(2,iseg)
          jj=jj+1
          lmat(jj)=mat(jorb)
          
          ncount=ncount+1
          jjorb=(jorb-1)/orbs%norb+1
          jjproc=orbs%onWhichMPI(jjorb)
          if(jjproc>jjprocold) then
              ! This part of the matrix is calculated by a new MPI process.
              sendcounts(jjproc-1)=ncount-1
              displs(jjproc)=displs(jjproc-1)+sendcounts(jjproc-1)
              ncount=1
              jjprocold=jjproc
          end if
      end do
  end do
  sendcounts(nproc-1)=ncount
  if(jj/=mad%nvctr) then
      write(*,'(a,2(2x,i0))') 'ERROR in compressMatrix: jj/=mad%nvctr',jj,mad%nvctr
      stop
  end if

  if(sum(sendcounts)/=mad%nvctr) then
      write(*,'(a,2(2x,i0))') 'ERROR in compressMatrix2: sum(sendcounts)/=mad%nvctr',sum(sendcounts),mad%nvctr
      stop
  end if

  !if(iproc==0) then
  !    do jjproc=0,nproc-1
  !        write(*,'(a,3i8)') 'jjproc, displs(jjproc), sendcounts(jjproc)', jjproc, displs(jjproc), sendcounts(jjproc)
  !    end do
  !end if
  
end subroutine initCommsCompression




subroutine initCompressedMatmul(iproc, nproc, norb, mad)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, norb
  type(matrixDescriptors),intent(inout):: mad
  
  ! Local variables
  integer:: iorb, jorb, ii, j, istat, iall, ij, iseg
  logical:: segment
  integer,dimension(:),allocatable:: row, column
  character(len=*),parameter:: subname='initCompressedMatmul'
  
  
  allocate(row(norb), stat=istat)
  call memocc(istat, row, 'row', subname)
  allocate(column(norb), stat=istat)
  call memocc(istat, column, 'column', subname)
  
  
  segment=.false.
  mad%nsegmatmul=0
  mad%nvctrmatmul=0
  do iorb=1,norb
      do jorb=1,norb
          ! Get an array of this line and column indicating whether
          ! there are nonzero numbers at these positions. Since the localization
          ! within the matrix is symmetric, we can use both time the same subroutine.
          call getRow(norb, mad, iorb, row) 
          call getRow(norb, mad, jorb, column) 
          !!if(iproc==0) write(*,'(a,i4,4x,100i4)') 'iorb, row', iorb, row
          !!if(iproc==0) write(*,'(a,i4,4x,100i4)') 'jorb, row', jorb, column
          ii=0
          do j=1,norb
              ii=ii+row(j)*column(j)
          end do
          if(ii>0) then
              ! This entry of the matrix will be different from zero.
              mad%nvctrmatmul=mad%nvctrmatmul+1
              if(.not. segment) then
                  ! This is the start of a new segment
                  segment=.true.
                  mad%nsegmatmul=mad%nsegmatmul+1
              end if
          else
              if(segment) then
                  ! We reached the end of a segment
                  segment=.false.
              end if
          end if
      end do
  end do
  
  allocate(mad%keygmatmul(2,mad%nsegmatmul), stat=istat)
  allocate(mad%keyvmatmul(mad%nsegmatmul), stat=istat)
  
  ! Now fill the descriptors.
  segment=.false.
  ij=0
  iseg=0
  do iorb=1,norb
      do jorb=1,norb
          ij=ij+1
          ! Get an array of this line and column indicating whether
          ! there are nonzero numbers at these positions. Since the localization
          ! within the matrix is symmetric, we can use both time the same subroutine.
          call getRow(norb, mad, iorb, row) 
          call getRow(norb, mad, jorb, column) 
          ii=0
          do j=1,norb
              ii=ii+row(j)*column(j)
          end do
          if(ii>0) then
              ! This entry of the matrix will be different from zero.
              if(.not. segment) then
                  ! This is the start of a new segment
                  segment=.true.
                  iseg=iseg+1
                  mad%keygmatmul(1,iseg)=ij
              end if
              mad%keyvmatmul(iseg)=mad%keyvmatmul(iseg)+1
          else
              if(segment) then
                  ! We reached the end of a segment
                  segment=.false.
                  mad%keygmatmul(2,iseg)=ij-1
              end if
          end if
      end do
  end do

  ! Close the last segment if required.
  if(segment) then
      mad%keygmatmul(2,iseg)=ij
  end if
  
  
  iall=-product(shape(row))*kind(row)
  deallocate(row, stat=istat)
  call memocc(istat, iall, 'row', subname)
  iall=-product(shape(column))*kind(column)
  deallocate(column, stat=istat)
  call memocc(istat, iall, 'column', subname)

end subroutine initCompressedMatmul



subroutine getRow(norb, mad, rowX, row)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: norb, rowX
  type(matrixDescriptors),intent(in):: mad
  integer,dimension(norb),intent(out):: row
  
  ! Local variables
  integer:: iseg, i, irow, icolumn
  
  row=0
  
  do iseg=1,mad%nseg
      do i=mad%keyg(1,iseg),mad%keyg(2,iseg)
      ! Get the row index of this element. Since the localization is symmetric, we can
      ! assume row or column ordering with respect to the segments.
          irow=(i-1)/norb+1
          if(irow==rowX) then
              ! Get the column index of this element.
              icolumn=i-(irow-1)*norb
              row(icolumn)=1
          end if
      end do
  end do

end subroutine getRow






subroutine initCompressedMatmul2(norb, nseg, keyg, nsegmatmul, keygmatmul, keyvmatmul)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer,intent(in):: norb, nseg
  integer,dimension(2,nseg),intent(in):: keyg
  integer,intent(out):: nsegmatmul
  integer,dimension(:,:),pointer,intent(out):: keygmatmul
  integer,dimension(:),pointer,intent(out):: keyvmatmul

  ! Local variables
  integer:: iorb, jorb, ii, j, istat, iall, ij, iseg, i
  logical:: segment
  character(len=*),parameter:: subname='initCompressedMatmul2'
  real(8),dimension(:),allocatable:: mat1, mat2, mat3



  allocate(mat1(norb**2), stat=istat)
  call memocc(istat, mat1, 'mat1', subname)
  allocate(mat2(norb**2), stat=istat)
  call memocc(istat, mat2, 'mat2', subname)
  allocate(mat3(norb**2), stat=istat)
  call memocc(istat, mat2, 'mat2', subname)

  mat1=0.d0
  mat2=0.d0
  do iseg=1,nseg
      do i=keyg(1,iseg),keyg(2,iseg)
          ! the localization region is "symmetric"
          mat1(i)=1.d0
          mat2(i)=1.d0
      end do
  end do

  call dgemm('n', 'n', norb, norb, norb, 1.d0, mat1, norb, mat2, norb, 0.d0, mat3, norb)

  segment=.false.
  nsegmatmul=0
  do iorb=1,norb**2
      if(mat3(iorb)>0.d0) then
          ! This entry of the matrix will be different from zero.
          if(.not. segment) then
              ! This is the start of a new segment
              segment=.true.
              nsegmatmul=nsegmatmul+1
          end if
      else
          if(segment) then
              ! We reached the end of a segment
              segment=.false.
          end if
      end if
  end do


  allocate(keygmatmul(2,nsegmatmul), stat=istat)
  call memocc(istat, keygmatmul, 'keygmatmul', subname)
  allocate(keyvmatmul(nsegmatmul), stat=istat)
  call memocc(istat, keyvmatmul, 'keyvmatmul', subname)
  keyvmatmul=0
  ! Now fill the descriptors.
  segment=.false.
  ij=0
  iseg=0
  do iorb=1,norb**2
      ij=iorb
      if(mat3(iorb)>0.d0) then
          ! This entry of the matrix will be different from zero.
          if(.not. segment) then
              ! This is the start of a new segment
              segment=.true.
              iseg=iseg+1
              keygmatmul(1,iseg)=ij
          end if
          keyvmatmul(iseg)=keyvmatmul(iseg)+1
      else
          if(segment) then
              ! We reached the end of a segment
              segment=.false.
              keygmatmul(2,iseg)=ij-1
          end if
      end if
  end do
  ! Close the last segment if required.
  if(segment) then
      keygmatmul(2,iseg)=ij
  end if


iall=-product(shape(mat1))*kind(mat1)
deallocate(mat1, stat=istat)
call memocc(istat, iall, 'mat1', subname)
iall=-product(shape(mat2))*kind(mat2)
deallocate(mat2, stat=istat)
call memocc(istat, iall, 'mat2', subname)
iall=-product(shape(mat3))*kind(mat3)
deallocate(mat3, stat=istat)
call memocc(istat, iall, 'mat3', subname)


end subroutine initCompressedMatmul2




subroutine initCompressedMatmul3(norb, mad)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer,intent(in):: norb
  type(matrixDescriptors),intent(inout):: mad

  ! Local variables
  integer:: iorb, jorb, ii, j, istat, iall, ij, iseg, i, iproc
  logical:: segment
  character(len=*),parameter:: subname='initCompressedMatmul3'
  real(8),dimension(:),allocatable:: mat1, mat2, mat3

  call mpi_comm_rank(mpi_comm_world,iproc,istat)

  allocate(mat1(norb**2), stat=istat)
  call memocc(istat, mat1, 'mat1', subname)
  allocate(mat2(norb**2), stat=istat)
  call memocc(istat, mat2, 'mat2', subname)
  allocate(mat3(norb**2), stat=istat)
  call memocc(istat, mat2, 'mat2', subname)
  call mpi_barrier(mpi_comm_world,istat)

  mat1=0.d0
  mat2=0.d0
  do iseg=1,mad%nseg
      !if(iproc==0) write(200,'(a,3i12)') 'iseg, mad%keyg(1,iseg), mad%keyg(2,iseg)', iseg, mad%keyg(1,iseg), mad%keyg(2,iseg)
      do i=mad%keyg(1,iseg),mad%keyg(2,iseg)
          ! the localization region is "symmetric"
          mat1(i)=1.d0
          mat2(i)=1.d0
      end do
  end do

  call dgemm('n', 'n', norb, norb, norb, 1.d0, mat1, norb, mat2, norb, 0.d0, mat3, norb)

  segment=.false.
  mad%nsegmatmul=0
  do iorb=1,norb**2
      if(mat3(iorb)>0.d0) then
          ! This entry of the matrix will be different from zero.
          if(.not. segment) then
              ! This is the start of a new segment
              segment=.true.
              mad%nsegmatmul=mad%nsegmatmul+1
          end if
      else
          if(segment) then
              ! We reached the end of a segment
              segment=.false.
          end if
      end if
  end do


  allocate(mad%keygmatmul(2,mad%nsegmatmul), stat=istat)
  call memocc(istat, mad%keygmatmul, 'mad%keygmatmul', subname)
  allocate(mad%keyvmatmul(mad%nsegmatmul), stat=istat)
  call memocc(istat, mad%keyvmatmul, 'mad%keyvmatmul', subname)
  mad%keyvmatmul=0
  ! Now fill the descriptors.
  segment=.false.
  ij=0
  iseg=0
  do iorb=1,norb**2
      ij=iorb
      if(mat3(iorb)>0.d0) then
          ! This entry of the matrix will be different from zero.
          if(.not. segment) then
              ! This is the start of a new segment
              segment=.true.
              iseg=iseg+1
              mad%keygmatmul(1,iseg)=ij
          end if
          mad%keyvmatmul(iseg)=mad%keyvmatmul(iseg)+1
      else
          if(segment) then
              ! We reached the end of a segment
              segment=.false.
              mad%keygmatmul(2,iseg)=ij-1
          end if
      end if
  end do
  ! Close the last segment if required.
  if(segment) then
      mad%keygmatmul(2,iseg)=ij
  end if


iall=-product(shape(mat1))*kind(mat1)
deallocate(mat1, stat=istat)
call memocc(istat, iall, 'mat1', subname)
iall=-product(shape(mat2))*kind(mat2)
deallocate(mat2, stat=istat)
call memocc(istat, iall, 'mat2', subname)
iall=-product(shape(mat3))*kind(mat3)
deallocate(mat3, stat=istat)
call memocc(istat, iall, 'mat3', subname)


end subroutine initCompressedMatmul3






subroutine repartitionOrbitals(iproc, nproc, norb, norb_par, norbp, isorb_par, isorb, onWhichMPI)
  use module_base
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, norb
  integer,dimension(0:nproc-1),intent(out):: norb_par, isorb_par
  integer,dimension(norb),intent(out):: onWhichMPI
  integer,intent(out):: norbp, isorb

  ! Local variables
  integer:: ii, kk, iiorb, mpiflag, iorb, ierr, jproc
  real(8):: tt

  ! Determine norb_par
  norb_par=0
  tt=dble(norb)/dble(nproc)
  ii=floor(tt)
  ! ii is now the number of orbitals that every process has. Distribute the remaining ones.
  norb_par(0:nproc-1)=ii
  kk=norb-nproc*ii
  norb_par(0:kk-1)=ii+1

  ! Determine norbp
  norbp=norb_par(iproc)

  ! Determine isorb
  isorb=0
  do jproc=0,iproc-1
      isorb=isorb+norb_par(jproc)
  end do

  ! Determine onWhichMPI and isorb_par
  iiorb=0
  isorb_par=0
  do jproc=0,nproc-1
      do iorb=1,norb_par(jproc)
          iiorb=iiorb+1
          onWhichMPI(iiorb)=jproc
      end do
      if(iproc==jproc) then
          isorb_par(jproc)=isorb
      end if
  end do
  call MPI_Initialized(mpiflag,ierr)
  if(mpiflag /= 0) call mpiallred(isorb_par(0), nproc, mpi_sum, mpi_comm_world, ierr)


end subroutine repartitionOrbitals




subroutine repartitionOrbitals2(iproc, nproc, norb, norb_par, norbp, isorb)
  use module_base
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, norb
  integer,dimension(0:nproc-1),intent(out):: norb_par
  integer,intent(out):: norbp, isorb

  ! Local variables
  integer:: ii, kk, iiorb, mpiflag, iorb, ierr, jproc
  real(8):: tt

  ! Determine norb_par
  norb_par=0
  tt=dble(norb)/dble(nproc)
  ii=floor(tt)
  ! ii is now the number of orbitals that every process has. Distribute the remaining ones.
  norb_par(0:nproc-1)=ii
  kk=norb-nproc*ii
  norb_par(0:kk-1)=ii+1

  ! Determine norbp
  norbp=norb_par(iproc)

  ! Determine isorb
  isorb=0
  do jproc=0,iproc-1
      isorb=isorb+norb_par(jproc)
  end do


end subroutine repartitionOrbitals2


subroutine check_linear_and_create_Lzd(iproc,nproc,input,Lzd,atoms,orbs,rxyz)
  use module_base
  use module_types
  use module_xc
  implicit none

  integer, intent(in) :: iproc,nproc
  type(input_variables), intent(in) :: input
  type(local_zone_descriptors), intent(inout) :: Lzd
  type(atoms_data), intent(in) :: atoms
  type(orbitals_data),intent(inout) :: orbs
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
!  real(gp), dimension(atoms%ntypes,3), intent(in) :: radii_cf
  !Local variables
  character(len=*), parameter :: subname='check_linear_and_create_Lzd'
  logical :: linear,newvalue
  integer :: iat,ityp,nspin_ig,i_all,i_stat,ii,iilr,ilr,iorb,iorb2,nilr,ispin
  integer,dimension(:,:),allocatable:: ilrtable
  real(gp), dimension(:), allocatable :: locrad
  logical,dimension(:),allocatable:: calculateBounds

  !default variables
  Lzd%nlr = 1

  if (input%nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=input%nspin
  end if

  linear  = .true.
  if (input%linear == 'FUL') then
     Lzd%nlr=atoms%nat
     allocate(locrad(Lzd%nlr+ndebug),stat=i_stat)
     call memocc(i_stat,locrad,'locrad',subname)
     ! locrad read from last line of  psppar
     do iat=1,atoms%nat
        ityp = atoms%iatype(iat)
        locrad(iat) = atoms%rloc(ityp,1)
     end do  
     call timing(iproc,'check_IG      ','ON')
     call check_linear_inputguess(iproc,Lzd%nlr,rxyz,locrad,&
          Lzd%hgrids(1),Lzd%hgrids(2),Lzd%hgrids(3),&
          Lzd%Glr,linear) 
     call timing(iproc,'check_IG      ','OF')
     if(input%nspin >= 4) linear = .false. 
  end if

  ! If we are using cubic code : by choice or because locregs are too big
  Lzd%linear = .true.
  if (input%linear == 'LIG' .or. input%linear =='OFF' .or. .not. linear) then
     Lzd%linear = .false.
     Lzd%nlr = 1
  end if


  if(input%linear /= 'TMO') then
     allocate(Lzd%Llr(Lzd%nlr+ndebug),stat=i_stat)
     allocate(Lzd%doHamAppl(Lzd%nlr+ndebug), stat=i_stat)
     call memocc(i_stat,Lzd%doHamAppl,'Lzd%doHamAppl',subname)
     Lzd%doHamAppl = .true. 
     !for now, always true because we want to calculate the hamiltonians for all locregs
     if(.not. Lzd%linear) then
        Lzd%lintyp = 0
        !copy Glr to Llr(1)
        call nullify_locreg_descriptors(Lzd%Llr(1))
        call copy_locreg_descriptors(Lzd%Glr,Lzd%Llr(1),subname)
     else 
        Lzd%lintyp = 1
        ! Assign orbitals to locreg (for LCAO IG each orbitals corresponds to an atomic function. WILL NEED TO CHANGE THIS)
        call assignToLocreg(iproc,nproc,orbs%nspinor,nspin_ig,atoms,orbs,Lzd)

        ! determine the localization regions
        ! calculateBounds indicate whether the arrays with the bounds (for convolutions...) shall also
        ! be allocated and calculated. In principle this is only necessary if the current process has orbitals
        ! in this localization region.
        allocate(calculateBounds(lzd%nlr),stat=i_stat)
        call memocc(i_stat,calculateBounds,'calculateBounds',subname)
        calculateBounds=.true.
!        call determine_locreg_periodic(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,Lzd%Glr,Lzd%Llr,calculateBounds)
        call determine_locreg_parallel(iproc,nproc,Lzd%nlr,rxyz,locrad,&
             Lzd%hgrids(1),Lzd%hgrids(2),Lzd%hgrids(3),Lzd%Glr,Lzd%Llr,&
             orbs,calculateBounds)  
        i_all = -product(shape(calculateBounds))*kind(calculateBounds) 
        deallocate(calculateBounds,stat=i_stat)
        call memocc(i_stat,i_all,'calculateBounds',subname)
        i_all = -product(shape(locrad))*kind(locrad)
        deallocate(locrad,stat=i_stat)
        call memocc(i_stat,i_all,'locrad',subname)

        ! determine the wavefunction dimension
        call wavefunction_dimension(Lzd,orbs)
     end if
  else
     Lzd%lintyp = 2
  end if
  
!DEBUG
!!if(iproc==0)then
!!print *,'###################################################'
!!print *,'##        General information:                   ##'
!!print *,'###################################################'
!!print *,'Lzd%nlr,linear, ndimpotisf :',Lzd%nlr,Lzd%linear,Lzd%ndimpotisf
!!print *,'###################################################'
!!print *,'##        Global box information:                ##'
!!print *,'###################################################'
!!write(*,'(a24,3i4)')'Global region n1,n2,n3:',Lzd%Glr%d%n1,Lzd%Glr%d%n2,Lzd%Glr%d%n3
!!write(*,*)'Global fine grid: nfl',Lzd%Glr%d%nfl1,Lzd%Glr%d%nfl2,Lzd%Glr%d%nfl3
!!write(*,*)'Global fine grid: nfu',Lzd%Glr%d%nfu1,Lzd%Glr%d%nfu2,Lzd%Glr%d%nfu3
!!write(*,*)'Global inter. grid: ni',Lzd%Glr%d%n1i,Lzd%Glr%d%n2i,Lzd%Glr%d%n3i
!!write(*,'(a27,f6.2,f6.2,f6.2)')'Global dimension (1x,y,z):',Lzd%Glr%d%n1*hx,Lzd%Glr%d%n2*hy,Lzd%Glr%d%n3*hz
!!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*hx*Lzd%Glr%d%n2*hy*Lzd%Glr%d%n3*hz
!!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
!!print *,'###################################################'
!!print *,'##        Local boxes information:               ##'
!!print *,'###################################################'
!!do i_stat =1, Lzd%nlr
!!   write(*,*)'=====> Region:',i_stat
!!   write(*,'(a24,3i4)')'Local region n1,n2,n3:',Lzd%Llr(i_stat)%d%n1,Lzd%Llr(i_stat)%d%n2,Lzd%Llr(i_stat)%d%n3
!!   write(*,*)'Local fine grid: nfl',Lzd%Llr(i_stat)%d%nfl1,Lzd%Llr(i_stat)%d%nfl2,Lzd%Llr(i_stat)%d%nfl3
!!   write(*,*)'Local fine grid: nfu',Lzd%Llr(i_stat)%d%nfu1,Lzd%Llr(i_stat)%d%nfu2,Lzd%Llr(i_stat)%d%nfu3
!!   write(*,*)'Local inter. grid: ni',Lzd%Llr(i_stat)%d%n1i,Lzd%Llr(i_stat)%d%n2i,Lzd%Llr(i_stat)%d%n3i
!!   write(*,'(a27,f6.2,f6.2,f6.2)')'Local dimension (1x,y,z):',Lzd%Llr(i_stat)%d%n1*hx,Lzd%Llr(i_stat)%d%n2*hy,&
!!            Lzd%Llr(i_stat)%d%n3*hz
!!   write(*,'(a17,f12.2)')'Local volume: ',Lzd%Llr(i_stat)%d%n1*hx*Lzd%Llr(i_stat)%d%n2*hy*Lzd%Llr(i_stat)%d%n3*hz
!!   print *,'Local wfd statistics:',Lzd%Llr(i_stat)%wfd%nseg_c,Lzd%Llr(i_stat)%wfd%nseg_f,Lzd%Llr(i_stat)%wfd%nvctr_c,&
!!            Lzd%Llr(i_stat)%wfd%nvctr_f
!!end do
!!end if
!!call mpi_finalize(i_stat)
!!stop
!END DEBUG

end subroutine check_linear_and_create_Lzd

subroutine create_LzdLIG(iproc,nproc,nspin,linearmode,hx,hy,hz,Glr,atoms,orbs,rxyz,Lzd)
  use module_base
  use module_types
  use module_xc
  implicit none

  integer, intent(in) :: iproc,nproc,nspin
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: Glr
  type(atoms_data), intent(in) :: atoms
  type(orbitals_data),intent(inout) :: orbs
  character(len=*), intent(in) :: linearmode
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  type(local_zone_descriptors), intent(out) :: Lzd
!  real(gp), dimension(atoms%ntypes,3), intent(in) :: radii_cf
  !Local variables
  character(len=*), parameter :: subname='check_linear_and_create_Lzd'
  logical :: linear,newvalue
  integer :: iat,ityp,nspin_ig,i_all,i_stat,ii,iilr,ilr,iorb,iorb2,nilr,ispin
  integer,dimension(:,:),allocatable:: ilrtable
  real(gp), dimension(:), allocatable :: locrad
  logical,dimension(:),allocatable:: calculateBounds

  !default variables
  Lzd%nlr = 1

  Lzd%hgrids(1)=hx
  Lzd%hgrids(2)=hy
  Lzd%hgrids(3)=hz

  if (nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=nspin
  end if

  linear  = .true.
  if (linearmode == 'LIG' .or. linearmode == 'FUL') then
     Lzd%nlr=atoms%nat
     allocate(locrad(Lzd%nlr+ndebug),stat=i_stat)
     call memocc(i_stat,locrad,'locrad',subname)
     ! locrad read from last line of  psppar
     do iat=1,atoms%nat
        ityp = atoms%iatype(iat)
        locrad(iat) = atoms%rloc(ityp,1)
     end do  
     call timing(iproc,'check_IG      ','ON')
     call check_linear_inputguess(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,&
          Glr,linear) 
     call timing(iproc,'check_IG      ','OF')
     if(nspin >= 4) linear = .false. 
  end if

  ! If we are using cubic code : by choice or because locregs are too big
  if (linearmode =='OFF' .or. .not. linear) then
     linear = .false.
     Lzd%nlr = 1
  end if

  Lzd%linear = .true.
  if (.not. linear)  Lzd%linear = .false.

!  print *,'before Glr => Lzd%Glr'
  call nullify_locreg_descriptors(Lzd%Glr)
  call copy_locreg_descriptors(Glr,Lzd%Glr,subname)

  if(linearmode /= 'TMO') then
     allocate(Lzd%Llr(Lzd%nlr+ndebug),stat=i_stat)
     allocate(Lzd%doHamAppl(Lzd%nlr+ndebug), stat=i_stat)
     call memocc(i_stat,Lzd%doHamAppl,'Lzd%doHamAppl',subname)
     Lzd%doHamAppl = .true. 
     !for now, always true because we want to calculate the hamiltonians for all locregs

     if(.not. Lzd%linear) then
        Lzd%lintyp = 0
        !copy Glr Lzd%Llr(1)
        call nullify_locreg_descriptors(Lzd%Llr(1))
!        print *,'before Glr => Lzd%Llr(1)'
        call copy_locreg_descriptors(Glr,Lzd%Llr(1),subname)
     else 
        Lzd%lintyp = 1
        ! Assign orbitals to locreg (for LCAO IG each orbitals corresponds to an atomic function. WILL NEED TO CHANGE THIS)
        call assignToLocreg(iproc,nproc,orbs%nspinor,nspin_ig,atoms,orbs,Lzd)

        ! determine the localization regions
        ! calculateBounds indicate whether the arrays with the bounds (for convolutions...) shall also
        ! be allocated and calculated. In principle this is only necessary if the current process has orbitals
        ! in this localization region.
        allocate(calculateBounds(lzd%nlr),stat=i_stat)
        call memocc(i_stat,calculateBounds,'calculateBounds',subname)
        calculateBounds=.true.
!        call determine_locreg_periodic(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,Glr,Lzd%Llr,calculateBounds)
        call determine_locreg_parallel(iproc,nproc,Lzd%nlr,rxyz,locrad,&
             hx,hy,hz,Glr,Lzd%Llr,&
             orbs,calculateBounds)  
        i_all = -product(shape(calculateBounds))*kind(calculateBounds) 
        deallocate(calculateBounds,stat=i_stat)
        call memocc(i_stat,i_all,'calculateBounds',subname)
        i_all = -product(shape(locrad))*kind(locrad)
        deallocate(locrad,stat=i_stat)
        call memocc(i_stat,i_all,'locrad',subname)

        ! determine the wavefunction dimension
        call wavefunction_dimension(Lzd,orbs)
     end if
  else
     Lzd%lintyp = 2
  end if

!DEBUG
!!if(iproc==0)then
!!print *,'###################################################'
!!print *,'##        General information:                   ##'
!!print *,'###################################################'
!!print *,'Lzd%nlr,linear, Lpsidimtot, ndimpotisf, Lnprojel:',Lzd%nlr,Lzd%linear,Lzd%ndimpotisf
!!print *,'###################################################'
!!print *,'##        Global box information:                ##'
!!print *,'###################################################'
!!write(*,'(a24,3i4)')'Global region n1,n2,n3:',Lzd%Glr%d%n1,Lzd%Glr%d%n2,Lzd%Glr%d%n3
!!write(*,*)'Global fine grid: nfl',Lzd%Glr%d%nfl1,Lzd%Glr%d%nfl2,Lzd%Glr%d%nfl3
!!write(*,*)'Global fine grid: nfu',Lzd%Glr%d%nfu1,Lzd%Glr%d%nfu2,Lzd%Glr%d%nfu3
!!write(*,*)'Global inter. grid: ni',Lzd%Glr%d%n1i,Lzd%Glr%d%n2i,Lzd%Glr%d%n3i
!!write(*,'(a27,f6.2,f6.2,f6.2)')'Global dimension (1x,y,z):',Lzd%Glr%d%n1*hx,Lzd%Glr%d%n2*hy,Lzd%Glr%d%n3*hz
!!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*hx*Lzd%Glr%d%n2*hy*Lzd%Glr%d%n3*hz
!!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
!!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*input%hx*Lzd%Glr%d%n2*input%hy*Lzd%Glr%d%n3*input%hz
!!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
!!print *,'###################################################'
!!print *,'##        Local boxes information:               ##'
!!print *,'###################################################'
!!do i_stat =1, Lzd%nlr
!!   write(*,*)'=====> Region:',i_stat
!!   write(*,'(a24,3i4)')'Local region n1,n2,n3:',Lzd%Llr(i_stat)%d%n1,Lzd%Llr(i_stat)%d%n2,Lzd%Llr(i_stat)%d%n3
!!   write(*,*)'Local fine grid: nfl',Lzd%Llr(i_stat)%d%nfl1,Lzd%Llr(i_stat)%d%nfl2,Lzd%Llr(i_stat)%d%nfl3
!!   write(*,*)'Local fine grid: nfu',Lzd%Llr(i_stat)%d%nfu1,Lzd%Llr(i_stat)%d%nfu2,Lzd%Llr(i_stat)%d%nfu3
!!   write(*,*)'Local inter. grid: ni',Lzd%Llr(i_stat)%d%n1i,Lzd%Llr(i_stat)%d%n2i,Lzd%Llr(i_stat)%d%n3i
!!   write(*,'(a27,f6.2,f6.2,f6.2)')'Local dimension (1x,y,z):',Lzd%Llr(i_stat)%d%n1*hx,Lzd%Llr(i_stat)%d%n2*hy,&
!!            Lzd%Llr(i_stat)%d%n3*hz
!!   write(*,'(a17,f12.2)')'Local volume: ',Lzd%Llr(i_stat)%d%n1*hx*Lzd%Llr(i_stat)%d%n2*hy*Lzd%Llr(i_stat)%d%n3*hz
!!   print *,'Local wfd statistics:',Lzd%Llr(i_stat)%wfd%nseg_c,Lzd%Llr(i_stat)%wfd%nseg_f,Lzd%Llr(i_stat)%wfd%nvctr_c,&
!!            Lzd%Llr(i_stat)%wfd%nvctr_f
!!end do
!!end if
!call mpi_finalize(i_stat)
!stop
!END DEBUG

end subroutine create_LzdLIG






integer function optimalLength(totalLength, value)
  implicit none
  
  ! Calling arguments
  integer,intent(in):: totalLength, value
  
  optimalLength=totalLength-ceiling(log10(dble(value+1)+1.d-10))

end function optimalLength





subroutine initCollectiveComms(iproc, nproc, lzd, input, orbs, collcomms)
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc
type(local_zone_descriptors),intent(in):: lzd
type(input_variables),intent(in):: input
type(orbitals_data),intent(inout):: orbs
type(collectiveComms),intent(out):: collcomms

! Local variables
integer:: iorb, ilr, kproc, jproc, ii, ncount, iiorb, istat, gdim, ldim, ist
integer:: n1l, n2l, n3l, n1g, n2g, n3g, nshift1, nshift2, nshift3, ind, i, is, ie
integer:: transform_index, iseg, offset, iall
integer,dimension(:),allocatable:: work_int
character(len=*),parameter:: subname='initCollectiveComms'
integer:: ii1s, ii1e, ii5s, ii5e, i1, i5
logical:: stop1, stop5

! Allocate all arrays
allocate(collComms%nvctr_par(orbs%norb,0:nproc-1), stat=istat)
call memocc(istat, collComms%nvctr_par, 'collComms%nvctr_par', subname)

allocate(collComms%sendcnts(0:nproc-1), stat=istat)
call memocc(istat, collComms%sendcnts, 'collComms%sendcnts', subname)

allocate(collComms%senddspls(0:nproc-1), stat=istat)
call memocc(istat, collComms%senddspls, 'collComms%senddspls', subname)

allocate(collComms%recvcnts(0:nproc-1), stat=istat)
call memocc(istat, collComms%recvcnts, 'collComms%recvcnts', subname)

allocate(collComms%recvdspls(0:nproc-1), stat=istat)
call memocc(istat, collComms%recvdspls, 'collComms%recvdspls', subname)


! Distribute the orbitals among the processes.
do iorb=1,orbs%norb
    ilr=orbs%inwhichlocreg(iorb)
    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
    ! All processes get ii elements
    ii=ncount/nproc
    do jproc=0,nproc-1
        collComms%nvctr_par(iorb,jproc)=ii
    end do
    ! Process from 0 to kproc get one additional element
    kproc=mod(ncount,nproc)-1
    do jproc=0,kproc
        collComms%nvctr_par(iorb,jproc)=collComms%nvctr_par(iorb,jproc)+1
    end do
    !write(*,'(a,3i6,i12)') 'iorb, iproc, ncount, collComms%nvctr_par(iorb,iproc)', iorb, iproc, ncount, collComms%nvctr_par(iorb,iproc)
end do

! Determine the amount of data that has has to be sent to each process
collComms%sendcnts=0
do jproc=0,nproc-1
    do iorb=1,orbs%norbp
        iiorb=orbs%isorb+iorb
        collComms%sendcnts(jproc) = collComms%sendcnts(jproc) + collComms%nvctr_par(iiorb,jproc)
    end do
    !write(*,'(a,2i6,i12)') 'jproc, iproc, collComms%sendcnts(jproc)', jproc, iproc, collComms%sendcnts(jproc)
end do

! Determine the displacements for the send operation
collComms%senddspls(0)=0
do jproc=1,nproc-1
    collComms%senddspls(jproc) = collComms%senddspls(jproc-1) + collComms%sendcnts(jproc-1)
    !write(*,'(a,2i6,i12)') 'jproc, iproc, collComms%senddspls(jproc)', jproc, iproc, collComms%senddspls(jproc)
end do

! Determine the amount of data that each process receives
collComms%recvcnts=0
do jproc=0,nproc-1
    do iorb=1,orbs%norb_par(jproc,0)
        iiorb=orbs%isorb_par(jproc)+iorb
        collComms%recvcnts(jproc) = collComms%recvcnts(jproc) + collComms%nvctr_par(iiorb,iproc)
    end do
    !write(*,'(a,2i6,i12)') 'jproc, iproc, collComms%recvcnts(jproc)', jproc, iproc, collComms%recvcnts(jproc)
end do

! Determine the displacements for the receive operation
collComms%recvdspls(0)=0
do jproc=1,nproc-1
   collComms%recvdspls(jproc) = collComms%recvdspls(jproc-1) + collComms%recvcnts(jproc-1)
    !write(*,'(a,2i6,i12)') 'jproc, iproc, collComms%recvdspls(jproc)', jproc, iproc, collComms%recvdspls(jproc)
end do

! Modify orbs%npsidim, if required
ii=0
do jproc=0,nproc-1
    ii=ii+collComms%recvcnts(jproc)
end do
!orbs%npsidim=max(orbs%npsidim,ii)
orbs%npsidim_orbs = max(orbs%npsidim_orbs,ii) 
orbs%npsidim_comp = max(orbs%npsidim_comp,ii)


ii1s=0
ii5s=0
ii1e=0
ii5e=0

! Get the global indices of all elements
allocate(collComms%indexarray(max(orbs%npsidim_orbs,orbs%npsidim_comp)), stat=istat)
call memocc(istat, collComms%indexarray, 'collComms%indexarray', subname)
ist=1
ind=1
do iorb=1,orbs%norbp
    iiorb=orbs%isorb+iorb
    ilr=orbs%inwhichlocreg(iiorb)
    ldim=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
    !!!gdim=lzd%glr%wfd%nvctr_c+7*lzd%glr%wfd%nvctr_f
    !!!call index_of_Lpsi_to_global2(iproc, nproc, ldim, gdim, orbs%norbp, orbs%nspinor, input%nspin, &
    !!!     lzd%glr, lzd%llr(ilr), collComms%indexarray(ist))
    n1l=lzd%llr(ilr)%d%n1
    n2l=lzd%llr(ilr)%d%n2
    n3l=lzd%llr(ilr)%d%n3
    n1g=lzd%glr%d%n1
    n2g=lzd%glr%d%n2
    n3g=lzd%glr%d%n3
    !write(*,'(a,i8,6i9)') 'ilr, n1l, n2l, n3l, n1g, n2g, n3g', ilr, n1l, n2l, n3l, n1g, n2g, n3g
    nshift1=lzd%llr(ilr)%ns1-lzd%glr%ns1
    nshift2=lzd%llr(ilr)%ns2-lzd%glr%ns2
    nshift3=lzd%llr(ilr)%ns3-lzd%glr%ns3

    if(iiorb==1) then
        ii1s=ind
    else if(iiorb==5) then
        ii5s=ind
    end if
    do iseg=1,lzd%llr(ilr)%wfd%nseg_c
        is=lzd%llr(ilr)%wfd%keygloc(1,iseg)
        ie=lzd%llr(ilr)%wfd%keygloc(2,iseg)
        !write(800+iiorb,'(a,i9,3i12,6i7)') 'ilr, iseg, is, ie, n1l, n2l, n3l, nshift1, nshift2, nshift3', &
        !      ilr, iseg, is, ie, n1l, n2l, n3l, nshift1, nshift2, nshift3
        do i=is,ie
            collComms%indexarray(ind)=transform_index(i, n1l, n2l, n3l, n1g, n2g, n3g, nshift1, nshift2, nshift3)
            !!!! DEBUG !!
            !!collComms%indexarray(ind)=iiorb
            !!!! DEBUG !!
            !!write(900+iiorb,'(a,i9,3i12,6i7,i10)') 'ilr, iseg, is, ie, n1l, n2l, n3l, nshift1, &
            !!    &nshift2, nshift3, collComms%indexarray(ind)', &
            !!    ilr, iseg, is, ie, n1l, n2l, n3l, nshift1, nshift2, nshift3, collComms%indexarray(ind)
            ind=ind+1
        end do
    end do
    !if(iiorb==1) then
    !    ii1e=ind-1
    !else if(iiorb==5) then
    !    ii5e=ind-1
    !end if


    offset=(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1)
    do iseg=1,lzd%llr(ilr)%wfd%nseg_f
        is=lzd%llr(ilr)%wfd%keygloc(1,iseg+lzd%llr(ilr)%wfd%nseg_c)
        ie=lzd%llr(ilr)%wfd%keygloc(2,iseg+lzd%llr(ilr)%wfd%nseg_c)
        do i=is,ie
            ii=transform_index(i, n1l, n2l, n3l, n1g, n2g, n3g, nshift1, nshift2, nshift3)

            collComms%indexarray(ind  ) = offset + 7*(ii-1)+1
            collComms%indexarray(ind+1) = offset + 7*(ii-1)+2
            collComms%indexarray(ind+2) = offset + 7*(ii-1)+3
            collComms%indexarray(ind+3) = offset + 7*(ii-1)+4
            collComms%indexarray(ind+4) = offset + 7*(ii-1)+5
            collComms%indexarray(ind+5) = offset + 7*(ii-1)+6
            collComms%indexarray(ind+6) = offset + 7*(ii-1)+7
            ind=ind+7
        end do
    end do
    if(iiorb==1) then
        ii1e=ind-1
    else if(iiorb==5) then
        ii5e=ind-1
    end if

    !do istat=0,ldim-1
    !    write(200+iproc,*) ist+istat, collComms%indexarray(ist+istat)
    !end do

    ist=ist+ldim
end do


!! ATTENTION: This will not work for nproc=1, so comment it.
!! As a consequence, the transposition will not work correctly.

!!! Transpose the index array
!!allocate(work_int(max(orbs%npsidim_orbs,orbs%npsidim_comp)), stat=istat)
!!call memocc(istat, work_int, 'work_int', subname)
!!call transpose_linear_int(iproc, 0, nproc-1, orbs, collComms, collComms%indexarray, mpi_comm_world, work_int)
!!iall=-product(shape(work_int))*kind(work_int)
!!deallocate(work_int, stat=istat)
!!call memocc(istat, iall, 'work_int', subname)



end subroutine initCollectiveComms












subroutine init_orbitals_data_for_linear(iproc, nproc, nspinor, input, at, glr, use_derivative_basis, rxyz, &
           lorbs)
  use module_base
  use module_types
  use module_interfaces, except_this_one => init_orbitals_data_for_linear
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, nspinor
  type(input_variables),intent(in):: input
  type(atoms_data),intent(in):: at
  type(locreg_descriptors),intent(in):: glr
  logical,intent(in):: use_derivative_basis
  real(8),dimension(3,at%nat),intent(in):: rxyz
  type(orbitals_data),intent(out):: lorbs
  
  ! Local variables
  integer:: norb, norbu, norbd, ii, ityp, iat, ilr, istat, iall, iorb, nlr
  integer,dimension(:),allocatable:: norbsPerLocreg, norbsPerAtom
  real(8),dimension(:,:),allocatable:: locregCenter
  character(len=*),parameter:: subname='init_orbitals_data_for_linear'
  
  call nullify_orbitals_data(lorbs)
  
  ! Count the number of basis functions.
  allocate(norbsPerAtom(at%nat), stat=istat)
  call memocc(istat, norbsPerAtom, 'norbsPerAtom', subname)
  norb=0
  nlr=0
  if(use_derivative_basis) then
      ii=4
  else
      ii=1
  end if
  do iat=1,at%nat
      ityp=at%iatype(iat)
      norbsPerAtom(iat)=input%lin%norbsPerType(ityp)
      norb=norb+ii*input%lin%norbsPerType(ityp)
      nlr=nlr+input%lin%norbsPerType(ityp)
  end do
  
  
  ! Distribute the basis functions among the processors.
  norbu=norb
  norbd=0
  call nullify_orbitals_data(lorbs)
  call orbitals_descriptors_forLinear(iproc, nproc, norb, norbu, norbd, input%nspin, nspinor,&
       input%nkpt, input%kpt, input%wkpt, lorbs)
  call repartitionOrbitals(iproc, nproc, lorbs%norb, lorbs%norb_par,&
       lorbs%norbp, lorbs%isorb_par, lorbs%isorb, lorbs%onWhichMPI)
  

  allocate(locregCenter(3,nlr), stat=istat)
  call memocc(istat, locregCenter, 'locregCenter', subname)
  
  ilr=0
  do iat=1,at%nat
      ityp=at%iatype(iat)
      do iorb=1,input%lin%norbsPerType(ityp)
          ilr=ilr+1
          locregCenter(:,ilr)=rxyz(:,iat)
      end do
  end do
  
  allocate(norbsPerLocreg(nlr), stat=istat)
  call memocc(istat, norbsPerLocreg, 'norbsPerLocreg', subname)
  norbsPerLocreg=ii !should be norbsPerLocreg
    
  iall=-product(shape(lorbs%inWhichLocreg))*kind(lorbs%inWhichLocreg)
  deallocate(lorbs%inWhichLocreg, stat=istat)
  call memocc(istat, iall, 'lorbs%inWhichLocreg', subname)
  
  call assignToLocreg2(iproc, nproc, lorbs%norb, lorbs%norb_par, at%nat, nlr, &
       input%nspin, norbsPerLocreg, locregCenter, lorbs%inwhichlocreg)

  call assignToLocreg2(iproc, nproc, lorbs%norb, lorbs%norb_par, at%nat, at%nat, &
       input%nspin, norbsPerAtom, rxyz, lorbs%onwhichatom)
  
  allocate(lorbs%eval(lorbs%norb), stat=istat)
  call memocc(istat, lorbs%eval, 'lorbs%eval', subname)
  lorbs%eval=-.5d0
  
  
  iall=-product(shape(norbsPerLocreg))*kind(norbsPerLocreg)
  deallocate(norbsPerLocreg, stat=istat)
  call memocc(istat, iall, 'norbsPerLocreg', subname)
  
  iall=-product(shape(locregCenter))*kind(locregCenter)
  deallocate(locregCenter, stat=istat)
  call memocc(istat, iall, 'locregCenter', subname)

  iall=-product(shape(norbsPerAtom))*kind(norbsPerAtom)
  deallocate(norbsPerAtom, stat=istat)
  call memocc(istat, iall, 'norbsPerAtom', subname)

end subroutine init_orbitals_data_for_linear



subroutine init_local_zone_descriptors(iproc, nproc, input, glr, at, rxyz, orbs, derorbs, lzd)
  use module_base
  use module_types
  use module_interfaces, except_this_one => init_local_zone_descriptors
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  type(input_variables),intent(in):: input
  type(locreg_descriptors),intent(in):: glr
  type(atoms_data),intent(in):: at
  real(8),dimension(3,at%nat),intent(in):: rxyz
  type(orbitals_data),intent(in):: orbs, derorbs
  type(local_zone_descriptors),intent(out):: lzd
  
  ! Local variables
  integer:: iat, ityp, ilr, istat, iorb, iall
  real(8),dimension(:,:),allocatable:: locregCenter
  character(len=*),parameter:: subname='init_local_zone_descriptors'
  
  call nullify_local_zone_descriptors(lzd)
  
  ! Count the number of localization regions
  lzd%nlr=0
  do iat=1,at%nat
      ityp=at%iatype(iat)
      lzd%nlr=lzd%nlr+input%lin%norbsPerType(ityp)
  end do
  
  
  allocate(locregCenter(3,lzd%nlr), stat=istat)
  call memocc(istat, locregCenter, 'locregCenter', subname)
  
  ilr=0
  do iat=1,at%nat
      ityp=at%iatype(iat)
      do iorb=1,input%lin%norbsPerType(ityp)
          ilr=ilr+1
          locregCenter(:,ilr)=rxyz(:,iat)
      end do
  end do
  
  
  call initLocregs(iproc, nproc, lzd%nlr, locregCenter, input%hx, input%hy, input%hz, lzd, orbs, &
       glr, input%lin%locrad, input%lin%locregShape, derorbs)

  iall=-product(shape(locregCenter))*kind(locregCenter)
  deallocate(locregCenter, stat=istat)
  call memocc(istat, iall, 'locregCenter', subname)


  call nullify_locreg_descriptors(lzd%Glr)
  call copy_locreg_descriptors(Glr, lzd%Glr, subname)

  lzd%hgrids(1)=input%hx
  lzd%hgrids(2)=input%hy
  lzd%hgrids(3)=input%hz

end subroutine init_local_zone_descriptors



subroutine redefine_locregs_quantities(iproc, nproc, hx, hy, hz, lzd, tmb, tmbmix, denspot)
  use module_base
  use module_types
  use module_interfaces, except_this_one => redefine_locregs_quantities
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  real(8),intent(in):: hx, hy, hz
  type(local_zone_descriptors),intent(inout):: lzd
  type(DFT_wavefunction),intent(inout):: tmb
  type(DFT_wavefunction),intent(inout):: tmbmix
  type(DFT_local_fields),intent(inout):: denspot
  
  ! Local variables
  integer:: iall, istat, tag
  type(orbitals_data):: orbs_tmp
  character(len=*),parameter:: subname='redefine_locregs_quantities'

  if(tmbmix%wfnmd%bs%use_derivative_basis) then
      call nullify_orbitals_data(orbs_tmp)
      call copy_orbitals_data(tmb%orbs, orbs_tmp, subname)
      call update_locreg(iproc, nproc, tmbmix%wfnmd%bs%use_derivative_basis, denspot, hx, hy, hz, &
           orbs_tmp, lzd, tmbmix%orbs, tmbmix%op, tmbmix%comon, tmb%comgp, tmbmix%comgp, tmbmix%comsr, tmbmix%mad)
      call deallocate_orbitals_data(orbs_tmp, subname)

      tmbmix%wfnmd%nphi=tmbmix%orbs%npsidim_orbs

      ! Reallocate tmbmix%psi, since it might have a new shape
      iall=-product(shape(tmbmix%psi))*kind(tmbmix%psi)
      deallocate(tmbmix%psi, stat=istat)
      call memocc(istat, iall, 'tmbmix%psi', subname)
      allocate(tmbmix%psi(tmbmix%orbs%npsidim_orbs), stat=istat)
      call memocc(istat, tmbmix%psi, 'tmbmix%psi', subname)

      call cancelCommunicationPotential(iproc, nproc, tmbmix%comgp)
      call deallocateCommunicationsBuffersPotential(tmbmix%comgp, subname)
  else
      tag=1
      call deallocateCommunicationbufferSumrho(tmbmix%comsr, subname)
      call deallocate_p2pComms(tmbmix%comsr, subname)
      call nullify_p2pComms(tmbmix%comsr)
      call initializeCommsSumrho(iproc, nproc, denspot%dpcom%nscatterarr, lzd, tmbmix%orbs, tag, tmbmix%comsr)
      call allocateCommunicationbufferSumrho(iproc, .false., tmbmix%comsr, subname)
  end if
  call deallocate_p2pComms(tmbmix%comgp, subname)
  call nullify_p2pComms(tmbmix%comgp)
  call initializeCommunicationPotential(iproc, nproc, denspot%dpcom%nscatterarr, tmbmix%orbs, &
       lzd, tmbmix%comgp, tmbmix%orbs%inWhichLocreg, tag)
  call allocateCommunicationsBuffersPotential(tmbmix%comgp, subname)
  call postCommunicationsPotential(iproc, nproc, denspot%dpcom%ndimpot, denspot%rhov, tmbmix%comgp)
end subroutine redefine_locregs_quantities



subroutine update_locreg(iproc, nproc, useDerivativeBasisFunctions, denspot, hx, hy, hz, &
           orbs_tmp, lzd, llborbs, lbop, lbcomon, comgp, lbcomgp, comsr, lbmad)
  use module_base
  use module_types
  use module_interfaces, except_this_one => update_locreg
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc
  logical,intent(in):: useDerivativeBasisFunctions
  type(DFT_local_fields), intent(in) :: denspot
  real(8),intent(in):: hx, hy, hz
  type(orbitals_data),intent(inout):: orbs_tmp
  type(local_zone_descriptors),intent(inout):: lzd
  type(orbitals_data),intent(inout):: llborbs
  type(overlapParameters),intent(inout):: lbop
  type(p2pComms),intent(inout):: lbcomon
  type(p2pComms),intent(inout):: comgp, lbcomgp
  type(p2pComms),intent(inout):: comsr
  type(matrixDescriptors),intent(inout):: lbmad
  
  ! Local variables
  integer:: norb, norbu, norbd, nspin, iorb, istat, iall, ilr, npsidim, nlr, i, tag, ii
  real(8),dimension(:,:),allocatable:: locregCenter
  real(8),dimension(:),allocatable:: locrad
  integer,dimension(:),allocatable:: orbsPerLocreg, onwhichatom
  type(locreg_descriptors):: glr_tmp
  character(len=*),parameter:: subname='update_locreg'


  ! Keep llborbs%onwhichatom
  allocate(onwhichatom(llborbs%norb), stat=istat)
  call memocc(istat, onwhichatom, 'onwhichatom', subname)
  call vcopy(llborbs%norb, llborbs%onwhichatom(1), 1, onwhichatom(1), 1)

  ! Create new types for large basis...
  call deallocate_orbitals_data(llborbs, subname)
  call deallocate_overlapParameters(lbop, subname)
  call deallocate_p2pComms(lbcomon, subname)
  call deallocate_matrixDescriptors(lbmad, subname)
  !!call deallocate_p2pComms(lbcomgp, subname)


  call nullify_orbitals_data(llborbs)
  call nullify_overlapParameters(lbop)
  call nullify_p2pComms(lbcomon)
  call nullify_matrixDescriptors(lbmad)
  !!call nullify_p2pComms(lbcomgp)
  tag=1
  if(.not.useDerivativeBasisFunctions) then
      norbu=orbs_tmp%norb
  else
      norbu=4*orbs_tmp%norb
  end if
  norb=norbu
  norbd=0
  nspin=1
  call orbitals_descriptors_forLinear(iproc, nproc, norb, norbu, norbd, nspin, orbs_tmp%nspinor,&
       orbs_tmp%nkpts, orbs_tmp%kpts, orbs_tmp%kwgts, llborbs)
  call repartitionOrbitals(iproc, nproc, llborbs%norb, llborbs%norb_par,&
       llborbs%norbp, llborbs%isorb_par, llborbs%isorb, llborbs%onWhichMPI)

  allocate(orbsperlocreg(lzd%nlr), stat=istat)
  call memocc(istat, orbsperlocreg, 'orbsperlocreg', subname)
  do iorb=1,lzd%nlr
      if(useDerivativeBasisFunctions) then
          orbsperlocreg(iorb)=4
      else
          orbsperlocreg(iorb)=1
      end if
  end do

  iall=-product(shape(llborbs%inWhichLocreg))*kind(llborbs%inWhichLocreg)
  deallocate(llborbs%inWhichLocreg, stat=istat)
  call memocc(istat, iall, 'llborbs%inWhichLocreg', subname)

  allocate(locregCenter(3,lzd%nlr), stat=istat)
  call memocc(istat, locregCenter, 'locregCenter', subname)
  do ilr=1,lzd%nlr
      locregCenter(:,ilr)=lzd%llr(ilr)%locregCenter
  end do

  call assignToLocreg2(iproc, nproc, llborbs%norb, llborbs%norb_par, 0, lzd%nlr, &
       nspin, orbsperlocreg, locregCenter, llborbs%inwhichlocreg)

  ! Assign inwhichlocreg manually
  if(useDerivativeBasisFunctions) then
      norb=4
  else
      norb=1
  end if
  ii=0
  do iorb=1,orbs_tmp%norb
      do i=1,norb
          ii=ii+1
          llborbs%inwhichlocreg(ii)=orbs_tmp%inwhichlocreg(iorb)
      end do
  end do

  ! Copy back onwhichatom
  allocate(llborbs%onwhichatom(llborbs%norb), stat=istat)
  call memocc(istat, llborbs%onwhichatom, 'llborbs%onwhichatom', subname)
  call vcopy(llborbs%norb, onwhichatom(1), 1, llborbs%onwhichatom(1), 1)

  ! Recreate lzd, since it has to contain the bounds also for the derivatives
  ! First copy to some temporary structure
  allocate(locrad(lzd%nlr), stat=istat)
  call memocc(istat, locrad, 'locrad', subname)
  call nullify_locreg_descriptors(glr_tmp)
  call copy_locreg_descriptors(lzd%glr, glr_tmp, subname)
  nlr=lzd%nlr
  locrad=lzd%llr(:)%locrad
  call deallocate_local_zone_descriptors(lzd, subname)
  call nullify_local_zone_descriptors(lzd)
  call initLocregs(iproc, nproc, nlr, locregCenter, hx, hy, hz, lzd, orbs_tmp, glr_tmp, locrad, 's', llborbs)
  call nullify_locreg_descriptors(lzd%glr)
  call copy_locreg_descriptors(glr_tmp, lzd%glr, subname)
  call deallocate_locreg_descriptors(glr_tmp, subname)
  iall=-product(shape(locrad))*kind(locrad)
  deallocate(locrad, stat=istat)
  call memocc(istat, iall, 'locrad', subname)

  iall=-product(shape(locregCenter))*kind(locregCenter)
  deallocate(locregCenter, stat=istat)
  call memocc(istat, iall, 'locregCenter', subname)
  iall=-product(shape(orbsperlocreg))*kind(orbsperlocreg)
  deallocate(orbsperlocreg, stat=istat)
  call memocc(istat, iall, 'orbsperlocreg', subname)

  npsidim = 0
  do iorb=1,llborbs%norbp
   ilr=llborbs%inwhichlocreg(iorb+llborbs%isorb)
   npsidim = npsidim + lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
  end do
  allocate(llborbs%eval(llborbs%norb), stat=istat)
  call memocc(istat, llborbs%eval, 'llborbs%eval', subname)
  llborbs%eval=-.5d0
  llborbs%npsidim_orbs=max(npsidim,1)
  call initCommsOrtho(iproc, nproc, nspin, hx, hy, hz, lzd, llborbs, llborbs%inWhichLocreg,&
       's', lbop, lbcomon, tag)
  call initMatrixCompression(iproc, nproc, lzd%nlr, llborbs, &
       lbop%noverlaps, lbop%overlaps, lbmad)
  call initCompressedMatmul3(llborbs%norb, lbmad)



  tag=1
  call deallocateCommunicationbufferSumrho(comsr, subname)
  call deallocate_p2pComms(comsr, subname)
  call nullify_p2pComms(comsr)
  call initializeCommsSumrho(iproc, nproc, denspot%dpcom%nscatterarr, lzd, llborbs, tag, comsr)
  call allocateCommunicationbufferSumrho(iproc, .false., comsr, subname)

  iall=-product(shape(onwhichatom))*kind(onwhichatom)
  deallocate(onwhichatom, stat=istat)
  call memocc(istat, iall, 'onwhichatom', subname)


end subroutine update_locreg



subroutine create_new_locregs(iproc, nproc, nlr, hx, hy, hz, lorbs, glr, locregCenter, locrad, nscatterarr, withder, &
           inwhichlocreg_reference, ldiis, lzdlarge, orbslarge, oplarge, comonlarge, madlarge, comgplarge, &
           lphilarge, lhphilarge, lhphilargeold, lphilargeold)
use module_base
use module_types
use module_interfaces, except_this_one => create_new_locregs
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc, nlr
real(8),intent(in):: hx, hy, hz
type(orbitals_data),intent(in):: lorbs
type(locreg_descriptors),intent(in):: glr
real(8),dimension(3,nlr),intent(in):: locregCenter
real(8),dimension(nlr):: locrad
integer,dimension(0:nproc-1,4),intent(in):: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
logical,intent(in):: withder
integer,dimension(lorbs%norb),intent(in):: inwhichlocreg_reference
type(localizedDIISParameters),intent(inout):: ldiis
type(local_zone_descriptors),intent(out):: lzdlarge
type(orbitals_data),intent(out):: orbslarge
type(overlapParameters),intent(out):: oplarge
type(p2pComms),intent(out):: comonlarge
type(matrixDescriptors),intent(out):: madlarge
type(p2pComms),intent(out):: comgplarge
real(8),dimension(:),pointer,intent(out):: lphilarge, lhphilarge, lhphilargeold, lphilargeold

! Local variables
integer:: tag, norbu, norbd, nspin, iorb, iiorb, ilr, npsidim, ii, istat, iall, ierr, norb
integer,dimension(:),allocatable:: orbsperlocreg
character(len=*),parameter:: subname='create_new_locregs'


   if(iproc==0) write(*,'(x,a)') 'creating new locregs...'
   call nullify_local_zone_descriptors(lzdlarge)
   call nullify_orbitals_data(orbslarge)
   call nullify_overlapParameters(oplarge)
   call nullify_p2pComms(comonlarge)
   call nullify_matrixDescriptors(madlarge)
   call nullify_p2pComms(comgplarge)

   tag=1
   lzdlarge%nlr=nlr
   if(.not.withder) then
       norbu=lorbs%norb
   else
       norbu=4*lorbs%norb
   end if
   norb=norbu
   norbd=0
   nspin=1
   call orbitals_descriptors_forLinear(iproc, nproc, norb, norbu, norbd, nspin, lorbs%nspinor,&
        lorbs%nkpts, lorbs%kpts, lorbs%kwgts, orbslarge)
   call repartitionOrbitals(iproc, nproc, orbslarge%norb, orbslarge%norb_par,&
        orbslarge%norbp, orbslarge%isorb_par, orbslarge%isorb, orbslarge%onWhichMPI)

   orbslarge%inwhichlocreg = inwhichlocreg_reference

   call initLocregs(iproc, nproc, lzdlarge%nlr, locregCenter, hx, hy, hz, lzdlarge, orbslarge, Glr, locrad, 's')
   call nullify_locreg_descriptors(lzdlarge%Glr)
   call copy_locreg_descriptors(Glr, lzdlarge%Glr, subname)
   npsidim = 0
   do iorb=1,orbslarge%norbp
    ilr=orbslarge%inwhichlocreg(iorb+orbslarge%isorb)
    npsidim = npsidim + lzdlarge%llr(ilr)%wfd%nvctr_c+7*lzdlarge%llr(ilr)%wfd%nvctr_f
   end do
   allocate(orbslarge%eval(orbslarge%norb), stat=istat)
   call memocc(istat, orbslarge%eval, 'orbslarge%eval', subname)
   orbslarge%eval=-.5d0
   orbslarge%npsidim_orbs=max(npsidim,1)
   call initCommsOrtho(iproc, nproc, nspin, hx, hy, hz, lzdlarge, orbslarge, orbslarge%inWhichLocreg,&
        's', oplarge, comonlarge, tag)
   call initMatrixCompression(iproc, nproc, lzdlarge%nlr, orbslarge, &
        oplarge%noverlaps, oplarge%overlaps, madlarge)
   call initCompressedMatmul3(orbslarge%norb, madlarge)

   call initializeCommunicationPotential(iproc, nproc, nscatterarr, orbslarge, lzdlarge, comgplarge, orbslarge%inWhichLocreg, tag)

   iall=-product(shape(ldiis%phiHist))*kind(ldiis%phiHist)
   deallocate(ldiis%phiHist, stat=istat)
   call memocc(istat, iall, 'ldiis%phiHist', subname)
   iall=-product(shape(ldiis%hphiHist))*kind(ldiis%hphiHist)
   deallocate(ldiis%hphiHist, stat=istat)
   call memocc(istat, iall, 'ldiis%hphiHist', subname)
   ii=0
   do iorb=1,orbslarge%norbp
       ilr=orbslarge%inwhichlocreg(orbslarge%isorb+iorb)
       ii=ii+ldiis%isx*(lzdlarge%llr(ilr)%wfd%nvctr_c+7*lzdlarge%llr(ilr)%wfd%nvctr_f)
   end do
   allocate(ldiis%phiHist(ii), stat=istat)
   call memocc(istat, ldiis%phiHist, 'ldiis%phiHist', subname)
   allocate(ldiis%hphiHist(ii), stat=istat)
   call memocc(istat, ldiis%hphiHist, 'ldiis%hphiHist', subname)

   allocate(lphilarge(orbslarge%npsidim_orbs), stat=istat)
   call memocc(istat, lphilarge, 'lphilarge', subname)
   allocate(lhphilarge(orbslarge%npsidim_orbs), stat=istat)
   call memocc(istat, lhphilarge, 'lhphilarge', subname)
   allocate(lhphilargeold(orbslarge%npsidim_orbs), stat=istat)
   call memocc(istat, lhphilargeold, 'lhphilargeold', subname)
   allocate(lphilargeold(orbslarge%npsidim_orbs), stat=istat)
   call memocc(istat, lphilargeold, 'lphilargeold', subname)

   lphilarge=0.d0
   lhphilarge=0.d0
   lhphilargeold=0.d0
   lphilargeold=0.d0

   lzdlarge%hgrids(1)=hx
   lzdlarge%hgrids(2)=hy
   lzdlarge%hgrids(3)=hz

end subroutine create_new_locregs



subroutine destroy_new_locregs(lzdlarge, orbslarge, oplarge, comonlarge, madlarge, comgplarge, &
           lphilarge, lhphilarge, lhphilargeold, lphilargeold)
  use module_base
  use module_types
  use module_interfaces, except_this_one => destroy_new_locregs
  implicit none

  ! Calling arguments
  type(local_zone_descriptors),intent(inout):: lzdlarge
  type(orbitals_data),intent(inout):: orbslarge
  type(overlapParameters),intent(inout):: oplarge
  type(p2pComms),intent(inout):: comonlarge
  type(matrixDescriptors),intent(inout):: madlarge
  type(p2pComms),intent(inout):: comgplarge
  real(8),dimension(:),pointer,intent(inout):: lphilarge, lhphilarge, lhphilargeold, lphilargeold

  ! Local variables
  integer:: istat, iall
  character(len=*),parameter:: subname='destroy_new_locregs'

  call deallocate_local_zone_descriptors(lzdlarge, subname)
  call deallocate_orbitals_data(orbslarge, subname)
  call deallocate_overlapParameters(oplarge, subname)
  call deallocate_p2pComms(comonlarge, subname)
  call deallocate_matrixDescriptors(madlarge, subname)
  call deallocate_p2pComms(comgplarge, subname)

  iall=-product(shape(lphilarge))*kind(lphilarge)
  deallocate(lphilarge, stat=istat)
  call memocc(istat, iall, 'lphilarge', subname)
  iall=-product(shape(lhphilarge))*kind(lhphilarge)
  deallocate(lhphilarge, stat=istat)
  call memocc(istat, iall, 'lhphilarge', subname)
  iall=-product(shape(lhphilargeold))*kind(lhphilargeold)
  deallocate(lhphilargeold, stat=istat)
  call memocc(istat, iall, 'lhphilargeold', subname)
  iall=-product(shape(lphilargeold))*kind(lphilargeold)
  deallocate(lphilargeold, stat=istat)
  call memocc(istat, iall, 'lphilargeold', subname)

end subroutine destroy_new_locregs



subroutine enlarge_locreg(iproc, nproc, hx, hy, hz, lzd, locrad, lorbs, op, comon, comgp, mad, &
           ldiis, denspot, nphi, lphi)
use module_base
use module_types
use module_interfaces, except_this_one => enlarge_locreg
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc
real(8),intent(in):: hx, hy, hz
type(local_zone_descriptors),intent(inout):: lzd
real(8),dimension(lzd%nlr),intent(in):: locrad
type(orbitals_data),intent(inout):: lorbs
type(p2pComms),intent(inout):: comon, comgp
type(overlapParameters),intent(inout):: op
type(matrixDescriptors),intent(inout):: mad
type(localizedDIISParameters),intent(inout):: ldiis
type(DFT_local_fields),intent(inout):: denspot
integer,intent(inout):: nphi
real(8),dimension(:),pointer:: lphi

! Local variables
type(local_zone_descriptors):: lzdlarge
type(orbitals_data):: orbslarge
type(p2pComms):: comonlarge, comgplarge
type(overlapParameters):: oplarge
type(matrixDescriptors):: madlarge
type(localizedDIISParameters):: ldiislarge
real(8),dimension(:),pointer:: lphilarge, lhphilarge, lhphilargeold, lphilargeold, lhphi, lhphiold, lphiold
real(8),dimension(:,:),allocatable:: locregCenter
integer,dimension(:),allocatable:: inwhichlocreg_reference, onwhichatom_reference
integer:: istat, iall, iorb, ilr
character(len=*),parameter:: subname='enlarge_locreg'


allocate(locregCenter(3,lzd%nlr), stat=istat)
call memocc(istat, locregCenter, 'locregCenter', subname)

allocate(inwhichlocreg_reference(lorbs%norb), stat=istat)
call memocc(istat, inwhichlocreg_reference, 'inwhichlocreg_reference', subname)

allocate(onwhichatom_reference(lorbs%norb), stat=istat)
call memocc(istat, onwhichatom_reference, 'onwhichatom_reference', subname)

! Fake allocation
allocate(lhphi(1), stat=istat)
call memocc(istat, lhphi, 'lhphi', subname)
allocate(lhphiold(1), stat=istat)
call memocc(istat, lhphiold, 'lhphiold', subname)
allocate(lphiold(1), stat=istat)
call memocc(istat, lphiold, 'lphiold', subname)

! always use the same inwhichlocreg
call vcopy(lorbs%norb, lorbs%inwhichlocreg(1), 1, inwhichlocreg_reference(1), 1)

do iorb=1,lorbs%norb
    ilr=lorbs%inwhichlocreg(iorb)
    locregCenter(:,ilr)=lzd%llr(ilr)%locregCenter
end do

! Go from the small locregs to the new larger locregs. Use lzdlarge etc as temporary variables.
call create_new_locregs(iproc, nproc, lzd%nlr, hx, hy, hz, lorbs, lzd%glr, locregCenter, &
     locrad, denspot%dpcom%nscatterarr, .false., inwhichlocreg_reference, ldiis, &
     lzdlarge, orbslarge, oplarge, comonlarge, madlarge, comgplarge, &
     lphilarge, lhphilarge, lhphilargeold, lphilargeold)
allocate(orbslarge%onwhichatom(lorbs%norb), stat=istat)
call memocc(istat, orbslarge%onwhichatom, 'orbslarge%onwhichatom', subname)
call small_to_large_locreg(iproc, nproc, lzd, lzdlarge, lorbs, orbslarge, lphi, lphilarge)
call vcopy(lorbs%norb, lorbs%onwhichatom(1), 1, onwhichatom_reference(1), 1)
call destroy_new_locregs(lzd, lorbs, op, comon, mad, comgp, &
     lphi, lhphi, lhphiold, lphiold)
call create_new_locregs(iproc, nproc, lzd%nlr, hx, hy, hz, orbslarge, lzdlarge%glr, locregCenter, &
     locrad, denspot%dpcom%nscatterarr, .false., inwhichlocreg_reference, ldiis, &
     lzd, lorbs, op, comon, mad, comgp, &
     lphi, lhphi, lhphiold, lphiold)
allocate(lorbs%onwhichatom(lorbs%norb), stat=istat)
call memocc(istat, lorbs%onwhichatom, 'lorbs%onwhichatom', subname)
call vcopy(lorbs%norb, onwhichatom_reference(1), 1, lorbs%onwhichatom(1), 1)
nphi=lorbs%npsidim_orbs
call dcopy(orbslarge%npsidim_orbs, lphilarge(1), 1, lphi(1), 1)
call vcopy(lorbs%norb, orbslarge%onwhichatom(1), 1, onwhichatom_reference(1), 1)
call destroy_new_locregs(lzdlarge, orbslarge, oplarge, comonlarge, madlarge, comgplarge, &
     lphilarge, lhphilarge, lhphilargeold, lphilargeold)

iall=-product(shape(inwhichlocreg_reference))*kind(inwhichlocreg_reference)
deallocate(inwhichlocreg_reference, stat=istat)
call memocc(istat, iall, 'inwhichlocreg_reference', subname)

iall=-product(shape(onwhichatom_reference))*kind(onwhichatom_reference)
deallocate(onwhichatom_reference, stat=istat)
call memocc(istat, iall, 'onwhichatom_reference', subname)

iall=-product(shape(locregCenter))*kind(locregCenter)
deallocate(locregCenter, stat=istat)
call memocc(istat, iall, 'locregCenter', subname)

iall=-product(shape(lhphi))*kind(lhphi)
deallocate(lhphi, stat=istat)
call memocc(istat, iall, 'lhphi', subname)

iall=-product(shape(lhphiold))*kind(lhphiold)
deallocate(lhphiold, stat=istat)
call memocc(istat, iall, 'lhphiold', subname)

iall=-product(shape(lphiold))*kind(lphiold)
deallocate(lphiold, stat=istat)
call memocc(istat, iall, 'lphiold', subname)


end subroutine enlarge_locreg
