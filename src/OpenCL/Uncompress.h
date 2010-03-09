#ifndef UNCOMPRESS_H
#define UNCOMPRESS_H
char * uncompress_program="\
#pragma OPENCL EXTENSION cl_khr_fp64: enable \n\
__kernel void uncompress_coarseKernel_d(size_t n1, size_t n2, size_t n3, size_t nseg_c, size_t nvctr_c, __global const size_t * keyg_c, __global const size_t const * keyv_c, __global const double * psi_c, __global double * psi_g) {\n\
size_t ig = get_global_id(0);\n\
ig = get_group_id(0) == get_num_groups(0) - 1 ? ig - ( get_global_size(0) - nvctr_c ) : ig;\n\
size_t length = nseg_c;\n\
__global const size_t * first;\n\
__global const size_t * middle;\n\
size_t half;\n\
first = keyv_c;\n\
while ( length > 0) {\n\
  half = length / 2;\n\
  middle = first + half;\n\
  if( *middle-1 <= ig ) {\n\
    first = middle+1;\n\
    length = length - half - 1;\n\
  } else {\n\
    length = half;\n\
  }\n\
}\n\
first--;\n\
size_t iseg = first - keyv_c;\n\
size_t jj,j0,j1,ii,i1,i2,i3;\n\
jj=keyv_c[iseg];\n\
j0=keyg_c[iseg*2];\n\
j1=keyg_c[iseg*2+1];\n\
ii=j0-1;\n\
i3=ii/((n1)*(n2));\n\
ii=ii-i3*(n1)*(n2);\n\
i2=ii/(n1);\n\
i1=ii-i2*(n1)+ig-(*first-1);\n\
//psi_g(i1,1,i2,1,i3,1)=psi_c[ig]\n\
psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1] = psi_c[ig];\n\
};\n\
\n\
__kernel void uncompress_fineKernel_d(size_t n1, size_t n2, size_t n3, size_t nseg_f, size_t nvctr_f, __global const size_t * keyg_f, __global const size_t const * keyv_f, __global const double * psi_f, __global double * psi_g, __local double * tmp) {\n\
size_t ig = get_global_id(0);\n\
ig = get_group_id(0) == get_num_groups(0) - 1 ? ig - ( get_global_size(0) - nvctr_f ) : ig;\n\
size_t length = nseg_f;\n\
__global const size_t * first;\n\
__global const size_t * middle;\n\
size_t half;\n\
first = keyv_f;\n\
do {\n\
  half = length / 2;\n\
  middle = first + half;\n\
  if( *middle-1 <= ig ) {\n\
    first = middle+1;\n\
    length = length - half - 1;\n\
  } else {\n\
    length = half;\n\
  }\n\
} while (length > 0);\n\
first--;\n\
size_t iseg = first - keyv_f;\n\
size_t jj,j0,ii,i1,i2,i3;\n\
jj=keyv_f[iseg];\n\
j0=keyg_f[iseg*2];\n\
ii=j0-1;\n\
i3=ii/((n1)*(n2));\n\
ii=ii-i3*(n1)*(n2);\n\
i2=ii/(n1);\n\
i1=ii-i2*(n1)+ig-(*first-1);\n\
/*\n\
 psig(i1,2,i2,1,i3,1)=psi_f(1,i-i0+jj)\n\
 psig(i1,1,i2,2,i3,1)=psi_f(2,i-i0+jj)\n\
 psig(i1,2,i2,2,i3,1)=psi_f(3,i-i0+jj)\n\
 psig(i1,1,i2,1,i3,2)=psi_f(4,i-i0+jj)\n\
 psig(i1,2,i2,1,i3,2)=psi_f(5,i-i0+jj)\n\
 psig(i1,1,i2,2,i3,2)=psi_f(6,i-i0+jj)\n\
 psig(i1,2,i2,2,i3,2)=psi_f(7,i-i0+jj)*/\n\
size_t i = get_local_id(0);\n\
size_t igr = ig - i;\n\
__local double * tmp_o = tmp + i;\n\
tmp_o[0*64] = psi_f[igr * 7 + i];\n\
tmp_o[1*64] = psi_f[igr * 7 + i + 1*64];\n\
tmp_o[2*64] = psi_f[igr * 7 + i + 2*64];\n\
tmp_o[3*64] = psi_f[igr * 7 + i + 3*64];\n\
tmp_o[4*64] = psi_f[igr * 7 + i + 4*64];\n\
tmp_o[5*64] = psi_f[igr * 7 + i + 5*64];\n\
tmp_o[6*64] = psi_f[igr * 7 + i + 6*64];\n\
barrier(CLK_LOCAL_MEM_FENCE);\n\
tmp_o = tmp + i*7;\n\
psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1] = tmp_o[0];\n\
psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1] = tmp_o[1];\n\
psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1] = tmp_o[2];\n\
psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1] = tmp_o[3];\n\
psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1] = tmp_o[4];\n\
psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1] = tmp_o[5];\n\
psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1] = tmp_o[6];\n\
};\n\
";

char * compress_program="\
#pragma OPENCL EXTENSION cl_khr_fp64: enable \n\
__kernel void compress_coarseKernel_d(size_t n1, size_t n2, size_t n3, size_t nseg_c, size_t nvctr_c, __global const size_t * keyg_c, __global const size_t const * keyv_c, __global double * psi_c, __global const double * psi_g) {\n\
size_t ig = get_global_id(0);\n\
ig = get_group_id(0) == get_num_groups(0) - 1 ? ig - ( get_global_size(0) - nvctr_c ) : ig;\n\
size_t length = nseg_c;\n\
__global const size_t * first;\n\
__global const size_t * middle;\n\
size_t half;\n\
first = keyv_c;\n\
while ( length > 0) {\n\
  half = length / 2;\n\
  middle = first + half;\n\
  if( *middle-1 <= ig ) {\n\
    first = middle+1;\n\
    length = length - half - 1;\n\
  } else {\n\
    length = half;\n\
  }\n\
}\n\
first--;\n\
size_t iseg = first - keyv_c;\n\
size_t jj,j0,ii,i1,i2,i3;\n\
jj=keyv_c[iseg];\n\
j0=keyg_c[iseg*2];\n\
ii=j0-1;\n\
i3=ii/((n1)*(n2));\n\
ii=ii-i3*(n1)*(n2);\n\
i2=ii/(n1);\n\
i1=ii-i2*(n1)+ig-(*first-1);\n\
//psi_g(i1,1,i2,1,i3,1)=psi_c[ig]\n\
psi_c[ig] = psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1];\n\
};\n\
\n\
//hypothesis : nseg_f > 0\n\
__kernel void compress_fineKernel_d(size_t n1, size_t n2, size_t n3, size_t nseg_f, size_t nvctr_f, __global const size_t * keyg_f, __global size_t * keyv_f, __global double * psi_f, __global const double * psi_g, __local double * tmp) {\n\
size_t ig = get_global_id(0);\n\
ig = get_group_id(0) == get_num_groups(0) - 1 ? ig - ( get_global_size(0) - nvctr_f ) : ig;\n\
size_t length = nseg_f;\n\
__global size_t * first;\n\
__global size_t * middle;\n\
size_t half;\n\
first = keyv_f;\n\
do {\n\
  half = length / 2;\n\
  middle = first + half;\n\
  if( *middle-1 <= ig ) {\n\
    length = length - half - 1;\n\
    first = middle+1;\n\
  } else {\n\
    length = half;\n\
  }\n\
} while ( length > 0);\n\
first--;\n\
size_t iseg = first - keyv_f;\n\
size_t jj,j0,ii,i1,i2,i3;\n\
jj=keyv_f[iseg];\n\
j0=keyg_f[iseg*2];\n\
ii=j0-1;\n\
i3=ii/((n1)*(n2));\n\
ii=ii-i3*(n1)*(n2);\n\
i2=ii/(n1);\n\
i1=ii-i2*(n1)+ig-(*first-1);\n\
size_t i = get_local_id(0);\n\
__local double * tmp_o = tmp + i*7;\n\
tmp_o[0] = psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1];\n\
tmp_o[1] = psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1];\n\
tmp_o[2] = psi_g[ ( ( ( (0 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1];\n\
tmp_o[3] = psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1];\n\
tmp_o[4] = psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 0 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1];\n\
tmp_o[5] = psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 0 ) * n1  + i1];\n\
tmp_o[6] = psi_g[ ( ( ( (1 * n3 + i3 ) * 2 + 1 ) * n2 + i2 ) * 2 + 1 ) * n1  + i1];\n\
barrier(CLK_LOCAL_MEM_FENCE);\n\
size_t igr = ig - i;\n\
tmp_o = tmp + i;\n\
psi_f[igr * 7 + i] = tmp_o[0*64];\n\
psi_f[igr * 7 + i + 1*64] = tmp_o[1*64];\n\
psi_f[igr * 7 + i + 2*64] = tmp_o[2*64];\n\
psi_f[igr * 7 + i + 3*64] = tmp_o[3*64];\n\
psi_f[igr * 7 + i + 4*64] = tmp_o[4*64];\n\
psi_f[igr * 7 + i + 5*64] = tmp_o[5*64];\n\
psi_f[igr * 7 + i + 6*64] = tmp_o[6*64];\n\
};\n\
";

inline void uncompress_coarse_generic(cl_kernel kernel, cl_command_queue *command_queue, cl_uint *n1, cl_uint *n2, cl_uint *n3,
                                    cl_uint *nseg_c, cl_uint *nvctr_c, cl_mem *keyg_c, cl_mem *keyv_c,
                                    cl_mem *psi_c, cl_mem * psi_out) {
    cl_int ciErrNum;
    size_t block_size_i=64;
    assert( *nvctr_c >= block_size_i );
    cl_uint i = 0;
    clSetKernelArg(kernel, i++, sizeof(*n1), (void*)n1);
    clSetKernelArg(kernel, i++, sizeof(*n2), (void*)n2);
    clSetKernelArg(kernel, i++, sizeof(*n3), (void*)n3);
    clSetKernelArg(kernel, i++, sizeof(*nseg_c), (void*)nseg_c);
    clSetKernelArg(kernel, i++, sizeof(*nvctr_c), (void*)nvctr_c);
    clSetKernelArg(kernel, i++, sizeof(*keyg_c), (void*)keyg_c);
    clSetKernelArg(kernel, i++, sizeof(*keyv_c), (void*)keyv_c);
    clSetKernelArg(kernel, i++, sizeof(*psi_c), (void*)psi_c);
    clSetKernelArg(kernel, i++, sizeof(*psi_out), (void*)psi_out);
    size_t localWorkSize[]= { block_size_i };
    size_t globalWorkSize[] = { shrRoundUp(block_size_i, *nvctr_c) } ;
    ciErrNum = clEnqueueNDRangeKernel  (*command_queue, kernel, 1, NULL, globalWorkSize, localWorkSize, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue uncompress_coarse kernel!");

}

inline void uncompress_fine_generic(cl_kernel kernel, cl_command_queue *command_queue, cl_uint *n1, cl_uint *n2, cl_uint *n3,
                                    cl_uint *nseg_f, cl_uint *nvctr_f, cl_mem *keyg_f, cl_mem *keyv_f,
                                    cl_mem *psi_f, cl_mem * psi_out) {
    cl_int ciErrNum;
    size_t block_size_i=64;
    assert( *nvctr_f >= block_size_i );
    cl_uint i = 0;
    clSetKernelArg(kernel, i++, sizeof(*n1), (void*)n1);
    clSetKernelArg(kernel, i++, sizeof(*n2), (void*)n2);
    clSetKernelArg(kernel, i++, sizeof(*n3), (void*)n3);
    clSetKernelArg(kernel, i++, sizeof(*nseg_f), (void*)nseg_f);
    clSetKernelArg(kernel, i++, sizeof(*nvctr_f), (void*)nvctr_f);
    clSetKernelArg(kernel, i++, sizeof(*keyg_f), (void*)keyg_f);
    clSetKernelArg(kernel, i++, sizeof(*keyv_f), (void*)keyv_f);
    clSetKernelArg(kernel, i++, sizeof(*psi_f), (void*)psi_f);
    clSetKernelArg(kernel, i++, sizeof(*psi_out), (void*)psi_out);
    clSetKernelArg(kernel, i++, sizeof(double)*block_size_i*7, NULL);
    size_t localWorkSize[]= { block_size_i };
    size_t globalWorkSize[] = { shrRoundUp(block_size_i, *nvctr_f) } ;
    ciErrNum = clEnqueueNDRangeKernel  (*command_queue, kernel, 1, NULL, globalWorkSize, localWorkSize, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue uncompress_fine kernel!");

}


inline void compress_coarse_generic(cl_kernel kernel, cl_command_queue *command_queue, cl_uint *n1, cl_uint *n2, cl_uint *n3,
                                    cl_uint *nseg_c, cl_uint *nvctr_c, cl_mem *keyg_c, cl_mem *keyv_c,
                                    cl_mem *psi_c, cl_mem * psi) {
    cl_int ciErrNum;
    size_t block_size_i=64;
    assert( *nvctr_c >= block_size_i );
    cl_uint i = 0;
    clSetKernelArg(kernel, i++, sizeof(*n1), (void*)n1);
    clSetKernelArg(kernel, i++, sizeof(*n2), (void*)n2);
    clSetKernelArg(kernel, i++, sizeof(*n3), (void*)n3);
    clSetKernelArg(kernel, i++, sizeof(*nseg_c), (void*)nseg_c);
    clSetKernelArg(kernel, i++, sizeof(*nvctr_c), (void*)nvctr_c);
    clSetKernelArg(kernel, i++, sizeof(*keyg_c), (void*)keyg_c);
    clSetKernelArg(kernel, i++, sizeof(*keyv_c), (void*)keyv_c);
    clSetKernelArg(kernel, i++, sizeof(*psi_c), (void*)psi_c);
    clSetKernelArg(kernel, i++, sizeof(*psi), (void*)psi);
    size_t localWorkSize[]= { block_size_i };
    size_t globalWorkSize[] = { shrRoundUp(block_size_i, *nvctr_c) } ;
    ciErrNum = clEnqueueNDRangeKernel  (*command_queue, kernel, 1, NULL, globalWorkSize, localWorkSize, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue compress_coarse kernel!");

}

inline void compress_fine_generic(cl_kernel kernel, cl_command_queue *command_queue, cl_uint *n1, cl_uint *n2, cl_uint *n3,
                                    cl_uint *nseg_f, cl_uint *nvctr_f, cl_mem *keyg_f, cl_mem *keyv_f,
                                    cl_mem *psi_f, cl_mem * psi) {
    cl_int ciErrNum;
    size_t block_size_i=64;
    assert( *nvctr_f >= block_size_i );
    cl_uint i = 0;
    clSetKernelArg(kernel, i++, sizeof(*n1), (void*)n1);
    clSetKernelArg(kernel, i++, sizeof(*n2), (void*)n2);
    clSetKernelArg(kernel, i++, sizeof(*n3), (void*)n3);
    clSetKernelArg(kernel, i++, sizeof(*nseg_f), (void*)nseg_f);
    clSetKernelArg(kernel, i++, sizeof(*nvctr_f), (void*)nvctr_f);
    clSetKernelArg(kernel, i++, sizeof(*keyg_f), (void*)keyg_f);
    clSetKernelArg(kernel, i++, sizeof(*keyv_f), (void*)keyv_f);
    clSetKernelArg(kernel, i++, sizeof(*psi_f), (void*)psi_f);
    clSetKernelArg(kernel, i++, sizeof(*psi), (void*)psi);
    clSetKernelArg(kernel, i++, sizeof(double)*block_size_i*7, NULL);
    size_t localWorkSize[]= { block_size_i };
    size_t globalWorkSize[] = { shrRoundUp(block_size_i, *nvctr_f) } ;
    ciErrNum = clEnqueueNDRangeKernel  (*command_queue, kernel, 1, NULL, globalWorkSize, localWorkSize, 0, NULL, NULL);
    oclErrorCheck(ciErrNum,"Failed to enqueue compress_fine kernel!");

}

#endif
