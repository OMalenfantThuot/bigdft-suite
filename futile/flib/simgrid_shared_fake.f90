!> fake module to substitute the simgrid shared allocation module..
!option 1 : crash
!option 2 : default to malloc ?
module smpi_shared
  use iso_c_binding
  public :: smpi_shared_malloc, smpi_shared_free
  interface


    pure function smpi_shared_malloc(size, file, line) bind(C, name='malloc')
    use, intrinsic :: iso_c_binding, only: c_ptr, c_char
      implicit none
    type(c_ptr) :: smpi_shared_malloc
    integer(kind=8), value :: size
    character(kind=c_char), intent(in) :: file(*)
    integer(kind=8), value :: line
    integer ierror
!    stop "trying to SMPI run shared allocations without --enable-simgrid-shared"
    end function smpi_shared_malloc

    pure subroutine smpi_shared_free(p) bind(C, name='malloc')
    use, intrinsic :: iso_c_binding, only: c_ptr
      implicit none
    type(c_ptr), intent(in), value :: p
!    stop "trying to SMPI run shared allocations without --enable-simgrid-shared"
    end subroutine smpi_shared_free
    
  end interface
end module smpi_shared
