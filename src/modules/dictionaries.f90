!> Define a dictionary and its basic usage rules
module dictionaries
  implicit none

  private

  integer, parameter, public :: max_field_length = 256

  !> error codes
  integer, parameter :: DICT_SUCCESS=0
  integer, parameter :: DICT_KEY_ABSENT=1
  integer, parameter :: DICT_VALUE_ABSENT=2
  integer, parameter :: DICT_ITEM_NOT_VALID=3
  integer, parameter :: DICT_CONVERSION_ERROR=-1

  logical :: exceptions=.false.
  integer :: last_error = DICT_SUCCESS

  type, public :: storage
     integer :: item !< Id of the item associated to the list
     integer :: nitems !< No. of items in the list
     integer :: nelems !< No. of items in the dictionary
     character(len=max_field_length) :: key
     character(len=max_field_length) :: value
  end type storage

  !> structure of the dictionary element
  type, public :: dictionary
     type(storage) :: data
     type(dictionary), pointer :: parent,next,child,previous
  end type dictionary

  !> operators in the dictionary
  interface operator(/)
     module procedure get_dict_ptr,get_item_ptr
  end interface
  interface operator(//)
     module procedure get_child_ptr,get_list_ptr
  end interface
  interface assignment(=)
     module procedure get_value,get_integer,get_real,get_double,get_long
  end interface
  interface pop
     module procedure pop_dict,pop_item
  end interface

  interface set
     module procedure put_child,put_value,put_list,put_integer,put_real,put_double,put_long
  end interface

  public :: operator(/), operator(//), assignment(=)
  public :: set,dict_init,dict_free,dictionary_print,try,close_try,pop,append,prepend
  

contains

  !error handling routines
  subroutine try()
    implicit none

    exceptions=.true.
  end subroutine try

  subroutine close_try()
    implicit none

    exceptions=.false.
  end subroutine close_try

  pure function try_error() result(ierr)
    implicit none
    integer :: ierr
    ierr = last_error
  end function try_error

  function no_key(dict)
    implicit none
    type(dictionary), intent(in) :: dict
    logical :: no_key
    
    no_key=len(trim(dict%data%key)) == 0 .and. dict%data%item == -1
  end function no_key

  function no_value(dict)
    implicit none
    type(dictionary), intent(in) :: dict
    logical :: no_value

    no_value=len(trim(dict%data%value)) == 0 .and. .not. associated(dict%child)
  end function no_value

  subroutine check_key(dict)
    implicit none
    type(dictionary), intent(in) :: dict

    if (no_key(dict)) then
       if (exceptions) then
          last_error=DICT_KEY_ABSENT
       else
          write(*,*)'ERROR: key absent in dictionary'
          stop
       end if
    end if

  end subroutine check_key

  subroutine check_value(dict)
    implicit none
    type(dictionary), intent(in) :: dict

    if (no_value(dict)) then
       if (exceptions) then
          last_error=DICT_VALUE_ABSENT
       else
          write(*,*)'ERROR: value absent in dictionary'
          stop
       end if
    end if

  end subroutine check_value

  subroutine check_conversion(ierror)
    implicit none
    integer, intent(in) :: ierror
    if (ierror /= 0) then
       if (exceptions) then
          last_error=DICT_CONVERSION_ERROR
       else
          write(*,*)'ERROR: conversion error'
          stop
       end if
    end if

  end subroutine check_conversion


  subroutine set_item(dict,item)
    implicit none
    type(dictionary) :: dict
    integer, intent(in) :: item

    dict%data%item=item
    if (associated(dict%parent)) then
       dict%parent%data%nitems=dict%parent%data%nitems+1
       if (item+1 > dict%parent%data%nitems) then
          if (exceptions) then
             last_error=DICT_ITEM_NOT_VALID
          else
             write(*,*)'ERROR: item not valid',item,dict%parent%data%nitems
             stop
          end if
       end if
    end if

  end subroutine set_item


  subroutine define_parent(dict,child)
    implicit none
    type(dictionary), target :: dict
    type(dictionary) :: child

    child%parent=>dict
  end subroutine define_parent

  subroutine define_brother(brother,dict)
    implicit none
    type(dictionary), target :: brother
    type(dictionary) :: dict

    dict%previous=>brother
  end subroutine define_brother

  subroutine reset_next(next,dict)
    implicit none
    type(dictionary), target :: next
    type(dictionary) :: dict
    !local variables
    type(dictionary), pointer :: dict_all
    
    !do something only if needed
    if (.not. associated(dict%next,target=next)) then
       dict_all=>dict%next
       dict%next=>next
       deallocate(dict_all)
    end if

  end subroutine reset_next


  subroutine pop_dict(dict,key)
    implicit none
    type(dictionary), intent(inout), pointer :: dict 
    character(len=*), intent(in) :: key
    
    !check if we are at the first level
    if (associated(dict%parent)) then
       call pop_dict_(dict%child,key)
    else
       call pop_dict_(dict,key)
    end if
  contains
    !> Eliminate a key from a dictionary if it exists
    recursive subroutine pop_dict_(dict,key)
      implicit none
      type(dictionary), intent(inout), pointer :: dict 
      character(len=*), intent(in) :: key
      !local variables
      type(dictionary), pointer :: dict_first !<in case of first occurrence

      if (associated(dict)) then
         !follow the chain, stop at  first occurence
         if (trim(dict%data%key) == trim(key)) then
            !          print *,'here',trim(key),associated(dict%next)
            if (associated(dict%parent)) then
               dict%parent%data%nelems=dict%parent%data%nelems-1
            else
               dict%data%nelems=dict%data%nelems-1
            end if
            if (associated(dict%next)) then
               call dict_free(dict%child)
               dict_first => dict
               !this is valid if we are not at the first element
               if (associated(dict%previous)) then
                  call define_brother(dict%previous,dict%next) 
                  dict%previous%next => dict%next
               else
                  !the next should now become me
                  dict => dict%next
               end if
               deallocate(dict_first)
            else
               call dict_free(dict)
            end if
         else if (associated(dict%next)) then
            call pop_dict_(dict%next,key)
         else
            if (exceptions) then
               last_error=DICT_KEY_ABSENT
            else
               write(*,*)'ERROR: key absent in dictionary'
               stop
            end if
         end if
      else
         if (exceptions) then
            last_error=DICT_KEY_ABSENT
         else
            write(*,*)'ERROR: key absent in dictionary'
            stop
         end if
      end if

    end subroutine pop_dict_
  end subroutine pop_dict

  subroutine pop_item(dict,item)
    implicit none
    type(dictionary), intent(inout), pointer :: dict 
    integer, intent(in) :: item

    !check if we are at the first level
    if (associated(dict%parent)) then
       call pop_item_(dict%child,item)
    else
       call pop_item_(dict,item)
    end if
  contains
    !> Eliminate a key from a dictionary if it exists
    recursive subroutine pop_item_(dict,item)
      implicit none
      type(dictionary), intent(inout), pointer :: dict 
      integer, intent(in) :: item
      !local variables
      type(dictionary), pointer :: dict_first !<in case of first occurrence

      if (associated(dict)) then
         !print *,dict%data%item,trim(dict%data%key)
         !follow the chain, stop at  first occurence
         if (dict%data%item == item) then
            if (associated(dict%parent)) then
               dict%parent%data%nitems=dict%parent%data%nitems-1
            end if
            if (associated(dict%next)) then
               call dict_free(dict%child)
               dict_first => dict
               !this is valid if we are not at the first element
               if (associated(dict%previous)) then
                  call define_brother(dict%previous,dict%next) 
                  dict%previous%next => dict%next
               else
                  !the next should now become me
                  dict => dict%next
               end if
               deallocate(dict_first)
            else
               call dict_free(dict)
            end if
         else if (associated(dict%next)) then
            call pop_item_(dict%next,item)
         else
            if (exceptions) then
               last_error=DICT_KEY_ABSENT
            else
               write(*,*)'ERROR: item absent in dictionary'
               stop
            end if
         end if
      else
         if (exceptions) then
            last_error=DICT_KEY_ABSENT
         else
            write(*,*)'ERROR: item absent in dictionary'
            stop
         end if
      end if

    end subroutine pop_item_
  end subroutine pop_item


  function get_ptr(dict,key) result (ptr)
    implicit none
    type(dictionary), intent(in), pointer :: dict !hidden inout
    character(len=*), intent(in) :: key
    type(dictionary), pointer :: ptr

    !if we are not at the topmost level check for the child
    if (associated(dict%parent)) then
       ptr=>get_child_ptr(dict,key)
    else
       ptr=>get_dict_ptr(dict,key)
    end if
  end function get_ptr
  

  !> Retrieve the pointer to the dictionary which has this key.
  !! If the key does not exists, create it in the next chain 
  !! Key Must be already present 
  recursive function get_dict_ptr(dict,key) result (dict_ptr)
    implicit none
    type(dictionary), intent(in), pointer :: dict !hidden inout
    character(len=*), intent(in) :: key
    type(dictionary), pointer :: dict_ptr

!    print *,'here',trim(key)
    !follow the chain, stop at  first occurence
    if (trim(dict%data%key) == trim(key)) then
       dict_ptr => dict
    else if (associated(dict%next)) then
       dict_ptr => get_dict_ptr(dict%next,key)
    else if (no_key(dict)) then !this is useful for the first assignation
       call set_elem(dict,key)
       !call set_field(key,dict%data%key)
       dict_ptr => dict
    else
       call dict_init(dict%next)
       !call set_field(key,dict%next%data%key)
       call define_brother(dict,dict%next) !chain the list in both directions
       if (associated(dict%parent)) call define_parent(dict%parent,dict%next)
       call set_elem(dict%next,key)
       dict_ptr => dict%next
    end if

  end function get_dict_ptr

  !> Retrieve the pointer to the dictionary which has this key.
  !! If the key does not exists, create it in the child chain
  function get_child_ptr(dict,key) result (subd_ptr)
    implicit none
    type(dictionary), intent(in), pointer :: dict !hidden inout
    character(len=*), intent(in) :: key
    type(dictionary), pointer :: subd_ptr

    call check_key(dict)
    
    if (associated(dict%child)) then
       subd_ptr => get_dict_ptr(dict%child,key)
    else
       call dict_init(dict%child)
       !call set_field(key,dict%child%data%key)
       call define_parent(dict,dict%child)
       call set_elem(dict%child,key)
       subd_ptr => dict%child
    end if

  end function get_child_ptr

  !> Retrieve the pointer to the item of the list.
  !! If the list does not exists, create it in the child chain.
  !! If the list is too short, create it in the next chain
  recursive function get_item_ptr(dict,item) result (item_ptr)
    implicit none
    type(dictionary), intent(in), pointer :: dict !hidden inout
    integer, intent(in) :: item
    type(dictionary), pointer :: item_ptr

    !follow the chain, stop at  first occurence
    if (dict%data%item == item) then
       item_ptr => dict
    else if (associated(dict%next)) then
       item_ptr => get_item_ptr(dict%next,item)
    else if (no_key(dict)) then
       call set_item(dict,item)
       item_ptr => dict
    else
       call dict_init(dict%next)
       call define_brother(dict,dict%next) !chain the list in both directions
       if (associated(dict%parent)) call define_parent(dict%parent,dict%next)
       call set_item(dict%next,item)
       item_ptr => dict%next
    end if

  end function get_item_ptr

  !> Retrieve the pointer to the item of the list.
  !! If the list does not exists, create it in the child chain.
  !! If the list is too short, create it in the next chain
  function get_list_ptr(dict,item) result (subd_ptr)
    implicit none
    type(dictionary), intent(in), pointer :: dict !hidden inout
    integer, intent(in) :: item
    type(dictionary), pointer :: subd_ptr

    call check_key(dict)
    
    if (associated(dict%child)) then
       subd_ptr => get_item_ptr(dict%child,item)
    else
       call dict_init(dict%child)
       call define_parent(dict,dict%child)
       call set_item(dict%child,item)
       subd_ptr => dict%child
    end if

  end function get_list_ptr
!
  !> assign a child to the  dictionary
  subroutine put_child(dict,subd)
    implicit none
    type(dictionary), pointer :: dict
    type(dictionary), intent(in), target :: subd

    call check_key(dict)

    call set_field(repeat(' ',max_field_length),dict%data%value)
    if ( .not. associated(dict%child,target=subd) .and. &
         associated(dict%child)) then
       call dict_free(dict%child)
    end if
    dict%child=>subd
    call define_parent(dict,dict%child)
    dict%data%nelems=dict%data%nelems+1
  end subroutine put_child

  !> append another dictionary
  recursive subroutine append(dict,brother)
    implicit none
    type(dictionary), pointer :: dict
    type(dictionary), intent(in), target :: brother

    if (.not. associated(dict)) then
       dict=>brother
    else if (associated(dict%next)) then
       call append(dict%next,brother)
    else
       dict%next=>brother
       call define_brother(dict,dict%next)
       dict%data%nelems=dict%data%nelems+brother%data%nelems
    end if
  end subroutine append

  !> append another dictionary
  recursive subroutine prepend(dict,brother)
    implicit none
    type(dictionary), pointer :: dict
    type(dictionary), pointer :: brother
    !local variables
    type(dictionary), pointer :: dict_tmp

    if (.not. associated(brother)) return

    if (.not. associated(dict)) then
       dict=>brother
    else if (associated(dict%previous)) then
       call prepend(dict%previous,brother)
    else
       dict_tmp=>brother
       call append(brother,dict)
       dict=>dict_tmp
    end if
  end subroutine prepend


  !> assign the value to the  dictionary
  subroutine put_value(dict,val)
    implicit none
    type(dictionary), pointer :: dict
    character(len=*), intent(in) :: val

    call check_key(dict)

    if (associated(dict%child)) call dict_free(dict%child)

    call set_field(val,dict%data%value)

  end subroutine put_value

  !> assign the value to the  dictionary (to be rewritten)
  subroutine put_list(dict,list,nitems)
    use yaml_output
    implicit none
    type(dictionary), pointer :: dict
    integer, intent(in) :: nitems
    character(len=*), dimension(*), intent(in) :: list
    !local variables
    integer :: item

    do item=1,nitems
       call set(dict//(item-1),list(item))
    end do

  end subroutine put_list

  !> get the value from the  dictionary
  subroutine get_value(val,dict)
    implicit none
    character(len=*), intent(out) :: val
    type(dictionary), intent(in) :: dict

    call check_key(dict)
    call check_value(dict)

    call get_field(dict%data%value,val)

  end subroutine get_value

  pure subroutine dictionary_nullify(dict)
    implicit none
    type(dictionary), intent(inout) :: dict

    dict%data%key=repeat(' ',max_field_length)
    dict%data%value=repeat(' ',max_field_length)
    dict%data%item=-1
    dict%data%nitems=0
    dict%data%nelems=0
    nullify(dict%child,dict%next,dict%parent,dict%previous)
  end subroutine dictionary_nullify

  pure subroutine dict_free(dict)
    type(dictionary), pointer :: dict

    if (associated(dict)) then
       call dict_free_(dict)
       deallocate(dict)
    end if

  contains

    pure recursive subroutine dict_free_(dict)
      implicit none
      type(dictionary), pointer :: dict

      !first destroy the children
      if (associated(dict%child)) then
         call dict_free_(dict%child)
         deallocate(dict%child)
         nullify(dict%child)
      end if
      !then destroy younger brothers
      if (associated(dict%next)) then
         call dict_free_(dict%next)
         deallocate(dict%next)
         nullify(dict%next)
      end if
      call dictionary_nullify(dict)

    end subroutine dict_free_

  end subroutine dict_free

  pure subroutine dict_init(dict)
    implicit none
    type(dictionary), pointer :: dict

    allocate(dict)
    call dictionary_nullify(dict)

  end subroutine dict_init

  recursive subroutine dictionary_print(dict,flow)
    use yaml_output
    implicit none
    type(dictionary), intent(in) :: dict
    logical, intent(in), optional :: flow
    !local variables
    logical :: flowrite,onlyval
    
    flowrite=.false.
    if (present(flow)) flowrite=flow

    if (associated(dict%child)) then
       !see whether the child is a list or not
       !print *trim(dict%data%key),dict%data%nitems
       if (dict%data%nitems > 0) then
          call yaml_open_sequence(trim(dict%data%key),flow=flowrite)
          call dictionary_print(dict%child,flow=flowrite)
          call yaml_close_sequence()
       else
          if (dict%data%item >= 0) then
             call yaml_sequence(advance='no')
             call dictionary_print(dict%child,flow=flowrite)
          else
             call yaml_open_map(trim(dict%data%key),flow=flowrite)
             !call yaml_map('No. of Elems',dict%data%nelems)
             call dictionary_print(dict%child,flow=flowrite)
             call yaml_close_map()
          end if
       end if
    else 
       !print *,'ciao',dict%key,len(trim(dict%key)),'key',dict%value,flowrite
       if (dict%data%item >= 0) then
          call yaml_sequence(trim(dict%data%value))
       else
          call yaml_map(trim(dict%data%key),trim(dict%data%value))
       end if
    end if
    if (associated(dict%next)) then
       call dictionary_print(dict%next,flow=flowrite)
    end if

  end subroutine dictionary_print
  
  pure subroutine set_elem(dict,key)
    implicit none
    type(dictionary), pointer :: dict !!TO BE VERIFIED
    character(len=*), intent(in) :: key

    call set_field(trim(key),dict%data%key)
    if (associated(dict%parent)) then
       dict%parent%data%nelems=dict%parent%data%nelems+1
    else
       dict%data%nelems=dict%data%nelems+1
    end if

  end subroutine set_elem

  pure subroutine set_field(input,output)
    implicit none
    character(len=*), intent(in) :: input !intent eliminated
    character(len=max_field_length), intent(out) :: output !intent eliminated
    !local variables
    integer :: ipos,i

    ipos=min(len(trim(input)),max_field_length)
    do i=1,ipos
       output(i:i)=input(i:i)
    end do
    do i=ipos+1,max_field_length
       output(i:i)=' ' 
    end do

  end subroutine set_field

  pure subroutine get_field(input,output)
    implicit none
    character(len=max_field_length), intent(in) :: input !intent eliminated
    character(len=*), intent(out) :: output !intent eliminated
    !local variables
    integer :: ipos,i

    ipos=min(len(output),max_field_length)
    do i=1,ipos
       output(i:i)=input(i:i)
    end do
    do i=ipos+1,len(output)
       output(i:i)=' ' 
    end do

  end subroutine get_field

  recursive function dict_list_size(dict) result(ntot)
    implicit none
    type(dictionary), intent(in) :: dict
    integer :: ntot
    !item
    integer :: npos=0
    integer :: ipos
    
    ntot=-1
    !print *,field_to_integer(dict%key),trim(dict%key),npos
    if (associated(dict%parent)) npos=0 !beginning of the list
    if (field_to_integer(dict%data%key) == npos) then
       npos=npos+1
       ntot=npos
    else
       npos=0
       return
    end if

    if (associated(dict%next)) then
       ntot=dict_list_size(dict%next)
    end if
  end function dict_list_size
 
  function field_to_integer(input)
    implicit none
    character(len=max_field_length), intent(in) :: input
    integer :: field_to_integer
    !local variables
    integer :: iprobe,ierror

    !look at conversion
    read(input,*,iostat=ierror)iprobe
    !print *,trim(input),'test',ierror
    if (ierror /=0) then
       field_to_integer=-1
    else
       field_to_integer=iprobe
    end if

  end function field_to_integer

  !set and get routines for different types
  subroutine get_integer(ival,dict)
    integer, intent(out) :: ival
    type(dictionary), intent(in) :: dict
    !local variables
    integer :: ierror
    character(len=max_field_length) :: val

    !take value
    val=dict
    !look at conversion
    read(val,*,iostat=ierror)ival

    call check_conversion(ierror)
    
  end subroutine get_integer

  !set and get routines for different types
  subroutine get_long(ival,dict)
    integer(kind=8), intent(out) :: ival
    type(dictionary), intent(in) :: dict
    !local variables
    integer :: ierror
    character(len=max_field_length) :: val

    !take value
    val=dict
    !look at conversion
    read(val,*,iostat=ierror)ival

    call check_conversion(ierror)
    
  end subroutine get_long


  !set and get routines for different types
  subroutine get_real(rval,dict)
    real(kind=4), intent(out) :: rval
    type(dictionary), intent(in) :: dict
    !local variables
    integer :: ierror
    character(len=max_field_length) :: val

    !take value
    val=dict
    !look at conversion
    read(val,*,iostat=ierror)rval

    call check_conversion(ierror)
    
  end subroutine get_real

  !set and get routines for different types
  subroutine get_double(dval,dict)
    real(kind=8), intent(out) :: dval
    type(dictionary), intent(in) :: dict
    !local variables
    integer :: ierror
    character(len=max_field_length) :: val

    !take value
    val=dict
    !look at conversion
    read(val,*,iostat=ierror)dval

    call check_conversion(ierror)
    
  end subroutine get_double


  !> assign the value to the  dictionary
  subroutine put_integer(dict,ival,fmt)
    use yaml_output
    implicit none
    type(dictionary), pointer :: dict
    integer, intent(in) :: ival
    character(len=*), optional, intent(in) :: fmt

    if (present(fmt)) then
       call put_value(dict,adjustl(trim(yaml_toa(ival,fmt=fmt))))
    else
       call put_value(dict,adjustl(trim(yaml_toa(ival))))
    end if

  end subroutine put_integer

  !> assign the value to the  dictionary
  subroutine put_double(dict,dval,fmt)
    use yaml_output
    implicit none
    type(dictionary), pointer :: dict
    real(kind=8), intent(in) :: dval
    character(len=*), optional, intent(in) :: fmt

    if (present(fmt)) then
       call put_value(dict,adjustl(trim(yaml_toa(dval,fmt=fmt))))
    else
       call put_value(dict,adjustl(trim(yaml_toa(dval))))
    end if

  end subroutine put_double

  !> assign the value to the  dictionary
  subroutine put_real(dict,rval,fmt)
    use yaml_output
    implicit none
    type(dictionary), pointer :: dict
    real(kind=4), intent(in) :: rval
    character(len=*), optional, intent(in) :: fmt

    if (present(fmt)) then
       call put_value(dict,adjustl(trim(yaml_toa(rval,fmt=fmt))))
    else
       call put_value(dict,adjustl(trim(yaml_toa(rval))))
    end if

  end subroutine put_real

  !> assign the value to the  dictionary
  subroutine put_long(dict,ilval,fmt)
    use yaml_output
    implicit none
    type(dictionary), pointer :: dict
    integer(kind=8), intent(in) :: ilval
    character(len=*), optional, intent(in) :: fmt

    if (present(fmt)) then
       call put_value(dict,adjustl(trim(yaml_toa(ilval,fmt=fmt))))
    else
       call put_value(dict,adjustl(trim(yaml_toa(ilval))))
    end if

  end subroutine put_long


end module dictionaries