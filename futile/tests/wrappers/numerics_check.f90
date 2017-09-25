!> @file
!!  Test of some functionalities of the numeric groups
!! @author
!!    Copyright (C) 2016-2017 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
program numeric_check
  use futile
  use f_harmonics
  character(len=*), parameter :: input1=&
       "  {name: ndim, shortname: n, default: 30,"//&
       "  help_string: Size of the array for multipoles,"//&
       "  help_dict: {Allowed values: integer}}"
  character(len=*), parameter :: input2=&
       "  {name: boldify, shortname: b, default: None,"//&
       "  help_string: Boldify the string as a test,"//&
       "  help_dict: {Allowed values: string scalar}}"
  character(len=*), parameter :: input3=&
       "  {name: blinkify, shortname: l, default: None,"//&
       "  help_string: Make the string blinking,"//&
       "  help_dict: {Allowed values: string scalar}}"

  character(len=*), parameter :: inputs=&
       '-'//input1//f_cr//&
       '-'//input2//f_cr//&
       '-'//input3


  integer :: n,i
  type(f_multipoles) :: mp
  type(dictionary), pointer :: options
  real(f_double), dimension(3) :: rxyz
  real(f_double), dimension(:), allocatable :: density
  
  call f_lib_initialize()
  call yaml_new_document()
  call yaml_argparse(options,inputs)
  n=options//'ndim'

  density=f_malloc(n,id='density')
  call f_random_number(density)

  rxyz=1.0_f_double

  !create random multipoles
  call f_multipoles_create(mp,2)

  do i=1,n
     call f_multipoles_accumulate(mp%Q,mp%lmax,rxyz,density(i))
  end do

  !here we may print the results of the multipole calculations
  call yaml_mapping_open('Multipoles of the array')
  call yaml_map('q0',sum(density))
  call yaml_mapping_close()

  call yaml_mapping_open('Calculated multipoles')
  call yaml_map('q0',mp%Q(0)%ptr)
  call yaml_map('q1',mp%Q(1)%ptr)
  call yaml_map('q2',mp%Q(2)%ptr)
  call yaml_mapping_close()

  call f_multipoles_free(mp)

  call f_free(density)
  call dict_free(options)

!!$  !test of the multipole preserving routine
!!$  !initialize the work arrays needed to integrate with isf
!!$  !names of the routines to be redefined
!!$  call initialize_real_space_conversion(isf_m=mp_isf_order)
!!$
!!$  boxit = box_iter(mesh,origin=rxyz,cutoff=cutoff)
!!$  call finalize_real_space_conversion()


  !here some tests about the box usage
  call test_box_functions()

  call f_lib_finalize()

end program numeric_check


subroutine test_box_functions()
  use futile, gp=>f_double
  use box
  implicit none
  !local variables
  integer(f_long) :: tomp,tseq
  type(cell) :: mesh_ortho
  integer, dimension(3) :: ndims
  real(gp), dimension(:,:,:,:), allocatable :: v1,v2

  ndims=[300,300,300]

  mesh_ortho=cell_new('S',ndims,[1.0_gp,1.0_gp,1.0_gp])

  v1=f_malloc([3,ndims(1),ndims(2),ndims(3)],id='v1')
  v2=f_malloc([3,ndims(1),ndims(2),ndims(3)],id='v2')

  call loop_dotp('SEQ',mesh_ortho,v1,v2,tseq)
  call yaml_map('Normal loop, seq (ns)',tseq)
  
  call loop_dotp('OMP',mesh_ortho,v1,v2,tomp)
  call yaml_map('Normal loop, omp (ns)',tomp)

  call loop_dotp('ITR',mesh_ortho,v1,v2,tseq)
  call yaml_map('Normal loop, itr (ns)',tseq)

  call loop_dotp('IOM',mesh_ortho,v1,v2,tseq)
  call yaml_map('Normal loop, iom (ns)',tseq)

  call loop_dotp('ITM',mesh_ortho,v1,v2,tseq)
  call yaml_map('Normal loop, mpi (ns)',tseq)

  call f_free(v1)
  call f_free(v2)

end subroutine test_box_functions

subroutine loop_dotp(strategy,mesh,v1,v2,time)
  use f_precisions
  use box
  use f_utils
  use yaml_strings
  use wrapper_MPI
  implicit none
  character(len=*), intent(in) :: strategy
  type(cell), intent(in) :: mesh
  real(f_double), dimension(3,mesh%ndims(1),mesh%ndims(2),mesh%ndims(3)), intent(inout) :: v1
  real(f_double), dimension(3,mesh%ndims(1),mesh%ndims(2),mesh%ndims(3)), intent(inout) :: v2
  integer(f_long), intent(out) :: time
  !local variables
  integer :: i1,i2,i3,n3p,i3s,ithread,nthread
  integer(f_long) :: t0,t1
  real(f_double) :: totdot,res
  type(box_iterator) :: bit
  integer, dimension(2,3) :: nbox
  !$ integer, external ::  omp_get_thread_num,omp_get_num_threads

  !initialization
  do i3=1,mesh%ndims(3)
     do i2=1,mesh%ndims(2)
        do i1=1,mesh%ndims(1)
           !the scalar product of these objects is 20.0
           v1(:,i1,i2,i3)=[1.0_f_double,2.0_f_double,3.0_f_double]
           v2(:,i1,i2,i3)=[2.0_f_double,3.0_f_double,4.0_f_double]
        end do
     end do
  end do
  t0=0
  t1=0

  select case(trim(strategy))
  case('SEQ')
     totdot=0.0_f_double
     t0=f_time()
     do i3=1,mesh%ndims(3)
        do i2=1,mesh%ndims(2)
           do i1=1,mesh%ndims(1)
              res=dotp_gd(mesh,v1(1,i1,i2,i3),v2(:,i1,i2,i3))
              res=res/20.0_f_double
              totdot=totdot+res
              v2(:,i1,i2,i3)=res
           end do
        end do
     end do
     t1=f_time()
  case('OMP')
     totdot=0.0_f_double
     t0=f_time()
     !$omp parallel do default(shared) &
     !$omp private(i1,i2,i3,res)&
     !$omp reduction(+:totdot)
     do i3=1,mesh%ndims(3)
        do i2=1,mesh%ndims(2)
           do i1=1,mesh%ndims(1)
              res=dotp_gd(mesh,v1(1,i1,i2,i3),v2(:,i1,i2,i3))
              res=res/20.0_f_double
              totdot=totdot+res
              v2(:,i1,i2,i3)=res
           end do
        end do
     end do
     !$omp end parallel do
     t1=f_time()
  case('ITR') !iterator case
     bit=box_iter(mesh)
     totdot=0.0_f_double
     t0=f_time()
     do while(box_next_point(bit))
        res=dotp_gd(bit%mesh,v1(1,bit%i,bit%j,bit%k),v2(:,bit%i,bit%j,bit%k))
        res=res/20.0_f_double
        totdot=totdot+res
        v2(:,bit%i,bit%j,bit%k)=res
     end do
     t1=f_time()
  case('IOM') !iterator with omp
     bit=box_iter(mesh)
     totdot=0.0_f_double
     t0=f_time()
     nthread=1
     !$omp parallel default(shared) &
     !$omp private(res,ithread)&
     !$omp firstprivate(bit)&
     !$omp reduction(+:totdot)
     ithread=0
     !$ ithread=omp_get_thread_num()
     !$ nthread=omp_get_num_threads()
     call box_iter_split(bit,nthread,ithread)
     do while(box_next_point(bit))
        res=dotp_gd(bit%mesh,v1(1,bit%i,bit%j,bit%k),v2(:,bit%i,bit%j,bit%k))
        res=res/20.0_f_double
        totdot=totdot+res
        v2(:,bit%i,bit%j,bit%k)=res
     end do
     call box_iter_merge(bit)
     !$omp end parallel
     t1=f_time()
  case('ITM') !iterator with mpi
     call mpiinit()
     nbox(1,:)=1
     nbox(2,:)=mesh%ndims
     call distribute_on_tasks(mesh%ndims(3),mpirank(),mpisize(),n3p,i3s)
     nbox(1,3)=i3s+1
     nbox(2,3)=i3s+n3p
     !print *,'here',mpisize(),mpirank(),i3s,n3p,mesh%ndims(3)
     bit=box_iter(mesh,i3s=i3s+1,n3p=n3p)
     totdot=0.0_f_double
     t0=f_time()
     do while(box_next_point(bit))
        res=dotp_gd(bit%mesh,v1(1,bit%i,bit%j,bit%k),v2(:,bit%i,bit%j,bit%k))
        res=res/20.0_f_double
        totdot=totdot+res
        v2(:,bit%i,bit%j,bit%k)=res
     end do
     call fmpi_allreduce(totdot,1,op=FMPI_SUM)
     !call mpigather
     t1=f_time()
     call mpifinalize()
  end select
  
  !totdot should be the size of the array
  call f_assert(int(totdot,f_long) == mesh%ndim,&
       'Wrong reduction, found "'+totdot+'" instead of "'+mesh%ndim+'"')
  !call yaml_map('TotDot',totdot)
  !totsum should be the size of the array multipliled by three
  call f_assert(sum(v2) == f_size(v2),&
       'Wrong array writing, found "'+sum(v2)+'" instead of "'+f_size(v2)+'"')
  !call yaml_map('TotSum',sum(v2))

  time=t1-t0

end subroutine loop_dotp

! Parallelization a number n over nproc nasks
subroutine distribute_on_tasks(n, iproc, nproc, np, is)
  implicit none
  ! Calling arguments
  integer,intent(in) :: n, iproc, nproc
  integer,intent(out) :: np, is

  ! Local variables
  integer :: ii

  ! First distribute evenly... (LG: if n is, say, 34 and nproc is 7 - thus 8 MPI processes)
  np = n/nproc                !(LG: we here have np=4) 
  is = iproc*np               !(LG: is=iproc*4 : 0,4,8,12,16,20,24,28)
  ! ... and now distribute the remaining objects.
  ii = n-nproc*np             !(LG: ii=34-28=6)
  if (iproc<ii) np = np + 1   !(LG: the first 6 tasks (iproc<=5) will have np=5)
  is = is + min(iproc,ii)     !(LG: update is, so (iproc,np,is): (0,5,0),(1,5,5),(2,5,10),(3,5,15),(4,5,20),(5,5,25),(6,4,30),(7,4,34))

end subroutine distribute_on_tasks
