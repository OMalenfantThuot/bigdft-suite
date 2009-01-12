#ifndef __structDefkinetic__
#define __structDefkinetic__

//maximum size of the shared memory array
//conceived for maximize occupancy on a hardware of compute
//capability 1.2 and higher (1024 threads at same time on a given multiprocessor)
#define MAX_SHARED_SIZE 3072 //16*256 4 kB (should be =~ 3.9 kB, try also 3072)
#define HALF_WARP_SIZE 16 // for all architectures
#define NUM_LINES 16 
#define HW_ELEM 1 //this is HALF_WARP_SIZE/NUM_LINES

//parameter related to the Magic Filter convolution
//lowfil + lupfil + 1  must be a multiple of 16
#define LOWFIL 14
#define LUPFIL 14

//convolution filters
#define KFIL0   -3.5536922899131901941296809374
#define KFIL1    2.2191465938911163898794546405
#define KFIL2   -0.6156141465570069496314853949
#define KFIL3    0.2371780582153805636239247476
#define KFIL4   -0.0822663999742123340987663521
#define KFIL5    0.02207029188482255523789911295638968409
#define KFIL6   -0.409765689342633823899327051188315485e-2
#define KFIL7    0.45167920287502235349480037639758496e-3
#define KFIL8   -0.2398228524507599670405555359023135e-4
#define KFIL9    2.0904234952920365957922889447361e-6
#define KFIL10  -3.7230763047369275848791496973044e-7
#define KFIL11  -1.05857055496741470373494132287e-8
#define KFIL12  -5.813879830282540547959250667e-11
#define KFIL13   2.70800493626319438269856689037647576e-13
#define KFIL14  -6.924474940639200152025730585882e-18

/*
#define KFIL0   0.e-3f 
#define KFIL1   1.e-3f 
#define KFIL2   2.e-3f 
#define KFIL3   3.e-3f 
#define KFIL4   4.e-3f 
#define KFIL5   5.e-3f 
#define KFIL6   6.e-3f 
#define KFIL7   7.e-3f 
#define KFIL8   8.e-3f 
#define KFIL9   9.e-3f 
#define KFIL10 10.e-3f
#define KFIL11 11.e-3f
#define KFIL12 12.e-3f
#define KFIL13 13.e-3f
#define KFIL14 14.e-3f
*/

typedef struct  _parK
{
  int ElementsPerBlock;

  int thline[HALF_WARP_SIZE]; //line considered by a thread within the half-warp
  int thelem[HALF_WARP_SIZE]; //elements considered by a thread within the half-warp
  int hwelem_calc[16]; //maximum number of half warps
  int hwelem_copy[16]; //maximum number of half-warps
  int hwoffset_calc[16]; //maximum number of half warps
  int hwoffset_copy[16]; //maximum number of half-warps
  float scale;

} parK_t;

#endif
