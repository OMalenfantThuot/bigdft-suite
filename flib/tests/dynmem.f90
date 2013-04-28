subroutine test_dynamic_memory()
   use yaml_output
   use dynamic_memory
   implicit none
   !logical :: fl
   real(kind=8), dimension(:), allocatable :: density,rhopot,potential,pot_ion,xc_pot
   real(kind=8), dimension(:), pointer :: extra_ref

   call yaml_comment('Routine-Tree creation example',hfill='~')
   !call dynmem_sandbox()

   call f_set_status(memory_limit=0.e0)
   call f_routine(id='PS_Check')

   call f_routine(id='Routine 0')
   !Density
   density=f_malloc(3*2,id='density')
   !Density then potential
   potential=f_malloc0(3,id='potential')

   call f_release_routine()
!!$
   call f_routine(id='Routine A')
   call f_release_routine()

!!$
!!$!   call f_malloc_dump_status()
!!$   call f_routine(id=subname)
!!$
!!$   ncommarr=f_malloc(lbounds=(/0,1/),ubounds=(/nproc-1,4/),id='ncommarr')
!!$   ncommarr=f_malloc((/0.to.nproc,1.to.4/),id='ncommarr')
!!$   ncommarr=f_malloc_ptr((/0.to.nproc-1,4/),id='ncommarr')
!!$   call f_release_routine()

   call f_routine(id='Routine D')
    call f_routine(id='SubCase 1')
    call f_release_routine()
    call f_routine(id='Subcase 2')
     call f_routine(id='SubSubcase1')
     call f_release_routine()
    call f_release_routine()
    call f_routine(id='SubCase 3')
    call f_release_routine()
   call f_release_routine()
   call f_routine(id='Routine E')
    call f_free(density)
   call f_release_routine()
   call f_routine(id='Routine F')
   call f_release_routine()
   ! call f_malloc_dump_status()

   !Allocations, considering also spin density
!!$   !ionic potential
   pot_ion=f_malloc(0,id='pot_ion')
   !XC potential
   xc_pot=f_malloc(3*2,id='xc_pot')

   !   call f_malloc_dump_status()
   extra_ref=f_malloc_ptr(0,id='extra_ref')

   rhopot=f_malloc(3*2,id='rhopot')
    call f_malloc_dump_status()
   call f_free(rhopot)
!!$
!!$   !   call f_free(density,potential,pot_ion,xc_pot,extra_ref)
!!$!   call f_malloc_dump_status()
!!$   !stop
   call f_free(pot_ion)
   call f_free(potential)
   call f_free(xc_pot)
   !   call f_malloc_dump_status()
   call f_free_ptr(extra_ref)
!!$   !   call yaml_open_map('Last')
!!$   !   call f_malloc_dump_status()
!!$   !   call yaml_close_map()
   call f_release_routine()

   call f_finalize()


end subroutine test_dynamic_memory

subroutine dynmem_sandbox()
  use yaml_output
  use dictionaries, dict_char_len=> max_field_length
  type(dictionary), pointer :: dict2,dictA
  character(len=dict_char_len) :: routinename

  call yaml_comment('Sandbox')  
   !let used to imagine a routine-tree creation
   nullify(dict2)
   call dict_init(dictA)
   dict2=>dictA//'Routine Tree'
!   call yaml_map('Length',dict_len(dict2))
   call add_routine(dict2,'Routine 0')
   call close_routine(dict2,'Routine 0')
   call add_routine(dict2,'Routine A')
   call close_routine(dict2,'Routine A')
   call add_routine(dict2,'Routine B')
   call close_routine(dict2,'Routine B')
   call add_routine(dict2,'Routine C')
   call close_routine(dict2,'Routine C')
   call add_routine(dict2,'Routine D')

   call open_routine(dict2)
   call add_routine(dict2,'SubCase 1')
   call close_routine(dict2,'SubCase 1')

   call add_routine(dict2,'Subcase 2')
   call open_routine(dict2)
   call add_routine(dict2,'SubSubCase1')
   call close_routine(dict2,'SubSubCase1')

   call close_routine(dict2,'SubSubCase1')
   
!   call close_routine(dict2)
   call add_routine(dict2,'SubCase 3')
   call close_routine(dict2,'SubCase 3')
   call close_routine(dict2,'SubCase 3')

   call add_routine(dict2,'Routine E')
   call close_routine(dict2,'Routine E')

   call add_routine(dict2,'Routine F')
!   call yaml_comment('Look Below',hfill='v')

   call yaml_open_map('Test Case before implementation')
   call yaml_dict_dump(dictA)
   call yaml_close_map()
!   call yaml_comment('Look above',hfill='^')

   call dict_free(dictA)

 contains

   subroutine open_routine(dict)
     implicit none
     type(dictionary), pointer :: dict
     !local variables
     integer :: ival
     type(dictionary), pointer :: dict_tmp

     !now imagine that a new routine is created
     ival=dict_len(dict)-1
     routinename=dict//ival

     !call yaml_map('The routine which has to be converted is',trim(routinename))

     call pop(dict,ival)

     dict_tmp=>dict//ival//trim(routinename)
     dict => dict_tmp
     nullify(dict_tmp)

   end subroutine open_routine

   subroutine close_routine(dict,name)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in), optional :: name
     !local variables
     logical :: jump_up
     type(dictionary), pointer :: dict_tmp

     if (.not. associated(dict)) stop 'ERROR, routine not associated' 

     !       call yaml_map('Key of the dictionary',trim(dict%data%key))

     if (present(name)) then
        !jump_up=(trim(dict%data%key) /= trim(name))
        jump_up=(trim(routinename) /= trim(name))
     else
        jump_up=.true.
     end if

     !       call yaml_map('Would like to jump up',jump_up)
     if (jump_up) then
        !now the routine has to be closed
        !we should jump at the upper level
        dict_tmp=>dict%parent 
        if (associated(dict_tmp%parent)) then
           nullify(dict)
           !this might be null if we are at the topmost level
           dict=>dict_tmp%parent
        end if
        nullify(dict_tmp)
     end if

     routinename=repeat(' ',len(routinename))
   end subroutine close_routine

   subroutine add_routine(dict,name)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in) :: name

     routinename=trim(name)
     call add(dict,trim(name))

   end subroutine add_routine

end subroutine dynmem_sandbox