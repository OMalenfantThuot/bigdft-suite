!> @file
!!    Routines to create the kernel for Poisson solver
!! @author
!!    Copyright (C) 2002-2013 BigDFT group  (LG)
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!> Initialization of the Poisson kernel
!! @ingroup PSOLVER
function pkernel_init(verb,iproc,nproc,igpu,geocode,ndims,hgrids,itype_scf,&
     alg,cavity,mu0_screening,angrad,mpi_env,taskgroup_size) result(kernel)
  use yaml_output
  use yaml_strings, only: f_strcpy
  use dictionaries, only: f_loc
  implicit none
  logical, intent(in) :: verb       !< verbosity
  integer, intent(in) :: itype_scf
  integer, intent(in) :: iproc      !< Proc Id
  integer, intent(in) :: nproc      !< Number of processes
  integer, intent(in) :: igpu
  character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  integer, dimension(3), intent(in) :: ndims
  real(gp), dimension(3), intent(in) :: hgrids
  !> algorithm of the Solver. Might accept the values "VAC" (default), "PCG", or "PI"
  character(len=*), intent(in), optional :: alg
  !> cavity used, possible values "none" (default), "rigid", "sccs"
  character(len=*), intent(in), optional :: cavity
  real(kind=8), intent(in), optional :: mu0_screening
  real(gp), dimension(3), intent(in), optional :: angrad
  type(mpi_environment), intent(in), optional :: mpi_env
  integer, intent(in), optional :: taskgroup_size
  type(coulomb_operator) :: kernel
  !local variables
  real(dp) :: alphat,betat,gammat,mu0t
  integer :: nthreads,group_size
  !integer :: ierr
  !$ integer :: omp_get_max_threads

  group_size=nproc
  if (present(taskgroup_size)) then
     !if the taskgroup size is not a divisor of nproc do not create taskgroups
     if (nproc >1 .and. taskgroup_size > 0 .and. taskgroup_size < nproc .and.&
          mod(nproc,taskgroup_size)==0) then
        group_size=taskgroup_size
     end if
  end if
     
  !nullification
  kernel=pkernel_null()

  if (present(angrad)) then
     kernel%angrad=angrad
  else
     alphat = 2.0_dp*datan(1.0_dp)
     betat = 2.0_dp*datan(1.0_dp)
     gammat = 2.0_dp*datan(1.0_dp)
     kernel%angrad=(/alphat,betat,gammat/)
  end if
  if (.not. present(mu0_screening)) then
     mu0t=0.0_gp
  else
     mu0t=mu0_screening
  end if
  kernel%mu=mu0t

  if (present(alg)) then
     select case(trim(alg))
     case('VAC')
        kernel%method=PS_VAC_ENUM
     case('PI')
        kernel%method=PS_PI_ENUM
        kernel%nord=16 
        !here the parameters can be specified from command line
        kernel%max_iter=50
        kernel%minres=1.0e-6_dp!1.0e-12_dp
        kernel%PI_eta=0.6_dp
     case('PCG')
        kernel%method=PS_PCG_ENUM
        kernel%nord=16
        kernel%max_iter=50
        kernel%minres=1.0e-6_dp!1.0e-12_dp
     case default
        call f_err_throw('Error, kernel algorithm '//trim(alg)//&
             'not valid')
     end select
  else
     kernel%method=PS_VAC_ENUM
  end if

  if (present(cavity)) then
     select case(trim(cavity))
     case('vacuum')
        call f_enum_attr(kernel%method,PS_NONE_ENUM)
     case('rigid')
        call f_enum_attr(kernel%method,PS_RIGID_ENUM)
     case('sccs')   
        call f_enum_attr(kernel%method,PS_SCCS_ENUM)
     case default
        call f_err_throw('Error, cavity method '//trim(cavity)//&
             ' not valid')
     end select
  else
     call f_enum_attr(kernel%method,PS_NONE_ENUM)
  end if

  !geocode and ISF family
  kernel%geocode=geocode
  kernel%itype_scf=itype_scf

  !dimensions and grid spacings
  kernel%ndims=ndims
  kernel%hgrids=hgrids

  !gpu acceleration
  kernel%igpu=igpu  

  kernel%initCufftPlan = 0
  kernel%keepGPUmemory = 1

  if (iproc == 0 .and. verb) then 
     if (mu0t==0.0_gp) then 
        call yaml_comment('Kernel Initialization',hfill='-')
        call yaml_mapping_open('Poisson Kernel Initialization')
     else
        call yaml_mapping_open('Helmholtz Kernel Initialization')
         call yaml_map('Screening Length (AU)',1/mu0t,fmt='(g25.17)')
     end if
  end if
  
  !import the mpi_environment if present
  if (present(mpi_env)) then
     kernel%mpi_env=mpi_env
  else
     call mpi_environment_set(kernel%mpi_env,iproc,nproc,MPI_COMM_WORLD,group_size)
  end if

  !gpu can be used only for one nproc
  !if (kernel%nproc > 1) kernel%igpu=0

  !-------------------
  nthreads=0
  if (kernel%mpi_env%iproc == 0 .and. kernel%mpi_env%igroup == 0 .and. verb) then
     !$ nthreads = omp_get_max_threads()
     call yaml_map('MPI tasks',kernel%mpi_env%nproc)
     if (nthreads /=0) call yaml_map('OpenMP threads per MPI task',nthreads)
     if (kernel%igpu==1) call yaml_map('Kernel copied on GPU',.true.)
     if (kernel%method /= 'VAC') call yaml_map('Iterative method for Generalised Equation',str(kernel%method))
     if (kernel%method .hasattr. PS_RIGID_ENUM) call yaml_map('Cavity determination','rigid')
     if (kernel%method .hasattr. PS_SCCS_ENUM) call yaml_map('Cavity determination','sccs')
     call yaml_mapping_close() !kernel
  end if

end function pkernel_init


!> Free memory used by the kernel operation
!! @ingroup PSOLVER
subroutine pkernel_free(kernel)
  use dynamic_memory
  implicit none
  type(coulomb_operator), intent(inout) :: kernel
  integer :: i_stat
  call f_free_ptr(kernel%kernel)
  call f_free_ptr(kernel%dlogeps)
  call f_free_ptr(kernel%oneoeps)
  call f_free_ptr(kernel%corr)
  call f_free_ptr(kernel%epsinnersccs)
  call f_free_ptr(kernel%pol_charge)
  call f_free_ptr(kernel%cavity)
  call f_free_ptr(kernel%counts)
  call f_free_ptr(kernel%displs)

  !free GPU data
  if (kernel%igpu == 1) then
    if (kernel%mpi_env%iproc == 0) then
     if (kernel%keepGPUmemory == 1) then
       call cudafree(kernel%work1_GPU)
       call cudafree(kernel%work2_GPU)
    call cudafree(kernel%z_GPU)
    call cudafree(kernel%r_GPU)
    call cudafree(kernel%oneoeps_GPU)
    call cudafree(kernel%p_GPU)
    call cudafree(kernel%q_GPU)
    call cudafree(kernel%x_GPU)
    call cudafree(kernel%corr_GPU)
    call cudafree(kernel%alpha_GPU)
    call cudafree(kernel%beta_GPU)
    call cudafree(kernel%beta0_GPU)
    call cudafree(kernel%kappa_GPU)
     endif
     call cudafree(kernel%k_GPU)
     if (kernel%initCufftPlan == 1) then
       call cufftDestroy(kernel%plan(1))
       call cufftDestroy(kernel%plan(2))
       call cufftDestroy(kernel%plan(3))
       call cufftDestroy(kernel%plan(4))
     endif
    endif
  end if

  !cannot yet free the communicators of the poisson kernel
  !lack of garbage collector

end subroutine pkernel_free


!> Allocate a pointer which corresponds to the zero-padded FFT slice needed for
!! calculating the convolution with the kernel expressed in the interpolating scaling
!! function basis. The kernel pointer is unallocated on input, allocated on output.
!! SYNOPSIS
!!    @param iproc,nproc number of process, number of processes
!!    @param n01,n02,n03 dimensions of the real space grid to be hit with the Poisson Solver
!!    @param itype_scf   order of the interpolating scaling functions used in the decomposition
!!    @param hx,hy,hz grid spacings. For the isolated BC case for the moment they are supposed to 
!!                    be equal in the three directions
!!    @param kernel   pointer for the kernel FFT. Unallocated on input, allocated on output.
!!                    Its dimensions are equivalent to the region of the FFT space for which the
!!                    kernel is injective. This will divide by two each direction, 
!!                    since the kernel for the zero-padded convolution is real and symmetric.
!!    @param gpu      tag for CUDA gpu   0: CUDA GPU is disabled
!!
!! @warning
!!    Due to the fact that the kernel dimensions are unknown before the calling, the kernel
!!    must be declared as pointer in input of this routine.
!!    To avoid that, one can properly define the kernel dimensions by adding 
!!    the nd1,nd2,nd3 arguments to the PS_dim4allocation routine, then eliminating the pointer
!!    declaration.
!! @ingroup PSOLVER
subroutine pkernel_set(kernel,eps,dlogeps,oneoeps,oneosqrteps,corr,verbose) !optional arguments
  use yaml_output
  use dynamic_memory
  use time_profiling, only: f_timing
  use dictionaries, only: f_err_throw
  use yaml_strings, only: operator(+)
  implicit none
  !Arguments
  type(coulomb_operator), intent(inout) :: kernel
  !> dielectric function. Needed for non VAC methods, given in full dimensions
  real(dp), dimension(:,:,:), intent(in), optional :: eps
  !> logarithmic derivative of epsilon. Needed for PCG method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:,:), intent(in), optional :: dlogeps
  !> inverse of epsilon. Needed for PI method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: oneoeps
  !> inverse square root of epsilon. Needed for PCG method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: oneosqrteps
  !> correction term of the Generalized Laplacian
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: corr
  real(dp) :: alpha
  logical, intent(in), optional :: verbose 
  !local variables
  logical :: dump,wrtmsg
  character(len=*), parameter :: subname='createKernel'
  integer :: m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,i_stat
  integer :: jproc,nlimd,nlimk,jfd,jhd,jzd,jfk,jhk,jzk,npd,npk
  real(kind=8) :: alphat,betat,gammat,mu0t,pi
  real(kind=8), dimension(:), allocatable :: pkernel2
  integer :: i1,i2,i3,j1,j2,j3,ind,indt,switch_alg,size2,sizek,kernelnproc,size3
  integer :: n3pr1,n3pr2,istart,jend,i23,i3s,n23
  integer,dimension(3) :: n

  !call timing(kernel%mpi_env%iproc+kernel%mpi_env%igroup*kernel%mpi_env%nproc,'PSolvKernel   ','ON')
  call f_timing(TCAT_PSOLV_KERNEL,'ON')

  pi=4.0_dp*atan(1.0_dp)
  wrtmsg=.true.
  if (present(verbose)) wrtmsg=verbose

  dump=wrtmsg .and. kernel%mpi_env%iproc+kernel%mpi_env%igroup==0

  mu0t=kernel%mu
  alphat=kernel%angrad(1)
  betat=kernel%angrad(2)
  gammat=kernel%angrad(3)

  if (dump) then 
     if (mu0t==0.0_gp) then 
        call yaml_mapping_open('Poisson Kernel Creation')
     else
        call yaml_mapping_open('Helmholtz Kernel Creation')
        call yaml_map('Screening Length (AU)',1/mu0t,fmt='(g25.17)')
     end if
  end if

  kernelnproc=kernel%mpi_env%nproc
  if (kernel%igpu == 1) kernelnproc=1


  select case(kernel%geocode)
     !if (kernel%geocode == 'P') then
  case('P')

     kernel%geo=[1,1,1]
     
     if (dump) then
        call yaml_map('Boundary Conditions','Periodic')
     end if
     call P_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc,.false.)

     if (kernel%igpu == 2) then
       kernel%kernel = f_malloc_ptr((n1/2+1)*n2*n3/kernelnproc,id='kernel%kernel')
     else
       kernel%kernel = f_malloc_ptr(nd1*nd2*nd3/kernelnproc,id='kernel%kernel')
     endif
     !!! PSolver n1-n2 plane mpi partitioning !!!   
     call inplane_partitioning(kernel%mpi_env,md2,n2,n3/2+1,kernel%part_mpi,kernel%inplane_mpi,n3pr1,n3pr2)
!!$     if (kernel%mpi_env%nproc>2*(n3/2+1)-1) then
!!$       n3pr1=kernel%mpi_env%nproc/(n3/2+1)
!!$       n3pr2=n3/2+1
!!$       md2plus=.false.
!!$       if ((md2/kernel%mpi_env%nproc)*n3pr1*n3pr2 < n2) then
!!$           md2plus=.true.
!!$       endif
!!$
!!$       if (kernel%mpi_env%iproc==0 .and. n3pr1>1) call yaml_map('PSolver n1-n2 plane mpi partitioning activated:',&
!!$          trim(yaml_toa(n3pr1,fmt='(i5)'))//' x'//trim(yaml_toa(n3pr2,fmt='(i5)'))//&
!!$          ' taskgroups')
!!$       if (kernel%mpi_env%iproc==0 .and. md2plus) &
!!$            call yaml_map('md2 was enlarged for PSolver n1-n2 plane mpi partitioning, md2=',md2)
!!$
!!$       !!$omp master !commented out, no parallel region
!!$       if (n3pr1>1) call mpi_environment_set1(kernel%inplane_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc, &
!!$                                             kernel%mpi_env%mpi_comm,n3pr1,n3pr2)
!!$       !!$omp end master
!!$       !!$omp barrier
!!$     else
!!$       n3pr1=1
!!$       n3pr2=kernel%mpi_env%nproc
!!$     endif
!!$
!!$     !!$omp master
!!$     call mpi_environment_set(kernel%part_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm,n3pr2)
!!$     !!$omp end master
!!$     !!$omp barrier

     ! n3pr1, n3pr2 are sent to Free_Kernel subroutine below
     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
     call Periodic_Kernel(n1,n2,n3,nd1,nd2,nd3,&
          kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%kernel,kernel%mpi_env%iproc,kernelnproc,mu0t,alphat,betat,gammat,n3pr2,n3pr1)

     nlimd=n2
     nlimk=n3/2+1

     !no powers of hgrid because they are incorporated in the plane wave treatment
     kernel%grid%scal=1.0_dp/(real(n1,dp)*real(n2*n3,dp)) !to reduce chances of integer overflow


  !else if (kernel%geocode == 'S') then
  case('S')     

     kernel%geo=[1,0,1]

     if (dump) then
        call yaml_map('Boundary Conditions','Surface')
     end if
     !Build the Kernel
     call S_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu,.false.)
     
     if (kernel%igpu == 2) then
       kernel%kernel = f_malloc_ptr((n1/2+1)*n2*n3/kernelnproc,id='kernel%kernel')
     else
       kernel%kernel = f_malloc_ptr(nd1*nd2*nd3/kernelnproc,id='kernel%kernel')
     endif

     !!! PSolver n1-n2 plane mpi partitioning !!!   
     call inplane_partitioning(kernel%mpi_env,md2,n2,n3/2+1,kernel%part_mpi,kernel%inplane_mpi,n3pr1,n3pr2)

!!$     if (kernel%mpi_env%nproc>2*(n3/2+1)-1) then
!!$       n3pr1=kernel%mpi_env%nproc/(n3/2+1)
!!$       n3pr2=n3/2+1
!!$       md2plus=.false.
!!$       if ((md2/kernel%mpi_env%nproc)*n3pr1*n3pr2 < n2) then
!!$           md2plus=.true.
!!$       endif
!!$
!!$       if (kernel%mpi_env%iproc==0 .and. n3pr1>1) &
!!$            call yaml_map('PSolver n1-n2 plane mpi partitioning activated:',&
!!$            trim(yaml_toa(n3pr1,fmt='(i5)'))//' x'//trim(yaml_toa(n3pr2,fmt='(i5)'))//&
!!$            ' taskgroups')
!!$       if (kernel%mpi_env%iproc==0 .and. md2plus) &
!!$            call yaml_map('md2 was enlarged for PSolver n1-n2 plane mpi partitioning, md2=',md2)
!!$
!!$       !$omp master
!!$       if (n3pr1>1) &
!!$            call mpi_environment_set1(kernel%inplane_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc, &
!!$            kernel%mpi_env%mpi_comm,n3pr1,n3pr2)
!!$       !$omp end master
!!$       !$omp barrier
!!$     else
!!$       n3pr1=1
!!$       n3pr2=kernel%mpi_env%nproc
!!$     endif
!!$
!!$     !$omp master
!!$     call mpi_environment_set(kernel%part_mpi,kernel%mpi_env%iproc,&
!!$          kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm,n3pr2)
!!$     !$omp end master
!!$     !$omp barrier

     ! n3pr1, n3pr2 are sent to Free_Kernel subroutine below
     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


     !the kernel must be built and scattered to all the processes
     call Surfaces_Kernel(kernel%mpi_env%iproc,kernelnproc,&
          kernel%mpi_env%mpi_comm,kernel%inplane_mpi%mpi_comm,&
          n1,n2,n3,m3,nd1,nd2,nd3,&
          kernel%hgrids(1),kernel%hgrids(3),kernel%hgrids(2),&
          kernel%itype_scf,kernel%kernel,mu0t,alphat,betat,gammat)!,n3pr2,n3pr1)

     !last plane calculated for the density and the kernel
     nlimd=n2
     nlimk=n3/2+1

     !only one power of hgrid 
     !factor of -4*pi for the definition of the Poisson equation
     kernel%grid%scal=-16.0_dp*atan(1.0_dp)*real(kernel%hgrids(2),dp)/real(n1*n2,dp)/real(n3,dp)

  !else if (kernel%geocode == 'F') then
  case('F')
     kernel%geo=[0,0,0]

     if (dump) then
        call yaml_map('Boundary Conditions','Free')
     end if
!     print *,'debug',kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3)
     !Build the Kernel
     call F_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),m1,m2,m3,n1,n2,n3,&
          md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu,.false.)
 
     if (kernel%igpu == 2) then
       kernel%kernel = f_malloc_ptr((n1/2+1)*n2*n3/kernelnproc,id='kernel%kernel')
     else
       !allocate(kernel%kernel(nd1*nd2*nd3/kernelnproc+ndebug),stat=i_stat)
       kernel%kernel = f_malloc_ptr(nd1*nd2*(nd3/kernelnproc),id='kernel%kernel')
     endif

     !!! PSolver n1-n2 plane mpi partitioning !!!   
     call inplane_partitioning(kernel%mpi_env,md2,n2/2,n3/2+1,kernel%part_mpi,kernel%inplane_mpi,n3pr1,n3pr2)
!!$     if (kernel%mpi_env%nproc>2*(n3/2+1)-1) then
!!$       n3pr1=kernel%mpi_env%nproc/(n3/2+1)
!!$       n3pr2=n3/2+1
!!$       md2plus=.false.
!!$       if ((md2/kernel%mpi_env%nproc)*n3pr1*n3pr2 < n2/2) then
!!$           md2plus=.true.
!!$       endif
!!$
!!$       if (kernel%mpi_env%iproc==0 .and. n3pr1>1) call yaml_map('PSolver n1-n2 plane mpi partitioning activated:',&
!!$          trim(yaml_toa(n3pr1,fmt='(i5)'))//' x'//trim(yaml_toa(n3pr2,fmt='(i5)'))//&
!!$          ' taskgroups')
!!$       if (kernel%mpi_env%iproc==0 .and. md2plus) &
!!$            call yaml_map('md2 was enlarged for PSolver n1-n2 plane mpi partitioning, md2=',md2)
!!$
!!$       !$omp master
!!$       if (n3pr1>1) call mpi_environment_set1(kernel%inplane_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc, &
!!$                                             kernel%mpi_env%mpi_comm,n3pr1,n3pr2)
!!$       !$omp end master
!!$       !$omp barrier
!!$     else
!!$       n3pr1=1
!!$       n3pr2=kernel%mpi_env%nproc
!!$     endif
!!$     !$omp master
!!$     call mpi_environment_set(kernel%part_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm,n3pr2)
!!$     !$omp end master
!!$     !$omp barrier

     ! n3pr1, n3pr2 are sent to Free_Kernel subroutine below
     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

     !the kernel must be built and scattered to all the processes
     call Free_Kernel(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          n1,n2,n3,nd1,nd2,nd3,kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%mpi_env%iproc,kernelnproc,kernel%kernel,mu0t,n3pr2,n3pr1)

     !last plane calculated for the density and the kernel
     nlimd=n2/2
     nlimk=n3/2+1

     !hgrid=max(hx,hy,hz)
     kernel%grid%scal=product(kernel%hgrids)/real(n1*n2,dp)/real(n3,dp)

  !else if (kernel%geocode == 'W') then
  case('W')

     kernel%geo=[0,0,1]

     if (dump) then
        call yaml_map('Boundary Conditions','Wire')
     end if
     call W_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu,.false.)

     if (kernel%igpu == 2) then
       kernel%kernel = f_malloc_ptr((n1/2+1)*n2*n3/kernelnproc,id='kernel%kernel')
     else
       kernel%kernel = f_malloc_ptr(nd1*nd2*(nd3/kernelnproc),id='kernel%kernel')
     endif

     !!! PSolver n1-n2 plane mpi partitioning !!!   
     call inplane_partitioning(kernel%mpi_env,md2,n2,n3/2+1,kernel%part_mpi,kernel%inplane_mpi,n3pr1,n3pr2)

!!$     if (kernel%mpi_env%nproc>2*(n3/2+1)-1) then
!!$       n3pr1=kernel%mpi_env%nproc/(n3/2+1)
!!$       n3pr2=n3/2+1
!!$       md2plus=.false.
!!$       if ((md2/kernel%mpi_env%nproc)*n3pr1*n3pr2 < n2) then
!!$           md2plus=.true.
!!$       endif
!!$
!!$       if (kernel%mpi_env%iproc==0 .and. n3pr1>1) call yaml_map('PSolver n1-n2 plane mpi partitioning activated:',&
!!$          trim(yaml_toa(n3pr1,fmt='(i5)'))//' x'//trim(yaml_toa(n3pr2,fmt='(i5)'))//&
!!$          ' taskgroups')
!!$       if (md2plus) call yaml_map('md2 was enlarged for PSolver n1-n2 plane mpi partitioning, md2=',md2)
!!$
!!$       !$omp master
!!$       if (n3pr1>1) call mpi_environment_set1(kernel%inplane_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc, &
!!$                                             kernel%mpi_env%mpi_comm,n3pr1,n3pr2)
!!$       !$omp end master
!!$       !$omp barrier
!!$     else
!!$       n3pr1=1
!!$       n3pr2=kernel%mpi_env%nproc
!!$     endif
!!$
!!$     !$omp master
!!$     call mpi_environment_set(kernel%part_mpi,kernel%mpi_env%iproc,kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm,n3pr2)
!!$     !$omp end master
!!$     !$omp barrier
!!$
!!$     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


     call Wires_Kernel(kernelnproc,&
          kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          n1,n2,n3,nd1,nd2,nd3,kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%kernel,mu0t)

     nlimd=n2
     nlimk=n3/2+1

     !only one power of hgrid 
     !factor of -1/(2pi) already included in the kernel definition
     kernel%grid%scal=-2.0_dp*kernel%hgrids(1)*kernel%hgrids(2)/real(n1*n2,dp)/real(n3,dp)

  case default
     !if (iproc==0)
     !write(*,'(1x,a,3a)')'createKernel, geocode not admitted',kernel%geocode
     call f_err_throw('createKernel, geocode '//trim(kernel%geocode)//&
          'not admitted')
  end select
  !print *,'thereAAA',iproc,nproc,kernel%mpi_env%iproc,kernel%nproc,kernel%mpi_env%mpi_comm
!call MPI_BARRIER(kernel%mpi_env%mpi_comm,ierr)

  if (dump) then
     call yaml_mapping_open('Memory Requirements per MPI task')
       call yaml_map('Density (MB)',8.0_gp*real(md1*md3,gp)*real(md2/kernel%mpi_env%nproc,gp)/(1024.0_gp**2),fmt='(f8.2)')
       call yaml_map('Kernel (MB)',8.0_gp*real(nd1*nd3,gp)*real(nd2/kernel%mpi_env%nproc,gp)/(1024.0_gp**2),fmt='(f8.2)')
       call yaml_map('Full Grid Arrays (MB)',&
            8.0_gp*real(kernel%ndims(1)*kernel%ndims(2),gp)*real(kernel%ndims(3),gp)/(1024.0_gp**2),fmt='(f8.2)')
       !print the load balancing of the different dimensions on screen
     if (kernel%mpi_env%nproc > 1) then
        call yaml_mapping_open('Load Balancing of calculations')
        jhd=10000
        jzd=10000
        npd=0
        load_balancing: do jproc=0,kernel%mpi_env%nproc-1
           !print *,'jproc,jfull=',jproc,jproc*md2/nproc,(jproc+1)*md2/nproc
           if ((jproc+1)*md2/kernel%mpi_env%nproc <= nlimd) then
              jfd=jproc
           else if (jproc*md2/kernel%mpi_env%nproc <= nlimd) then
              jhd=jproc
              npd=nint(real(nlimd-(jproc)*md2/kernel%mpi_env%nproc,kind=8)/real(md2/kernel%mpi_env%nproc,kind=8)*100.d0)
           else
              jzd=jproc
              exit load_balancing
           end if
        end do load_balancing
        call yaml_mapping_open('Density')
         call yaml_map('MPI tasks 0-'//jfd**'(i5)','100%')
         if (jfd < kernel%mpi_env%nproc-1) &
              call yaml_map('MPI task '//jhd**'(i5)',npd**'(i5)'//'%')
         if (jhd < kernel%mpi_env%nproc-1) &
              call yaml_map('MPI tasks'//jhd**'(i5)'//'-'//&
              (kernel%mpi_env%nproc-1)**'(i3)','0%')
        call yaml_mapping_close()
        jhk=10000
        jzk=10000
        npk=0
       ! if (geocode /= 'P') then
           load_balancingk: do jproc=0,kernel%mpi_env%nproc-1
              !print *,'jproc,jfull=',jproc,jproc*nd3/kernel%mpi_env%nproc,(jproc+1)*nd3/kernel%mpi_env%nproc
              if ((jproc+1)*nd3/kernel%mpi_env%nproc <= nlimk) then
                 jfk=jproc
              else if (jproc*nd3/kernel%mpi_env%nproc <= nlimk) then
                 jhk=jproc
                 npk=nint(real(nlimk-(jproc)*nd3/kernel%mpi_env%nproc,kind=8)/real(nd3/kernel%mpi_env%nproc,kind=8)*100.d0)
              else
                 jzk=jproc
                 exit load_balancingk
              end if
           end do load_balancingk
           call yaml_mapping_open('Kernel')
           call yaml_map('MPI tasks 0-'//trim(yaml_toa(jfk,fmt='(i5)')),'100%')
!           print *,'here,npk',npk
           if (jfk < kernel%mpi_env%nproc-1) &
                call yaml_map('MPI task'//trim(yaml_toa(jhk,fmt='(i5)')),trim(yaml_toa(npk,fmt='(i5)'))//'%')
           if (jhk < kernel%mpi_env%nproc-1) &
                call yaml_map('MPI tasks'//trim(yaml_toa(jhk,fmt='(i5)'))//'-'//&
                yaml_toa(kernel%mpi_env%nproc-1,fmt='(i3)'),'0%')
           call yaml_mapping_close()
        call yaml_map('Complete LB per task','1/3 LB_density + 2/3 LB_kernel')
        call yaml_mapping_close()
     end if
     call yaml_mapping_close() !memory

  end if

  if (kernel%igpu >0) then

    size2=2*n1*n2*n3
    sizek=(n1/2+1)*n2*n3
    size3=n1*n2*n3

   if (kernel%mpi_env%iproc == 0) then
    if (kernel%igpu == 1) then
      if (kernel%keepGPUmemory == 1) then
        call cudamalloc(size2,kernel%work1_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size2,kernel%work2_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%z_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%r_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%oneoeps_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%p_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%q_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%x_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(size3,kernel%corr_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat


        call cudamalloc(sizeof(alpha),kernel%alpha_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(sizeof(alpha),kernel%beta_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(sizeof(alpha),kernel%beta0_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat
        call cudamalloc(sizeof(alpha),kernel%kappa_GPU,i_stat)
        if (i_stat /= 0) print *,'error cudamalloc',i_stat

        call cudamemset(kernel%p_GPU, 0, size3,i_stat)
        if (i_stat /= 0) print *,'error cudamemset p',i_stat
        call cudamemset(kernel%q_GPU, 0, size3,i_stat)
        if (i_stat /= 0) print *,'error cudamemset q',i_stat
        call cudamemset(kernel%x_GPU, 0, size3,i_stat)
        if (i_stat /= 0) print *,'error cudamemset x',i_stat

      endif
      call cudamalloc(sizek,kernel%k_GPU,i_stat)
      if (i_stat /= 0) print *,'error cudamalloc',i_stat
    endif

    pkernel2 = f_malloc((n1/2+1)*n2*n3,id='pkernel2')

    ! transpose kernel for GPU
    do i3=1,n3
       j3=i3+(i3/(n3/2+2))*(n3+2-2*i3)!injective dimension
       do i2=1,n2
          j2=i2+(i2/(n2/2+2))*(n2+2-2*i2)!injective dimension
          do i1=1,n1
             j1=i1+(i1/(n1/2+2))*(n1+2-2*i1)!injective dimension
             !injective index
             ind=j1+(j2-1)*nd1+(j3-1)*nd1*nd2
             !unfolded index
             indt=i2+(j1-1)*n2+(i3-1)*nd1*n2
             pkernel2(indt)=kernel%kernel(ind)
          end do
       end do
    end do
    !offset to zero
    if (kernel%geocode == 'P') pkernel2(1)=0.0_dp

    if (kernel%igpu == 2) kernel%kernel=pkernel2
   endif

   if (kernel%mpi_env%iproc == 0) then
    if (kernel%igpu == 1) then 
      call reset_gpu_data((n1/2+1)*n2*n3,pkernel2,kernel%k_GPU)

      if (dump) call yaml_map('Kernel Copied on GPU',.true.)

      n(1)=n1!kernel%ndims(1)*(2-kernel%geo(1))
      n(2)=n3!kernel%ndims(2)*(2-kernel%geo(2))
      n(3)=n2!kernel%ndims(3)*(2-kernel%geo(3))

      if (kernel%initCufftPlan == 1) then
        call cuda_3d_psolver_general_plan(n,kernel%plan,switch_alg,kernel%geo)
      endif
    endif

    call f_free(pkernel2)
 endif

endif
  
!print *,'there',iproc,nproc,kernel%iproc,kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm
!call MPI_BARRIER(kernel%mpi_comm,ierr)
!print *,'okcomm',kernel%mpi_comm,kernel%iproc
!call MPI_BARRIER(bigdft_mpi%mpi_comm,ierr)

  if (dump) call yaml_mapping_close() !kernel

  !here the FFT_metadata routine can be filled
  kernel%grid%m1 =m1 
  kernel%grid%m2 =m2 
  kernel%grid%m3 =m3 
  kernel%grid%n1 =n1 
  kernel%grid%n2 =n2 
  kernel%grid%n3 =n3 
  kernel%grid%md1=md1
  kernel%grid%md2=md2
  kernel%grid%md3=md3
  kernel%grid%nd1=nd1
  kernel%grid%nd2=nd2
  kernel%grid%nd3=nd3
  kernel%grid%istart=kernel%mpi_env%iproc*(md2/kernel%mpi_env%nproc)
  kernel%grid%iend=min((kernel%mpi_env%iproc+1)*md2/kernel%mpi_env%nproc,kernel%grid%m2)
  if (kernel%grid%istart <= kernel%grid%m2-1) then
     kernel%grid%n3p=kernel%grid%iend-kernel%grid%istart
  else
     kernel%grid%n3p=0
  end if

if (kernel%igpu == 0) then
  !add the checks that are done at the beginning of the Poisson Solver
  if (mod(kernel%grid%n1,2) /= 0 .and. kernel%geo(1)==0) &
       call f_err_throw('Parallel convolution:ERROR:n1') !this can be avoided
  if (mod(kernel%grid%n2,2) /= 0 .and. kernel%geo(3)==0) &
       call f_err_throw('Parallel convolution:ERROR:n2') !this can be avoided
  if (mod(kernel%grid%n3,2) /= 0 .and. kernel%geo(2)==0) &
       call f_err_throw('Parallel convolution:ERROR:n3') !this can be avoided
  if (kernel%grid%nd1 < kernel%grid%n1/2+1) call f_err_throw('Parallel convolution:ERROR:nd1') 
  if (kernel%grid%nd2 < kernel%grid%n2/2+1) call f_err_throw('Parallel convolution:ERROR:nd2')
  if (kernel%grid%nd3 < kernel%grid%n3/2+1) call f_err_throw('Parallel convolution:ERROR:nd3')
  !these can be relaxed
!!$  if (kernel%grid%md1 < n1dim) call f_err_throw('Parallel convolution:ERROR:md1')
!!$  if (kernel%grid%md2 < n2dim) call f_err_throw('Parallel convolution:ERROR:md2')
!!$  if (kernel%grid%md3 < n3dim) call f_err_throw('Parallel convolution:ERROR:md3')
  if (mod(kernel%grid%nd3,kernel%mpi_env%nproc) /= 0) &
       call f_err_throw('Parallel convolution:ERROR:nd3')
  if (mod(kernel%grid%md2,kernel%mpi_env%nproc) /= 0) &
       call f_err_throw('Parallel convolution:ERROR:md2'+&
	yaml_toa(kernel%mpi_env%nproc)+yaml_toa(kernel%grid%md2))
end if
  !allocate and set the distributions for the Poisson Solver
  kernel%counts = f_malloc_ptr([0.to.kernel%mpi_env%nproc-1],id='counts')
  kernel%displs = f_malloc_ptr([0.to.kernel%mpi_env%nproc-1],id='displs')
  do jproc=0,kernel%mpi_env%nproc-1
     istart=min(jproc*(md2/kernel%mpi_env%nproc),m2-1)
     jend=max(min(md2/kernel%mpi_env%nproc,m2-md2/kernel%mpi_env%nproc*jproc),0)
     kernel%counts(jproc)=kernel%grid%m1*kernel%grid%m3*jend
     kernel%displs(jproc)=kernel%grid%m1*kernel%grid%m3*istart
  end do

  select case(trim(str(kernel%method)))
  case('PCG')
  if (present(eps)) then
     if (present(oneosqrteps)) then
        call pkernel_set_epsilon(kernel,eps=eps,oneosqrteps=oneosqrteps)
     else if (present(corr)) then
        call pkernel_set_epsilon(kernel,eps=eps,corr=corr)
     else
        call pkernel_set_epsilon(kernel,eps=eps)
     end if
  else if (present(oneosqrteps) .and. present(corr)) then
     call pkernel_set_epsilon(kernel,oneosqrteps=oneosqrteps,corr=corr)
  else if (present(oneosqrteps) .neqv. present(corr)) then
     call f_err_throw('For PCG method either eps, oneosqrteps and/or corr should be present')
  end if
  case('PI')
     if (present(eps)) then
        if (present(oneoeps)) then
           call pkernel_set_epsilon(kernel,eps=eps,oneoeps=oneoeps)
        else if (present(dlogeps)) then
           call pkernel_set_epsilon(kernel,eps=eps,dlogeps=dlogeps)
        else
           call pkernel_set_epsilon(kernel,eps=eps)
        end if
     else if (present(oneoeps) .and. present(dlogeps)) then
        call pkernel_set_epsilon(kernel,oneoeps=oneoeps,dlogeps=dlogeps)
     else if (present(oneoeps) .neqv. present(dlogeps)) then
        call f_err_throw('For PI method either eps, oneoeps and/or dlogeps should be present')
     end if
  end select

  call f_timing(TCAT_PSOLV_KERNEL,'OF')
  !call timing(kernel%mpi_env%iproc+kernel%mpi_env%igroup*kernel%mpi_env%nproc,'PSolvKernel   ','OF')

END SUBROUTINE pkernel_set


!> set the epsilon in the pkernel structure as a function of the seteps variable.
!! This routine has to be called each time the dielectric function has to be set
subroutine pkernel_set_epsilon(kernel,eps,dlogeps,oneoeps,oneosqrteps,corr)
  implicit none
  !> Poisson Solver kernel
  type(coulomb_operator), intent(inout) :: kernel
  !> dielectric function. Needed for non VAC methods, given in full dimensions
  real(dp), dimension(:,:,:), intent(in), optional :: eps
  !> logarithmic derivative of epsilon. Needed for PCG method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:,:), intent(in), optional :: dlogeps
  !> inverse of epsilon. Needed for PI method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: oneoeps
  !> inverse square root of epsilon. Needed for PCG method.
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: oneosqrteps
  !> correction term of the Generalized Laplacian
  !! if absent, it will be calculated from the array of epsilon
  real(dp), dimension(:,:,:), intent(in), optional :: corr
  !local variables
  integer :: n1,n23,i3s,i23,i3,i2,i1
  real(kind=8) :: pi
  real(dp), dimension(:,:,:), allocatable :: de2,ddeps
  real(dp), dimension(:,:,:,:), allocatable :: deps

  pi=4.0_dp*atan(1.0_dp)
  if (present(corr)) then
     !check the dimensions (for the moment no parallelism)
     if (any(shape(corr) /= kernel%ndims)) &
          call f_err_throw('Error in the dimensions of the array corr,'//&
          trim(yaml_toa(shape(corr))))
  end if
  if (present(eps)) then
     !check the dimensions (for the moment no parallelism)
     if (any(shape(eps) /= kernel%ndims)) &
          call f_err_throw('Error in the dimensions of the array epsilon,'//&
          trim(yaml_toa(shape(eps))))
  end if
  if (present(oneoeps)) then
     !check the dimensions (for the moment no parallelism)
     if (any(shape(oneoeps) /= kernel%ndims)) &
          call f_err_throw('Error in the dimensions of the array oneoeps,'//&
          trim(yaml_toa(shape(oneoeps))))
  end if
  if (present(oneosqrteps)) then
     !check the dimensions (for the moment no parallelism)
     if (any(shape(oneosqrteps) /= kernel%ndims)) &
          call f_err_throw('Error in the dimensions of the array oneosqrteps,'//&
          trim(yaml_toa(shape(oneosqrteps))))
  end if
  if (present(dlogeps)) then
     !check the dimensions (for the moment no parallelism)
     if (any(shape(dlogeps) /= &
          [3,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)])) &
          call f_err_throw('Error in the dimensions of the array dlogeps,'//&
          trim(yaml_toa(shape(dlogeps))))
  end if

  !store the arrays needed for the method
  !the stored arrays are of rank two to collapse indices for
  !omp parallelism
  n1=kernel%ndims(1)
  n23=kernel%ndims(2)*kernel%grid%n3p
  !starting point in third direction
  i3s=kernel%grid%istart+1
  if (kernel%grid%n3p==0) i3s=1
  select case(trim(str(kernel%method)))
  case('PCG')
     kernel%cavity=f_malloc_ptr([n1,n23],id='cavity')
     kernel%pol_charge=f_malloc_ptr([n1,n23],id='pol_charge')
     if (present(corr)) then
        kernel%corr=f_malloc_ptr([n1,n23],id='corr')
        call f_memcpy(n=n1*n23,src=corr(1,1,i3s),dest=kernel%corr)
     else if (present(eps)) then
        kernel%corr=f_malloc_ptr([n1,n23],id='corr')
!!$        !allocate arrays
        deps=f_malloc([kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),3],id='deps')
        de2 =f_malloc(kernel%ndims,id='de2')
        ddeps=f_malloc(kernel%ndims,id='ddeps')

        call fssnord3DmatNabla3varde2_LG(kernel%geocode,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
             eps,deps,de2,kernel%nord,kernel%hgrids)

        call fssnord3DmatDiv3var_LG(kernel%geocode,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
             deps,ddeps,kernel%nord,kernel%hgrids)

        i23=1
        do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
           do i2=1,kernel%ndims(2)
              do i1=1,kernel%ndims(1)
                 kernel%corr(i1,i23)=(-0.125d0/pi)*&
                      (0.5d0*de2(i1,i2,i3)/eps(i1,i2,i3)-ddeps(i1,i2,i3))
              end do
              i23=i23+1
           end do
        end do
        call f_free(deps)
        call f_free(ddeps)
        call f_free(de2)

     else
        call f_err_throw('For method "PCG" the arrays corr or epsilon should be present')   
     end if
     if (present(oneosqrteps)) then
        kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneosqrteps')
        call f_memcpy(n=n1*n23,src=oneosqrteps(1,1,i3s),&
             dest=kernel%oneoeps)
     else if (present(eps)) then
        kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneosqrteps')
        i23=1
        do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
           do i2=1,kernel%ndims(2)
              do i1=1,kernel%ndims(1)
                 kernel%oneoeps(i1,i23)=1.0_dp/sqrt(eps(i1,i2,i3))
              end do
              i23=i23+1
           end do
        end do
     else
        call f_err_throw('For method "PCG" the arrays oneosqrteps or epsilon should be present')   
     end if
  case('PI')
     kernel%cavity=f_malloc_ptr([n1,n23],id='cavity')
     kernel%pol_charge=f_malloc_ptr([n1,n23],id='pol_charge')
     if (present(dlogeps)) then
        !kernel%dlogeps=f_malloc_ptr(src=dlogeps,id='dlogeps')
        kernel%dlogeps=f_malloc_ptr(shape(dlogeps),id='dlogeps')
        call f_memcpy(src=dlogeps,dest=kernel%dlogeps)
     else if (present(eps)) then
        kernel%dlogeps=f_malloc_ptr([3,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)],&
             id='dlogeps')
        !allocate arrays
        deps=f_malloc([kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),3],id='deps')
        call fssnord3DmatNabla3var_LG(kernel%geocode,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
             eps,deps,kernel%nord,kernel%hgrids)
        do i3=1,kernel%ndims(3)
           do i2=1,kernel%ndims(2)
              do i1=1,kernel%ndims(1)
                 !switch and create the logarithmic derivative of epsilon
                 kernel%dlogeps(1,i1,i2,i3)=deps(i1,i2,i3,1)/eps(i1,i2,i3)
                 kernel%dlogeps(2,i1,i2,i3)=deps(i1,i2,i3,2)/eps(i1,i2,i3)
                 kernel%dlogeps(3,i1,i2,i3)=deps(i1,i2,i3,3)/eps(i1,i2,i3)
              end do
           end do
        end do
        call f_free(deps)
     else
        call f_err_throw('For method "PI" the arrays dlogeps or epsilon should be present')
     end if

     if (present(oneoeps)) then
        kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneoeps')
        call f_memcpy(n=n1*n23,src=oneoeps(1,1,i3s),&
             dest=kernel%oneoeps)
     else if (present(eps)) then
        kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneoeps')
        i23=1
        do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
           do i2=1,kernel%ndims(2)
              do i1=1,kernel%ndims(1)
                 kernel%oneoeps(i1,i23)=1.0_dp/eps(i1,i2,i3)
              end do
              i23=i23+1
           end do
        end do
     else
        call f_err_throw('For method "PI" the arrays oneoeps or epsilon should be present')
     end if
  end select

end subroutine pkernel_set_epsilon

!> create the memory space needed to store the arrays for the 
!! description of the cavity
subroutine pkernel_allocate_cavity(kernel,vacuum)
  implicit none
  type(coulomb_operator), intent(inout) :: kernel
  logical, intent(in), optional :: vacuum !<if .true. the cavity is allocated as no cavity exists, i.e. only vacuum
  !local variables
  integer :: n1,n23,i1,i23

  n1=kernel%ndims(1)
  n23=kernel%ndims(2)*kernel%grid%n3p
  select case(trim(str(kernel%method)))
  case('PCG')
     kernel%corr=f_malloc_ptr([n1,n23],id='corr')
     kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneosqrteps')
     kernel%epsinnersccs=f_malloc_ptr([n1,n23],id='epsinnersccs')
     kernel%pol_charge=f_malloc_ptr([n1,n23],id='pol_charge')
     kernel%cavity=f_malloc_ptr([n1,n23],id='cavity')
  case('PI')
     kernel%dlogeps=f_malloc_ptr([3,kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)],&
          id='dlogeps')
     kernel%oneoeps=f_malloc_ptr([n1,n23],id='oneoeps')
     kernel%epsinnersccs=f_malloc_ptr([n1,n23],id='epsinnersccs')
     kernel%pol_charge=f_malloc_ptr([n1,n23],id='pol_charge')
     kernel%cavity=f_malloc_ptr([n1,n23],id='cavity')
  end select
  if (present(vacuum)) then
     if (vacuum) then
        select case(trim(str(kernel%method)))
        case('PCG')
           call f_zero(kernel%corr)
        case('PI')
           call f_zero(kernel%dlogeps)
        end select
        call f_zero(kernel%epsinnersccs)
        call f_zero(kernel%pol_charge)
        call f_zero(kernel%cavity)
        do i23=1,n23
           do i1=1,n1
              kernel%oneoeps(i1,i23)=1.0_dp
           end do
        end do
     end if
  end if

end subroutine pkernel_allocate_cavity

!>put in depsdrho array the extra potential
subroutine sccs_extra_potential(kernel,pot,depsdrho)
  use yaml_output
  implicit none
  type(coulomb_operator), intent(in) :: kernel
  !>complete potential, needed to calculate the derivative
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)), intent(in) :: pot
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2)*kernel%grid%n3p), intent(inout) :: depsdrho
  !local variables
  integer :: i3,i3s,i2,i1,i23,i,n01,n02,n03,unt
  real(dp) :: d2,x
  real(dp), dimension(:,:,:,:), allocatable :: nabla_pot
  !real(dp), dimension(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)) :: pot2,depsdrho1,depsdrho2

  n01=kernel%ndims(1)
  n02=kernel%ndims(2)
  n03=kernel%ndims(3)
  !starting point in third direction
  i3s=kernel%grid%istart+1

  nabla_pot=f_malloc([n01,n02,n03,3],id='nabla_pot')
  !calculate derivative of the potential
  call fssnord3DmatNabla3var_LG(kernel%geocode,n01,n02,n03,pot,nabla_pot,kernel%nord,kernel%hgrids)
  i23=1
  do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
     do i2=1,n02
        do i1=1,n01
           !this section has to be inserted into a optimized calculation of the derivative
           d2=0.0_dp
           do i=1,3
              d2 = d2+nabla_pot(i1,i2,i3,i)**2
           end do
           !depsdrho1(i1,i2,i3)=depsdrho(i1,i23)
           depsdrho(i1,i23)=depsdrho(i1,i23)*d2
           !pot2(i1,i2,i3)=d2
           !depsdrho2(i1,i2,i3)=depsdrho(i1,i23)
        end do
        i23=i23+1
     end do
  end do

!     unt=f_get_free_unit(22)
!     call f_open_file(unt,file='extra_term_line_sccs_x.dat')
!     do i1=1,n01
!        x=i1*kernel%hgrids(1)
!        write(unt,'(1x,I8,5(1x,e22.15))')i1,x,pot(i1,n02/2,n03/2),depsdrho1(i1,n02/2,n03/2),pot2(i1,n02/2,n03/2),depsdrho2(i1,n02/2,n03/2)
!     end do
!     call f_close(unt)
 
  call f_free(nabla_pot)
!  call yaml_map('extra term here',.true.)

  if (kernel%mpi_env%iproc==0 .and. kernel%mpi_env%igroup==0) &
       call yaml_map('Extra SCF potential calculated',.true.)

end subroutine sccs_extra_potential

!>put in pol_charge array the polarization charge
subroutine polarization_charge(kernel,pot,rho)
  implicit none
  type(coulomb_operator), intent(in) :: kernel
  !>complete potential, needed to calculate the derivative
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)), intent(in) :: pot
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2)*kernel%grid%n3p), intent(inout) :: rho
  !local variables
  integer :: i3,i3s,i2,i1,i23,i,n01,n02,n03
  real(dp) :: d2,pi
  real(dp), dimension(:,:,:,:), allocatable :: nabla_pot
  real(dp), dimension(:,:,:), allocatable :: lapla_pot

  pi=4.0_dp*atan(1.0_dp)
  n01=kernel%ndims(1)
  n02=kernel%ndims(2)
  n03=kernel%ndims(3)
  !starting point in third direction
  i3s=kernel%grid%istart+1

  nabla_pot=f_malloc([n01,n02,n03,3],id='nabla_pot')
  lapla_pot=f_malloc([n01,n02,n03],id='lapla_pot')
  !calculate derivative of the potential
  call fssnord3DmatNabla3var_LG(kernel%geocode,n01,n02,n03,pot,nabla_pot,kernel%nord,kernel%hgrids)
  call fssnord3DmatDiv3var_LG(kernel%geocode,n01,n02,n03,nabla_pot,lapla_pot,kernel%nord,kernel%hgrids)
  i23=1
  do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
     do i2=1,n02
        do i1=1,n01
           !this section has to be inserted into a optimized calculation of the
           !derivative
           kernel%pol_charge(i1,i23)=(-0.25_dp/pi)*lapla_pot(i1,i2,i3)-rho(i1,i23)
        end do
        i23=i23+1
     end do
  end do

  call f_free(nabla_pot)
  call f_free(lapla_pot)

  if (kernel%mpi_env%iproc==0 .and. kernel%mpi_env%igroup==0) &
       call yaml_map('Polarization charge calculated',.true.)

end subroutine polarization_charge

!>build the needed arrays of the cavity from a given density
!!according to the SCF cavity definition given by Andreussi et al. JCP 136, 064102 (2012)
!! @warning: for the moment the density is supposed to be not distributed as the 
!! derivatives are calculated sequentially
subroutine pkernel_build_epsilon(kernel,edens,eps0,depsdrho)
  use numerics, only: safe_exp
  use f_utils
  use yaml_output

  implicit none
  !> Poisson Solver kernel
  real(dp), intent(in) :: eps0
  type(coulomb_operator), intent(inout) :: kernel
  !> electronic density in the full box. This is needed because of the calculation of the 
  !! gradient
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3)), intent(inout) :: edens
  !> functional derivative of the sc epsilon with respect to 
  !! the electronic density, in distributed memory
  real(dp), dimension(kernel%ndims(1),kernel%ndims(2)*kernel%grid%n3p), intent(out) :: depsdrho

  
  !local variables
  logical, parameter :: dumpeps=.false.  !.true.
  real(kind=8), parameter :: edensmax = 0.005d0 !0.0050d0
  real(kind=8), parameter :: edensmin = 0.0001d0
  real(kind=8), parameter :: innervalue = 0.9d0
  integer :: n01,n02,n03,i,i1,i2,i3,i23,i3s,unt
  real(dp) :: oneoeps0,oneosqrteps0,pi,coeff,coeff1,fact1,fact2,fact3,r,t,d2,dtx,dd,x,y,z
  real(dp), dimension(:,:,:), allocatable :: ddt_edens,epscurr,epsinner,depsdrho1
  real(dp), dimension(:,:,:,:), allocatable :: nabla_edens

  n01=kernel%ndims(1)
  n02=kernel%ndims(2)
  n03=kernel%ndims(3)
  !starting point in third direction
  i3s=kernel%grid%istart+1

  !allocate the work arrays
  nabla_edens=f_malloc([n01,n02,n03,3],id='nabla_edens')
  ddt_edens=f_malloc(kernel%ndims,id='ddt_edens')
  epsinner=f_malloc(kernel%ndims,id='epsinner')
  depsdrho1=f_malloc(kernel%ndims,id='depsdrho1')
  if (dumpeps) epscurr=f_malloc(kernel%ndims,id='epscurr')

  !build the gradients and the laplacian of the density
  !density gradient in du
  call fssnord3DmatNabla3var_LG(kernel%geocode,n01,n02,n03,edens,nabla_edens,kernel%nord,kernel%hgrids)
  !density laplacian in d2u
  call fssnord3DmatDiv3var_LG(kernel%geocode,n01,n02,n03,nabla_edens,ddt_edens,kernel%nord,kernel%hgrids)

  pi = 4.d0*datan(1.d0)
  oneoeps0=1.d0/eps0
  oneosqrteps0=1.d0/dsqrt(eps0)
  fact1=2.d0*pi/(dlog(edensmax)-dlog(edensmin))
  fact2=(dlog(eps0))/(2.d0*pi)
  fact3=(dlog(eps0))/(dlog(edensmax)-dlog(edensmin))

  if (kernel%mpi_env%iproc==0 .and. kernel%mpi_env%igroup==0) &
       call yaml_map('Rebuilding the cavity for method',trim(str(kernel%method)))

  !now fill the pkernel arrays according the the chosen method
  !if ( trim(PSol)=='PCG') then
  select case(trim(str(kernel%method)))
  case('PCG')
     !in PCG we only need corr, oneosqrtepsilon
     i23=1
     do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
        !do i3=1,n03
        do i2=1,n02
           do i1=1,n01
             if (kernel%epsinnersccs(i1,i23).gt.innervalue) then ! Check for inner sccs cavity value to fix as vacuum
                 !eps(i1,i2,i3)=1.d0
                 kernel%cavity(i1,i23)=1.d0
                 if (dumpeps) epscurr(i1,i2,i3)=1.d0
                 kernel%oneoeps(i1,i23)=1.d0 !oneosqrteps(i1,i2,i3)
!!$                 do i=1,3
!!$                    dlogeps(i,i1,i2,i3)=0.d0
!!$                 end do
                 kernel%corr(i1,i23)=0.d0 !corr(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
                 depsdrho1(i1,i2,i3)=0.d0
             else

              if (dabs(edens(i1,i2,i3)).gt.edensmax) then
                 !eps(i1,i2,i3)=1.d0
                 kernel%cavity(i1,i23)=1.d0
                 if (dumpeps) epscurr(i1,i2,i3)=1.d0
                 kernel%oneoeps(i1,i23)=1.d0 !oneosqrteps(i1,i2,i3)
!!$                 do i=1,3
!!$                    dlogeps(i,i1,i2,i3)=0.d0
!!$                 end do
                 kernel%corr(i1,i23)=0.d0 !corr(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
                 depsdrho1(i1,i2,i3)=0.d0
              else if (dabs(edens(i1,i2,i3)).lt.edensmin) then
                 !eps(i1,i2,i3)=eps0
                 kernel%cavity(i1,i23)=eps0
                 if (dumpeps) epscurr(i1,i2,i3)=eps0
                 kernel%oneoeps(i1,i23)=oneosqrteps0 !oneosqrteps(i1,i2,i3)
!!$                 do i=1,3
!!$                    dlogeps(i,i1,i2,i3)=0.d0
!!$                 end do
                 kernel%corr(i1,i23)=0.d0 !corr(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
                 depsdrho1(i1,i2,i3)=0.d0
              else
                 r=fact1*(log(edensmax)-log(dabs(edens(i1,i2,i3))))
                 t=fact2*(r-sin(r))
                 !eps(i1,i2,i3)=exp(t)
                 kernel%cavity(i1,i23)=safe_exp(t)
                 if (dumpeps) epscurr(i1,i2,i3)=safe_exp(t)
                 kernel%oneoeps(i1,i23)=safe_exp(-0.5d0*t) !oneosqrteps(i1,i2,i3)
                 coeff=fact3*(1.d0-cos(r))
                 dtx=-coeff/dabs(edens(i1,i2,i3))
                 depsdrho(i1,i23)=-safe_exp(t)*0.125d0/pi*dtx
                 depsdrho1(i1,i2,i3)=-safe_exp(t)*0.125d0/pi*dtx
                 d2=0.d0
                 do i=1,3
                    !dlogeps(i,i1,i2,i3)=dtx*nabla_edens(i1,i2,i3,isp,i)
                    d2 = d2+nabla_edens(i1,i2,i3,i)**2
                 end do
                 dd = ddt_edens(i1,i2,i3)
                 coeff1=(0.5d0*(coeff**2)+fact3*fact1*sin(r)+coeff)/((edens(i1,i2,i3))**2)
                 kernel%corr(i1,i23)=(0.125d0/pi)*safe_exp(t)*(coeff1*d2+dtx*dd) !corr(i1,i2,i3)
              end if

             end if
           end do
           i23=i23+1
        end do
     end do
  case('PI')
     !for PI we need  dlogeps,oneoeps
     !first oneovereps
     i23=1
     do i3=i3s,i3s+kernel%grid%n3p-1!kernel%ndims(3)
        do i2=1,n02
           do i1=1,n01
             epsinner(i1,i2,i3)=kernel%epsinnersccs(i1,i23)
             if (kernel%epsinnersccs(i1,i23).gt.innervalue) then ! Check for inner sccs cavity value to fix as vacuum
                 !eps(i1,i2,i3)=1.d0
                 kernel%cavity(i1,i23)=1.d0
                 if (dumpeps) epscurr(i1,i2,i3)=1.d0
                 kernel%oneoeps(i1,i23)=1.d0 !oneoeps(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
             else

              if (dabs(edens(i1,i2,i3)).gt.edensmax) then
                 !eps(i1,i2,i3)=1.d0
                 kernel%cavity(i1,i23)=1.d0
                 if (dumpeps) epscurr(i1,i2,i3)=1.d0
                 kernel%oneoeps(i1,i23)=1.d0 !oneoeps(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
              else if (dabs(edens(i1,i2,i3)).lt.edensmin) then
                 !eps(i1,i2,i3)=eps0
                 kernel%cavity(i1,i23)=eps0
                 if (dumpeps) epscurr(i1,i2,i3)=eps0
                 kernel%oneoeps(i1,i23)=oneoeps0 !oneoeps(i1,i2,i3)
                 depsdrho(i1,i23)=0.d0
              else
                 r=fact1*(log(edensmax)-log(dabs(edens(i1,i2,i3))))
                 t=fact2*(r-sin(r))
                 coeff=fact3*(1.d0-cos(r))
                 dtx=-coeff/dabs(edens(i1,i2,i3))
                 depsdrho(i1,i23)=-safe_exp(t)*0.125d0/pi*dtx
                 kernel%cavity(i1,i23)=safe_exp(t)
                 !eps(i1,i2,i3)=dexp(t)
                 if (dumpeps) epscurr(i1,i2,i3)=safe_exp(t)
                 kernel%oneoeps(i1,i23)=safe_exp(-t) !oneoeps(i1,i2,i3)
              end if

             end if
           end do
           i23=i23+1
        end do
     end do

     !then dlogeps
     do i3=1,n03
        do i2=1,n02
           do i1=1,n01
             if (epsinner(i1,i2,i3).gt.innervalue) then ! Check for inner sccs cavity value to fix as vacuum
              do i=1,3
               kernel%dlogeps(i,i1,i2,i3)=0.d0 !dlogeps(i,i1,i2,i3)
              end do
             else

              if (dabs(edens(i1,i2,i3)).gt.edensmax) then
                 do i=1,3
                    kernel%dlogeps(i,i1,i2,i3)=0.d0 !dlogeps(i,i1,i2,i3)
                 end do
              else if (dabs(edens(i1,i2,i3)).lt.edensmin) then
                 do i=1,3
                    kernel%dlogeps(i,i1,i2,i3)=0.d0 !dlogeps(i,i1,i2,i3)
                 end do
              else
                 r=fact1*(log(edensmax)-log(dabs(edens(i1,i2,i3))))
                 coeff=fact3*(1.d0-cos(r))
                 dtx=-coeff/dabs(edens(i1,i2,i3))
                 do i=1,3
                    kernel%dlogeps(i,i1,i2,i3)=dtx*nabla_edens(i1,i2,i3,i) !dlogeps(i,i1,i2,i3)
                 end do
              end if

             end if
           end do
        end do
     end do

  end select

  if (dumpeps) then

     unt=f_get_free_unit(21)
     call f_open_file(unt,file='epsilon_sccs.dat')
     i1=1!n03/2
     do i2=1,n02
        do i3=1,n03
           write(unt,'(2(1x,I4),3(1x,e14.7))')i2,i3,epscurr(i1,i2,i3),epscurr(n01/2,i2,i3),edens(n01/2,i2,i3)
        end do
     end do
     call f_close(unt)

     unt=f_get_free_unit(22)
     call f_open_file(unt,file='epsilon_line_sccs_x.dat')
     do i1=1,n01
        x=i1*kernel%hgrids(1)
        write(unt,'(1x,I8,4(1x,e22.15))')i1,x,epscurr(i1,n02/2,n03/2),edens(i1,n02/2,n03/2),depsdrho1(i1,n02/2,n03/2)
     end do
     call f_close(unt)

     unt=f_get_free_unit(23)
     call f_open_file(unt,file='epsilon_line_sccs_y.dat')
     do i2=1,n02
        y=i2*kernel%hgrids(2)
        write(unt,'(1x,I8,3(1x,e22.15))')i2,y,epscurr(n01/2,i2,n03/2),edens(n01/2,i2,n03/2)
     end do
     call f_close(unt)

     unt=f_get_free_unit(24)
     call f_open_file(unt,file='epsilon_line_sccs_z.dat')
     do i3=1,n03
        z=i3*kernel%hgrids(3)
        write(unt,'(1x,I8,3(1x,e22.15))')i3,z,epscurr(n01/2,n02/2,i3),edens(n01/2,n02/2,i3)
     end do
     call f_close(unt)

     call f_free(epscurr)

  end if

  call f_free(ddt_edens)
  call f_free(nabla_edens)
  call f_free(epsinner)
  call f_free(depsdrho1)

end subroutine pkernel_build_epsilon
  
subroutine inplane_partitioning(mpi_env,mdz,n2wires,n3planes,part_mpi,inplane_mpi,n3pr1,n3pr2)
  use wrapper_mpi
  use yaml_output
  implicit none
  integer, intent(in) :: mdz !< dimension of the density in the z direction
  integer, intent(in) :: n2wires,n3planes !<number of interesting wires in a plane and number of interesting planes
  type(mpi_environment), intent(in) :: mpi_env !< global env of Psolver
  integer, intent(out) :: n3pr1,n3pr2 !< mpi grid of processors based on mpi_env
  type(mpi_environment), intent(out) :: inplane_mpi,part_mpi !<internal environments for the partitioning
  !local variables
  
  !condition for activation of the inplane partitioning (inactive for the moment due to breaking of OMP parallelization)
  if (mpi_env%nproc>2*(n3planes)-1 .and. .false.) then
     n3pr1=mpi_env%nproc/(n3planes)
     n3pr2=n3planes
!!$     md2plus=.false.
!!$     if ((mdz/mpi_env%nproc)*n3pr1*n3pr2 < n2wires) then
!!$        md2plus=.true.
!!$     endif

     if (mpi_env%iproc==0 .and. n3pr1>1 .and. mpi_env%igroup==0 ) then 
          call yaml_map('PSolver n1-n2 plane mpi partitioning activated:',&
          trim(yaml_toa(n3pr1,fmt='(i5)'))//' x'//trim(yaml_toa(n3pr2,fmt='(i5)'))//&
          ' taskgroups')
        call yaml_map('md2 was enlarged for PSolver n1-n2 plane mpi partitioning, md2=',mdz)
     end if

     if (n3pr1>1) &
          call mpi_environment_set1(inplane_mpi,mpi_env%iproc, &
          mpi_env%mpi_comm,n3pr1,n3pr2)
  else
     n3pr1=1
     n3pr2=mpi_env%nproc
     inplane_mpi=mpi_environment_null()
  endif

  call mpi_environment_set(part_mpi,mpi_env%iproc,&
       mpi_env%nproc,mpi_env%mpi_comm,n3pr2)

end subroutine inplane_partitioning

!>This routine computes 'nord' order accurate first derivatives 
!! on a equally spaced grid with coefficients from 'Mathematica' program.
!! 
!! input:
!! ngrid       = number of points in the grid, 
!! u(ngrid)    = function values at the grid points
!! 
!! output:
!! du(ngrid)   = first derivative values at the grid points
subroutine fssnord3DmatNabla3varde2_LG(geocode,n01,n02,n03,u,du,du2,nord,hgrids)
  implicit none


  !c..declare the pass
  character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  integer, intent(in) :: n01,n02,n03,nord
  real(kind=8), dimension(3), intent(in) :: hgrids
  real(kind=8), dimension(n01,n02,n03) :: u
  real(kind=8), dimension(n01,n02,n03,3) :: du
  real(kind=8), dimension(n01,n02,n03) :: du2

  !c..local variables
  integer :: n,m,n_cell
  integer :: i,j,ib,i1,i2,i3,ii
  real(kind=8), dimension(-nord/2:nord/2,-nord/2:nord/2) :: c1D
  real(kind=8) :: hx,hy,hz
  logical :: perx,pery,perz

  n = nord+1
  m = nord/2
  hx = hgrids(1)!acell/real(n01,kind=8)
  hy = hgrids(2)!acell/real(n02,kind=8)
  hz = hgrids(3)!acell/real(n03,kind=8)
  n_cell = max(n01,n02,n03)

  !buffers associated to the geocode
  !conditions for periodicity in the three directions
  perx=(geocode /= 'F')
  pery=(geocode == 'P')
  perz=(geocode /= 'F')

  ! Beware that n_cell has to be > than n.
  if (n_cell.lt.n) then
     call f_err_throw('Ngrid in has to be setted > than n=nord + 1')
     !stop
  end if

  ! Setting of 'nord' order accurate first derivative coefficient from 'Matematica'.
  !Only nord=2,4,6,8,16

  select case(nord)
  case(2,4,6,8,16)
     !O.K.
  case default
     write(*,*)'Only nord-order 2,4,6,8,16 accurate first derivative'
     stop
  end select

  do i=-m,m
     do j=-m,m
        c1D(i,j)=0.d0
     end do
  end do

  include 'FiniteDiffCorff.inc'

  do i3=1,n03
     do i2=1,n02
        do i1=1,n01

           du(i1,i2,i3,1) = 0.0d0
           du2(i1,i2,i3) = 0.0d0

           if (i1.le.m) then
            if (perx) then
             do j=-m,m
              ii=modulo(i1 + j + n01 - 1, n01 ) + 1
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(ii,i2,i3)/hx
             end do
            else
             do j=-m,m
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,i1-m-1)*u(j+m+1,i2,i3)/hx
             end do
            end if
           else if (i1.gt.n01-m) then
            if (perx) then
             do j=-m,m
              ii=modulo(i1 + j - 1, n01 ) + 1
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(ii,i2,i3)/hx
             end do
            else
             do j=-m,m
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,i1-n01+m)*u(n01 + j - m,i2,i3)/hx
             end do
            end if
           else
              do j=-m,m
                 du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(i1 + j,i2,i3)/hx
              end do
           end if

           du2(i1,i2,i3) = du(i1,i2,i3,1)*du(i1,i2,i3,1)
           du(i1,i2,i3,2) = 0.0d0

           if (i2.le.m) then
            if (pery) then
             do j=-m,m
              ii=modulo(i2 + j + n02 - 1, n02 ) + 1
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,ii,i3)/hy
             end do
            else
             do j=-m,m
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,i2-m-1)*u(i1,j+m+1,i3)/hy
             end do
            end if
           else if (i2.gt.n02-m) then
            if (pery) then
             do j=-m,m
              ii=modulo(i2 + j - 1, n02 ) + 1
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,ii,i3)/hy
             end do
            else
             do j=-m,m
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,i2-n02+m)*u(i1,n02 + j - m,i3)/hy
             end do
            end if
           else
              do j=-m,m
                 du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,i2 + j,i3)/hy
              end do
           end if

           du2(i1,i2,i3) = du2(i1,i2,i3) + du(i1,i2,i3,2)*du(i1,i2,i3,2)

           du(i1,i2,i3,3) = 0.0d0

           if (i3.le.m) then
            if (perz) then
             do j=-m,m
              ii=modulo(i3 + j + n03 - 1, n03 ) + 1
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,ii)/hz
             end do
            else
             do j=-m,m
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,i3-m-1)*u(i1,i2,j+m+1)/hz
             end do
            end if
           else if (i3.gt.n03-m) then
            if (perz) then
             do j=-m,m
              ii=modulo(i3 + j - 1, n03 ) + 1
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,ii)/hz
             end do
            else
             do j=-m,m
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,i3-n03+m)*u(i1,i2,n03 + j - m)/hz
             end do
            end if
           else
              do j=-m,m
                 du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,i3 + j)/hz
              end do
           end if

           du2(i1,i2,i3) = du2(i1,i2,i3) + du(i1,i2,i3,3)*du(i1,i2,i3,3)

        end do
     end do
  end do

end subroutine fssnord3DmatNabla3varde2_LG

!>this routine computes 'nord' order accurate first derivatives 
!!on a equally spaced grid with coefficients from 'Matematica' program.
!!
!!input:
!!ngrid       = number of points in the grid, 
!!u(ngrid)    = function values at the grid points
!!
!!output:
!!du(ngrid)   = first derivative values at the grid points
!!
!!declare the pass
subroutine fssnord3DmatDiv3var_LG(geocode,n01,n02,n03,u,du,nord,hgrids)
  implicit none

  character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  integer, intent(in) :: n01,n02,n03,nord
  real(kind=8), dimension(3), intent(in) :: hgrids
  real(kind=8), dimension(n01,n02,n03,3) :: u
  real(kind=8), dimension(n01,n02,n03) :: du

  !c..local variables
  integer :: n,m,n_cell
  integer :: i,j,ib,i1,i2,i3,ii
  real(kind=8), dimension(-nord/2:nord/2,-nord/2:nord/2) :: c1D
  real(kind=8) :: hx,hy,hz,d1,d2,d3
  real(kind=8), parameter :: zero = 0.d0! 1.0d-11
  logical :: perx,pery,perz

  n = nord+1
  m = nord/2
  hx = hgrids(1)!acell/real(n01,kind=8)
  hy = hgrids(2)!acell/real(n02,kind=8)
  hz = hgrids(3)!acell/real(n03,kind=8)
  n_cell = max(n01,n02,n03)

  !buffers associated to the geocode
  !conditions for periodicity in the three directions
  perx=(geocode /= 'F')
  pery=(geocode == 'P')
  perz=(geocode /= 'F')

  ! Beware that n_cell has to be > than n.
  if (n_cell.lt.n) then
     write(*,*)'ngrid in has to be setted > than n=nord + 1'
     stop
  end if

  ! Setting of 'nord' order accurate first derivative coefficient from 'Matematica'.
  !Only nord=2,4,6,8,16

  select case(nord)
  case(2,4,6,8,16)
     !O.K.
  case default
     write(*,*)'Only nord-order 2,4,6,8,16 accurate first derivative'
     stop
  end select

  do i=-m,m
     do j=-m,m
        c1D(i,j)=0.d0
     end do
  end do

  include 'FiniteDiffCorff.inc'

  do i3=1,n03
     do i2=1,n02
        do i1=1,n01

           du(i1,i2,i3) = 0.0d0

           d1 = 0.d0
           if (i1.le.m) then
              if (perx) then
               do j=-m,m
                ii=modulo(i1 + j + n01 - 1, n01 ) + 1
                d1 = d1 + c1D(j,0)*u(ii,i2,i3,1)!/hx
               end do
              else
               do j=-m,m
                 d1 = d1 + c1D(j,i1-m-1)*u(j+m+1,i2,i3,1)!/hx
               end do
              end if
           else if (i1.gt.n01-m) then
              if (perx) then
               do j=-m,m
                ii=modulo(i1 + j - 1, n01 ) + 1
                d1 = d1 + c1D(j,0)*u(ii,i2,i3,1)!/hx
               end do
              else
               do j=-m,m
                 d1 = d1 + c1D(j,i1-n01+m)*u(n01 + j - m,i2,i3,1)!/hx
               end do
              end if
           else
              do j=-m,m
                 d1 = d1 + c1D(j,0)*u(i1 + j,i2,i3,1)!/hx
              end do
           end if
           d1=d1/hx

           d2 = 0.d0
           if (i2.le.m) then
              if (pery) then
               do j=-m,m
                ii=modulo(i2 + j + n02 - 1, n02 ) + 1
                d2 = d2 + c1D(j,0)*u(i1,ii,i3,2)!/hy
               end do
              else
               do j=-m,m
                 d2 = d2 + c1D(j,i2-m-1)*u(i1,j+m+1,i3,2)!/hy
               end do
              end if
           else if (i2.gt.n02-m) then
              if (pery) then
               do j=-m,m
                ii=modulo(i2 + j - 1, n02 ) + 1
                d2 = d2 + c1D(j,0)*u(i1,ii,i3,2)!/hy
               end do
              else
               do j=-m,m
                 d2 = d2 + c1D(j,i2-n02+m)*u(i1,n02 + j - m,i3,2)!/hy
               end do
              end if
           else
              do j=-m,m
                 d2 = d2 + c1D(j,0)*u(i1,i2 + j,i3,2)!/hy
              end do
           end if
           d2=d2/hy

           d3 = 0.d0
           if (i3.le.m) then
              if (perz) then
               do j=-m,m
                ii=modulo(i3 + j + n03 - 1, n03 ) + 1
                d3 = d3 + c1D(j,0)*u(i1,i2,ii,3)!/hz
               end do
              else
               do j=-m,m
                 d3 = d3 + c1D(j,i3-m-1)*u(i1,i2,j+m+1,3)!/hz
               end do
              end if
           else if (i3.gt.n03-m) then
              if (perz) then
               do j=-m,m
                ii=modulo(i3 + j - 1, n03 ) + 1
                d3 = d3 + c1D(j,0)*u(i1,i2,ii,3)!/hz
               end do
              else
               do j=-m,m
                d3 = d3 + c1D(j,i3-n03+m)*u(i1,i2,n03 + j - m,3)!/hz
               end do
              end if
           else
              do j=-m,m
                 d3 = d3 + c1D(j,0)*u(i1,i2,i3 + j,3)!/hz
              end do
           end if
           d3=d3/hz

           du(i1,i2,i3) = d1+d2+d3

        end do
     end do
  end do

end subroutine fssnord3DmatDiv3var_LG

subroutine fssnord3DmatNabla3var_LG(geocode,n01,n02,n03,u,du,nord,hgrids)
  implicit none

  !c..this routine computes 'nord' order accurate first derivatives 
  !c..on a equally spaced grid with coefficients from 'Matematica' program.

  !c..input:
  !c..ngrid       = number of points in the grid, 
  !c..u(ngrid)    = function values at the grid points

  !c..output:
  !c..du(ngrid)   = first derivative values at the grid points

  !c..declare the pass
  character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  integer, intent(in) :: n01,n02,n03,nord
  real(kind=8), dimension(3), intent(in) :: hgrids
  real(kind=8), dimension(n01,n02,n03) :: u
  real(kind=8), dimension(n01,n02,n03,3) :: du

  !c..local variables
  integer :: n,m,n_cell,ii
  integer :: i,j,ib,i1,i2,i3
  real(kind=8), dimension(-nord/2:nord/2,-nord/2:nord/2) :: c1D
  real(kind=8) :: hx,hy,hz
  logical :: perx,pery,perz

  n = nord+1
  m = nord/2
  hx = hgrids(1)!acell/real(n01,kind=8)
  hy = hgrids(2)!acell/real(n02,kind=8)
  hz = hgrids(3)!acell/real(n03,kind=8)
  n_cell = max(n01,n02,n03)

  !buffers associated to the geocode
  !conditions for periodicity in the three directions
  perx=(geocode /= 'F')
  pery=(geocode == 'P')
  perz=(geocode /= 'F')


  ! Beware that n_cell has to be > than n.
  if (n_cell.lt.n) then
     write(*,*)'ngrid in has to be setted > than n=nord + 1'
     stop
  end if

  ! Setting of 'nord' order accurate first derivative coefficient from 'Matematica'.
  !Only nord=2,4,6,8,16

  select case(nord)
  case(2,4,6,8,16)
     !O.K.
  case default
     write(*,*)'Only nord-order 2,4,6,8,16 accurate first derivative'
     stop
  end select

  do i=-m,m
     do j=-m,m
        c1D(i,j)=0.d0
     end do
  end do

  include 'FiniteDiffCorff.inc'

  do i3=1,n03
     do i2=1,n02
        do i1=1,n01

           du(i1,i2,i3,1) = 0.0d0

           if (i1.le.m) then
            if (perx) then
             do j=-m,m
              ii=modulo(i1 + j + n01 - 1, n01 ) + 1
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(ii,i2,i3)/hx
             end do
            else
             do j=-m,m
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,i1-m-1)*u(j+m+1,i2,i3)/hx
             end do
            end if
           else if (i1.gt.n01-m) then
            if (perx) then
             do j=-m,m
              ii=modulo(i1 + j - 1, n01 ) + 1
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(ii,i2,i3)/hx
             end do
            else
             do j=-m,m
              du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,i1-n01+m)*u(n01 + j - m,i2,i3)/hx
             end do
            end if
           else
            do j=-m,m
             du(i1,i2,i3,1) = du(i1,i2,i3,1) + c1D(j,0)*u(i1 + j,i2,i3)/hx
            end do
           end if

           du(i1,i2,i3,2) = 0.0d0

           if (i2.le.m) then
            if (pery) then
             do j=-m,m
              ii=modulo(i2 + j + n02 - 1, n02 ) + 1
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,ii,i3)/hy
             end do
            else
             do j=-m,m
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,i2-m-1)*u(i1,j+m+1,i3)/hy
             end do
            end if
           else if (i2.gt.n02-m) then
            if (pery) then
             do j=-m,m
              ii=modulo(i2 + j - 1, n02 ) + 1
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,ii,i3)/hy
             end do
            else
             do j=-m,m
              du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,i2-n02+m)*u(i1,n02 + j - m,i3)/hy
             end do
            end if
           else
            do j=-m,m
             du(i1,i2,i3,2) = du(i1,i2,i3,2) + c1D(j,0)*u(i1,i2 + j,i3)/hy
            end do
           end if

           du(i1,i2,i3,3) = 0.0d0

           if (i3.le.m) then
            if (perz) then
             do j=-m,m
              ii=modulo(i3 + j + n03 - 1, n03 ) + 1
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,ii)/hz
             end do
            else
             do j=-m,m
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,i3-m-1)*u(i1,i2,j+m+1)/hz
             end do
            end if
           else if (i3.gt.n03-m) then
            if (perz) then
             do j=-m,m
              ii=modulo(i3 + j - 1, n03 ) + 1
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,ii)/hz
             end do
            else
             do j=-m,m
              du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,i3-n03+m)*u(i1,i2,n03 + j - m)/hz
             end do
            end if
           else
            do j=-m,m
             du(i1,i2,i3,3) = du(i1,i2,i3,3) + c1D(j,0)*u(i1,i2,i3 + j)/hz
            end do
           end if

        end do
     end do
  end do

end subroutine fssnord3DmatNabla3var_LG

!> Like fssnord3DmatNabla but corrected such that the index goes at the beginning
!! Multiplies also times (nabla epsilon)/(4pi*epsilon)= nabla (log(epsilon))/(4*pi)
subroutine fssnord3DmatNabla_LG(geocode,n01,n02,n03,u,nord,hgrids,eta,dlogeps,rhopol,rhores2)
  !use module_defs, only: pi_param
  implicit none

  !c..this routine computes 'nord' order accurate first derivatives 
  !c..on a equally spaced grid with coefficients from 'Matematica' program.

  !c..input:
  !c..ngrid       = number of points in the grid, 
  !c..u(ngrid)    = function values at the grid points

  !c..output:
  !c..du(ngrid)   = first derivative values at the grid points

  !c..declare the pass

  character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
  integer, intent(in) :: n01,n02,n03,nord
  real(kind=8), intent(in) :: eta
  real(kind=8), dimension(3), intent(in) :: hgrids
  real(kind=8), dimension(n01,n02,n03), intent(in) :: u
  real(kind=8), dimension(3,n01,n02,n03), intent(in) :: dlogeps
  real(kind=8), dimension(n01,n02,n03), intent(inout) :: rhopol
  real(kind=8), intent(out) :: rhores2

  !c..local variables
  integer :: n,m,n_cell
  integer :: i,j,ib,i1,i2,i3,isp,i1_max,i2_max,ii
  !real(kind=8), parameter :: oneo4pi=0.25d0/pi_param
  real(kind=8), dimension(-nord/2:nord/2,-nord/2:nord/2) :: c1D,c1DF
  real(kind=8) :: hx,hy,hz,max_diff,fact,dx,dy,dz,res,rho
  real(kind=8) :: oneo4pi,rpoints
  logical :: perx,pery,perz

  oneo4pi=1.0d0/(16.d0*atan(1.d0))

  n = nord+1
  m = nord/2
  hx = hgrids(1)!acell/real(n01,kind=8)
  hy = hgrids(2)!acell/real(n02,kind=8)
  hz = hgrids(3)!acell/real(n03,kind=8)
  n_cell = max(n01,n02,n03)
  rpoints=product(real([n01,n02,n03],dp))

  !buffers associated to the geocode
  !conditions for periodicity in the three directions
  perx=(geocode /= 'F')
  pery=(geocode == 'P')
  perz=(geocode /= 'F')

  ! Beware that n_cell has to be > than n.
  if (n_cell.lt.n) then
     write(*,*)'ngrid in has to be setted > than n=nord + 1'
     stop
  end if

  ! Setting of 'nord' order accurate first derivative coefficient from 'Matematica'.
  !Only nord=2,4,6,8,16
  if (all(nord /=[2,4,6,8,16])) then
     write(*,*)'Only nord-order 2,4,6,8,16 accurate first derivative'
     stop
  end if

  do i=-m,m
     do j=-m,m
        c1D(i,j)=0.d0
        c1DF(i,j)=0.d0
     end do
  end do

  include 'FiniteDiffCorff.inc'

  rhores2=0.d0
  do i3=1,n03
     do i2=1,n02
        do i1=1,n01

           dx=0.d0

           if (i1.le.m) then
              if (perx) then
               do j=-m,m
                ii=modulo(i1 + j + n01 - 1, n01 ) + 1
                dx = dx + c1D(j,0)*u(ii,i2,i3)
               end do
              else
               do j=-m,m
                dx = dx + c1D(j,i1-m-1)*u(j+m+1,i2,i3)
               end do
              end if
           else if (i1.gt.n01-m) then
              if (perx) then
               do j=-m,m
                ii=modulo(i1 + j - 1, n01 ) + 1
                dx = dx + c1D(j,0)*u(ii,i2,i3)
               end do
              else
               do j=-m,m
                dx = dx + c1D(j,i1-n01+m)*u(n01 + j - m,i2,i3)
               end do
              end if
           else
              do j=-m,m
                 dx = dx + c1D(j,0)*u(i1 + j,i2,i3)
              end do
           end if
           dx=dx/hx

           dy = 0.0d0
           if (i2.le.m) then
              if (pery) then
               do j=-m,m
                ii=modulo(i2 + j + n02 - 1, n02 ) + 1
                dy = dy + c1D(j,0)*u(i1,ii,i3)
               end do
              else
               do j=-m,m
                dy = dy + c1D(j,i2-m-1)*u(i1,j+m+1,i3)
               end do
              end if
           else if (i2.gt.n02-m) then
              if (pery) then
               do j=-m,m
                ii=modulo(i2 + j - 1, n02 ) + 1
                dy = dy + c1D(j,0)*u(i1,ii,i3)
               end do
              else
               do j=-m,m
                dy = dy + c1D(j,i2-n02+m)*u(i1,n02 + j - m,i3)
               end do
              end if
           else
              do j=-m,m
                 dy = dy + c1D(j,0)*u(i1,i2 + j,i3)
              end do
           end if
           dy=dy/hy

           dz = 0.0d0
           if (i3.le.m) then
              if (perz) then
               do j=-m,m
                ii=modulo(i3 + j + n03 - 1, n03 ) + 1
                dz = dz + c1D(j,0)*u(i1,i2,ii)
               end do
              else
               do j=-m,m
                dz = dz + c1D(j,i3-m-1)*u(i1,i2,j+m+1)
               end do
              end if
           else if (i3.gt.n03-m) then
              if (perz) then
               do j=-m,m
                ii=modulo(i3 + j - 1, n03 ) + 1
                dz = dz + c1D(j,0)*u(i1,i2,ii)
               end do
              else
               do j=-m,m
                dz = dz + c1D(j,i3-n03+m)*u(i1,i2,n03 + j - m)
               end do
              end if
           else
              do j=-m,m
                 dz = dz + c1D(j,0)*u(i1,i2,i3 + j)
              end do
           end if
           dz=dz/hz

           !retrieve the previous treatment
           res = dlogeps(1,i1,i2,i3)*dx + &
                dlogeps(2,i1,i2,i3)*dy + dlogeps(3,i1,i2,i3)*dz
           res = res*oneo4pi
           rho=rhopol(i1,i2,i3)
           res=res-rho
           res=eta*res
           rhores2=rhores2+res*res
           rhopol(i1,i2,i3)=res+rho

        end do
     end do
  end do
!  rhores2=rhores2/rpoints

end subroutine fssnord3DmatNabla_LG
