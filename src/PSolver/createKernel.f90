!> @file
!!    Routines to create the kernel for Poisson solver
!! @author
!!    Copyright (C) 2002-2011 BigDFT group  (LG)
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 

!> Initialization of the Poisson kernel
!! @param verb   verbosity
!! @param iproc  proc id
!! @param nproc  proc number
function pkernel_init(verb,iproc,nproc,igpu,geocode,ndims,hgrids,itype_scf,&
     mu0_screening,angrad,mpi_env,taskgroup_size) result(kernel)
  use module_base
!! @param iproc  proc id
!! @param nproc  proc number
  use module_types
  use yaml_output
  implicit none
  logical, intent(in) :: verb
  integer, intent(in) :: itype_scf,iproc,nproc,igpu
  character(len=1), intent(in) :: geocode
  integer, dimension(3), intent(in) :: ndims
  real(gp), dimension(3), intent(in) :: hgrids
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

  group_size=0
  if (present(taskgroup_size)) group_size=taskgroup_size
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

  !geocode and ISF family
  kernel%geocode=geocode
  kernel%itype_scf=itype_scf

  !dimensions and grid spacings
  kernel%ndims=ndims
  kernel%hgrids=hgrids

  !gpu acceleration
  kernel%igpu=igpu  

  if (iproc == 0 .and. verb) then 
     if (mu0t==0.0_gp) then 
        call yaml_comment('Kernel Initialization',hfill='-')
        call yaml_open_map('Poisson Kernel Initialization')
     else
        call yaml_open_map('Helmholtz Kernel Initialization')
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
     call yaml_close_map() !kernel
  end if

end function pkernel_init

subroutine pkernel_free(kernel,subname)
  use module_base
  implicit none
  character(len=*), intent(in) :: subname
  type(coulomb_operator), intent(inout) :: kernel
  !local variables
  integer :: i_all,i_stat

  if (associated(kernel%kernel)) then
     i_all=-product(shape(kernel%kernel))*kind(kernel%kernel)
     deallocate(kernel%kernel,stat=i_stat)
     call memocc(i_stat,i_all,'kernel',subname)
  end if

  !free GPU data
  if (kernel%igpu == 1) then
    if (kernel%mpi_env%iproc == 0) then
     call cudafree(kernel%work1_GPU)
     call cudafree(kernel%work2_GPU)
     call cudafree(kernel%k_GPU)
    endif
  end if
  

  !cannot yet free the communicators of the poisson kernel

end subroutine pkernel_free


!> Allocate a pointer which corresponds to the zero-padded FFT slice needed for
!! calculating the convolution with the kernel expressed in the interpolating scaling
!! function basis. The kernel pointer is unallocated on input, allocated on output.
!! SYNOPSIS
!!    @param geocode  Indicates the boundary conditions (BC) of the problem:
!!              - 'F' free BC, isolated systems.
!!                    The program calculates the solution as if the given density is
!!                    "alone" in R^3 space.
!!              - 'S' surface BC, isolated in y direction, periodic in xz plane                
!!                    The given density is supposed to be periodic in the xz plane,
!!                    so the dimensions in these direction mus be compatible with the FFT
!!                    Beware of the fact that the isolated direction is y!
!!              - 'P' periodic BC.
!!                    The density is supposed to be periodic in all the three directions,
!!                    then all the dimensions must be compatible with the FFT.
!!                    No need for setting up the kernel.
!!              - 'W' Wires BC.
!!                    The density is supposed to be periodic in z direction, 
!!                    which has to be compatible with the FFT.
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
subroutine pkernel_set(kernel,wrtmsg) !optional arguments
  use module_base, only: ndebug
  use yaml_output
  implicit none
  logical, intent(in) :: wrtmsg
  type(coulomb_operator), intent(inout) :: kernel
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !local variables
  logical :: dump
  character(len=*), parameter :: subname='createKernel'
  integer :: m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,i_stat
  integer :: jproc,nlimd,nlimk,jfd,jhd,jzd,jfk,jhk,jzk,npd,npk
  real(kind=8) :: alphat,betat,gammat,mu0t
  real(kind=8), dimension(:), allocatable :: pkernel2
  integer :: i1,i2,i3,j1,j2,j3,ind,indt,switch_alg,size2,sizek,i_all,kernelnproc
  integer,dimension(3) :: n

  call timing(kernel%mpi_env%iproc+kernel%mpi_env%igroup*kernel%mpi_env%nproc,'PSolvKernel   ','ON')

  dump=wrtmsg .and. kernel%mpi_env%iproc+kernel%mpi_env%igroup==0

  mu0t=kernel%mu
  alphat=kernel%angrad(1)
  betat=kernel%angrad(2)
  gammat=kernel%angrad(3)

  if (dump) then 
     if (mu0t==0.0_gp) then 
        call yaml_open_map('Poisson Kernel Creation')
     else
        call yaml_open_map('Helmholtz Kernel Creation')
        call yaml_map('Screening Length (AU)',1/mu0t,fmt='(g25.17)')
     end if
  end if

  kernelnproc=kernel%mpi_env%nproc
  if (kernel%igpu == 1) kernelnproc=1

  if (kernel%geocode == 'P') then
     
     if (dump) then
        call yaml_map('Boundary Conditions','Periodic')
     end if
     call P_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc)

     if (kernel%igpu == 2) then
       allocate(kernel%kernel((n1/2+1)*n2*n3/kernelnproc+ndebug),stat=i_stat)
     else
       allocate(kernel%kernel(nd1*nd2*nd3/kernelnproc+ndebug),stat=i_stat)
     endif
     call memocc(i_stat,kernel%kernel,'kernel',subname)

     call Periodic_Kernel(n1,n2,n3,nd1,nd2,nd3,&
          kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%kernel,kernel%mpi_env%iproc,kernelnproc,mu0t,alphat,betat,gammat)

     nlimd=n2
     nlimk=n3/2+1

  else if (kernel%geocode == 'S') then
     
     if (dump) then
        call yaml_map('Boundary Conditions','Surface')
     end if
     !Build the Kernel
     call S_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu)
     
     if (kernel%igpu == 2) then
       allocate(kernel%kernel((n1/2+1)*n2*n3/kernelnproc+ndebug),stat=i_stat)
     else
       allocate(kernel%kernel(nd1*nd2*nd3/kernelnproc+ndebug),stat=i_stat)
     endif
     call memocc(i_stat,kernel%kernel,'kernel',subname)

     !the kernel must be built and scattered to all the processes
     call Surfaces_Kernel(kernel%mpi_env%iproc,kernelnproc,kernel%mpi_env%mpi_comm,n1,n2,n3,m3,nd1,nd2,nd3,&
          kernel%hgrids(1),kernel%hgrids(3),kernel%hgrids(2),&
          kernel%itype_scf,kernel%kernel,mu0t,alphat,betat,gammat)

     !last plane calculated for the density and the kernel
     nlimd=n2
     nlimk=n3/2+1

  else if (kernel%geocode == 'F') then

     if (dump) then
        call yaml_map('Boundary Conditions','Free')
     end if
!     print *,'debug',kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3)
     !Build the Kernel
     call F_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),m1,m2,m3,n1,n2,n3,&
          md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu)
  
     if (kernel%igpu == 2) then
       allocate(kernel%kernel((n1/2+1)*n2*n3/kernelnproc+ndebug),stat=i_stat)
     else
       allocate(kernel%kernel(nd1*nd2*nd3/kernelnproc+ndebug),stat=i_stat)
     endif

     call memocc(i_stat,kernel%kernel,'kernel',subname)

     !the kernel must be built and scattered to all the processes
     call Free_Kernel(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          n1,n2,n3,nd1,nd2,nd3,kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%mpi_env%iproc,kernelnproc,kernel%kernel,mu0t)

     !last plane calculated for the density and the kernel
     nlimd=n2/2
     nlimk=n3/2+1
     
  else if (kernel%geocode == 'W') then

     if (dump) then
        call yaml_map('Boundary Conditions','Wire')
     end if
     call W_FFT_dimensions(kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,kernelnproc,kernel%igpu)

     if (kernel%igpu == 2) then
       allocate(kernel%kernel((n1/2+1)*n2*n3/kernelnproc+ndebug),stat=i_stat)
     else
       allocate(kernel%kernel(nd1*nd2*(nd3/kernelnproc)+ndebug),stat=i_stat)
     endif

     call Wires_Kernel(kernel%mpi_env%iproc,kernelnproc,&
          kernel%ndims(1),kernel%ndims(2),kernel%ndims(3),&
          n1,n2,n3,nd1,nd2,nd3,kernel%hgrids(1),kernel%hgrids(2),kernel%hgrids(3),&
          kernel%itype_scf,kernel%kernel,mu0t)

     nlimd=n2
     nlimk=n3/2+1
              
  else
     
     !if (iproc==0) 
     write(*,'(1x,a,3a)')'createKernel, geocode not admitted',kernel%geocode

     stop
  end if
!print *,'thereAAA',iproc,nproc,kernel%mpi_env%iproc,kernel%nproc,kernel%mpi_env%mpi_comm
!call MPI_BARRIER(kernel%mpi_env%mpi_comm,ierr)

  if (dump) then
     call yaml_open_map('Memory Requirements per MPI task')
       call yaml_map('Density (MB)',8.0_gp*real(md1*md3,gp)*real(md2/kernel%mpi_env%nproc,gp)/(1024.0_gp**2),fmt='(f8.2)')
       call yaml_map('Kernel (MB)',8.0_gp*real(nd1*nd3,gp)*real(nd2/kernel%mpi_env%nproc,gp)/(1024.0_gp**2),fmt='(f8.2)')
       call yaml_map('Full Grid Arrays (MB)',&
            8.0_gp*real(kernel%ndims(1)*kernel%ndims(2),gp)*real(kernel%ndims(3),gp)/(1024.0_gp**2),fmt='(f8.2)')
       !print the load balancing of the different dimensions on screen
     if (kernel%mpi_env%nproc > 1) then
        call yaml_open_map('Load Balancing of calculations')
        !write(*,'(1x,a)')&
        !     'Load Balancing for Poisson Solver related operations:'
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
        call yaml_open_map('Density')
         call yaml_map('MPI tasks 0-'//trim(yaml_toa(jfd,fmt='(i5)')),'100%')
         if (jfd < kernel%mpi_env%nproc-1) &
              call yaml_map('MPI task'//trim(yaml_toa(jhd,fmt='(i5)')),trim(yaml_toa(npd,fmt='(i5)'))//'%')
         if (jhd < kernel%mpi_env%nproc-1) &
              call yaml_map('MPI tasks'//trim(yaml_toa(jhd,fmt='(i5)'))//'-'//&
              yaml_toa(kernel%mpi_env%nproc-1,fmt='(i3)'),'0%')
        call yaml_close_map()
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
           call yaml_open_map('Kernel')
           call yaml_map('MPI tasks 0-'//trim(yaml_toa(jfk,fmt='(i5)')),'100%')
!           print *,'here,npk',npk
           if (jfk < kernel%mpi_env%nproc-1) &
                call yaml_map('MPI task'//trim(yaml_toa(jhk,fmt='(i5)')),trim(yaml_toa(npk,fmt='(i5)'))//'%')
           if (jhk < kernel%mpi_env%nproc-1) &
                call yaml_map('MPI tasks'//trim(yaml_toa(jhk,fmt='(i5)'))//'-'//&
                yaml_toa(kernel%mpi_env%nproc-1,fmt='(i3)'),'0%')
           call yaml_close_map()
        call yaml_map('Complete LB per task','1/3 LB_density + 2/3 LB_kernel')
        call yaml_close_map()
     end if
     call yaml_close_map() !memory

  end if

  if (kernel%igpu >0) then

    size2=2*n1*n2*n3
    sizek=(n1/2+1)*n2*n3

   if (kernel%mpi_env%iproc == 0) then
    if (kernel%igpu == 1) then
      call cudamalloc(size2,kernel%work1_GPU,i_stat)
      if (i_stat /= 0) print *,'error cudamalloc',i_stat
      call cudamalloc(size2,kernel%work2_GPU,i_stat)
      if (i_stat /= 0) print *,'error cudamalloc',i_stat
      call cudamalloc(sizek,kernel%k_GPU,i_stat)
      if (i_stat /= 0) print *,'error cudamalloc',i_stat
    endif

    allocate(pkernel2((n1/2+1)*n2*n3+ndebug),stat=i_stat)
    call memocc(i_stat,pkernel2,'pkernel2',subname)

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

    if(kernel%geocode == 'P') then
     kernel%geo(1)=1
     kernel%geo(2)=1
     kernel%geo(3)=1
    else if (kernel%geocode == 'S') then
     kernel%geo(1)=1
     kernel%geo(2)=0
     kernel%geo(3)=1
    else if (kernel%geocode == 'F') then
     kernel%geo(1)=0
     kernel%geo(2)=0
     kernel%geo(3)=0
    else if (kernel%geocode == 'W') then
     kernel%geo(1)=0
     kernel%geo(2)=0
     kernel%geo(3)=1
    end if

   if (kernel%mpi_env%iproc == 0) then
    if (kernel%igpu == 1) then 
      call reset_gpu_data((n1/2+1)*n2*n3,pkernel2,kernel%k_GPU)

      n(1)=n1!kernel%ndims(1)*(2-kernel%geo(1))
      n(2)=n3!kernel%ndims(2)*(2-kernel%geo(2))
      n(3)=n2!kernel%ndims(3)*(2-kernel%geo(3))

      call cuda_3d_psolver_general_plan(n,kernel%plan,switch_alg,kernel%geo)
     if (dump) call yaml_map('Kernel Copied on GPU',.true.)
    endif

    i_all=-product(shape(pkernel2))*kind(pkernel2)
    deallocate(pkernel2,stat=i_stat)
    call memocc(i_stat,i_all,'pkernel2',subname)  
  endif

 endif
  
!print *,'there',iproc,nproc,kernel%iproc,kernel%mpi_env%nproc,kernel%mpi_env%mpi_comm
!call MPI_BARRIER(kernel%mpi_comm,ierr)
!print *,'okcomm',kernel%mpi_comm,kernel%iproc
!call MPI_BARRIER(bigdft_mpi%mpi_comm,ierr)

  if (dump) call yaml_close_map() !kernel

  call timing(kernel%mpi_env%iproc+kernel%mpi_env%igroup*kernel%mpi_env%nproc,'PSolvKernel   ','OF')

END SUBROUTINE pkernel_set
