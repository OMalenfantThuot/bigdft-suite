!> @file
!! Include file used in yaml_output.f90.
!! Body of the yaml_map template for matrices.
!! yaml: Yet Another Markup Language (ML for Human)
!! @author
!!    Copyright (C) 2013-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
  character(len=*), intent(in) :: mapname
  character(len=*), optional, intent(in) :: label,advance,fmt
  integer, optional, intent(in) :: unit
  !local variables
  integer :: strm,unt,irow
  character(len=3) :: adv
  character(len=tot_max_record_length) :: towrite

  unt=0
  if (present(unit)) unt=unit
  call get_stream(unt,strm)

  adv='def' !default value
  if (present(advance)) adv=advance

  !open the sequence associated to the matrix
  if (present(label)) then
     call yaml_open_sequence(mapname,label=label,advance=adv,unit=unt)
  else
     call yaml_open_sequence(mapname,advance=adv,unit=unt)
  end if
  do irow=1,size(mapvalue,2)
     if (present(fmt)) then
        call yaml_sequence(trim(yaml_toa(mapvalue(:,irow),fmt=fmt)),&
             advance=adv,unit=unt)
     else
        call yaml_sequence(trim(yaml_toa(mapvalue(:,irow))),&
             advance=adv,unit=unt)
     end if
  end do

  call yaml_close_sequence(advance=adv,unit=unt)
