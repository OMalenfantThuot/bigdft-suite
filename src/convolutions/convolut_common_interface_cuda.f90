!prepare the keys to be passed in GPU global or constant memory (presumably texture)
subroutine adjust_keys_for_gpu(nseg_c,nseg_f,keyv_c,keyg_c,keyv_f,keyg_f,nvctr_c,keys_GPU)
  use module_base
  implicit none
  integer, intent(in) :: nseg_c,nseg_f,nvctr_c
  integer, dimension(nseg_c), intent(in) :: keyv_c
  integer, dimension(nseg_f), intent(in) :: keyv_f  
  integer, dimension(2,nseg_c), intent(in) :: keyg_c
  integer, dimension(2,nseg_f), intent(in) :: keyg_f
  real(kind=8), intent(out) :: keys_GPU
  !local variables
  character(len=*), parameter :: subname='adjust_keys_for_gpu'
  !maximum number of elements to be passed into a block
  integer :: iseg,i_stat,i_all,segment_elements,nseg_tot,j,nseggpu,nblocks,nseg_block
  integer :: elems_block,nblocks_max,ncuts
  integer, dimension(:,:), allocatable :: keys
  
  call readkeysinfo(elems_block,nblocks_max)
  
  nseg_tot=0
  !assign the keys values, coarse part
  do iseg=1,nseg_c
     segment_elements=keyg_c(2,iseg)-keyg_c(1,iseg)+1
     if (segment_elements <= elems_block) then
        nseg_tot=nseg_tot+1
     else
        ncuts=(segment_elements-1)/elems_block+1
        do j=1,ncuts
           nseg_tot=nseg_tot+1
        end do
     end if
  end do
  !assign the keys values, fine part
  do iseg=1,nseg_f
     segment_elements=keyg_f(2,iseg)-keyg_f(1,iseg)+1
     if (segment_elements <= elems_block) then
        nseg_tot=nseg_tot+1
     else
        ncuts=(segment_elements-1)/elems_block+1
        do j=1,ncuts
           nseg_tot=nseg_tot+1
        end do
     end if
  end do

  !number of segments treated by each block;
  nseg_block =(nseg_tot+1)/nblocks_max +1

  nblocks=min(nblocks_max,nseg_tot+1)

  !print *,'nseg,nblocks',nseg_block,nblocks
  call copynseginfo(nblocks,nseg_block)

  nseggpu=nseg_block*nblocks


  !allocate the array to be copied
  allocate(keys(4,nseggpu+ndebug),stat=i_stat)
  call memocc(i_stat,keys,'keys',subname)
  
  nseg_tot=0
  !assign the keys values, coarse part
  do iseg=1,nseg_c
     segment_elements=keyg_c(2,iseg)-keyg_c(1,iseg)+1
     if (segment_elements <= elems_block) then
        nseg_tot=nseg_tot+1;
        keys(1,nseg_tot)=1 !which means coarse segment
        keys(2,nseg_tot)=segment_elements
        keys(3,nseg_tot)=keyv_c(iseg)
        keys(4,nseg_tot)=keyg_c(1,iseg)
     else
        ncuts=(segment_elements-1)/elems_block+1
        do j=1,ncuts-1
           nseg_tot=nseg_tot+1
           keys(1,nseg_tot)=1
           keys(2,nseg_tot)=elems_block
           keys(3,nseg_tot)=keyv_c(iseg)+(j-1)*elems_block
           keys(4,nseg_tot)=keyg_c(1,iseg)+(j-1)*elems_block
        end do
        j=ncuts
        nseg_tot=nseg_tot+1
        keys(1,nseg_tot)=1
        keys(2,nseg_tot)=segment_elements-(j-1)*elems_block
        keys(3,nseg_tot)=keyv_c(iseg)+(j-1)*elems_block
        keys(4,nseg_tot)=keyg_c(1,iseg)+(j-1)*elems_block
     end if
  end do
  !assign the keys values, fine part
  do iseg=1,nseg_f
     segment_elements=keyg_f(2,iseg)-keyg_f(1,iseg)+1
     if (segment_elements <= elems_block) then
        nseg_tot=nseg_tot+1;
        keys(1,nseg_tot)=nvctr_c !which means fine segment
        keys(2,nseg_tot)=segment_elements
        keys(3,nseg_tot)=keyv_f(iseg)
        keys(4,nseg_tot)=keyg_f(1,iseg)
     else
        ncuts=(segment_elements-1)/elems_block+1
        do j=1,ncuts-1
           nseg_tot=nseg_tot+1
           keys(1,nseg_tot)=nvctr_c
           keys(2,nseg_tot)=elems_block
           keys(3,nseg_tot)=keyv_f(iseg)+(j-1)*elems_block
           keys(4,nseg_tot)=keyg_f(1,iseg)+(j-1)*elems_block
        end do
        j=ncuts
        nseg_tot=nseg_tot+1
        keys(1,nseg_tot)=nvctr_c
        keys(2,nseg_tot)=segment_elements-(j-1)*elems_block
        keys(3,nseg_tot)=keyv_f(iseg)+(j-1)*elems_block
        keys(4,nseg_tot)=keyg_f(1,iseg)+(j-1)*elems_block
     end if
  end do

  !fill the last part of the segments
  do iseg=nseg_tot+1,nblocks*nseg_block
     keys(1,iseg)=0
     keys(2,iseg)=0
     keys(3,iseg)=0
     keys(4,iseg)=0
  end do

  !allocate the gpu pointer and copy the values
  !!!call GPU_int_allocate(4*nseggpu,keys_GPU,i_stat)
  call sg_gpu_alloc(keys_GPU,4*nseggpu,4,i_stat)

!!  call GPU_int_send(4*nseggpu,keys,keys_GPU,i_stat)
  call  sg_gpu_imm_send(keys_GPU,keys,4*nseggpu,4,i_stat)
  
  i_all=-product(shape(keys))*kind(keys)
  deallocate(keys,stat=i_stat)
  call memocc(i_stat,i_all,'keys',subname)


end subroutine adjust_keys_for_gpu

subroutine prepare_gpu_for_locham(n1,n2,n3,nspin,hx,hy,hz,wfd,orbs,GPU)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: n1,n2,n3,nspin
  real(gp), intent(in) :: hx,hy,hz
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(orbitals_data), intent(in) :: orbs
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  character(len=*), parameter :: subname='prepare_gpu_for_locham'
  integer :: i_stat,iorb

  print *, " in   prepare_gpu_for_locham " 
 
  call adjust_keys_for_gpu(wfd%nseg_c,wfd%nseg_f,wfd%keyv(1),wfd%keyg(1,1),&
       wfd%keyv(wfd%nseg_c+1),wfd%keyg(1,wfd%nseg_c+1),wfd%nvctr_c,GPU%keys)

  !create parameters
  call creategpuparameters(n1,n2,n3,hx,hy,hz)

  !allocate the number of GPU pointers for the wavefunctions
  allocate(GPU%psi(orbs%norbp+ndebug),stat=i_stat)
  call memocc(i_stat,GPU%psi,'GPU%psi',subname)

  !allocate space on the card
  !allocate the compressed wavefunctions such as to be used as workspace
  do iorb=1,orbs%norbp
     call sg_gpu_alloc(GPU%psi(iorb),(2*n1+2)*(2*n2+2)*(2*n3+2)*orbs%nspinor,8,i_stat)
  end do

  call sg_gpu_alloc(GPU%work1,(2*n1+2)*(2*n2+2)*(2*n3+2),8,i_stat)
  call sg_gpu_alloc(GPU%work2,(2*n1+2)*(2*n2+2)*(2*n3+2),8,i_stat)
  call sg_gpu_alloc(GPU%work3,(2*n1+2)*(2*n2+2)*(2*n3+2),8,i_stat)

  !here spin value should be taken into account
  call sg_gpu_alloc(GPU%rhopot,(2*n1+2)*(2*n2+2)*(2*n3+2)*nspin,8,i_stat)

  !needed for the preconditioning
  call sg_gpu_alloc(GPU%r,(wfd%nvctr_c+7*wfd%nvctr_f),8,i_stat)

  call sg_gpu_alloc(GPU%d,(2*n1+2)*(2*n2+2)*(2*n3+2),8,i_stat)

  
  if(GPUshare .and. GPUconv) then
     !gpu sharing is enabled, we need pinned memory and set useDynamic on the GPU_pointer structure
     call sg_cpu_pinned_alloc(GPU%pinned_in,(2*n1+2)*(2*n2+2)*(2*n3+2)*orbs%nspinor,8,i_stat)
     call sg_cpu_pinned_alloc(GPU%pinned_out,(2*n1+2)*(2*n2+2)*(2*n3+2)*orbs%nspinor,8,i_stat)
     
     GPU%useDynamic = .true.
  else
     GPU%useDynamic = .false.
  end if
  
  !at the starting point do not use full_locham
  GPU%full_locham = .false.

end subroutine prepare_gpu_for_locham



subroutine free_gpu(GPU,norbp)
  use module_base
  use module_types
  implicit none
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  character(len=*), parameter :: subname='free_GPU'
  integer :: i_stat,iorb,norbp,i_all
  

  call sg_gpu_free(GPU%r,i_stat)
  call sg_gpu_free(GPU%d,i_stat)
  call sg_gpu_free(GPU%work1,i_stat)
  call sg_gpu_free(GPU%work2,i_stat)
  call sg_gpu_free(GPU%work3,i_stat)
  call sg_gpu_free(GPU%keys,i_stat)
  call sg_gpu_free(GPU%rhopot,i_stat)



  do iorb=1,norbp
     call sg_gpu_free(GPU%psi(iorb),i_stat)
  end do

  i_all=-product(shape(GPU%psi))*kind(GPU%psi)
  deallocate(GPU%psi,stat=i_stat)
  call memocc(i_stat,i_all,'GPU%psi',subname)

end subroutine free_gpu


subroutine local_hamiltonian_GPU(iproc,orbs,lr,hx,hy,hz,&
     nspin,pot,psi,hpsi,ekin_sum,epot_sum,GPU)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,nspin
  real(gp), intent(in) :: hx,hy,hz
  type(orbitals_data), intent(in) :: orbs
  type(locreg_descriptors), intent(in) :: lr
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%nspinor*orbs%norbp), intent(in) :: psi
  real(wp), dimension(lr%d%n1i,lr%d%n2i,lr%d%n3i,nspin) :: pot
  real(gp), intent(out) :: ekin_sum,epot_sum
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%nspinor*orbs%norbp), intent(out) :: hpsi

  type(GPU_pointers), intent(inout) :: GPU
  !local variables
  character(len=*), parameter :: subname='local_hamiltonian_GPU'

  integer :: i_stat,iorb

  !stream ptr array
  real(kind=8), dimension(orbs%norbp) :: tab_stream_ptr
  real(kind=8) :: stream_ptr_first_trsf



  if (.not. GPU%useDynamic) then 
     ! ** GPU are not shared

     !copy the potential on GPU
     call sg_gpu_imm_send(GPU%rhopot,pot,lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,i_stat)

     !if required copy the wavefunctions on the GPU 
     if (GPU%full_locham) then
        do iorb=1,orbs%norbp
           call sg_gpu_imm_send(GPU%psi(iorb),&
                psi(1,(iorb-1)*orbs%nspinor+1),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)
        end do
     end if

     !calculate the local hamiltonian
     !WARNING: the difference between full_locham and normal locham is inside
     call gpu_locham(lr%d%n1,lr%d%n2,lr%d%n3,hx,hy,hz,orbs,GPU,ekin_sum,epot_sum)
     
     
     !copy back the compressed wavefunctions
     !receive the data of GPU
     do iorb=1,orbs%norbp
        call sg_gpu_imm_recv(hpsi(1,(iorb-1)*orbs%nspinor+1),GPU%psi(iorb),&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
             i_stat)
     end do
     
  else
     !GPU are shared
     
     !print *,'here',GPU%full_locham
     !copy the potential on GPU
     call sg_create_stream(stream_ptr_first_trsf)
 
     call sg_memcpy_f_to_c(GPU%pinned_in,&
          pot,&
          lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,&
          stream_ptr_first_trsf,i_stat)


     call sg_gpu_pi_send(GPU%rhopot,&
          GPU%pinned_in,&
          lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,&
          stream_ptr_first_trsf,i_stat)
     
     call sg_launch_all_streams() !stream are removed after this call, the queue becomes empty
     
     do iorb=1,orbs%norbp      

        !each orbital create one stream
        call sg_create_stream(tab_stream_ptr(iorb))
        
        if (GPU%full_locham) then
           call sg_memcpy_f_to_c(GPU%pinned_in,&
                psi(1,(iorb-1)*orbs%nspinor+1),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)
           
           
           call sg_gpu_pi_send(GPU%psi(iorb),&
                GPU%pinned_in,&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)
        end if
        
        !calculate the local hamiltonian
        !WARNING: the difference between full_locham and normal locham is inside
        call gpu_locham_helper_stream(lr%d%n1,lr%d%n2,lr%d%n3,hx,hy,hz,orbs,GPU,ekin_sum,epot_sum,iorb,tab_stream_ptr(iorb))
        
        
        !copy back the compressed wavefunctions
        !receive the data of GPU
        call sg_gpu_pi_recv(GPU%pinned_out,&
             GPU%psi(iorb),&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
             tab_stream_ptr(iorb),i_stat)


        call sg_memcpy_c_to_f(hpsi(1,(iorb-1)*orbs%nspinor+1),&
             GPU%pinned_out,&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
             tab_stream_ptr(iorb),i_stat)
        
     end do
     call sg_launch_all_streams() !stream are removed after this call, the queue becomes empty
     
  end if
  
  
end subroutine local_hamiltonian_GPU


subroutine preconditionall_GPU(iproc,nproc,orbs,lr,hx,hy,hz,ncong,hpsi,gnrm,GPU)
  use module_base
  use module_types
  implicit none
  type(orbitals_data), intent(in) :: orbs
  integer, intent(in) :: iproc,nproc,ncong
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: lr
  real(dp), intent(out) :: gnrm
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%nspinor,orbs%norbp), intent(inout) :: hpsi
  !local variables
  character(len=*), parameter :: subname='preconditionall_GPU'
  integer ::  ierr,iorb,i_stat,ncplx,i_all,inds
  real(wp) :: scpr
  type(GPU_pointers), intent(inout) :: GPU
  type(workarr_precond) :: w
  real(wp), dimension(:,:), allocatable :: b
  real(gp), dimension(0:7) :: scal
  !stream ptr array
  real(kind=8), dimension(orbs%norbp) :: tab_stream_ptr

  ncplx=1
  
  call allocate_work_arrays(lr%geocode,lr%hybrid_on,ncplx,lr%d,w)


  if (.not. GPU%useDynamic) then

  !arrays for the CG procedure
  allocate(b(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),1+ndebug),stat=i_stat)
  call memocc(i_stat,b,'b',subname)


!!$     do iorb=1,orbs%norbp
!!$        
!!$        call sg_gpu_imm_send(GPU%psi(iorb),&
!!$             hpsi(1+((lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor)*((iorb-1)*orbs%nspinor)),&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)
!!$     end do
!!$   
!!$     call gpu_precond(lr,hx,hy,hz,GPU,orbs%norbp,ncong,&
!!$          orbs%eval(min(orbs%isorb+1,orbs%norb)),gnrm)
!!$   
!!$
!!$     do iorb=1,orbs%norbp
!!$  
!!$        call sg_gpu_imm_recv(hpsi(1+((lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor)*((iorb-1)*orbs%nspinor)),&
!!$             GPU%psi(iorb),&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)
!!$        
!!$     end do
     !new preconditioner, takes into account the FFT preconditioning on CPU
     gnrm=0.0_dp
     do iorb=1,orbs%norbp

        do inds=1,orbs%nspinor,ncplx

           !the nrm2 function can be replaced here by ddot
           scpr=nrm2(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),hpsi(1,inds,iorb),1)
           gnrm=gnrm+orbs%kwgts(orbs%iokpt(iorb))*scpr**2

           call precondition_preconditioner(lr,ncplx,hx,hy,hz,scal,0.5_wp,w,&
                hpsi(1,inds,iorb),b)

           call sg_gpu_imm_send(GPU%psi(iorb),&
                hpsi(1,inds,iorb),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)

           !this is the b array
           call sg_gpu_imm_send(GPU%rhopot,b,&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)

           call gpu_intprecond(lr,hx,hy,hz,GPU,orbs%norbp,ncong,&
                orbs%eval(min(orbs%isorb+1,orbs%norb)),iorb)

           call sg_gpu_imm_recv(&
                hpsi(1,inds,iorb),&
                GPU%psi(iorb),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)
           
        end do

     end do

  else

     !====use dynamic repartition

!!$     do iorb=1,orbs%norbp
!!$        inds=1
!!$        call sg_create_stream(tab_stream_ptr(iorb))
!!$
!!$        call sg_memcpy_f_to_c(GPU%pinned_in,&
!!$             hpsi(1,inds,iorb),&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
!!$             tab_stream_ptr(iorb),i_stat)
!!$
!!$        call sg_gpu_pi_send(GPU%psi(iorb),&
!!$             GPU%pinned_in,&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
!!$             tab_stream_ptr(iorb),i_stat)
!!$
!!$        call gpu_precond_helper_stream(lr,hx,hy,hz,GPU,orbs%norbp,ncong,&
!!$             orbs%eval(min(orbs%isorb+1,orbs%norb)),gnrm,iorb,tab_stream_ptr(iorb))
!!$
!!$        call sg_gpu_pi_recv(GPU%pinned_out,&  
!!$             GPU%psi(iorb),&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
!!$             tab_stream_ptr(iorb),i_stat)
!!$
!!$        call sg_memcpy_c_to_f(hpsi(1,inds,iorb),&
!!$             GPU%pinned_out,&
!!$             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
!!$             tab_stream_ptr(iorb),i_stat)
!!$
!!$     end do

     !arrays for the CG procedure
     allocate(b(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),orbs%norbp+ndebug),stat=i_stat)
     call memocc(i_stat,b,'b',subname)

     gnrm=0.0_dp

     do iorb=1,orbs%norbp
        do inds=1,orbs%nspinor,ncplx !the streams should be more if nspinor>1
           !the nrm2 function can be replaced here by ddot
           scpr=nrm2(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),hpsi(1,inds,iorb),1)
           gnrm=gnrm+orbs%kwgts(orbs%iokpt(iorb))*scpr**2

           call precondition_preconditioner(lr,ncplx,hx,hy,hz,scal,0.5_wp,w,&
                hpsi(1,inds,iorb),b(1,iorb))

           call sg_create_stream(tab_stream_ptr(iorb))

!!$           call gpu_precondprecond_helper_stream(lr,hx,hy,hz,0.5_wp,scal,ncplx,w,&
!!$                hpsi(1,inds,iorb),b(1,iorb),tab_stream_ptr(iorb))

           call sg_memcpy_f_to_c(GPU%pinned_in,&
                hpsi(1,inds,iorb),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

           call sg_gpu_pi_send(GPU%psi(iorb),&
                GPU%pinned_in,&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

           !send also the b array in the rhopot space
           call sg_memcpy_f_to_c(GPU%pinned_in,&
                b(1,iorb),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

           call sg_gpu_pi_send(GPU%rhopot,&
                GPU%pinned_in,&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

           call sg_intprecond_adapter(lr%d%n1,lr%d%n2,lr%d%n3,&
                lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,&
                0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
                GPU%psi(iorb),&
                GPU%keys,GPU%r,GPU%rhopot,GPU%d,GPU%work1,GPU%work2,GPU%work3,&
                0.5_wp,ncong,tab_stream_ptr(iorb))

           call sg_gpu_pi_recv(GPU%pinned_out,&  
                GPU%psi(iorb),&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

           call sg_memcpy_c_to_f(hpsi(1,inds,iorb),&
                GPU%pinned_out,&
                (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
                tab_stream_ptr(iorb),i_stat)

        end do
     end do


     call sg_launch_all_streams() !stream are removed after this call, the queue becomes empty

     !end of dynamic repartition
  end if

  i_all=-product(shape(b))*kind(b)
  deallocate(b,stat=i_stat)
  call memocc(i_stat,i_all,'b',subname)

  call deallocate_work_arrays(lr%geocode,lr%hybrid_on,ncplx,w)


end subroutine preconditionall_GPU


subroutine local_partial_density_GPU(iproc,nproc,orbs,&
     nrhotot,lr,hxh,hyh,hzh,nspin,psi,rho_p,GPU)
  use module_base
  use module_types
  use module_interfaces
  implicit none
  integer, intent(in) :: iproc,nproc,nrhotot
  type(orbitals_data), intent(in) :: orbs
  integer, intent(in) :: nspin
  real(gp), intent(in) :: hxh,hyh,hzh
  type(locreg_descriptors), intent(in) :: lr
 
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%norbp*orbs%nspinor), intent(in) :: psi
  real(dp), dimension(lr%d%n1i,lr%d%n2i,nrhotot,max(nspin,orbs%nspinor)), intent(inout) :: rho_p
  type(GPU_pointers), intent(inout) :: GPU
  
  integer:: iorb,i_stat
  real(kind=8) :: stream_ptr


  if (.not. GPU%useDynamic) then 

        
     !copy the wavefunctions on GPU
     do iorb=1,orbs%norbp
  
        call sg_gpu_imm_send(GPU%psi(iorb),&
             psi(1,(iorb-1)*orbs%nspinor+1),&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,i_stat)
     end do
       
     !calculate the density
     call gpu_locden(lr,nspin,hxh,hyh,hzh,orbs,GPU)
     
  
     call sg_gpu_imm_recv(rho_p,GPU%rhopot,lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,i_stat)
  else
     !use dynamic GPU
     
     call sg_create_stream(stream_ptr) !only one stream, it could be good to optimize that
     !copy the wavefunctions on GPU
     do iorb=1,orbs%norbp
 
        call sg_memcpy_f_to_c(GPU%pinned_in,&
             psi(1,(iorb-1)*orbs%nspinor+1),&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
             stream_ptr,i_stat)
        
 
        call sg_gpu_pi_send(GPU%psi(iorb),&
             GPU%pinned_in,&
             (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%nspinor,8,&
             stream_ptr,i_stat)

     end do
     
       
     
     !calculate the density
     call gpu_locden_helper_stream(lr,nspin,hxh,hyh,hzh,orbs,GPU,stream_ptr)
     
     !copy back the results and leave the uncompressed wavefunctions on the card
     
      
     call sg_gpu_pi_recv(GPU%pinned_out,&
          GPU%rhopot,&
          lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,&
          stream_ptr,i_stat)
     
     
      call sg_memcpy_c_to_f(rho_p,&
          GPU%pinned_out,&
          lr%d%n1i*lr%d%n2i*lr%d%n3i*nspin,8,&
          stream_ptr,i_stat)
     

     
     
     call sg_launch_all_streams() !stream are removed after this call, the queue becomes empty
     
     
  end if
  

end subroutine local_partial_density_GPU


subroutine gpu_locden(lr,nspin,hxh,hyh,hzh,orbs,GPU)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: nspin
  real(gp), intent(in) :: hxh,hyh,hzh
  type(locreg_descriptors), intent(in) :: lr
  type(orbitals_data), intent(in) :: orbs
  type(GPU_pointers), intent(out) :: GPU
  !local variables

  call gpulocden(lr%d%n1,lr%d%n2,lr%d%n3,orbs%norbp,nspin,&
       hxh,hyh,hzh,&
       orbs%occup(min(orbs%isorb+1,orbs%norb)),&
       orbs%spinsgn(min(orbs%isorb+1,orbs%norb)),&
       GPU%psi,GPU%keys,&
       GPU%work1,GPU%work2,GPU%rhopot)

end subroutine gpu_locden

subroutine gpu_locden_helper_stream(lr,nspin,hxh,hyh,hzh,orbs,GPU,stream_ptr)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: nspin
  real(gp), intent(in) :: hxh,hyh,hzh
  type(locreg_descriptors), intent(in) :: lr
  type(orbitals_data), intent(in) :: orbs
  type(GPU_pointers), intent(out) :: GPU
  real(kind=8), intent(in) :: stream_ptr
  !local variables

  call sg_locden_adapter(lr%d%n1,lr%d%n2,lr%d%n3,orbs%norbp,nspin,&
       hxh,hyh,hzh,&
       orbs%occup(min(orbs%isorb+1,orbs%norb)),&
       orbs%spinsgn(min(orbs%isorb+1,orbs%norb)),&
       GPU%psi,GPU%keys,&
       GPU%work1,GPU%work2,GPU%rhopot,&
       stream_ptr)

end subroutine gpu_locden_helper_stream


subroutine gpu_locham(n1,n2,n3,hx,hy,hz,orbs,GPU,ekin_sum,epot_sum)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(gp), intent(in) :: hx,hy,hz
  real(gp), intent(out) :: ekin_sum,epot_sum
  type(orbitals_data), intent(in) :: orbs
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: i_stat,iorb
  real(gp) :: ekin,epot
  ekin_sum=0.0_gp
  epot_sum=0.0_gp

  if (GPU%full_locham) then
     do iorb=1,orbs%norbp

        call gpufulllocham(n1,n2,n3,0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
             GPU%psi(iorb),GPU%rhopot,GPU%keys,&
             GPU%work1,GPU%work2,GPU%work3,epot,ekin)

        ekin_sum=ekin_sum+orbs%occup(iorb+orbs%isorb)*ekin
        epot_sum=epot_sum+orbs%occup(iorb+orbs%isorb)*epot

     end do
  else
     do iorb=1,orbs%norbp

        call gpulocham(n1,n2,n3,0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
             GPU%psi(iorb),GPU%rhopot,GPU%keys,&
             GPU%work1,GPU%work2,GPU%work3,epot,ekin)

        ekin_sum=ekin_sum+orbs%occup(iorb+orbs%isorb)*ekin
        epot_sum=epot_sum+orbs%occup(iorb+orbs%isorb)*epot

     end do
  end if

end subroutine gpu_locham


subroutine gpu_locham_helper_stream(n1,n2,n3,hx,hy,hz,orbs,GPU,ekin_sum,epot_sum,iorb,stream_ptr)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(gp), intent(in) :: hx,hy,hz
  real(gp), intent(out) :: ekin_sum,epot_sum
  type(orbitals_data), intent(in) :: orbs
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: i_stat
  integer, intent(in) ::iorb
  real(gp) :: ekin,epot

  real(gp) :: ocupGPU
  real(kind=8), intent(in) :: stream_ptr 

  ekin_sum=0.0_gp
  epot_sum=0.0_gp


  ocupGPU = orbs%occup(iorb+orbs%isorb)

  if (GPU%full_locham) then
     call sg_fulllocham_adapter(n1,n2,n3,0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
          GPU%psi(iorb),GPU%rhopot,GPU%keys,&
          GPU%work1,GPU%work2,GPU%work3,epot_sum,ekin_sum,ocupGPU,stream_ptr)
  else
     call sg_locham_adapter(n1,n2,n3,0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
          GPU%psi(iorb),GPU%rhopot,GPU%keys,&
          GPU%work1,GPU%work2,GPU%work3,epot_sum,ekin_sum,ocupGPU,stream_ptr)
  end if


end subroutine gpu_locham_helper_stream


subroutine gpu_precond(lr,hx,hy,hz,GPU,norbp,ncong,eval,gnrm)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: norbp,ncong
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: lr
  real(wp), dimension(norbp), intent(in) :: eval
  real(wp), intent(out) :: gnrm
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: i_stat,iorb
  real(wp) :: gnrm_gpu

  gnrm=0.0_wp
  do iorb=1,norbp

     !use rhopot as a work array here
     call gpuprecond(lr%d%n1,lr%d%n2,lr%d%n3,lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,&
          0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
          GPU%psi(iorb),&
          GPU%keys,GPU%r,GPU%rhopot,GPU%d,GPU%work1,GPU%work2,GPU%work3,&
          0.5_wp,ncong,gnrm_gpu)

     gnrm=gnrm+gnrm_gpu

  end do

end subroutine gpu_precond

subroutine gpu_intprecond(lr,hx,hy,hz,GPU,norbp,ncong,eval,iorb)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: norbp,ncong,iorb
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: lr
  real(wp), dimension(norbp), intent(in) :: eval
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: i_stat

  !use rhopot as a work array here
  call gpuintprecond(lr%d%n1,lr%d%n2,lr%d%n3,lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,&
       0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
       GPU%psi(iorb),&
       GPU%keys,GPU%r,GPU%rhopot,GPU%d,GPU%work1,GPU%work2,GPU%work3,&
       0.5_wp,ncong)

end subroutine gpu_intprecond


subroutine gpu_precond_helper_stream(lr,hx,hy,hz,GPU,norbp,ncong,eval,gnrm,currOrb,stream_ptr)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: norbp,ncong
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: lr
  real(wp), dimension(norbp), intent(in) :: eval
  real(wp), intent(out) :: gnrm
  type(GPU_pointers), intent(out) :: GPU
  !local variables
  integer :: i_stat
  integer,intent(in) :: currOrb
 ! real(wp) :: gnrm_gpu
  real(kind=8), intent(in) :: stream_ptr 

  real(kind=8) :: callback_pointer,callback_param
  gnrm=0.0_wp

  
  call sg_precond_adapter(lr%d%n1,lr%d%n2,lr%d%n3,lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,&
       0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,&
       GPU%psi(currOrb),&
       GPU%keys,GPU%r,GPU%rhopot,GPU%d,GPU%work1,GPU%work2,GPU%work3,&
       0.5_wp,ncong,gnrm,stream_ptr)

end subroutine gpu_precond_helper_stream

subroutine gpu_precondprecond_helper_stream(lr,hx,hy,hz,cprecr,scal,ncplx,w,x,b,&
     stream_ptr)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: ncplx
  real(wp), intent(in) :: cprecr
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: lr
  type(workarr_precond), intent(inout) :: w
  real(gp), dimension(0:7), intent(inout) :: scal
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx) ::  x
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx) ::  b

  !local variables
  integer :: i_stat
 ! real(wp) :: gnrm_gpu
  real(kind=8), intent(in) :: stream_ptr 
  

  call sg_precond_preconditioner_adapter(lr%hybrid_on,lr%d%n1,lr%d%n2,lr%d%n3,&
       lr%wfd%nvctr_c,lr%wfd%nvctr_f,lr%wfd%nseg_c,lr%wfd%nseg_f,ncplx,cprecr,&
       0.5_gp*hx,0.5_gp*hy,0.5_gp*hz,scal,lr%wfd%keyg,lr%wfd%keyv,&
       w%modul1,w%modul2,w%modul3,w%af,w%bf,w%cf,w%ef,w%kern_k1,w%kern_k2,w%kern_k3,&
       w%z1,w%z3,w%x_c,w%psifscf,w%ww,x,b,stream_ptr)

end subroutine gpu_precondprecond_helper_stream


subroutine precond_preconditioner_wrapper(hybrid_on,&
     n1,n2,n3,nvctr_c,nvctr_f,nseg_c,nseg_f,ncplx,&
     cprecr,hx,hy,hz,scal,keyg,keyv,modul1,modul2,modul3,&
     af,bf,cf,ef,kern_k1,kern_k2,kern_k3,z1,z3,x_c,psifscf,ww,&
     x,b)
  use module_base
  use module_types
  implicit none
  logical :: hybrid_on
  integer :: n1,n2,n3,nvctr_c,nvctr_f,nseg_c,nseg_f,ncplx
  real(wp) :: cprecr
  real(gp) :: hx,hy,hz
  real(gp), dimension(0:7) :: scal
  integer, dimension(*) :: modul1,modul2,modul3,keyg,keyv
  real(wp), dimension(*) :: af,bf,cf,ef,kern_k1,kern_k2,kern_k3,z1,z3,x_c,psifscf,ww
  real(wp), dimension(nvctr_c+7*nvctr_f,ncplx) ::  x
  real(wp), dimension(nvctr_c+7*nvctr_f,ncplx) ::  b

  !local variables
  integer :: nd1,nd2,nd3,idx,i
  integer :: n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b 
  real(gp) :: fac
  real(wp) :: fac_h,h0,h1,h2,h3,alpha1


!!$  call dimensions_fft(n1,n2,n3,&
!!$       nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)
!!$
!!$  if (ncplx /=2 .and. .not. hybrid_on) then
!!$     call prepare_sdc(n1,n2,n3,&
!!$          modul1,modul2,modul3,af,bf,cf,ef,hx,hy,hz)
!!$  end if
!!$  !	initializes the wavelet scaling coefficients	
!!$  call wscal_init_per(scal,hx,hy,hz,cprecr)
!!$
!!$  if (hybrid_on) then
!!$     do idx=1,ncplx
!!$        !b=x
!!$        call dcopy(nvctr_c+7*nvctr_f,x(1,idx),1,b(1,idx),1) 
!!$
!!$        call prec_fft_fast(n1,n2,n3,&
!!$             nseg_c,nvctr_c,nseg_f,nvctr_f,&
!!$             keyg,keyv, &
!!$             cprecr,hx,hy,hz,x(1,idx),&
!!$             kern_k1,kern_k2,kern_k3,z1,z3,x_c,&
!!$             nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b)
!!$     end do
!!$
!!$  else
!!$     ! Array sizes for the real-to-complex FFT: note that n1(there)=n1(here)+1
!!$     ! and the same for lr%d%n2,n3.
!!$
!!$     do idx=1,ncplx
!!$        !	scale the r.h.s. that is also the scaled input guess :
!!$        !	b'=D^{-1/2}b
!!$        call wscal_per_self(nvctr_c,nvctr_f,scal,&
!!$             x(1,idx),x(nvctr_c+1,idx))
!!$        !b=x
!!$        call dcopy(nvctr_c+7*nvctr_f,x(1,idx),1,b(1,idx),1) 
!!$
!!$        !if GPU is swithced on and there is no call to GPU preconditioner
!!$        !do not do the FFT preconditioning
!!$        if (.not. GPUconv .or. .true.) then
!!$           !	compute the input guess x via a Fourier transform in a cubic box.
!!$           !	Arrays psifscf and ww serve as work arrays for the Fourier
!!$           fac=1.0_gp/scal(0)**2
!!$           call prec_fft_c(n1,n2,n3,nseg_c,&
!!$                nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
!!$                cprecr,hx,hy,hz,x(1,idx),&
!!$                psifscf(1),psifscf(n1+2),&
!!$                psifscf(n1+n2+3),ww(1),ww(nd1b*nd2*nd3*4+1),&
!!$                ww(nd1b*nd2*nd3*4+nd1*nd2*nd3f*4+1),&
!!$                nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,fac)
!!$        end if
!!$     end do
!!$  end if

  
end subroutine precond_preconditioner_wrapper
