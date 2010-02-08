#include "OpenCL_wrappers.h"



cl_device_id oclGetFirstDev(cl_context cxGPUContext)
{
    size_t szParmDataBytes;
    cl_device_id* cdDevices;

    // get the list of GPU devices associated with context
    clGetContextInfo(cxGPUContext, CL_CONTEXT_DEVICES, 0, NULL, &szParmDataBytes);
    cdDevices = (cl_device_id*) malloc(szParmDataBytes);

    clGetContextInfo(cxGPUContext, CL_CONTEXT_DEVICES, szParmDataBytes, cdDevices, NULL);

    cl_device_id first = cdDevices[0];
    free(cdDevices);

    return first;
}

void FC_FUNC_(ocl_build_kernels,OCL_BUILD_KERNELS)(cl_context * context) {
    build_magicfilter_kernels(context);
    build_kinetic_kernels(context);
    build_wavelet_kernels(context);
    build_uncompress_kernels(context);
    build_initialize_kernels(context);
}



void FC_FUNC_(ocl_create_gpu_context,OCL_CREATE_GPU_CONTEXT)(cl_context * context) {
    cl_int ciErrNum = CL_SUCCESS;
    *context = clCreateContextFromType(0, CL_DEVICE_TYPE_GPU, NULL, NULL, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p\n",*context);
#endif
    oclErrorCheck(ciErrNum,"Failed to create GPU context!");
}

void FC_FUNC_(ocl_create_cpu_context,OCL_CREATE_CPU_CONTEXT)(cl_context * context) {
    cl_int ciErrNum = CL_SUCCESS;
    *context = clCreateContextFromType(0, CL_DEVICE_TYPE_CPU, NULL, NULL, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p\n",*context);
#endif
    oclErrorCheck(ciErrNum,"Failed to create CPU context!");
}

void FC_FUNC_(ocl_create_read_buffer,OCL_CREATE_READ_BUFFER)(cl_context *context, size_t *size, cl_mem *buff_ptr) {
    cl_int ciErrNum = CL_SUCCESS;
    *buff_ptr = clCreateBuffer( *context, CL_MEM_READ_ONLY, *size, NULL, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p, memory address: %p, size: %d\n",*context,*buff_ptr,*size);
#endif
    oclErrorCheck(ciErrNum,"Failed to create read buffer!");
}

void FC_FUNC_(ocl_create_read_write_buffer,OCL_CREATE_READ_WRITE_BUFFER)(cl_context *context, size_t *size, cl_mem *buff_ptr) {
    cl_int ciErrNum = CL_SUCCESS;
    *buff_ptr = clCreateBuffer( *context, CL_MEM_READ_WRITE, *size, NULL, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p, memory address: %p, size: %d\n",*context,*buff_ptr,*size);
#endif
    oclErrorCheck(ciErrNum,"Failed to create read_write buffer!");
}

void FC_FUNC_(ocl_create_read_buffer_and_copy,OCL_CREATE_READ_BUFFER_AND_COPY)(cl_context *context, size_t *size, void *host_ptr, cl_mem *buff_ptr) {
    cl_int ciErrNum = CL_SUCCESS;
    *buff_ptr = clCreateBuffer( *context, CL_MEM_READ_ONLY|CL_MEM_COPY_HOST_PTR, *size, host_ptr, &ciErrNum);
    oclErrorCheck(ciErrNum,"Failed to create initialized read buffer!");
}

void FC_FUNC_(ocl_create_write_buffer,OCL_CREATE_WRITE_BUFFER)(cl_context *context, size_t *size, cl_mem *buff_ptr) {
    cl_int ciErrNum = CL_SUCCESS;
    *buff_ptr = clCreateBuffer( *context, CL_MEM_WRITE_ONLY, *size, NULL, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p, memory address: %p, size: %d\n",*context,*buff_ptr,*size);
#endif
    oclErrorCheck(ciErrNum,"Failed to create write buffer!");
}

void FC_FUNC_(ocl_release_mem_object,OCL_RELEASE_MEM_OBJECT)(cl_mem *buff_ptr) {
    cl_int ciErrNum = clReleaseMemObject( *buff_ptr);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("memory address: %p\n",*buff_ptr);
#endif
    oclErrorCheck(ciErrNum,"Failed to release buffer!");
}

void FC_FUNC_(ocl_enqueue_read_buffer,OCL_ENQUEUE_READ_BUFFER)(cl_command_queue *command_queue, cl_mem *buffer, size_t *size, void *ptr){
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("command queue: %p, memory address: %p, size: %d, target: %p\n",*command_queue,*buffer,*size, ptr);
#endif
    cl_int ciErrNum = clEnqueueReadBuffer( *command_queue, *buffer, CL_TRUE, 0, *size, ptr, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue read buffer!");
}

void FC_FUNC_(ocl_enqueue_write_buffer,OCL_ENQUEUE_WRITE_BUFFER)(cl_command_queue *command_queue, cl_mem *buffer, size_t *size,	const void *ptr){
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("command queue: %p, memory address: %p, size: %d, source: %p\n",*command_queue,*buffer,*size, ptr);
#endif
    cl_int ciErrNum = clEnqueueWriteBuffer( *command_queue, *buffer, CL_TRUE, 0, *size, ptr, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue write buffer!");
}

void FC_FUNC_(ocl_create_command_queue,OCL_CREATE_COMMAND_QUEUE)(cl_command_queue *hCmdQueue, cl_context *context){
    size_t nContextDescriptorSize;
    cl_int ciErrNum;
    clGetContextInfo(*context, CL_CONTEXT_DEVICES, 0, 0, &nContextDescriptorSize);
    cl_device_id * aDevices = (cl_device_id *) malloc(nContextDescriptorSize);
    clGetContextInfo(*context, CL_CONTEXT_DEVICES, nContextDescriptorSize, aDevices, 0);
    // create a command queue for first device the context reported
    *hCmdQueue = clCreateCommandQueue(*context, aDevices[0], 0, &ciErrNum);
#if DEBUG
    printf("%s %s\n", __func__, __FILE__);
    printf("contexte address: %p, command queue: %p\n",*context, *hCmdQueue);
#endif
    if (ciErrNum != CL_SUCCESS)
    {
        fprintf(stderr,"Error: Failed to create command queue!\n");
        exit(1);
    }
}


size_t shrRoundUp(size_t group_size, size_t global_size)
{
    size_t r = global_size % group_size;
    if(r == 0)
    {
        return global_size;
    } else
    {
        return global_size + group_size - r;
    }
}




void FC_FUNC_(ocl_finish,OCL_FINISH)(cl_command_queue *command_queue){
    cl_int ciErrNum;
    ciErrNum = clFinish(*command_queue);
    oclErrorCheck(ciErrNum,"Failed to finish!");
}

void FC_FUNC_(ocl_enqueue_barrier,OCL_ENQUEUE_BARRIER)(cl_command_queue *command_queue){
    cl_int ciErrNum;
    ciErrNum = clEnqueueBarrier(*command_queue);
    oclErrorCheck(ciErrNum,"Failed to enqueue barrier!");
}
