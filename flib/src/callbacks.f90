!> @file
!! Contains defintion of callback mechanisms for BigDFT
!! @ingroup flib
!! @author Luigi Genovese
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> @brief Module interfacing the callback to different functions
!! @details Should be used in the error handling module
!! The user of this module is able to define the stopping routine, the new error and the error codes
module exception_callbacks

  implicit none
  private

  !address of the generic callback functions, valid for errors with non-specific callbacks
  integer(kind=8) :: callback_add=0
  integer(kind=8) :: callback_data_add=0
  !address of the overrided severe error
  integer(kind=8) :: severe_callback_add=0

  integer(kind=8), external :: f_loc

  interface f_err_set_callback
     module procedure err_set_callback_simple,err_set_callback_advanced
  end interface

  !internal variables not meant to be exported outside
  public :: callback_add,callback_data_add,severe_callback_add,err_abort

  public :: f_err_set_callback,f_err_unset_callback
  public :: f_err_severe,f_err_severe_override,f_err_severe_restore,f_err_ignore
  
  ! public :: f_loc

contains

  !subroutine which defines the way the system stops
  subroutine err_abort(callback,callback_data)
    !use metadata_interfaces
    implicit none
    integer(kind=8), intent(in) :: callback,callback_data

    if (callback_data /=0 .and. callback /=0) then
       call call_external_c_fromadd(callback) !for the moment data are ignored
    else if (callback /=0) then
       call call_external_c_fromadd(callback)
    else
       call f_err_severe()
    end if
  end subroutine err_abort

  !> Defines the error routine which have to be used
  subroutine err_set_callback_simple(callback)
    implicit none
    external :: callback

    callback_add=f_loc(callback)
    callback_data_add=0

  end subroutine err_set_callback_simple

  subroutine err_set_callback_advanced(callback,callback_data_address)
    implicit none
    integer(kind=8), intent(in) :: callback_data_address
    external :: callback

    callback_add=f_loc(callback)
    callback_data_add=callback_data_address

  end subroutine err_set_callback_advanced

  subroutine f_err_unset_callback()
    implicit none

    callback_add=0
    callback_data_add=0
  end subroutine f_err_unset_callback

  subroutine f_err_severe_override(callback)
    implicit none
    external :: callback

    severe_callback_add=f_loc(callback)
  end subroutine f_err_severe_override

  subroutine f_err_severe_restore()
    implicit none
    severe_callback_add=0
  end subroutine f_err_severe_restore

  !>wrapper to ignore errors, do not dump
  subroutine f_err_ignore()
    implicit none
  end subroutine f_err_ignore

  !>wrapper for severe errors, the can be desactivated
  subroutine f_err_severe()
    implicit none
    if (severe_callback_add == 0) then
       call f_err_severe_internal()
    else
       call call_external_c_fromadd(severe_callback_add)
    end if
  end subroutine f_err_severe

  !> Callback routine for severe errors
  subroutine f_err_severe_internal()
    implicit none
    call f_dump_last_error()
    stop 'Severe error, cannot proceed'
  end subroutine f_err_severe_internal
  

end module exception_callbacks
