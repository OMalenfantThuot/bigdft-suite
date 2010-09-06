#include "bench_lib.h"


#define MAX_N1 128
#define MAX_N2 128
#define MAX_N3 512
#define N1_STEP 128
#define N2_STEP 128
#define N3_STEP 512
#define N1_URANGE 0 
#define N2_URANGE 0 
#define N3_URANGE 0
#define N1_USTEP 1
#define N2_USTEP 1
#define N3_USTEP 1

int main(){
  cl_uint n1,n2,n3;
  cl_uint un1,un2,un3;
  double *in, *out;
  cl_uint size = (MAX_N1+N1_URANGE)*(MAX_N2+N2_URANGE)*(MAX_N3+N3_URANGE);
  cl_ulong t0,t1;



//  in = (double*) malloc(size*sizeof(double));
//  out = (double*) malloc(size*sizeof(double));


  ocl_create_gpu_context_(&context);
  ocl_build_programs_(&context);
  ocl_create_command_queue_(&queue,&context);
  init_event_list_();
 
  cl_mem cmPinnedBufIn = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_ALLOC_HOST_PTR, size*sizeof(double), NULL, NULL);
  cl_mem cmPinnedBufOut = clCreateBuffer(context, CL_MEM_WRITE_ONLY | CL_MEM_ALLOC_HOST_PTR, size*sizeof(double), NULL, NULL);
  in = (double *)clEnqueueMapBuffer(queue->command_queue, cmPinnedBufIn, CL_TRUE, CL_MAP_WRITE, 0, size*sizeof(double), 0, NULL, NULL, NULL);
  out = (double *)clEnqueueMapBuffer(queue->command_queue, cmPinnedBufOut, CL_TRUE, CL_MAP_READ, 0, size*sizeof(double), 0, NULL, NULL, NULL);
  init_random(in, size);

  for( n1 = N1_STEP; n1 <= MAX_N1; n1 += N1_STEP ){
    for( un1 = n1 - N1_URANGE; un1 <= n1 + N1_URANGE; un1 += N1_USTEP){
      for( n2 = N2_STEP; n2 <= MAX_N2; n2 += N2_STEP ){
        for( un2 = n2 - N2_URANGE; un2 <= n2 + N2_URANGE; un2 += N2_USTEP){
          for( n3 = N3_STEP; n3 <= MAX_N3; n3 += N3_STEP ){
            for( un3 = n3 - N3_URANGE; un3 <= n3 + N3_URANGE; un3 += N3_USTEP){
              printf("%d %d %d\n",un1,un2,un3);
              nanosec_(&t0);
              bench_magicfilter1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_magicfilter1d_straight(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_magicfilter1d_block(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_magicfiltergrow1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_magicfiltershrink1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_kinetic1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_ana1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_ana1d_block(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_anashrink1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_syn1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_syngrow1d(un1,un2,un3,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_gemm(un1,un2,un3,in,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
              nanosec_(&t0);
              bench_zgemm(un1,un2,un3,in,in,out);
              nanosec_(&t1);
              printf("%lu usec\n",(t1-t0)/1000);
            }
          }
        }
      }
    }
  }

  ocl_release_mem_object_(&cmPinnedBufIn);
  ocl_release_mem_object_(&cmPinnedBufOut);
  print_event_list_();
  ocl_clean_command_queue_(&queue);
  ocl_clean_(&context);
  return 0;
}