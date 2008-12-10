  subroutine set_cpu_gpu_aff()
    implicit none
    stop 'FAKE CPU_GPU_AFF'
  end subroutine set_cpu_gpu_aff

  subroutine intertamponcGPU()
    implicit none
    stop 'FAKE CUDA Interface'
  end subroutine intertamponcGPU

  subroutine CUDA_ALLOC_MEM()
    implicit none
    stop 'FAKE CUDA_ALLOC_MEM'
  end subroutine CUDA_ALLOC_MEM

  subroutine cuda_psi_to_vpsi()
    implicit none
    stop 'fake cuda_psi_to_vpsi'
  end subroutine cuda_psi_to_vpsi
     
  subroutine cuda_fetch_vpsi()
    implicit none
    stop 'fake cuda_fetch_vpsi'
  end subroutine cuda_fetch_vpsi

  subroutine CUDA_DEALLOCATE_MEM()
    implicit none
    stop 'fake CUDA_DEALLOCATE_MEM'
  end subroutine CUDA_DEALLOCATE_MEM

  subroutine GPU_allocate()
    implicit none
    stop 'fake GPU_allocate'
  end subroutine GPU_allocate

  subroutine GPU_deallocate()
    implicit none
    stop 'fake GPU_deallocate'
  end subroutine GPU_deallocate

  subroutine GPU_send()
    implicit none
    stop 'fake GPU_send'
  end subroutine GPU_send

  subroutine GPU_receive()
    implicit none
    stop 'fake GPU_receive'
  end subroutine GPU_receive

  subroutine localpotential()
    implicit none
    stop 'fake localpotential'
  end subroutine localpotential

  subroutine kineticterm()
    implicit none
    stop 'fake kineticterm'
  end subroutine kineticterm

