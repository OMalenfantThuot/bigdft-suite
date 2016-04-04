module my_objects

  type my_object
     character(len = 10) :: label
     integer, dimension(:), pointer :: data
  end type my_object

contains

  subroutine my_object_alloc(pobj, add)
    use f_precisions
    type(my_object), pointer :: pobj
    integer(f_address), intent(out) :: add

    allocate(pobj)
    call my_object_nullify(pobj)
    add = f_loc(pobj)
  end subroutine my_object_alloc

  subroutine my_object_dealloc(pobj)
    type(my_object), pointer :: pobj

    call my_object_free(pobj)
    deallocate(pobj)
  end subroutine my_object_dealloc

  subroutine my_object_nullify(obj)
    type(my_object), intent(out) :: obj
    write(obj%label, "(A)") ""
    nullify(obj%data)
  end subroutine my_object_nullify

  subroutine my_object_set_data(obj, label, data, ln)
    use dynamic_memory
    type(my_object), intent(inout) :: obj
    character(len = *), intent(in) :: label
    integer, intent(in) :: ln
    integer, dimension(ln), intent(in) :: data

    if (associated(obj%data)) call f_free_ptr(obj%data)
    obj%data = f_malloc_ptr(size(data), id = "data")
    obj%data = data
    write(obj%label, "(A)") label
  end subroutine my_object_set_data

  subroutine my_object_serialize(obj)
    use yaml_output
    use yaml_strings
    type(my_object), intent(in) :: obj

    integer :: i

    call yaml_sequence_open(trim(obj%label))
    do i = 1, size(obj%data), 1
       call yaml_sequence(advance = "NO")
       call yaml_scalar(yaml_toa(obj%data(i)))
    end do
    call yaml_sequence_close()
  end subroutine my_object_serialize

  subroutine my_object_free(obj)
    use dynamic_memory
    type(my_object), intent(inout) :: obj
    if (associated(obj%data)) call f_free_ptr(obj%data)
    call my_object_nullify(obj)
  end subroutine my_object_free

end module my_objects


program test
  use my_objects
  use f_precisions
  
  type(my_object) :: obj

  call f_lib_initialize()

  call f_object_new("my_object", my_object_alloc, my_object_dealloc)
  call f_object_add_method("my_object", "set_data", my_object_set_data, 2)
  call f_object_add_method("my_object", "serialize", my_object_serialize, 0)

  call f_object_add_method("class", "version", version, 0)

  call my_object_nullify(obj)
  call my_object_set_data(obj, "fortran", (/ 1, 2, 3 /), 3)

  call f_python_initialize()

  call f_python_execute("futile.version()")

  call f_python_add_object("my_object", "obj", obj)
  !call f_python_execute('obj = futile.FObject("my_object", %ld)' % f_loc(obj))

  call f_python_execute("obj.serialize()")
  call f_python_execute('obj.set_data("python", (4,5,6,7))')
  call f_python_execute("obj.serialize()")

  call f_python_execute('obj2 = futile.FObject("my_object")')
  call f_python_execute('obj2.set_data("python new", (42, ))')
  call f_python_execute("obj2.serialize()")

  call f_python_finalize()

  call my_object_free(obj)

  call f_lib_finalize()

contains

  subroutine version()
    use f_lib_package
    use yaml_output
    
    call yaml_map("Futile version", package_version)
  end subroutine version
end program test
