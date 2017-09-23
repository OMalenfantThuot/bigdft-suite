!> @file
!! Wrapper for remote memory access
!! @author
!!    Copyright (C) 2012-2016 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
module f_onesided
  use time_profiling, only: TIMING_UNINITIALIZED
  use fmpi_types
  use dictionaries
  use f_precisions
  use f_enums
  implicit none

  private

  interface fmpi_win_create
    module procedure mpiwindow_d0!, mpiwindow_i0, mpiwindow_long0, mpiwindow_l0
 end interface fmpi_win_create

  interface fmpi_get
     module procedure fmpi_get_d0
  end interface fmpi_get

  interface mpiput
     module procedure mpiput_d0
  end interface mpiput

  interface mpiaccumulate
     module procedure mpiaccumulate_d0
  end interface mpiaccumulate

  interface assignment(=)
     module procedure win_allocate_w1,win_allocate_w2
     module procedure win_allocate_w1_ptr
  end interface assignment(=)

  interface free_fmpi_win_arr
     module procedure free_fmpi_win_arr,free_fmpi_win_arr2
  end interface free_fmpi_win_arr

  type, public :: fmpi_info
     integer(fmpi_integer) :: handle=FMPI_INFO_NULL
     type(dictionary), pointer :: dict=>null()
  end type fmpi_info

  type, public :: fmpi_win
     integer(fmpi_integer) :: handle=FMPI_WIN_NULL !< handle of the MPI_WINDOW as returned by MPI call
     integer(fmpi_integer) :: disp_unit=0
     integer(fmpi_address) :: size=0
     integer(fmpi_address) :: comm=FMPI_COMM_NULL
     type(dictionary), pointer :: dict_info=>null() !<copy of the information passed to the window
  end type fmpi_win

  integer, parameter :: FMPI_OPEN=100
  integer, parameter :: FMPI_CLOSE=101
  integer, parameter :: FMPI_START_READ=102
  integer, parameter :: FMPI_END_READ=103
  integer, parameter :: FMPI_START_WRITE=104
  integer, parameter :: FMPI_END_WRITE=105
  
  type(f_enumerator), public :: FMPI_WIN_OPEN =f_enumerator('WIN_OPEN',FMPI_OPEN,null())
  type(f_enumerator), public :: FMPI_WIN_CLOSE =f_enumerator('WIN_CLOSE',FMPI_CLOSE,null())

  !>Timing categories
  integer, public, save :: TCAT_FENCE        = TIMING_UNINITIALIZED

  public :: fmpi_win_create,fmpi_win_fence,fmpi_win_free,fmpi_get,free_fmpi_win_ptr
  public :: free_fmpi_win_arr
  public :: assignment(=)

  contains

    subroutine fmpi_info_create(info)
      implicit none
      type(fmpi_info), intent(out) :: info
      !local variables
      integer(fmpi_integer) :: ierr
      nullify(info%dict)
      call mpi_info_create(info%handle, ierr)

      if (ierr /= FMPI_SUCCESS) then
         call f_err_throw('Error in mpi_info_create',&
              err_id=ERR_MPI_WRAPPERS)
      end if
      call dict_init(info%dict)

    end subroutine fmpi_info_create

    subroutine fmpi_info_set(info,dict)
      implicit none
      type(fmpi_info), intent(inout) :: info
      type(dictionary), pointer :: dict
      !local variables
      integer(fmpi_integer) :: ierr
      type(dictionary), pointer :: iter

      if (.not. associated(info%dict)) &
           call f_err_throw('Error in mpi_info_set, window not created',&
           err_id=ERR_MPI_WRAPPERS)

      do while(iterating(iter,on=dict))
         call mpi_info_set(info%handle,trim(dict_key(iter)),trim(dict_value(iter)), ierr)
         if (ierr/=FMPI_SUCCESS) then
            call f_err_throw('Error in mpi_info_set, key='//trim(dict_key(iter))//&
                 ', value='//trim(dict_value(iter)),err_id=ERR_MPI_WRAPPERS)
         end if
      end do
      call dict_update(src=dict,dest=info%dict)
    end subroutine fmpi_info_set

    subroutine fmpi_info_free(info)
      implicit none
      type(fmpi_info), intent(inout) :: info
      !local variables
      integer(fmpi_integer) :: ierr

      call dict_free(info%dict)
      call mpi_info_free(info%handle, ierr)
      if (ierr/= FMPI_SUCCESS) then
         call f_err_throw('Error in mpi_info_free',&
              err_id=ERR_MPI_WRAPPERS)
      end if
      info%handle=FMPI_INFO_NULL
    end subroutine fmpi_info_free

    subroutine mpiwindow_d0(win,base,size,comm,dict_info,info)
      implicit none
      real(f_double) :: base
      integer(f_long),intent(in) :: size
      integer(fmpi_integer),intent(in), optional :: comm
      type(dictionary), pointer, optional :: dict_info
      type(fmpi_info), intent(in), optional :: info
      type(fmpi_win) :: win
      !local variables
      integer(fmpi_integer) :: ierr,infohandle
      type(fmpi_info) :: info_

      infohandle=FMPI_INFO_NULL
      if (present(dict_info)) then
         call fmpi_info_create(info_)
         call fmpi_info_set(info_,dict_info)
         infohandle=info_%handle
      end if

      if (present(info)) then
         infohandle=info%handle
      end if

      !info=mpiinfo("no_locks", "true")

      win%disp_unit=mpitypesize(base)
      win%size=int(size,fmpi_address)
      win%comm=fmpi_comm(comm)
      call mpi_win_create(base, win%size*win%disp_unit, &
           win%disp_unit, infohandle,win%comm,win%handle, ierr)

      if (ierr/=FMPI_SUCCESS) then
         call f_err_throw('Error in mpi_win_create',&
              err_id=ERR_MPI_WRAPPERS)
      end if

      if (present(dict_info)) then
         call fmpi_info_free(info_)
      end if
      !call mpiinfofree(info)

!!$      call mpi_win_fence(MPI_MODE_NOPRECEDE, window, ierr)
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_fence',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if


    end subroutine mpiwindow_d0
    
!!$    function mpiwindow_i0(size,base,comm) result(window)
!!$      use dictionaries, only: f_err_throw,f_err_define
!!$      implicit none
!!$      integer,intent(in) :: size
!!$      integer,intent(in) :: base
!!$      integer,intent(in) :: comm
!!$      !local variables
!!$      integer :: sizeof,info,ierr
!!$      integer :: window
!!$
!!$      sizeof=mpitypesize(base)
!!$      info=mpiinfo("no_locks", "true")
!!$
!!$      call mpi_win_create(base, int(size,kind=mpi_address_kind)*int(sizeof,kind=mpi_address_kind), &
!!$           sizeof, info,comm, window, ierr)
!!$
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_create',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$      call mpiinfofree(info)
!!$
!!$      call mpi_win_fence(FMPI_MODE_NOPRECEDE, window, ierr)
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_fence',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$
!!$    end function mpiwindow_i0
!!$
!!$    function mpiwindow_long0(size,base,comm) result(window)
!!$      use dictionaries, only: f_err_throw,f_err_define
!!$      implicit none
!!$      integer,intent(in) :: size
!!$      integer(f_long),intent(in) :: base
!!$      integer,intent(in) :: comm
!!$      !local variables
!!$      integer :: sizeof,info,ierr
!!$      integer :: window
!!$
!!$      sizeof=mpitypesize(base)
!!$      info=mpiinfo("no_locks", "true")
!!$
!!$      call mpi_win_create(base, int(size,kind=mpi_address_kind)*int(sizeof,kind=mpi_address_kind), &
!!$           sizeof, info,comm, window, ierr)
!!$
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_create',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$      call mpiinfofree(info)
!!$
!!$      call mpi_win_fence(FMPI_MODE_NOPRECEDE, window, ierr)
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_fence',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$
!!$    end function mpiwindow_long0
!!$
!!$
!!$    function mpiwindow_l0(size,base,comm) result(window)
!!$      use dictionaries, only: f_err_throw,f_err_define
!!$      implicit none
!!$      integer,intent(in) :: size
!!$      logical,intent(in) :: base
!!$      integer,intent(in) :: comm
!!$      !local variables
!!$      integer :: sizeof,info,ierr
!!$      integer :: window
!!$
!!$      sizeof=mpitypesize(base)
!!$      info=mpiinfo("no_locks", "true")
!!$
!!$      call mpi_win_create(base, int(size,kind=mpi_address_kind)*int(sizeof,kind=mpi_address_kind), &
!!$           sizeof, info,comm, window, ierr)
!!$
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_create',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$      call mpiinfofree(info)
!!$
!!$      call mpi_win_fence(FMPI_MODE_NOPRECEDE, window, ierr)
!!$      if (ierr/=0) then
!!$         call f_err_throw('Error in mpi_win_fence',&
!!$              err_id=ERR_MPI_WRAPPERS)
!!$      end if
!!$
!!$
!!$    end function mpiwindow_l0

    subroutine win_allocate_w1(array,m)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:), allocatable, intent(inout) :: array
      type(malloc_information_all), intent(in) :: m
      !local variables
      integer :: ierror

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)

      allocate(array(m%lbounds(1):m%ubounds(1)),stat=ierror)

      call malloc_validate(ierror,size(shape(array)),m)

      !here the database for the allocation might be updated

      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS

    end subroutine win_allocate_w1
    subroutine win_allocate_w2(array,m)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:,:), allocatable, intent(inout) :: array
      type(malloc_information_all), intent(in) :: m
      !local variables
      integer :: ierror

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)

      allocate(array(m%lbounds(1):m%ubounds(1),m%lbounds(2):m%ubounds(2)),stat=ierror)

      call malloc_validate(ierror,size(shape(array)),m)

      !here the database for the allocation might be updated

      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS

    end subroutine win_allocate_w2

    subroutine win_allocate_w1_ptr(array,m)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:), pointer, intent(inout) :: array
      type(malloc_information_ptr), intent(in) :: m
      !local variables
      integer :: ierror

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)

      allocate(array(m%lbounds(1):m%ubounds(1)),stat=ierror)

      call malloc_validate(ierror,size(shape(array)),m)

      !here the database for the allocation might be updated

      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS

    end subroutine win_allocate_w1_ptr

    subroutine free_fmpi_win_ptr(array)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:), pointer :: array

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)
      deallocate(array) !let it crash if istat=/0
      nullify(array)
      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS
    end subroutine free_fmpi_win_ptr

    subroutine free_fmpi_win_arr(array)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:), allocatable, intent(inout) :: array

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)
      deallocate(array) !let it crash if istat=/0
      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS
    end subroutine free_fmpi_win_arr

    subroutine free_fmpi_win_arr2(array)
      use dynamic_memory
      implicit none
      type(fmpi_win), dimension(:,:), allocatable, intent(inout) :: array

      call f_timer_interrupt(TCAT_ARRAY_ALLOCATIONS)
      deallocate(array) !let it crash if istat=/0
      call f_timer_resume()!TCAT_ARRAY_ALLOCATIONS
    end subroutine free_fmpi_win_arr2


  subroutine mpi_fence(window, assert)
    use dictionaries, only: f_err_throw,f_err_define
    ! Calling arguments
    integer,intent(inout) :: window !<window to be synchronized
    integer,intent(in),optional :: assert

    ! Local variables
    integer :: ierr, assert_, tcat

    if (present(assert)) then
       assert_ = assert
    else
       assert_ = 0
    end if
    tcat=TCAT_FENCE
    ! Synchronize the communication
    call f_timer_interrupt(tcat)
    call mpi_win_fence(assert_, window, ierr)
    call f_timer_resume()
    if (ierr/=0) then
       call f_err_throw('Error in mpi_win_fence',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine mpi_fence

  subroutine fmpi_win_fence(win,why)
    implicit none
    type(fmpi_win), intent(inout) :: win
    type(f_enumerator), intent(in) :: why
    !local variables
    integer(fmpi_integer) :: ierr
    
    select case(toi(why))
    case(FMPI_OPEN)
       !this should be executed by evarybody in the communicator
       call mpi_win_fence(FMPI_MODE_NOPRECEDE, win%handle, ierr)
    case(FMPI_END_READ,FMPI_START_WRITE)
       call mpi_win_fence(FMPI_MODE_NOSTORE, win%handle, ierr)
    case(FMPI_START_READ,FMPI_END_WRITE)
       call mpi_win_fence(FMPI_MODE_NOPUT, win%handle, ierr)
    case(FMPI_CLOSE)
       call mpi_win_fence(FMPI_MODE_NOSUCCEED, win%handle, ierr)
    end select

    if (ierr/=FMPI_SUCCESS) then
       call f_err_throw('Error in mpi_win_fence',&
            err_id=ERR_MPI_WRAPPERS)
    end if

  end subroutine fmpi_win_fence

  subroutine fmpi_win_free(win)
    implicit none
    type(fmpi_win), intent(inout) :: win
    !local variables
    integer(fmpi_integer) :: ierr

    call mpi_win_free(win%handle, ierr)
    if (ierr/= FMPI_SUCCESS) then
       call f_err_throw('Error in mpi_win_free',&
            err_id=ERR_MPI_WRAPPERS)
    end if

    win%handle=FMPI_WIN_NULL
    win%disp_unit=0
    win%size=0
    win%comm=FMPI_COMM_NULL
    call dict_free(win%dict_info)
  end subroutine fmpi_win_free

  subroutine mpiwinstart(grp,win,assert)
    implicit none
    integer, intent(in) :: grp
    integer, intent(in) :: win
    integer, intent(in), optional :: assert
    !local variables
    integer :: assert_,ierr
    assert_=0
    if (present(assert)) assert_=assert

    if (grp==FMPI_GROUP_NULL) then
       call f_err_throw('Error in mpi_win_start, passed a null group',&
            err_id=ERR_MPI_WRAPPERS)
    end if


    call MPI_WIN_START(grp,assert_,win,ierr)
    if (ierr /=0) then
       call f_err_throw('Error in mpi_win_start',&
            err_id=ERR_MPI_WRAPPERS)
    end if

  end subroutine mpiwinstart

  subroutine mpiwinpost(grp,win,assert)
    implicit none
    integer, intent(in) :: grp
    integer, intent(in) :: win
    integer, intent(in), optional :: assert
    !local variables
    integer :: assert_,ierr
    assert_=0
    if (present(assert)) assert_=assert

    if (grp==FMPI_GROUP_NULL) then
       call f_err_throw('Error in mpi_win_post, passed a null group',&
            err_id=ERR_MPI_WRAPPERS)
    end if

    call MPI_WIN_POST(grp,assert_,win,ierr)
    if (ierr /=0) then
       call f_err_throw('Error in mpi_win_post',&
            err_id=ERR_MPI_WRAPPERS)
    end if

  end subroutine mpiwinpost

  subroutine mpiwincomplete(win)
    implicit none
    integer, intent(in) :: win
    !local variables
    integer :: ierr

    call MPI_WIN_COMPLETE(win,ierr)
    if (ierr /=0) then
       call f_err_throw('Error in mpi_win_complete',&
            err_id=ERR_MPI_WRAPPERS)
    end if

  end subroutine mpiwincomplete

  subroutine mpiwinwait(win)
    implicit none
    integer, intent(in) :: win
    !local variables
    integer :: ierr

    call MPI_WIN_WAIT(win,ierr)
    if (ierr /=0) then
       call f_err_throw('Error in mpi_win_wait',&
            err_id=ERR_MPI_WRAPPERS)
    end if

  end subroutine mpiwinwait


  subroutine mpi_fenceandfree(window, assert)
    use dictionaries, only: f_err_throw,f_err_define
    ! Calling arguments
    integer,intent(inout) :: window !<window to be synchronized and freed
    integer,intent(in),optional :: assert

    ! Local variables
    integer :: ierr, assert_

    if (present(assert)) then
       assert_ = assert
    else
       assert_ = 0
    end if

    ! Synchronize the communication
    call mpi_win_fence(assert_, window, ierr)
    if (ierr/=0) then
       call f_err_throw('Error in mpi_win_fence',&
            err_id=ERR_MPI_WRAPPERS)
    end if
    call mpi_win_free(window, ierr)
    if (ierr/=0) then
       call f_err_throw('Error in mpi_win_fence',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine mpi_fenceandfree

  subroutine mpiget_d0(origin,count,target_rank,target_disp,window)
    use dictionaries, only: f_err_throw,f_err_define
    implicit none
    double precision,intent(inout) :: origin !<fake intent(in)
    integer,intent(in) :: count, target_rank,window
    integer(fmpi_address),intent(in) :: target_disp

    ! Local variables
    integer :: ierr

    call mpi_get(origin,count,mpitype(origin),target_rank, &
         target_disp,count,mpitype(origin), window, ierr)
    if (ierr/=0) then
       call f_err_throw('Error in mpi_get',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine mpiget_d0

  subroutine fmpi_get_d0(origin_addr,target_rank,win,count,target_disp,origin_displ)
    use dynamic_memory, only: f_subptr
    implicit none
    real(f_double) :: origin_addr
    integer, intent(in) :: count
    integer(fmpi_integer), intent(in) :: target_rank
    integer(fmpi_address), intent(in) :: target_disp
    type(fmpi_win), intent(in) :: win
    integer, intent(in), optional :: origin_displ
    !local variables
    real(f_double), dimension(:), pointer :: origin_ptr
    ! Local variables
    integer :: from
    integer(fmpi_integer) :: ierr
    external :: MPI_GET

    from=1
    if(present(origin_displ)) from=origin_displ+1
    origin_ptr=>f_subptr(origin_addr,count,from=from)
    call MPI_GET(origin_ptr,count,mpitype(origin_ptr),target_rank, &
         target_disp,int(count,fmpi_integer),win%disp_unit, win%handle, ierr)
    if (ierr/=FMPI_SUCCESS) then
       call f_err_throw('Error in mpi_get',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine fmpi_get_d0



  subroutine mpiput_d0(origin,count,target_rank,target_disp,window)
    use dictionaries, only: f_err_throw,f_err_define
    implicit none
    double precision,intent(inout) :: origin !<fake intent(in)
    integer,intent(in) :: count, target_rank,window
    integer(fmpi_address),intent(in) :: target_disp

    ! Local variables
    integer :: ierr

    call mpi_put(origin,count,mpitype(origin),target_rank, &
         target_disp,count,mpitype(origin), window, ierr)
    if (ierr/=0) then
       call f_err_throw('Error in mpi_put',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine mpiput_d0

  subroutine mpiaccumulate_d0(origin,count,target_rank,target_disp,op,window)
    use yaml_strings    
    implicit none
    double precision,intent(inout) :: origin !<fake intent(in)
    integer,intent(in) :: count, target_rank,window,op
    integer(fmpi_address),intent(in) :: target_disp

    ! Local variables
    integer :: ierr

    if (count<0) then
        call f_err_throw('count<0, value='//trim(yaml_toa(count)))
    end if
    call mpi_accumulate(origin,count,mpitype(origin),target_rank, &
         target_disp,count,mpitype(origin), op, window, ierr)
    if (ierr/=0) then
       call f_err_throw('Error in mpi_accumulate',&
            err_id=ERR_MPI_WRAPPERS)
    end if
  end subroutine mpiaccumulate_d0

!!$  subroutine mpiaccumulate_double(origin_addr, origin_count, target_rank, target_disp, target_count, op, wind)
!!$    use dictionaries, only: f_err_throw,f_err_define
!!$    use yaml_strings, only: yaml_toa
!!$    implicit none
!!$    double precision,intent(in) :: origin_addr
!!$    integer,intent(in) :: origin_count, target_rank, target_count, op
!!$    integer(fmpi_address),intent(in) :: target_disp
!!$    integer,intent(inout) :: wind
!!$    !local variables
!!$    integer :: nproc,jproc,nrecvbuf,ierr
!!$    external :: getall
!!$    logical :: check
!!$    integer,target:: window
!!$
!!$
!!$    call mpi_accumulate(origin_addr, origin_count, mpitype(origin_addr), &
!!$         target_rank, target_disp, target_count, mpitype(origin_addr), op, wind, ierr)
!!$    if (ierr/=0) then
!!$       call f_err_throw('An error in calling to MPI_ACCUMULATE occured',&
!!$            err_id=ERR_MPI_WRAPPERS)
!!$       return
!!$    end if
!!$
!!$  end subroutine mpiaccumulate_double
!!$


end module f_onesided
