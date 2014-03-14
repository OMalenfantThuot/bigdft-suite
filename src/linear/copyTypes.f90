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

  call nullify_orbitals_data(tmbout%orbs)
  call copy_orbitals_data(tmbin%orbs, tmbout%orbs, subname)
  call nullify_local_zone_descriptors(tmbout%lzd)
  call copy_old_supportfunctions(iproc,tmbin%orbs,tmbin%lzd,tmbin%psi,tmbout%lzd,tmbout%psi)

  if (associated(tmbin%coeff)) then !(in%lin%scf_mode/=LINEAR_FOE) then ! should move this check to copy_old_coeffs
      call copy_old_coefficients(tmbin%orbs%norb, tmbin%coeff, tmbout%coeff)
  else
      nullify(tmbout%coeff)
  end if

  ! should technically copy these across as well but not needed for restart and will eventually be removing wfnmd as a type
  !nullify(tmbout%linmat%denskern%matrix_compr)
  nullify(tmbout%linmat%denskern_large%matrix_compr)

  ! should also copy/nullify p2pcomms etc

  !call copy_old_inwhichlocreg(tmbin%orbs%norb, tmbin%orbs%inwhichlocreg, tmbout%orbs%inwhichlocreg, &
  !     tmbin%orbs%onwhichatom, tmbout%orbs%onwhichatom)

end subroutine copy_tmbs

subroutine copy_convolutions_bounds(geocode,boundsin, boundsout, subname)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  character(len=1),intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  type(convolutions_bounds),intent(in):: boundsin
  type(convolutions_bounds),intent(inout):: boundsout
  character(len=*),intent(in):: subname
  
  ! Local variables
  integer:: iis1, iie1, iis2, iie2, iis3, iie3, i1, i2, i3, istat, iall
  
  call copy_kinetic_bounds(geocode, boundsin%kb, boundsout%kb, subname)
  call copy_shrink_bounds(geocode, boundsin%sb, boundsout%sb, subname)
  call copy_grow_bounds(geocode, boundsin%gb, boundsout%gb, subname)
  
  if(geocode == 'F') then
     if(associated(boundsout%ibyyzz_r)) then
         iall=-product(shape(boundsout%ibyyzz_r))*kind(boundsout%ibyyzz_r)
         deallocate(boundsout%ibyyzz_r, stat=istat)
         call memocc(istat, iall, 'boundsout%ibyyzz_r', subname)
     end if
  
     if(associated(boundsin%ibyyzz_r)) then
         iis1=lbound(boundsin%ibyyzz_r,1)
         iie1=ubound(boundsin%ibyyzz_r,1)
         iis2=lbound(boundsin%ibyyzz_r,2)
         iie2=ubound(boundsin%ibyyzz_r,2)
         iis3=lbound(boundsin%ibyyzz_r,3)
         iie3=ubound(boundsin%ibyyzz_r,3)
         allocate(boundsout%ibyyzz_r(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
         call memocc(istat, boundsout%ibyyzz_r, 'boundsout%ibyyzz_r', subname)
         do i3=iis3,iie3
             do i2=iis2,iie2
                 do i1=iis1,iie1
                     boundsout%ibyyzz_r(i1,i2,i3) = boundsin%ibyyzz_r(i1,i2,i3)
                 end do
             end do
         end do
     end if
  end if
end subroutine copy_convolutions_bounds

subroutine copy_kinetic_bounds(geocode,kbin, kbout, subname)
use module_base
use module_types
implicit none

! Calling arguments
character(len=1),intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode 
type(kinetic_bounds),intent(in):: kbin
type(kinetic_bounds),intent(inout):: kbout
character(len=*),intent(in):: subname

! Local variables
integer:: iis1, iie1, iis2, iie2, iis3, iie3, i1, i2, i3, istat, iall

if(geocode == 'F') then
   if(associated(kbout%ibyz_c)) then
       iall=-product(shape(kbout%ibyz_c))*kind(kbout%ibyz_c)
       deallocate(kbout%ibyz_c, stat=istat)
       call memocc(istat, iall, 'kbout%ibyz_c', subname)
   end if
   if(associated(kbin%ibyz_c)) then
       iis1=lbound(kbin%ibyz_c,1)
       iie1=ubound(kbin%ibyz_c,1)
       iis2=lbound(kbin%ibyz_c,2)
       iie2=ubound(kbin%ibyz_c,2)
       iis3=lbound(kbin%ibyz_c,3)
       iie3=ubound(kbin%ibyz_c,3)
       allocate(kbout%ibyz_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, kbout%ibyz_c, 'kbout%ibyz_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   kbout%ibyz_c(i1,i2,i3) = kbin%ibyz_c(i1,i2,i3)
               end do
           end do
       end do
   end if
   
   
   if(associated(kbout%ibxz_c)) then
       iall=-product(shape(kbout%ibxz_c))*kind(kbout%ibxz_c)
       deallocate(kbout%ibxz_c, stat=istat)
       call memocc(istat, iall, 'kbout%ibxz_c', subname)
   end if
   if(associated(kbin%ibxz_c)) then
       iis1=lbound(kbin%ibxz_c,1)
       iie1=ubound(kbin%ibxz_c,1)
       iis2=lbound(kbin%ibxz_c,2)
       iie2=ubound(kbin%ibxz_c,2)
       iis3=lbound(kbin%ibxz_c,3)
       iie3=ubound(kbin%ibxz_c,3)
       allocate(kbout%ibxz_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, kbout%ibxz_c, 'kbout%ibxz_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   kbout%ibxz_c(i1,i2,i3) = kbin%ibxz_c(i1,i2,i3)
               end do
           end do
       end do
   end if
   
   
   if(associated(kbout%ibxy_c)) then
       iall=-product(shape(kbout%ibxy_c))*kind(kbout%ibxy_c)
       deallocate(kbout%ibxy_c, stat=istat)
       call memocc(istat, iall, 'kbout%ibxy_c', subname)
   end if
   if(associated(kbin%ibxy_c)) then
       iis1=lbound(kbin%ibxy_c,1)
       iie1=ubound(kbin%ibxy_c,1)
       iis2=lbound(kbin%ibxy_c,2)
       iie2=ubound(kbin%ibxy_c,2)
       iis3=lbound(kbin%ibxy_c,3)
       iie3=ubound(kbin%ibxy_c,3)
       allocate(kbout%ibxy_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, kbout%ibxy_c, 'kbout%ibxy_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   kbout%ibxy_c(i1,i2,i3) = kbin%ibxy_c(i1,i2,i3)
               end do
           end do
       end do
   end if
end if

if(associated(kbout%ibyz_f)) then
    iall=-product(shape(kbout%ibyz_f))*kind(kbout%ibyz_f)
    deallocate(kbout%ibyz_f, stat=istat)
    call memocc(istat, iall, 'kbout%ibyz_f', subname)
end if
if(associated(kbin%ibyz_f)) then
    iis1=lbound(kbin%ibyz_f,1)
    iie1=ubound(kbin%ibyz_f,1)
    iis2=lbound(kbin%ibyz_f,2)
    iie2=ubound(kbin%ibyz_f,2)
    iis3=lbound(kbin%ibyz_f,3)
    iie3=ubound(kbin%ibyz_f,3)
    allocate(kbout%ibyz_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, kbout%ibyz_f, 'kbout%ibyz_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                kbout%ibyz_f(i1,i2,i3) = kbin%ibyz_f(i1,i2,i3)
            end do
        end do
    end do
end if


if(associated(kbout%ibxz_f)) then
    iall=-product(shape(kbout%ibxz_f))*kind(kbout%ibxz_f)
    deallocate(kbout%ibxz_f, stat=istat)
    call memocc(istat, iall, 'kbout%ibxz_f', subname)
end if
if(associated(kbin%ibxz_f)) then
    iis1=lbound(kbin%ibxz_f,1)
    iie1=ubound(kbin%ibxz_f,1)
    iis2=lbound(kbin%ibxz_f,2)
    iie2=ubound(kbin%ibxz_f,2)
    iis3=lbound(kbin%ibxz_f,3)
    iie3=ubound(kbin%ibxz_f,3)
    allocate(kbout%ibxz_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, kbout%ibxz_f, 'kbout%ibxz_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                kbout%ibxz_f(i1,i2,i3) = kbin%ibxz_f(i1,i2,i3)
            end do
        end do
    end do
end if


if(associated(kbout%ibxy_f)) then
    iall=-product(shape(kbout%ibxy_f))*kind(kbout%ibxy_f)
    deallocate(kbout%ibxy_f, stat=istat)
    call memocc(istat, iall, 'kbout%ibxy_f', subname)
end if
if(associated(kbin%ibxy_f)) then
    iis1=lbound(kbin%ibxy_f,1)
    iie1=ubound(kbin%ibxy_f,1)
    iis2=lbound(kbin%ibxy_f,2)
    iie2=ubound(kbin%ibxy_f,2)
    iis3=lbound(kbin%ibxy_f,3)
    iie3=ubound(kbin%ibxy_f,3)
    allocate(kbout%ibxy_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, kbout%ibxy_f, 'kbout%ibxy_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                kbout%ibxy_f(i1,i2,i3) = kbin%ibxy_f(i1,i2,i3)
            end do
        end do
    end do
end if


end subroutine copy_kinetic_bounds




subroutine copy_shrink_bounds(geocode, sbin, sbout, subname)
use module_base
use module_types
implicit none

! Calling arguments
character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
type(shrink_bounds),intent(in):: sbin
type(shrink_bounds),intent(inout):: sbout
character(len=*),intent(in):: subname

! Local variables
integer:: iis1, iie1, iis2, iie2, iis3, iie3, i1, i2, i3, istat, iall

if(geocode == 'F') then
   if(associated(sbout%ibzzx_c)) then
       iall=-product(shape(sbout%ibzzx_c))*kind(sbout%ibzzx_c)
       deallocate(sbout%ibzzx_c, stat=istat)
       call memocc(istat, iall, 'sbout%ibzzx_c', subname)
   end if
   if(associated(sbin%ibzzx_c)) then
       iis1=lbound(sbin%ibzzx_c,1)
       iie1=ubound(sbin%ibzzx_c,1)
       iis2=lbound(sbin%ibzzx_c,2)
       iie2=ubound(sbin%ibzzx_c,2)
       iis3=lbound(sbin%ibzzx_c,3)
       iie3=ubound(sbin%ibzzx_c,3)
       allocate(sbout%ibzzx_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, sbout%ibzzx_c, 'sbout%ibzzx_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   sbout%ibzzx_c(i1,i2,i3) = sbin%ibzzx_c(i1,i2,i3)
               end do
           end do
       end do
   end if
   
   
   if(associated(sbout%ibyyzz_c)) then
       iall=-product(shape(sbout%ibyyzz_c))*kind(sbout%ibyyzz_c)
       deallocate(sbout%ibyyzz_c, stat=istat)
       call memocc(istat, iall, 'sbout%ibyyzz_c', subname)
   end if
   if(associated(sbin%ibyyzz_c)) then
       iis1=lbound(sbin%ibyyzz_c,1)
       iie1=ubound(sbin%ibyyzz_c,1)
       iis2=lbound(sbin%ibyyzz_c,2)
       iie2=ubound(sbin%ibyyzz_c,2)
       iis3=lbound(sbin%ibyyzz_c,3)
       iie3=ubound(sbin%ibyyzz_c,3)
       allocate(sbout%ibyyzz_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, sbout%ibyyzz_c, 'sbout%ibyyzz_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   sbout%ibyyzz_c(i1,i2,i3) = sbin%ibyyzz_c(i1,i2,i3)
               end do
           end do
       end do
   end if
end if

if(associated(sbout%ibxy_ff)) then
    iall=-product(shape(sbout%ibxy_ff))*kind(sbout%ibxy_ff)
    deallocate(sbout%ibxy_ff, stat=istat)
    call memocc(istat, iall, 'sbout%ibxy_ff', subname)
end if
if(associated(sbin%ibxy_ff)) then
    iis1=lbound(sbin%ibxy_ff,1)
    iie1=ubound(sbin%ibxy_ff,1)
    iis2=lbound(sbin%ibxy_ff,2)
    iie2=ubound(sbin%ibxy_ff,2)
    iis3=lbound(sbin%ibxy_ff,3)
    iie3=ubound(sbin%ibxy_ff,3)
    allocate(sbout%ibxy_ff(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, sbout%ibxy_ff, 'sbout%ibxy_ff', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                sbout%ibxy_ff(i1,i2,i3) = sbin%ibxy_ff(i1,i2,i3)
            end do
        end do
    end do
end if


if(associated(sbout%ibzzx_f)) then
    iall=-product(shape(sbout%ibzzx_f))*kind(sbout%ibzzx_f)
    deallocate(sbout%ibzzx_f, stat=istat)
    call memocc(istat, iall, 'sbout%ibzzx_f', subname)
end if
if(associated(sbin%ibzzx_f)) then
    iis1=lbound(sbin%ibzzx_f,1)
    iie1=ubound(sbin%ibzzx_f,1)
    iis2=lbound(sbin%ibzzx_f,2)
    iie2=ubound(sbin%ibzzx_f,2)
    iis3=lbound(sbin%ibzzx_f,3)
    iie3=ubound(sbin%ibzzx_f,3)
    allocate(sbout%ibzzx_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, sbout%ibzzx_f, 'sbout%ibzzx_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                sbout%ibzzx_f(i1,i2,i3) = sbin%ibzzx_f(i1,i2,i3)
            end do
        end do
    end do
end if


if(associated(sbout%ibyyzz_f)) then
    iall=-product(shape(sbout%ibyyzz_f))*kind(sbout%ibyyzz_f)
    deallocate(sbout%ibyyzz_f, stat=istat)
    call memocc(istat, iall, 'sbout%ibyyzz_f', subname)
end if
if(associated(sbin%ibyyzz_f)) then
    iis1=lbound(sbin%ibyyzz_f,1)
    iie1=ubound(sbin%ibyyzz_f,1)
    iis2=lbound(sbin%ibyyzz_f,2)
    iie2=ubound(sbin%ibyyzz_f,2)
    iis3=lbound(sbin%ibyyzz_f,3)
    iie3=ubound(sbin%ibyyzz_f,3)
    allocate(sbout%ibyyzz_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, sbout%ibyyzz_f, 'sbout%ibyyzz_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                sbout%ibyyzz_f(i1,i2,i3) = sbin%ibyyzz_f(i1,i2,i3)
            end do
        end do
    end do
end if



end subroutine copy_shrink_bounds




subroutine copy_grow_bounds(geocode, gbin, gbout, subname)
use module_base
use module_types
implicit none

! Calling arguments
character(len=1),intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
type(grow_bounds),intent(in):: gbin
type(grow_bounds),intent(inout):: gbout
character(len=*),intent(in):: subname

! Local variables
integer:: iis1, iie1, iis2, iie2, iis3, iie3, i1, i2, i3, istat, iall

if(geocode == 'F')then
   if(associated(gbout%ibzxx_c)) then
       iall=-product(shape(gbout%ibzxx_c))*kind(gbout%ibzxx_c)
       deallocate(gbout%ibzxx_c, stat=istat)
       call memocc(istat, iall, 'gbout%ibzxx_c', subname)
   end if
   if(associated(gbin%ibzxx_c)) then
       iis1=lbound(gbin%ibzxx_c,1)
       iie1=ubound(gbin%ibzxx_c,1)
       iis2=lbound(gbin%ibzxx_c,2)
       iie2=ubound(gbin%ibzxx_c,2)
       iis3=lbound(gbin%ibzxx_c,3)
       iie3=ubound(gbin%ibzxx_c,3)
       allocate(gbout%ibzxx_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, gbout%ibzxx_c, 'gbout%ibzxx_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   gbout%ibzxx_c(i1,i2,i3) = gbin%ibzxx_c(i1,i2,i3)
               end do
           end do
       end do
   end if
       
   
   if(associated(gbout%ibxxyy_c)) then
       iall=-product(shape(gbout%ibxxyy_c))*kind(gbout%ibxxyy_c)
       deallocate(gbout%ibxxyy_c, stat=istat)
       call memocc(istat, iall, 'gbout%ibxxyy_c', subname)
   end if
   if(associated(gbin%ibxxyy_c)) then
       iis1=lbound(gbin%ibxxyy_c,1)
       iie1=ubound(gbin%ibxxyy_c,1)
       iis2=lbound(gbin%ibxxyy_c,2)
       iie2=ubound(gbin%ibxxyy_c,2)
       iis3=lbound(gbin%ibxxyy_c,3)
       iie3=ubound(gbin%ibxxyy_c,3)
       allocate(gbout%ibxxyy_c(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
       call memocc(istat, gbout%ibxxyy_c, 'gbout%ibxxyy_c', subname)
       do i3=iis3,iie3
           do i2=iis2,iie2
               do i1=iis1,iie1
                   gbout%ibxxyy_c(i1,i2,i3) = gbin%ibxxyy_c(i1,i2,i3)
               end do
           end do
       end do
   end if
end if

if(associated(gbout%ibyz_ff)) then
    iall=-product(shape(gbout%ibyz_ff))*kind(gbout%ibyz_ff)
    deallocate(gbout%ibyz_ff, stat=istat)
    call memocc(istat, iall, 'gbout%ibyz_ff', subname)
end if
if(associated(gbin%ibyz_ff)) then
    iis1=lbound(gbin%ibyz_ff,1)
    iie1=ubound(gbin%ibyz_ff,1)
    iis2=lbound(gbin%ibyz_ff,2)
    iie2=ubound(gbin%ibyz_ff,2)
    iis3=lbound(gbin%ibyz_ff,3)
    iie3=ubound(gbin%ibyz_ff,3)
    allocate(gbout%ibyz_ff(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, gbout%ibyz_ff, 'gbout%ibyz_ff', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                gbout%ibyz_ff(i1,i2,i3) = gbin%ibyz_ff(i1,i2,i3)
            end do
        end do
    end do
end if

if(associated(gbout%ibzxx_f)) then
    iall=-product(shape(gbout%ibzxx_f))*kind(gbout%ibzxx_f)
    deallocate(gbout%ibzxx_f, stat=istat)
    call memocc(istat, iall, 'gbout%ibzxx_f', subname)
end if
if(associated(gbin%ibzxx_f)) then
    iis1=lbound(gbin%ibzxx_f,1)
    iie1=ubound(gbin%ibzxx_f,1)
    iis2=lbound(gbin%ibzxx_f,2)
    iie2=ubound(gbin%ibzxx_f,2)
    iis3=lbound(gbin%ibzxx_f,3)
    iie3=ubound(gbin%ibzxx_f,3)
    allocate(gbout%ibzxx_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, gbout%ibzxx_f, 'gbout%ibzxx_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                gbout%ibzxx_f(i1,i2,i3) = gbin%ibzxx_f(i1,i2,i3)
            end do
        end do
    end do
end if


if(associated(gbout%ibxxyy_f)) then
    iall=-product(shape(gbout%ibxxyy_f))*kind(gbout%ibxxyy_f)
    deallocate(gbout%ibxxyy_f, stat=istat)
    call memocc(istat, iall, 'gbout%ibxxyy_f', subname)
end if
if(associated(gbin%ibxxyy_f)) then
    iis1=lbound(gbin%ibxxyy_f,1)
    iie1=ubound(gbin%ibxxyy_f,1)
    iis2=lbound(gbin%ibxxyy_f,2)
    iie2=ubound(gbin%ibxxyy_f,2)
    iis3=lbound(gbin%ibxxyy_f,3)
    iie3=ubound(gbin%ibxxyy_f,3)
    allocate(gbout%ibxxyy_f(iis1:iie1,iis2:iie2,iis3:iie3), stat=istat)
    call memocc(istat, gbout%ibxxyy_f, 'gbout%ibxxyy_f', subname)
    do i3=iis3,iie3
        do i2=iis2,iie2
            do i1=iis1,iie1
                gbout%ibxxyy_f(i1,i2,i3) = gbin%ibxxyy_f(i1,i2,i3)
            end do
        end do
    end do
end if


end subroutine copy_grow_bounds

subroutine copy_orbitals_data(orbsin, orbsout, subname)
use module_base
use module_types
implicit none

! Calling arguments
type(orbitals_data),intent(in):: orbsin
type(orbitals_data),intent(inout):: orbsout
character(len=*),intent(in):: subname

! Local variables
integer:: iis1, iie1, iis2, iie2, i1, i2, istat, iall

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

if(associated(orbsout%norb_par)) then
    iall=-product(shape(orbsout%norb_par))*kind(orbsout%norb_par)
    deallocate(orbsout%norb_par, stat=istat)
    call memocc(istat, iall, 'orbsout%norb_par', subname)
end if
if(associated(orbsin%norb_par)) then
    iis1=lbound(orbsin%norb_par,1)
    iie1=ubound(orbsin%norb_par,1)
    iis2=lbound(orbsin%norb_par,2)
    iie2=ubound(orbsin%norb_par,2)
    allocate(orbsout%norb_par(iis1:iie1,iis2:iie2), stat=istat)
    call memocc(istat, orbsout%norb_par, 'orbsout%norb_par', subname)
    do i1=iis1,iie1
       do i2 = iis2,iie2
        orbsout%norb_par(i1,i2) = orbsin%norb_par(i1,i2)
       end do
    end do
end if

if(associated(orbsout%iokpt)) then
    iall=-product(shape(orbsout%iokpt))*kind(orbsout%iokpt)
    deallocate(orbsout%iokpt, stat=istat)
    call memocc(istat, iall, 'orbsout%iokpt', subname)
end if
if(associated(orbsin%iokpt)) then
    iis1=lbound(orbsin%iokpt,1)
    iie1=ubound(orbsin%iokpt,1)
    allocate(orbsout%iokpt(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%iokpt, 'orbsout%iokpt', subname)
    do i1=iis1,iie1
        orbsout%iokpt(i1) = orbsin%iokpt(i1)
    end do
end if

if(associated(orbsout%ikptproc)) then
    iall=-product(shape(orbsout%ikptproc))*kind(orbsout%ikptproc)
    deallocate(orbsout%ikptproc, stat=istat)
    call memocc(istat, iall, 'orbsout%ikptproc', subname)
end if
if(associated(orbsin%ikptproc)) then
    iis1=lbound(orbsin%ikptproc,1)
    iie1=ubound(orbsin%ikptproc,1)
    allocate(orbsout%ikptproc(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%ikptproc, 'orbsout%ikptproc', subname)
    do i1=iis1,iie1
        orbsout%ikptproc(i1) = orbsin%ikptproc(i1)
    end do
end if

if(associated(orbsout%inwhichlocreg)) then
    iall=-product(shape(orbsout%inwhichlocreg))*kind(orbsout%inwhichlocreg)
    deallocate(orbsout%inwhichlocreg, stat=istat)
    call memocc(istat, iall, 'orbsout%inwhichlocreg', subname)
end if
if(associated(orbsin%inwhichlocreg)) then
    iis1=lbound(orbsin%inwhichlocreg,1)
    iie1=ubound(orbsin%inwhichlocreg,1)
    allocate(orbsout%inwhichlocreg(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%inwhichlocreg, 'orbsout%inwhichlocreg', subname)
    do i1=iis1,iie1
        orbsout%inwhichlocreg(i1) = orbsin%inwhichlocreg(i1)
    end do
end if

if(associated(orbsout%onwhichatom)) then
    iall=-product(shape(orbsout%onwhichatom))*kind(orbsout%onwhichatom)
    deallocate(orbsout%onwhichatom, stat=istat)
    call memocc(istat, iall, 'orbsout%onwhichatom', subname)
end if
if(associated(orbsin%onwhichatom)) then
    iis1=lbound(orbsin%onwhichatom,1)
    iie1=ubound(orbsin%onwhichatom,1)
    allocate(orbsout%onwhichatom(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%onwhichatom, 'orbsout%onwhichatom', subname)
    do i1=iis1,iie1
        orbsout%onwhichatom(i1) = orbsin%onwhichatom(i1)
    end do
end if

if(associated(orbsout%isorb_par)) then
    iall=-product(shape(orbsout%isorb_par))*kind(orbsout%isorb_par)
    deallocate(orbsout%isorb_par, stat=istat)
    call memocc(istat, iall, 'orbsout%isorb_par', subname)
end if
if(associated(orbsin%isorb_par)) then
    iis1=lbound(orbsin%isorb_par,1)
    iie1=ubound(orbsin%isorb_par,1)
    allocate(orbsout%isorb_par(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%isorb_par, 'orbsout%isorb_par', subname)
    do i1=iis1,iie1
        orbsout%isorb_par(i1) = orbsin%isorb_par(i1)
    end do
end if

if(associated(orbsout%eval)) then
    iall=-product(shape(orbsout%eval))*kind(orbsout%eval)
    deallocate(orbsout%eval, stat=istat)
    call memocc(istat, iall, 'orbsout%eval', subname)
end if
if(associated(orbsin%eval)) then
    iis1=lbound(orbsin%eval,1)
    iie1=ubound(orbsin%eval,1)
    if(iie1 /= iis1 ) then
       allocate(orbsout%eval(iis1:iie1), stat=istat)
       call memocc(istat, orbsout%eval, 'orbsout%eval', subname)
       do i1=iis1,iie1
           orbsout%eval(i1) = orbsin%eval(i1)
       end do
    end if
end if

if(associated(orbsout%occup)) then
    iall=-product(shape(orbsout%occup))*kind(orbsout%occup)
    deallocate(orbsout%occup, stat=istat)
    call memocc(istat, iall, 'orbsout%occup', subname)
end if
if(associated(orbsin%occup)) then
    iis1=lbound(orbsin%occup,1)
    iie1=ubound(orbsin%occup,1)
    allocate(orbsout%occup(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%occup, 'orbsout%occup', subname)
    do i1=iis1,iie1
        orbsout%occup(i1) = orbsin%occup(i1)
    end do
end if

if(associated(orbsout%spinsgn)) then
    iall=-product(shape(orbsout%spinsgn))*kind(orbsout%spinsgn)
    deallocate(orbsout%spinsgn, stat=istat)
    call memocc(istat, iall, 'orbsout%spinsgn', subname)
end if
if(associated(orbsin%spinsgn)) then
    iis1=lbound(orbsin%spinsgn,1)
    iie1=ubound(orbsin%spinsgn,1)
    allocate(orbsout%spinsgn(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%spinsgn, 'orbsout%spinsgn', subname)
    do i1=iis1,iie1
        orbsout%spinsgn(i1) = orbsin%spinsgn(i1)
    end do
end if


if(associated(orbsout%kwgts)) then
    iall=-product(shape(orbsout%kwgts))*kind(orbsout%kwgts)
    deallocate(orbsout%kwgts, stat=istat)
    call memocc(istat, iall, 'orbsout%kwgts', subname)
end if
if(associated(orbsin%kwgts)) then
    iis1=lbound(orbsin%kwgts,1)
    iie1=ubound(orbsin%kwgts,1)
    allocate(orbsout%kwgts(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%kwgts, 'orbsout%kwgts', subname)
    do i1=iis1,iie1
        orbsout%kwgts(i1) = orbsin%kwgts(i1)
    end do
end if


if(associated(orbsout%kpts)) then
    iall=-product(shape(orbsout%kpts))*kind(orbsout%kpts)
    deallocate(orbsout%kpts, stat=istat)
    call memocc(istat, iall, 'orbsout%kpts', subname)
end if
if(associated(orbsin%kpts)) then
    iis1=lbound(orbsin%kpts,1)
    iie1=ubound(orbsin%kpts,1)
    iis2=lbound(orbsin%kpts,2)
    iie2=ubound(orbsin%kpts,2)
    allocate(orbsout%kpts(iis1:iie1,iis2:iie2), stat=istat)
    call memocc(istat, orbsout%kpts, 'orbsout%kpts', subname)
    do i2=iis2,iie2
        do i1=iis1,iie1
            orbsout%kpts(i1,i2) = orbsin%kpts(i1,i2)
        end do
    end do
end if


if(associated(orbsout%ispot)) then
    iall=-product(shape(orbsout%ispot))*kind(orbsout%ispot)
    deallocate(orbsout%ispot, stat=istat)
    call memocc(istat, iall, 'orbsout%ispot', subname)
end if
if(associated(orbsin%ispot)) then
    iis1=lbound(orbsin%ispot,1)
    iie1=ubound(orbsin%ispot,1)
    allocate(orbsout%ispot(iis1:iie1), stat=istat)
    call memocc(istat, orbsout%ispot, 'orbsout%ispot', subname)
    do i1=iis1,iie1
        orbsout%ispot(i1) = orbsin%ispot(i1)
    end do
end if


end subroutine copy_orbitals_data


subroutine copy_orthon_data(odin, odout, subname)
  use module_base
  use module_types
  implicit none
  
  ! Calling aruments
  type(orthon_data),intent(in):: odin
  type(orthon_data),intent(out):: odout
  character(len=*),intent(in):: subname

  odout%directDiag=odin%directDiag
  odout%norbpInguess=odin%norbpInguess
  odout%bsLow=odin%bsLow
  odout%bsUp=odin%bsUp
  odout%methOrtho=odin%methOrtho
  odout%iguessTol=odin%iguessTol
  odout%methTransformOverlap=odin%methTransformOverlap
  odout%nItOrtho=odin%nItOrtho
  odout%blocksize_pdsyev=odin%blocksize_pdsyev
  odout%blocksize_pdgemm=odin%blocksize_pdgemm
  odout%nproc_pdsyev=odin%nproc_pdsyev

end subroutine copy_orthon_data


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




!only copying sparsity pattern here, not copying whole matrix (assuming matrices not allocated)
subroutine sparse_copy_pattern(sparseMat_in, sparseMat_out, iproc, subname)
  use module_base
  use module_types
  use sparsematrix_base, only: sparseMatrix
  implicit none

  ! Calling arguments
  type(sparseMatrix),intent(in):: sparseMat_in
  type(sparseMatrix),intent(inout):: sparseMat_out
  integer, intent(in) :: iproc
  character(len=*),intent(in):: subname

  ! Local variables
  integer:: iis1, iie1, iis2, iie2, i1, i2, istat, iall

  call timing(iproc,'sparse_copy','ON')

  sparsemat_out%nseg = sparsemat_in%nseg
  sparsemat_out%store_index = sparsemat_in%store_index
  sparsemat_out%nvctr = sparsemat_in%nvctr
  sparsemat_out%nvctrp = sparsemat_in%nvctrp
  sparsemat_out%isvctr = sparsemat_in%isvctr
  sparsemat_out%nfvctr = sparsemat_in%nfvctr
  sparsemat_out%nfvctrp = sparsemat_in%nfvctrp
  sparsemat_out%isfvctr = sparsemat_in%isfvctr
  sparsemat_out%parallel_compression = sparsemat_in%parallel_compression

  if(associated(sparsemat_out%nvctr_par)) then
     call f_free_ptr(sparsemat_out%nvctr_par)
  end if
  if(associated(sparsemat_in%nvctr_par)) then
     iis1=lbound(sparsemat_in%nvctr_par,1)
     iie1=ubound(sparsemat_in%nvctr_par,1)
     sparsemat_out%nvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%nvctr_par')
     do i1=iis1,iie1
        sparsemat_out%nvctr_par(i1) = sparsemat_in%nvctr_par(i1)
     end do
  end if
  if(associated(sparsemat_out%isvctr_par)) then
     call f_free_ptr(sparsemat_out%isvctr_par)
  end if
  if(associated(sparsemat_in%isvctr_par)) then
     iis1=lbound(sparsemat_in%isvctr_par,1)
     iie1=ubound(sparsemat_in%isvctr_par,1)
     sparsemat_out%isvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%isvctr_par')
     do i1=iis1,iie1
        sparsemat_out%isvctr_par(i1) = sparsemat_in%isvctr_par(i1)
     end do
  end if
  if(associated(sparsemat_out%nfvctr_par)) then
     call f_free_ptr(sparsemat_out%nfvctr_par)
  end if
  if(associated(sparsemat_in%nfvctr_par)) then
     iis1=lbound(sparsemat_in%nfvctr_par,1)
     iie1=ubound(sparsemat_in%nfvctr_par,1)
     sparsemat_out%nfvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%nfvctr_par')
     do i1=iis1,iie1
        sparsemat_out%nfvctr_par(i1) = sparsemat_in%nfvctr_par(i1)
     end do
  end if
  if(associated(sparsemat_out%isfvctr_par)) then
     call f_free_ptr(sparsemat_out%isfvctr_par)
  end if
  if(associated(sparsemat_in%isfvctr_par)) then
     iis1=lbound(sparsemat_in%isfvctr_par,1)
     iie1=ubound(sparsemat_in%isfvctr_par,1)
     sparsemat_out%isfvctr_par=f_malloc_ptr((/iis1.to.iie1/),id='sparsemat_out%isfvctr_par')
     do i1=iis1,iie1
        sparsemat_out%isfvctr_par(i1) = sparsemat_in%isfvctr_par(i1)
     end do
  end if

  nullify(sparsemat_out%matrix)
  nullify(sparsemat_out%matrix_compr)
  nullify(sparsemat_out%matrixp)
  nullify(sparsemat_out%matrix_comprp)

  if(associated(sparsemat_out%keyv)) then
     iall=-product(shape(sparsemat_out%keyv))*kind(sparsemat_out%keyv)
     deallocate(sparsemat_out%keyv, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%keyv', subname)
  end if
  if(associated(sparsemat_in%keyv)) then
     iis1=lbound(sparsemat_in%keyv,1)
     iie1=ubound(sparsemat_in%keyv,1)
     allocate(sparsemat_out%keyv(iis1:iie1), stat=istat)
     call memocc(istat, sparsemat_out%keyv, 'sparsemat_out%keyv', subname)
     do i1=iis1,iie1
        sparsemat_out%keyv(i1) = sparsemat_in%keyv(i1)
     end do
  end if

  if(associated(sparsemat_out%nsegline)) then
     iall=-product(shape(sparsemat_out%nsegline))*kind(sparsemat_out%nsegline)
     deallocate(sparsemat_out%nsegline, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%nsegline', subname)
  end if
  if(associated(sparsemat_in%nsegline)) then
     iis1=lbound(sparsemat_in%nsegline,1)
     iie1=ubound(sparsemat_in%nsegline,1)
     allocate(sparsemat_out%nsegline(iis1:iie1), stat=istat)
     call memocc(istat, sparsemat_out%nsegline, 'sparsemat_out%nsegline', subname)
     do i1=iis1,iie1
        sparsemat_out%nsegline(i1) = sparsemat_in%nsegline(i1)
     end do
  end if

  if(associated(sparsemat_out%istsegline)) then
     iall=-product(shape(sparsemat_out%istsegline))*kind(sparsemat_out%istsegline)
     deallocate(sparsemat_out%istsegline, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%istsegline', subname)
  end if
  if(associated(sparsemat_in%istsegline)) then
     iis1=lbound(sparsemat_in%istsegline,1)
     iie1=ubound(sparsemat_in%istsegline,1)
     allocate(sparsemat_out%istsegline(iis1:iie1), stat=istat)
     call memocc(istat, sparsemat_out%istsegline, 'sparsemat_out%istsegline', subname)
     do i1=iis1,iie1
        sparsemat_out%istsegline(i1) = sparsemat_in%istsegline(i1)
     end do
  end if

  if(associated(sparsemat_out%keyg)) then
     iall=-product(shape(sparsemat_out%keyg))*kind(sparsemat_out%keyg)
     deallocate(sparsemat_out%keyg, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%keyg', subname)
  end if
  if(associated(sparsemat_in%keyg)) then
     iis1=lbound(sparsemat_in%keyg,1)
     iie1=ubound(sparsemat_in%keyg,1)
     iis2=lbound(sparsemat_in%keyg,2)
     iie2=ubound(sparsemat_in%keyg,2)
     allocate(sparsemat_out%keyg(iis1:iie1,iis2:iie2), stat=istat)
     call memocc(istat, sparsemat_out%keyg, 'sparsemat_out%keyg', subname)
     do i1=iis1,iie1
        do i2 = iis2,iie2
           sparsemat_out%keyg(i1,i2) = sparsemat_in%keyg(i1,i2)
        end do
     end do
  end if

  if(associated(sparsemat_out%matrixindex_in_compressed_arr)) then
     iall=-product(shape(sparsemat_out%matrixindex_in_compressed_arr))*kind(sparsemat_out%matrixindex_in_compressed_arr)
     deallocate(sparsemat_out%matrixindex_in_compressed_arr, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%matrixindex_in_compressed_arr', subname)
  end if
  if(associated(sparsemat_in%matrixindex_in_compressed_arr)) then
     iis1=lbound(sparsemat_in%matrixindex_in_compressed_arr,1)
     iie1=ubound(sparsemat_in%matrixindex_in_compressed_arr,1)
     iis2=lbound(sparsemat_in%matrixindex_in_compressed_arr,2)
     iie2=ubound(sparsemat_in%matrixindex_in_compressed_arr,2)
     allocate(sparsemat_out%matrixindex_in_compressed_arr(iis1:iie1,iis2:iie2), stat=istat)
     call memocc(istat, sparsemat_out%matrixindex_in_compressed_arr, 'sparsemat_out%matrixindex_in_compressed_arr', subname)
     do i1=iis1,iie1
        do i2 = iis2,iie2
           sparsemat_out%matrixindex_in_compressed_arr(i1,i2) = sparsemat_in%matrixindex_in_compressed_arr(i1,i2)
        end do
     end do
  end if

  if(associated(sparsemat_out%orb_from_index)) then
     iall=-product(shape(sparsemat_out%orb_from_index))*kind(sparsemat_out%orb_from_index)
     deallocate(sparsemat_out%orb_from_index, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%orb_from_index', subname)
  end if
  if(associated(sparsemat_in%orb_from_index)) then
     iis1=lbound(sparsemat_in%orb_from_index,1)
     iie1=ubound(sparsemat_in%orb_from_index,1)
     iis2=lbound(sparsemat_in%orb_from_index,2)
     iie2=ubound(sparsemat_in%orb_from_index,2)
     allocate(sparsemat_out%orb_from_index(iis1:iie1,iis2:iie2), stat=istat)
     call memocc(istat, sparsemat_out%orb_from_index, 'sparsemat_out%orb_from_index', subname)
     do i1=iis1,iie1
        do i2 = iis2,iie2
           sparsemat_out%orb_from_index(i1,i2) = sparsemat_in%orb_from_index(i1,i2)
        end do
     end do
  end if

  if(associated(sparsemat_out%matrixindex_in_compressed_fortransposed)) then
     iall=-product(shape(sparsemat_out%matrixindex_in_compressed_fortransposed))*&
         &kind(sparsemat_out%matrixindex_in_compressed_fortransposed)
     deallocate(sparsemat_out%matrixindex_in_compressed_fortransposed, stat=istat)
     call memocc(istat, iall, 'sparsemat_out%matrixindex_in_compressed_fortransposed', subname)
  end if
  if(associated(sparsemat_in%matrixindex_in_compressed_fortransposed)) then
     iis1=lbound(sparsemat_in%matrixindex_in_compressed_fortransposed,1)
     iie1=ubound(sparsemat_in%matrixindex_in_compressed_fortransposed,1)
     iis2=lbound(sparsemat_in%matrixindex_in_compressed_fortransposed,2)
     iie2=ubound(sparsemat_in%matrixindex_in_compressed_fortransposed,2)
     allocate(sparsemat_out%matrixindex_in_compressed_fortransposed(iis1:iie1,iis2:iie2), stat=istat)
     call memocc(istat, sparsemat_out%matrixindex_in_compressed_fortransposed, &
         'sparsemat_out%matrixindex_in_compressed_fortransposed', subname)
     do i1=iis1,iie1
        do i2 = iis2,iie2
           sparsemat_out%matrixindex_in_compressed_fortransposed(i1,i2) = &
                sparsemat_in%matrixindex_in_compressed_fortransposed(i1,i2)
        end do
     end do
  end if

  call timing(iproc,'sparse_copy','OF')

end subroutine sparse_copy_pattern

