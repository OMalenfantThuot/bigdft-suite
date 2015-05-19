!> @file
!! Include fortran file for memcpy interfaces
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
subroutine f_memcpy_i0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  integer(kind=4) :: dest !<destination buffer address
  integer(kind=4) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n
  nd=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_i0

subroutine f_memcpy_i1(dest,src)
  implicit none
  integer, dimension(:), intent(inout) :: dest !<destination buffer
  integer, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_i1

!!$subroutine f_memcpy_il0(dest,src,n)
!!$  implicit none
!!$  integer, intent(in) :: n !<nelems
!!$  integer(kind=8) :: dest !<destination buffer address
!!$  integer(kind=8) :: src !<source buffer address
!!$  !local variables
!!$  integer :: ns,nd
!!$  ns=n
!!$  nd=n
!!$  include 'f_memcpy-base-inc.f90'
!!$end subroutine f_memcpy_il0

subroutine f_memcpy_il1(dest,src)
  implicit none
  integer(kind=8), dimension(:), intent(inout) :: dest !<destination buffer
  integer(kind=8), dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_il1

subroutine f_memcpy_i1i2(dest,src)
  implicit none
  integer, dimension(:), intent(inout) :: dest !<destination buffer
  integer, dimension(:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_i1i2

subroutine f_memcpy_i2i1(dest,src)
  implicit none
  integer, dimension(:,:), intent(inout) :: dest !<destination buffer
  integer, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_i2i1

subroutine f_memcpy_c1i1(dest,src)
  implicit none
  integer, dimension(:), intent(inout) :: dest !<destination buffer
  character, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  external :: f_atoi
  nd=size(dest)
  ns=size(src)
  !include 'f_memcpy-base-inc.f90'
  if (nd < ns) then
     call f_err_throw('Error in f_memcpy; the size of the source ('//trim(yaml_toa(ns))//&
          ') and of the destination buffer ('//trim(yaml_toa(nd))//&
          ') are not compatible',err_id=ERR_INVALID_COPY)
     return
  end if
  if (ns <=0) return
  call f_atoi(ns,src,dest)

end subroutine f_memcpy_c1i1

subroutine f_memcpy_i1c1(dest,src)
  implicit none
  character, dimension(:), intent(inout) :: dest !<destination buffer
  integer, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  external :: f_itoa
  nd=size(dest)
  ns=size(src)
  !include 'f_memcpy-base-inc.f90'
  if (nd < ns) then
     call f_err_throw('Error in f_memcpy; the size of the source ('//trim(yaml_toa(ns))//&
          ') and of the destination buffer ('//trim(yaml_toa(nd))//&
          ') are not compatible',err_id=ERR_INVALID_COPY)
     return
  end if
  if (ns <=0) return
  call f_itoa(ns,src,dest)

end subroutine f_memcpy_i1c1

subroutine f_memcpy_li0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  integer(kind=8) :: dest !<destination buffer address
  integer(kind=8) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n
  nd=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_li0


subroutine f_memcpy_d0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision :: dest !<destination buffer address
  double precision :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n
  nd=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d0


subroutine f_memcpy_d1(dest,src)
  implicit none
  double precision, dimension(:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d1

subroutine f_memcpy_d2(dest,src)
  implicit none
  double precision, dimension(:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d2

subroutine f_memcpy_d3(dest,src)
  implicit none
  double precision, dimension(:,:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d3

subroutine f_memcpy_d4(dest,src)
  implicit none
  double precision, dimension(:,:,:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:,:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d4

subroutine f_memcpy_d1d0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision :: dest !<destination buffer address
  double precision, dimension(:), intent(in) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n 
  nd=size(src) !inverted 
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d1d0

subroutine f_memcpy_d0d1(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision, dimension(:), intent(inout) :: dest !<destination buffer address
  double precision :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d0d1

subroutine f_memcpy_d0d2(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision, dimension(:,:), intent(inout) :: dest !<destination buffer address
  double precision :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d0d2

subroutine f_memcpy_d0d3(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision, dimension(:,:,:), intent(inout) :: dest !<destination buffer address
  double precision :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d0d3

subroutine f_memcpy_d3d0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision, intent(inout) :: dest !<destination buffer address
  double precision, dimension(:,:,:), intent(in) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(src)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d3d0

subroutine f_memcpy_d2d0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  double precision, intent(inout) :: dest !<destination buffer address
  double precision, dimension(:,:), intent(in) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(src)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d2d0


subroutine f_memcpy_li0li1(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  integer(kind=8), dimension(:), intent(inout) :: dest !<destination buffer address
  integer(kind=8) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_li0li1

subroutine f_memcpy_i0i1(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  integer(kind=4), dimension(:), intent(inout) :: dest !<destination buffer address
  integer(kind=4) :: src !<source buffer address
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_i0i1

subroutine f_memcpy_d1d2(dest,src)
  implicit none
  double precision, dimension(:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d1d2

subroutine f_memcpy_d2d3(dest,src)
  implicit none
  double precision, dimension(:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d2d3

subroutine f_memcpy_d3d2(dest,src)
  implicit none
  double precision, dimension(:,:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:,:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d3d2

subroutine f_memcpy_d2d1(dest,src)
  implicit none
  double precision, dimension(:,:), intent(inout) :: dest !<destination buffer
  double precision, dimension(:), intent(in) :: src !<source buffer 
  !local variables
  integer :: ns,nd
  nd=size(dest)
  ns=size(src)
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_d2d1

subroutine f_memcpy_r0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  real :: dest !<destination buffer address
  real :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n
  nd=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_r0

subroutine f_memcpy_l0(dest,src,n)
  implicit none
  integer, intent(in) :: n !<nelems
  logical :: dest !<destination buffer address
  logical :: src !<source buffer address
  !local variables
  integer :: ns,nd
  ns=n
  nd=n
  include 'f_memcpy-base-inc.f90'
end subroutine f_memcpy_l0

function f_maxdiff_i0(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer, intent(inout) :: a
  integer, intent(inout) :: b
  integer :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  ns=-1
  nd=-1
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i0

function f_maxdiff_l0(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  logical, intent(inout) :: a
  logical, intent(inout) :: b
  logical :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  ns=-1
  nd=-1
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_l0

function f_maxdiff_d0(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, intent(inout) :: a
  double precision, intent(inout) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  ns=-1
  nd=-1
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d0

function f_maxdiff_r0(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  real, intent(inout) :: a
  real, intent(inout) :: b
  real :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  ns=-1
  nd=-1
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_r0

function f_maxdiff_c1i1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  character, dimension(:), intent(in) :: a
  integer, dimension(:), intent(in) :: b
  integer :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  ns=size(a)
  nd=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_c1i1

function f_maxdiff_d2d3(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, dimension(:,:), intent(in) :: a 
  double precision, dimension(:,:,:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d2d3

function f_maxdiff_d2d1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, dimension(:,:), intent(in) :: a 
  double precision, dimension(:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d2d1

function f_maxdiff_d0d1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, intent(inout) :: a 
  double precision, dimension(:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=-1
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d0d1

function f_maxdiff_d1d2(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, dimension(:), intent(in) :: a 
  double precision, dimension(:,:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d1d2
function f_maxdiff_d2(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, dimension(:,:), intent(in) :: a 
  double precision, dimension(:,:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d2
function f_maxdiff_d1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  double precision, dimension(:), intent(in) :: a 
  double precision, dimension(:), intent(in) :: b
  double precision :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_d1

function f_maxdiff_i2i1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer, dimension(:,:), intent(in) :: a 
  integer, dimension(:), intent(in) :: b
  integer :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i2i1
function f_maxdiff_i2(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer, dimension(:,:), intent(in) :: a 
  integer, dimension(:,:), intent(in) :: b
  integer :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i2
function f_maxdiff_i1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer, dimension(:), intent(in) :: a 
  integer, dimension(:), intent(in) :: b
  integer :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i1
function f_maxdiff_i1i2(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer(kind=4), dimension(:), intent(in) :: a 
  integer(kind=4), dimension(:,:), intent(in) :: b
  integer(kind=4) :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=size(a)
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i1i2

function f_maxdiff_li0li1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer(kind=8), intent(inout) :: a 
  integer(kind=8), dimension(:), intent(in) :: b
  integer(kind=8) :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=-1
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_li0li1

function f_maxdiff_i0i1(a,b,n) result(maxdiff)
  use f_utils, only: f_diff
  implicit none
  integer(kind=4), intent(inout) :: a 
  integer(kind=4), dimension(:), intent(in) :: b
  integer(kind=4) :: maxdiff
  integer, intent(in), optional :: n
  !local variables
  integer :: ns,nd,cnt
  nd=-1
  ns=size(b)
  include 'f_maxdiff-base-inc.f90'
end function f_maxdiff_i0i1