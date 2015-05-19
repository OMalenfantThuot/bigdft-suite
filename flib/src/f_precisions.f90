!> @file
!! Define precisions in portable format for future usage
!! @author
!!    Copyright (C) 2014-2015 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
module f_precisions
  implicit none

  public

  !for reals and complex
  integer, parameter :: simple = selected_real_kind(6, 37)
  integer, parameter :: double = selected_real_kind(15, 307)
  integer, parameter :: quadruple = selected_real_kind(33, 4931)

  !for integers to be verified
  integer, parameter :: short=selected_int_kind(4)
  integer, parameter :: four=selected_int_kind(8)
  integer, parameter :: long=selected_int_kind(16)

  !logicals to be done also, and tested against bits and bytes with f_loc
  !integer, parameter :: bit=0 !not supported
  integer, parameter :: byte=1
  
end module f_precisions