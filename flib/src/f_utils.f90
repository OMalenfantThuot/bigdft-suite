!> @file
!! Manage different low-level operations
!! like operations on external files and basic operations in memory
!! @author
!!    Copyright (C) 2012-2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Manage low-level operations (external files and basic memory operations)
module f_utils
  use dictionaries, only: f_err_throw,f_err_define, &
       & dictionary, dict_len, dict_iter, dict_next, dict_value, max_field_length
  use yaml_strings, only: yaml_toa,operator(.eqv.)
  implicit none

  private

  integer, private, save :: INPUT_OUTPUT_ERROR

  integer, public, save :: TCAT_INIT_TO_ZERO

  !preprocessed include file with processor-specific values
  include 'f_utils.inc' !defines recl_kind

  !> This type can be used to get strings from a file or a dictionary long string.
  type, public :: io_stream
     integer :: iunit = 0
     type(dictionary), pointer :: lstring => null()
  end type io_stream

  !> enumerator type, useful to define different modes
  type, public :: f_enumerator
     character(len=64) :: name
     integer :: id
  end type f_enumerator

  integer, parameter, private :: NULL_INT=-1024
  character(len=*), parameter, private :: null_name='nullified enumerator'

  type(f_enumerator), parameter, private :: &
       f_enum_null=f_enumerator(null_name,NULL_INT)

  !>interface for difference between two intrinsic types
  interface f_diff
     module procedure f_diff_i,f_diff_r,f_diff_d,f_diff_li,f_diff_l
     module procedure f_diff_d2d3,f_diff_d2d1,f_diff_d1d2,f_diff_d2,f_diff_d1
     module procedure f_diff_i2i1,f_diff_i1,f_diff_i2,f_diff_i1i2
     module procedure f_diff_li2li1,f_diff_li1,f_diff_li2,f_diff_li1li2
     module procedure f_diff_d0d1,f_diff_i0i1
     module procedure f_diff_c1i1,f_diff_li0li1
  end interface f_diff

  !> Initialize to zero an array (should be called f_memset)
  interface f_zero
     module procedure zero_string
     module procedure put_to_zero_simple
     module procedure put_to_zero_double, put_to_zero_double_1, put_to_zero_double_2
     module procedure put_to_zero_double_3, put_to_zero_double_4, put_to_zero_double_5
     module procedure put_to_zero_double_6, put_to_zero_double_7
     module procedure put_to_zero_integer,put_to_zero_integer1,put_to_zero_integer2
     module procedure put_to_zero_integer3
  end interface f_zero

  !to be verified if clock_gettime is without side-effect, otherwise the routine cannot be pure
  interface
     pure subroutine nanosec(itime)
       implicit none
       integer(kind=8), intent(out) :: itime
     end subroutine nanosec
  end interface

  interface operator(==)
     module procedure enum_is_int,enum_is_enum
  end interface operator(==)

  interface int
     module procedure int_enum
  end interface int

  interface char
     module procedure char_enum
  end interface char

  public :: f_diff,int,char,f_enumerator_null,operator(==),f_file_unit
  public :: f_utils_errors,f_utils_recl,f_file_exists,f_close,f_zero
  public :: f_get_free_unit,f_delete_file,f_getpid,f_rewind
  public :: f_iostream_from_file,f_iostream_from_lstring
  public :: f_iostream_get_line,f_iostream_release,f_time,f_pause

contains

  pure function f_enumerator_null() result(en)
    implicit none
    type(f_enumerator) :: en
    en=f_enum_null
  end function f_enumerator_null

  elemental pure function enum_is_enum(en,en1) result(ok)
    implicit none
    type(f_enumerator), intent(in) :: en
    type(f_enumerator), intent(in) :: en1
    logical :: ok
    ok = en == en1%id
  end function enum_is_enum

  elemental pure function enum_is_int(en,int) result(ok)
    implicit none
    type(f_enumerator), intent(in) :: en
    integer, intent(in) :: int
    logical :: ok
    ok = en%id == int
  end function enum_is_int

  elemental pure function enum_is_char(en,char) result(ok)
    implicit none
    type(f_enumerator), intent(in) :: en
    character(len=*), intent(in) :: char
    logical :: ok
    ok = trim(en%name) .eqv. trim(char)
  end function enum_is_char

  !>integer of f_enumerator type.
  elemental pure function int_enum(en)
    type(f_enumerator), intent(in) :: en
    integer :: int_enum
    int_enum=en%id
  end function int_enum

  !>char of f_enumerator type.
  elemental pure function char_enum(en)
    type(f_enumerator), intent(in) :: en
    character(len=len(en%name)) :: char_enum
    char_enum=en%name
  end function char_enum
  
  subroutine f_utils_errors()

    call f_err_define('INPUT_OUTPUT_ERROR',&
         'Some of intrinsic I/O fortan routines returned an error code',&
         INPUT_OUTPUT_ERROR,&
         err_action='Check if you have correct file system permission in i/o library or check the fortan runtime library')

  end subroutine f_utils_errors

  pure function f_time()
    integer(kind=8) :: f_time
    !local variables
    integer(kind=8) :: itime
    call nanosec(itime)
    f_time=itime
  end function f_time

  !>enter in a infinite loop for sec seconds. Use cpu_time as granularity is enough
  subroutine f_pause(sec,verbose)
    implicit none
    integer, intent(in) :: sec !< seconds to be waited
    logical, intent(in), optional :: verbose !<for debugging purposes, do not eliminate
    !local variables
    logical :: verb
    integer(kind=8) :: t0,t1
    integer :: count

    verb=.false.
    if (present(verbose)) verb=verbose

    if (sec <=0) return
    t0=f_time()
    t1=t0
    !this loop has to be modified to avoid the compiler to perform too agressive optimisations
    count=0
    do while(real(t1-t0,kind=8)*1.d-9 < real(sec,kind=8))
       count=count+1
       t1=f_time()
    end do
    !this output is needed to avoid the compiler to perform too agressive optimizations
    !therefore having a infinie loop
    if (verb) print *,'Paused for '//trim(yaml_toa(sec))//' seconds, counting:'//&
         trim(yaml_toa(count))
  end subroutine f_pause

  !> gives the maximum record length allowed for a given unit
  subroutine f_utils_recl(unt,recl_max,recl)
    implicit none
    integer, intent(in) :: unt !< unit to be checked for record length
    integer, intent(in) :: recl_max !< maximum value for record length
    !> Value for the record length. This corresponds to the minimum between recl_max and the processor-dependent value
    !! provided by inquire statement
    integer, intent(out) :: recl 
    !local variables
    logical :: unit_is_open
    integer :: ierr,ierr_recl
    integer(kind=recl_kind) :: recl_file

    !in case of any error, the value is set to recl_max
    recl=recl_max
    ierr_recl=-1
    !initialize the value of recl_file
    recl_file=int(-1234567891,kind=recl_kind)
    inquire(unit=unt,opened=unit_is_open,iostat=ierr)
    if (ierr == 0 .and. .not. unit_is_open) then
       !inquire the record length for the unit
       inquire(unit=unt,recl=recl_file,iostat=ierr_recl)
    end if
    if (ierr_recl == 0) then
       recl=int(min(int(recl_max,kind=recl_kind),recl_file))
    end if
    if (recl <=0) recl=recl_max
  end subroutine f_utils_recl

  !> inquire for the existence of a file
  subroutine f_file_exists(file,exists)
    implicit none
    character(len=*), intent(in) :: file
    logical, intent(out) :: exists
    !local variables
    integer :: ierr 

    exists=.false.
    inquire(file=trim(file),exist=exists,iostat=ierr)
    if (ierr /=0) then
       call f_err_throw('Error in inquiring file='//&
         trim(file)//', iostat='//trim(yaml_toa(ierr)),&
         err_id=INPUT_OUTPUT_ERROR)
    end if
    exists = exists .and. ierr==0

  end subroutine f_file_exists

  !> call the close statement and retrieve the error
  !! do not close the file if the unit is not connected
  subroutine f_close(unit)
    implicit none
    integer, intent(in) :: unit
    !local variables
    integer :: ierr

    if (unit > 0) then
       close(unit,iostat=ierr)
       if (ierr /= 0) call f_err_throw('Error in closing unit='//&
               trim(yaml_toa(unit))//', iostat='//trim(yaml_toa(ierr)),&
               err_id=INPUT_OUTPUT_ERROR)
    end if
  end subroutine f_close

  !>search the unit associated to a filename.
  !! the unit is -1 if the file does not exists or if the file is
  !! not connected
  subroutine f_file_unit(file,unit)
    implicit none
    character(len=*), intent(in) :: file
    integer, intent(out) :: unit
    !local variables
    logical ::  exists
    integer :: unt,ierr

    unit=-1
    call f_file_exists(file,exists)
    if (exists) then
       inquire(file=trim(file),number=unt,iostat=ierr)
       if (ierr /= 0) then
          call f_err_throw('Error in inquiring file='//&
               trim(file)//' for number, iostat='//trim(yaml_toa(ierr)),&
               err_id=INPUT_OUTPUT_ERROR)
       else
          unit=unt
       end if
    end if
  end subroutine f_file_unit

  !>get a unit which is not opened at present
  !! start the search from the unit
  function f_get_free_unit(unit) result(unt2)
    implicit none
    !> putative free unit. Starts to search from this value
    integer, intent(in), optional :: unit
    integer :: unt2
    !local variables
    logical :: unit_is_open
    integer :: unt,ierr

    unit_is_open=.true.
    unt=7
    if (present(unit)) unt=unit
    do while(unit_is_open)
       unt=unt+1
       inquire(unit=unt,opened=unit_is_open,iostat=ierr)
       if (ierr /=0) then
          call f_err_throw('Error in inquiring unit='//&
               trim(yaml_toa(unt))//', iostat='//trim(yaml_toa(ierr)),&
               err_id=INPUT_OUTPUT_ERROR)
          exit
       end if
    end do
    unt2=unt
  end function f_get_free_unit

  !> delete an existing file. If the file does not exists, it does nothing
  subroutine f_delete_file(file)
    implicit none
    character(len=*), intent(in) :: file
    !local variables
    logical :: exists
    integer :: ierr
    external :: delete

    call f_file_exists(trim(file),exists)
    if (exists) then
       !c-function in utils.c
       call delete(trim(file),len_trim(file),ierr)
       if (ierr /=0) call f_err_throw('Error in deleting file='//&
            trim(file)//'iostat='//trim(yaml_toa(ierr)),&
            err_id=INPUT_OUTPUT_ERROR)
    end if
    
  end subroutine f_delete_file

  !> get process id
  function f_getpid()
    implicit none
    integer :: f_getpid
    !local variables
    integer :: pid
    external :: getprocid

    call getprocid(pid)
    f_getpid=pid

  end function f_getpid

  !> rewind a unit
  subroutine f_rewind(unit)
    implicit none
    integer, intent(in) :: unit
    !local variables
    integer :: ierr

    rewind(unit,iostat=ierr)
    if (ierr /=0) call f_err_throw('Error in rewind unit='//&
         trim(yaml_toa(unit))//'iostat='//trim(yaml_toa(ierr)),&
         err_id=INPUT_OUTPUT_ERROR)
    
  end subroutine f_rewind

  subroutine f_iostream_from_file(ios, filename)
    implicit none
    type(io_stream), intent(out) :: ios
    character(len = *), intent(in) :: filename
    !Local variables
    integer :: ierror

    ios%iunit=f_get_free_unit(742)
    open(unit=ios%iunit,file=trim(filename),status='old',iostat=ierror)
    !Check the open statement
    if (ierror /= 0) call f_err_throw('Error in opening file='//&
         trim(filename)//' iostat='//trim(yaml_toa(ierror)),&
         err_id=INPUT_OUTPUT_ERROR)
    nullify(ios%lstring)
  end subroutine f_iostream_from_file

  subroutine f_iostream_from_lstring(ios, dict)
    implicit none
    type(io_stream), intent(out) :: ios
    type(dictionary), pointer :: dict

    ios%iunit = 0
    if (dict_len(dict) < 0) call f_err_throw('Error dict is not a long string',&
         err_id=INPUT_OUTPUT_ERROR)
    ios%lstring => dict
  end subroutine f_iostream_from_lstring

  subroutine f_iostream_get_line(ios, line, eof)
    implicit none
    !Arguments
    type(io_stream), intent(inout) :: ios
    character(len=max_field_length), intent(out) :: line
    logical, optional, intent(out) :: eof
    !Local variables
    integer :: i_stat
    character(len=8) :: fmt

    if (ios%iunit > 0) then
       write(fmt, "(A,I0,A)") "(A", max_field_length, ")"
       if (present(eof)) then
          read(ios%iunit, trim(fmt), iostat = i_stat) line
       else
          read(ios%iunit, trim(fmt)) line
          i_stat = 0
       end if
       if (i_stat /= 0) then
          close(ios%iunit)
          ios%iunit = 0
       end if
       if (present(eof)) eof = (i_stat /= 0)
    else if (associated(ios%lstring)) then
       if (dict_len(ios%lstring) > 0) ios%lstring => dict_iter(ios%lstring)
       line = dict_value(ios%lstring)
       ios%lstring => dict_next(ios%lstring)
       if (present(eof)) eof = .not. associated(ios%lstring)
    else if (present(eof)) then
       eof = .true.
    end if
  end subroutine f_iostream_get_line

  subroutine f_iostream_release(ios)
    implicit none
    type(io_stream), intent(inout) :: ios

    if (ios%iunit > 0) close(ios%iunit)
    ios%iunit = 0
    nullify(ios%lstring)
  end subroutine f_iostream_release

  !>perform a difference of two objects (of similar kind)
  subroutine f_diff_i(n,a_add,b_add,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), intent(inout) :: a_add
    integer(kind=4), intent(inout) :: b_add
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a_add,b_add,diff)
  end subroutine f_diff_i
  subroutine f_diff_i2i1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), dimension(:,:),   intent(in) :: a
    integer(kind=4), dimension(:), intent(in) :: b
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a(1,1),b(1),diff)
  end subroutine f_diff_i2i1
  subroutine f_diff_i2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), dimension(:,:),   intent(in) :: a
    integer(kind=4), dimension(:,:), intent(in) :: b
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a(1,1),b(1,1),diff)
  end subroutine f_diff_i2
  subroutine f_diff_i1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), dimension(:),   intent(in) :: a
    integer(kind=4), dimension(:), intent(in) :: b
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a(1),b(1),diff)
  end subroutine f_diff_i1
  subroutine f_diff_i1i2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), dimension(:),   intent(in) :: a
    integer(kind=4), dimension(:,:), intent(in) :: b
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a(1),b(1,1),diff)
  end subroutine f_diff_i1i2


  subroutine f_diff_li(n,a_add,b_add,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), intent(inout) :: a_add
    integer(kind=8), intent(inout) :: b_add
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a_add,b_add,diff)
  end subroutine f_diff_li
  subroutine f_diff_li2li1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), dimension(:,:),   intent(in) :: a
    integer(kind=8), dimension(:), intent(in) :: b
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a(1,1),b(1),diff)
  end subroutine f_diff_li2li1
  subroutine f_diff_li2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), dimension(:,:),   intent(in) :: a
    integer(kind=8), dimension(:,:), intent(in) :: b
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a(1,1),b(1,1),diff)
  end subroutine f_diff_li2
  subroutine f_diff_li1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), dimension(:),   intent(in) :: a
    integer(kind=8), dimension(:), intent(in) :: b
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a(1),b(1),diff)
  end subroutine f_diff_li1
  subroutine f_diff_li1li2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), dimension(:),   intent(in) :: a
    integer(kind=8), dimension(:,:), intent(in) :: b
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a(1),b(1,1),diff)
  end subroutine f_diff_li1li2


  subroutine f_diff_r(n,a_add,b_add,diff)
    implicit none
    integer, intent(in) :: n
    real, intent(inout) :: a_add
    real, intent(inout) :: b_add
    real, intent(out) :: diff
    external :: diff_r
    call diff_r(n,a_add,b_add,diff)
  end subroutine f_diff_r

  subroutine f_diff_d(n,a_add,b_add,diff)
    implicit none
    integer, intent(in) :: n
    double precision, intent(inout) :: a_add
    double precision, intent(inout) :: b_add
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a_add,b_add,diff)
  end subroutine f_diff_d
  subroutine f_diff_d1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, dimension(:),   intent(in) :: a
    double precision, dimension(:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a(1),b(1),diff)
  end subroutine f_diff_d1
  subroutine f_diff_d2d3(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, dimension(:,:),   intent(in) :: a
    double precision, dimension(:,:,:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a(1,1),b(1,1,1),diff)
  end subroutine f_diff_d2d3
  subroutine f_diff_d2d1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, dimension(:,:),   intent(in) :: a
    double precision, dimension(:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a(1,1),b(1),diff)
  end subroutine f_diff_d2d1
  subroutine f_diff_d0d1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, intent(inout) :: a
    double precision, dimension(:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a,b(1),diff)
  end subroutine f_diff_d0d1

  subroutine f_diff_d2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, dimension(:,:),   intent(in) :: a
    double precision, dimension(:,:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a(1,1),b(1,1),diff)
  end subroutine f_diff_d2
  subroutine f_diff_d1d2(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    double precision, dimension(:),   intent(in) :: a
    double precision, dimension(:,:), intent(in) :: b
    double precision, intent(out) :: diff
    external :: diff_d
    call diff_d(n,a(1),b(1,1),diff)
  end subroutine f_diff_d1d2


  subroutine f_diff_l(n,a_add,b_add,diff)
    implicit none
    integer, intent(in) :: n
    logical, intent(inout) :: a_add
    logical, intent(inout) :: b_add
    logical, intent(out) :: diff
    external :: diff_l
    call diff_l(n,a_add,b_add,diff)
  end subroutine f_diff_l

  subroutine f_diff_c1i1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    character, dimension(:),   intent(in) :: a
    integer, dimension(:), intent(in) :: b
    integer, intent(out) :: diff
    external :: diff_ci
    call diff_ci(n,a(1),b(1),diff)
  end subroutine f_diff_c1i1

  subroutine f_diff_li0li1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=8), intent(inout) :: a
    integer(kind=8), dimension(:), intent(in) :: b
    integer(kind=8), intent(out) :: diff
    external :: diff_li
    call diff_li(n,a,b(1),diff)
  end subroutine f_diff_li0li1

  subroutine f_diff_i0i1(n,a,b,diff)
    implicit none
    integer, intent(in) :: n
    integer(kind=4), intent(inout) :: a
    integer(kind=4), dimension(:), intent(in) :: b
    integer(kind=4), intent(out) :: diff
    external :: diff_i
    call diff_i(n,a,b(1),diff)
  end subroutine f_diff_i0i1

  subroutine zero_string(str)
    use yaml_strings, only: f_strcpy
    implicit none
    character(len=*), intent(out) :: str
    call f_strcpy(src=' ',dest=str)
  end subroutine zero_string

  subroutine put_to_zero_simple(n,da)
    implicit none
    integer, intent(in) :: n
    real, intent(out) :: da

    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero_simple(n,da)
    call f_timer_resume()
  end subroutine put_to_zero_simple

  subroutine put_to_zero_double(n,da)
    implicit none
    integer, intent(in) :: n
    double precision, intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero(n,da)
    call f_timer_resume()
  end subroutine put_to_zero_double

  subroutine put_to_zero_double_1(da)
    implicit none
    double precision, dimension(:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero(size(da),da)
    call f_timer_resume()
  end subroutine put_to_zero_double_1

  subroutine put_to_zero_double_2(da)
    implicit none
    double precision, dimension(:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero(size(da),da)
    call f_timer_resume()
  end subroutine put_to_zero_double_2

  subroutine put_to_zero_double_3(da)
    implicit none
    double precision, dimension(:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO) 
    call razero(size(da),da)
    call f_timer_resume() 
  end subroutine put_to_zero_double_3

  subroutine put_to_zero_double_4(da)
    implicit none
    double precision, dimension(:,:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO) 
    call razero(size(da),da)
    call f_timer_resume() 
  end subroutine put_to_zero_double_4

  subroutine put_to_zero_double_5(da)
    implicit none
    double precision, dimension(:,:,:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO) 
    call razero(size(da),da)
    call f_timer_resume() 
  end subroutine put_to_zero_double_5

  subroutine put_to_zero_double_6(da)
    implicit none
    double precision, dimension(:,:,:,:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO) 
    call razero(size(da),da)
    call f_timer_resume() 
  end subroutine put_to_zero_double_6

  subroutine put_to_zero_double_7(da)
    implicit none
    double precision, dimension(:,:,:,:,:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO) 
    call razero(size(da),da)
    call f_timer_resume() 
  end subroutine put_to_zero_double_7

  subroutine put_to_zero_integer(n,da)
    implicit none
    integer, intent(in) :: n
    integer, intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero_integer(n,da)
    call f_timer_resume()
  end subroutine put_to_zero_integer

  subroutine put_to_zero_integer1(da)
    implicit none
    integer, dimension(:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero_integer(size(da),da)
    call f_timer_resume()
  end subroutine put_to_zero_integer1
  subroutine put_to_zero_integer2(da)
    implicit none
    integer, dimension(:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero_integer(size(da),da)
    call f_timer_resume()
  end subroutine put_to_zero_integer2
  subroutine put_to_zero_integer3(da)
    implicit none
    integer, dimension(:,:,:), intent(out) :: da
    call f_timer_interrupt(TCAT_INIT_TO_ZERO)
    call razero_integer(size(da),da)
    call f_timer_resume()
  end subroutine put_to_zero_integer3

  
end module f_utils
