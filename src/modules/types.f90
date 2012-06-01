!> @file
!!  Define the fortran types
!! @author
!!    Copyright (C) 2008-2011 BigDFT group (LG)
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 

 
!>  Modules which contains the Fortran data structures
!!  and the routines of allocations and de-allocations
module module_types

  use m_ab6_mixing, only : ab6_mixing_object
  use module_base, only : gp,wp,dp,tp,uninitialized
  implicit none

  !> Input wf parameters.
  integer, parameter :: INPUT_PSI_EMPTY        = -1000
  integer, parameter :: INPUT_PSI_RANDOM       = -2
  integer, parameter :: INPUT_PSI_CP2K         = -1
  integer, parameter :: INPUT_PSI_LCAO         = 0
  integer, parameter :: INPUT_PSI_MEMORY_WVL   = 1
  integer, parameter :: INPUT_PSI_DISK_WVL     = 2
  integer, parameter :: INPUT_PSI_LCAO_GAUSS   = 10
  integer, parameter :: INPUT_PSI_MEMORY_GAUSS = 11
  integer, parameter :: INPUT_PSI_DISK_GAUSS   = 12
  integer, parameter :: INPUT_PSI_LINEAR       = 100
  integer, parameter :: INPUT_PSI_MEMORY_LINEAR= 101

  integer, dimension(10), parameter :: input_psi_values = &
       (/ INPUT_PSI_EMPTY, INPUT_PSI_RANDOM, INPUT_PSI_CP2K, &
       INPUT_PSI_LCAO, INPUT_PSI_MEMORY_WVL, INPUT_PSI_DISK_WVL, &
       INPUT_PSI_LCAO_GAUSS, INPUT_PSI_MEMORY_GAUSS, INPUT_PSI_DISK_GAUSS, &
       INPUT_PSI_LINEAR /)

  !> Output wf parameters.
  integer, parameter :: WF_FORMAT_NONE   = 0
  integer, parameter :: WF_FORMAT_PLAIN  = 1
  integer, parameter :: WF_FORMAT_BINARY = 2
  integer, parameter :: WF_FORMAT_ETSF   = 3
  integer, parameter :: WF_N_FORMAT      = 4
  character(len = 12), dimension(0:WF_N_FORMAT-1), parameter :: wf_format_names = &
       (/ "none        ", "plain text  ", "Fortran bin.", "ETSF        " /)

  !> Output grid parameters.
  integer, parameter :: OUTPUT_DENSPOT_NONE    = 0
  integer, parameter :: OUTPUT_DENSPOT_DENSITY = 1
  integer, parameter :: OUTPUT_DENSPOT_DENSPOT = 2
  character(len = 12), dimension(0:2), parameter :: OUTPUT_DENSPOT_names = &
       (/ "none        ", "density     ", "dens. + pot." /)
  integer, parameter :: OUTPUT_DENSPOT_FORMAT_TEXT = 0
  integer, parameter :: OUTPUT_DENSPOT_FORMAT_ETSF = 1
  integer, parameter :: OUTPUT_DENSPOT_FORMAT_CUBE = 2
  character(len = 4), dimension(0:2), parameter :: OUTPUT_DENSPOT_format_names = &
       (/ "text", "ETSF", "cube" /)

  !> SCF mixing parameters. (mixing parameters to be added)
  integer, parameter :: SCF_KIND_GENERALIZED_DIRMIN = -1
  integer, parameter :: SCF_KIND_DIRECT_MINIMIZATION = 0

  !> Occupation parameters.
  integer, parameter :: SMEARING_DIST_ERF   = 1
  integer, parameter :: SMEARING_DIST_FERMI = 2
  integer, parameter :: SMEARING_DIST_COLD1 = 3  !Marzari's cold smearing  with a=-.5634 (bumb minimization)
  integer, parameter :: SMEARING_DIST_COLD2 = 4  !Marzari's cold smearing  with a=-.8165 (monotonic tail)
  integer, parameter :: SMEARING_DIST_METPX = 5  !Methfessel and Paxton (same as COLD with a=0)
  character(len = 11), dimension(5), parameter :: smearing_names = &
       (/ "Error func.",&
       "Fermi      ", &
       "Cold (bumb)", &
       "Cold (mono)",   &
       "Meth.-Pax. " /)

  !> Target function for the optimization of the basis functions (linear scaling version)
  integer,parameter:: TARGET_FUNCTION_IS_TRACE=0
  integer,parameter:: TARGET_FUNCTION_IS_ENERGY=1
  integer,parameter:: DECREASE_LINEAR=0
  integer,parameter:: DECREASE_ABRUPT=1
  integer,parameter:: COMMUNICATION_COLLECTIVE=0
  integer,parameter:: COMMUNICATION_P2P=1
  integer,parameter:: LINEAR_DIRECT_MINIMIZATION=100
  integer,parameter:: LINEAR_MIXDENS_SIMPLE=101
  integer,parameter:: LINEAR_MIXPOT_SIMPLE=102
  

  !> Type used for the orthogonalisation parameter
  type, public :: orthon_data
     !> directDiag decides which input guess is chosen:
     !!   if .true. -> as usual direct diagonalization of the Hamiltonian with dsyev (suitable for small systems)
     !!   if .false. -> iterative diagonalization (suitable for large systems)
     logical:: directDiag
     !> norbpInguess indicates how many orbitals shall be treated by each process during the input guess
     !! if directDiag=.false.
     integer:: norbpInguess
     !> You have to choose two numbers for the block size, bsLow and bsUp:
     !!   if bsLow<bsUp, then the program will choose an appropriate block size in between these two numbers
     !!   if bsLow==bsUp, then the program will take exactly this blocksize
     integer:: bsLow, bsUp
     !> the variable methOrtho indicates which orthonormalization procedure is used:
     !!   methOrtho==0 -> Gram-Schmidt with Cholesky decomposition
     !!   methOrtho==1 -> combined block wise classical Gram-Schmidt and Cholesky
     !!   methOrtho==2 -> Loewdin
     integer:: methOrtho
     !> iguessTol gives the tolerance to which the input guess will converged (maximal
     !! residue of all orbitals).
     real(gp):: iguessTol
     integer:: methTransformOverlap, nItOrtho, blocksize_pdsyev, blocksize_pdgemm
  end type orthon_data

  type, public :: SIC_data
     character(len=4) :: approach !< approach for the Self-Interaction-Correction (PZ, NK)
     integer :: ixc !< base for the SIC correction
     real(gp) :: alpha !<downscaling coefficient
     real(gp) :: fref !< reference occupation (for alphaNK case)
  end type SIC_data

  !> Flags for the input files.
  integer, parameter, public :: INPUTS_NONE  =   0
  integer, parameter, public :: INPUTS_DFT   =   1
  integer, parameter, public :: INPUTS_GEOPT =   2
  integer, parameter, public :: INPUTS_PERF  =   4
  integer, parameter, public :: INPUTS_KPT   =   8
  integer, parameter, public :: INPUTS_MIX   =  16
  integer, parameter, public :: INPUTS_TDDFT =  32
  integer, parameter, public :: INPUTS_SIC   =  64
  integer, parameter, public :: INPUTS_FREQ  = 128
  integer, parameter, public :: INPUTS_LIN   = 256

!> Contains all parameters related to the linear scaling version.
  type,public:: linearInputParameters 
    integer:: DIISHistMin, DIISHistMax, nItPrecond
    integer :: nItSCCWhenOptimizing, confPotOrder, norbsPerProcIG, nItBasis_lowaccuracy, nItBasis_highaccuracy
    integer:: nItInguess, nItOrtho, mixHist_lowaccuracy, mixHist_highaccuracy
    integer:: methTransformOverlap, blocksize_pdgemm, blocksize_pdsyev
    integer:: correctionOrthoconstraint, nproc_pdsyev, nproc_pdgemm, memoryForCommunOverlapIG
    integer:: nItInnerLoop, nit_lowaccuracy, nit_highaccuracy
    integer:: nItSCCWhenOptimizing_lowaccuracy, nItSCCWhenFixed_lowaccuracy
    integer:: nItSCCWhenOptimizing_highaccuracy, nItSCCWhenFixed_highaccuracy
    integer:: confinement_decrease_mode, communication_strategy_overlap
    real(8):: convCrit_lowaccuracy, convCrit_highaccuracy, alphaSD, alphaDIIS
    real(8):: alphaMixWhenFixed_lowaccuracy, alphaMixWhenFixed_highaccuracy
    integer:: increase_locrad_after, plotBasisFunctions
    real(8):: locrad_increase_amount
    real(kind=8) :: alphaMixWhenOptimizing_lowaccuracy, alphaMixWhenOptimizing_highaccuracy
    real(8):: lowaccuray_converged, convCritMix, factor_enlarge, decrease_amount, decrease_step 
    real(8):: highaccuracy_converged !lr408
    real(8),dimension(:),pointer:: locrad, locrad_lowaccuracy, locrad_highaccuracy, locrad_type
    real(8),dimension(:),pointer:: potentialPrefac, potentialPrefac_lowaccuracy, potentialPrefac_highaccuracy
    integer,dimension(:),pointer:: norbsPerType
    logical:: useDerivativeBasisFunctions, transformToGlobal, mixedmode
    integer:: scf_mode
    character(len=1):: locregShape
  end type linearInputParameters

  integer, parameter, public :: INPUT_IG_OFF  = 0
  integer, parameter, public :: INPUT_IG_LIG  = 1
  integer, parameter, public :: INPUT_IG_FULL = 2
  integer, parameter, public :: INPUT_IG_TMO  = 3

!> Structure of the variables read by input.* files (*.dft, *.geopt...)
  type, public :: input_variables
     !strings of the input files
     character(len=100) :: file_dft,file_geopt,file_kpt,file_perf,file_tddft, &
          file_mix,file_sic,file_occnum,file_igpop,file_lin, dir_output
     integer :: files ! existing files.
     !miscellaneous variables
     logical :: gaussian_help
     integer :: ixc,ncharge,itermax,nrepmax,ncong,idsx,ncongt,inputPsiId,nspin,mpol,itrpmax
     integer :: norbv,nvirt,nplot,iscf,norbsempty,norbsuempty,norbsdempty, occopt
     integer :: OUTPUT_DENSPOT,dispersion,last_run,output_wf_format,OUTPUT_DENSPOT_format
     real(gp) :: frac_fluct,gnrm_sw,alphamix,Tel, alphadiis
     real(gp) :: hx,hy,hz,crmult,frmult,gnrm_cv,rbuf,rpnrm_cv,gnrm_startmix
     integer :: verbosity
     real(gp) :: elecfield(3)
     logical :: disableSym

     ! For absorption calculations
     integer :: iabscalc_type   ! 0 non calc, 1 cheb ,  2 lanc
     !! integer :: iat_absorber, L_absorber, N_absorber, rpower_absorber, Linit_absorber
     integer :: iat_absorber,  L_absorber
     real(gp), pointer:: Gabs_coeffs(:)
     real(gp) :: abscalc_bottomshift
     logical ::  c_absorbtion , abscalc_alterpot, abscalc_eqdiff,abscalc_S_do_cg, abscalc_Sinv_do_cg
     integer ::  potshortcut
     integer ::  nsteps
     character(len=100) :: extraOrbital
     character(len=1000) :: xabs_res_prefix
   
     ! Frequencies calculations (finite difference)
     real(gp) :: freq_alpha
     integer :: freq_order
     integer :: freq_method

     ! kpoints related input variables
     integer :: nkpt, nkptv,ngroups_kptv
     integer, dimension(:), pointer :: nkptsv_group
     real(gp), pointer :: kpt(:,:), wkpt(:), kptv(:,:)
     character(len=100) :: band_structure_filename

     ! Geometry variables from *.geopt
     character(len=10) :: geopt_approach
     integer :: ncount_cluster_x, history
     real(gp) :: betax,forcemax,randdis
     integer :: optcell, ionmov, nnos
     real(gp) :: dtion, mditemp, mdftemp, noseinert, friction, mdwall
     real(gp) :: bmass, vmass, strprecon, strfact
     real(gp) :: strtarget(6)
     real(gp), pointer :: qmass(:)
     real(gp) :: dtinit,dtmax !for FIRE
     ! tddft variables from *.tddft
     character(len=10) :: tddft_approach
     !variables for SIC
     type(SIC_data) :: SIC !<parameters for the SIC methods

     !> variable for material acceleration
     !! values 0: traditional CPU calculation
     !!        1: CUDA acceleration with CUBLAS
     !!        2: OpenCL acceleration (with CUBLAS one day)
     integer :: iacceleration

     ! Performance variables from input.perf
     logical :: debug      !< Debug option (used by memocc)
     integer :: ncache_fft !< Cache size for FFT
     real(gp) :: projrad   !< Coarse radius of the projectors in units of the maxrad
     real(gp) :: symTol    !< Tolerance for symmetry detection.
     integer :: linear
     logical :: signaling  !< Expose results on DBus or Inet.
     integer :: signalTimeout !< Timeout for inet connection.
     character(len = 64) :: domain !< Domain to get the IP from hostname.
     double precision :: gmainloop !< Internal C pointer on the signaling structure.

     !orthogonalisation data
     type(orthon_data) :: orthpar
  
     !linear scaling data
     type(linearInputParameters) :: lin

     !> parallelisation scheme of the exact exchange operator
     !!   BC (Blocking Collective)
     !!   OP2P (Overlap Point-to-Point)
     character(len=4) :: exctxpar

     !> paradigm for unblocking global communications via OMP_NESTING
     character(len=3) :: unblock_comms

     !> communication scheme for the density
     !!  DBL traditional scheme with double precision
     !!  MIX mixed single-double precision scheme (requires rho_descriptors)
     character(len=3) :: rho_commun
  end type input_variables

  type, public :: energy_terms
     real(gp) :: eh     =0.0_gp
     real(gp) :: exc    =0.0_gp
     real(gp) :: evxc   =0.0_gp
     real(gp) :: eion   =0.0_gp
     real(gp) :: edisp  =0.0_gp
     real(gp) :: ekin   =0.0_gp
     real(gp) :: epot   =0.0_gp
     real(gp) :: eproj  =0.0_gp
     real(gp) :: eexctX =0.0_gp
     real(gp) :: ebs    =0.0_gp
     real(gp) :: eKS    =0.0_gp
     real(gp) :: trH    =0.0_gp
     real(gp) :: evsum  =0.0_gp
     real(gp) :: evsic  =0.0_gp 
     real(gp) :: excrhoc=0.0_gp 
     !real(gp), dimension(:,:), pointer :: fion,f

     integer(kind = 8) :: c_obj = 0  !< Storage of the C wrapper object.
  end type energy_terms

!>  Bounds for coarse and fine grids for kinetic operations
!!  Useful only for isolated systems AND in CPU
  type, public :: kinetic_bounds
     integer, dimension(:,:,:), pointer :: ibyz_c,ibxz_c,ibxy_c
     integer, dimension(:,:,:), pointer :: ibyz_f,ibxz_f,ibxy_f
  end type kinetic_bounds


!>  Bounds to compress the wavefunctions
!!  Useful only for isolated systems AND in CPU
  type, public :: shrink_bounds
     integer, dimension(:,:,:), pointer :: ibzzx_c,ibyyzz_c
     integer, dimension(:,:,:), pointer :: ibxy_ff,ibzzx_f,ibyyzz_f
  end type shrink_bounds


!>  Bounds to uncompress the wavefunctions
!!  Useful only for isolated systems AND in CPU
  type, public :: grow_bounds
     integer, dimension(:,:,:), pointer :: ibzxx_c,ibxxyy_c
     integer, dimension(:,:,:), pointer :: ibyz_ff,ibzxx_f,ibxxyy_f
  end type grow_bounds


!>  Bounds for convolutions operations
!!  Useful only for isolated systems AND in CPU
  type, public :: convolutions_bounds
     type(kinetic_bounds) :: kb
     type(shrink_bounds) :: sb
     type(grow_bounds) :: gb
     integer, dimension(:,:,:), pointer :: ibyyzz_r !< real space border
  end type convolutions_bounds

!>  Used for lookup table for compressed wavefunctions
  type, public :: wavefunctions_descriptors
     integer :: nvctr_c,nvctr_f,nseg_c,nseg_f
     integer, dimension(:,:), pointer :: keyglob
     integer, dimension(:,:), pointer :: keygloc
     integer, dimension(:), pointer :: keyvloc,keyvglob
  end type wavefunctions_descriptors

!>  Grid dimensions in old different wavelet basis
  type, public :: grid_dimensions
     integer :: n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,n1i,n2i,n3i
  end type grid_dimensions

!> Contains the information needed for describing completely a
!! wavefunction localisation region
  type, public :: locreg_descriptors
     character(len=1) :: geocode
     logical :: hybrid_on   !< interesting for global, periodic, localisation regions
     integer :: ns1,ns2,ns3 !< starting point of the localisation region in global coordinates
     integer :: nsi1,nsi2,nsi3  !< starting point of locreg for interpolating grid
     integer :: Localnorb              !< number of orbitals contained in locreg
     integer,dimension(3) :: outofzone  !< vector of points outside of the zone outside Glr for periodic systems
!     integer,dimension(:), pointer :: projflg    !< atoms contributing nlpsp projectors to locreg
     type(grid_dimensions) :: d
     type(wavefunctions_descriptors) :: wfd
     type(convolutions_bounds) :: bounds
     real(8),dimension(3):: locregCenter !< center of the locreg 
     real(8):: locrad !< cutoff radius of the localization region
  end type locreg_descriptors

!>  Non local pseudopotential descriptors
  type, public :: nonlocal_psp_descriptors
     integer :: nproj,nprojel,natoms                  !< Number of projectors and number of elements
     type(locreg_descriptors), dimension(:), pointer :: plr !< pointer which indicates the different localization region per processor
     !> Projector segments on real space grid
!!$     integer, dimension(:), pointer :: nvctr_p,nseg_p,keyv_p
!!$     integer, dimension(:,:), pointer :: keyg_p 
!!$     !> Parameters for the boxes containing the projectors
!!$     integer, dimension(:,:,:), pointer :: nboxp_c,nboxp_f
  end type nonlocal_psp_descriptors


!> Used to split between points to be treated in simple or in double precision
  type, public :: rho_descriptors
     character(len=1) :: geocode
     integer :: icomm !< method for communicating the density
     integer :: nrhotot !< dimension of the partial density array before communication
     integer :: n_csegs,n_fsegs,dp_size,sp_size
     integer, dimension(:,:), pointer :: spkey,dpkey
     integer, dimension(:), pointer :: cseg_b,fseg_b
  end type rho_descriptors

!> Quantities used for the symmetry operators.
  type, public :: symmetry_data
     integer :: symObj    !< The symmetry object from ABINIT
     integer, dimension(:,:,:), pointer :: irrzon
     real(dp), dimension(:,:,:), pointer :: phnons
  end type symmetry_data

!>  Atomic data (name, polarisation, ...)
  type, public :: atoms_data
     character(len=1) :: geocode
     character(len=5) :: format
     character(len=20) :: units
     integer :: nat                                        !< nat            Number of atoms
     integer :: ntypes                                     !< ntypes         Number of type of atoms
     integer :: natsc
     character(len=20), dimension(:), pointer :: atomnames !< atomnames(ntypes) Name of type of atoms
     real(gp) :: alat1,alat2,alat3                         !< dimension of the periodic supercell
     integer, dimension(:), pointer :: iatype              !< iatype(nat)    Type of the atoms
     integer, dimension(:), pointer :: iasctype
     integer, dimension(:), pointer :: natpol
     integer, dimension(:), pointer :: nelpsp
     integer, dimension(:), pointer :: npspcode
     integer, dimension(:), pointer :: ixcpsp
     integer, dimension(:), pointer :: nzatom
     real(gp), dimension(:,:), pointer :: radii_cf         !< user defined radii_cf, overridden in sysprop.f90
     integer, dimension(:), pointer :: ifrztyp             !< ifrztyp(nat) Frozen atoms
     real(gp), dimension(:), pointer :: amu                !< amu(ntypes)  Atomic Mass Unit for each type of atoms
     real(gp), dimension(:,:), pointer :: aocc,rloc
     real(gp), dimension(:,:,:), pointer :: psppar !< pseudopotential parameters (HGH SR section)
     logical :: donlcc                             !< activate non-linear core correction treatment
     integer, dimension(:), pointer :: nlcc_ngv,nlcc_ngc !<number of valence and core gaussians describing NLCC 
     real(gp), dimension(:,:), pointer :: nlccpar    !< parameters for the non-linear core correction, if present
     real(gp), dimension(:,:), pointer :: ig_nlccpar !< parameters for the input NLCC
     type(symmetry_data) :: sym                      !< The symmetry operators

     !! for abscalc with pawpatch
     integer, dimension(:), pointer ::  paw_NofL, paw_l, paw_nofchannels
     integer, dimension(:), pointer ::  paw_nofgaussians
     real(gp), dimension(:), pointer :: paw_Greal, paw_Gimag, paw_Gcoeffs
     real(gp), dimension(:), pointer :: paw_H_matrices, paw_S_matrices, paw_Sm1_matrices
     integer :: iat_absorber 

  end type atoms_data

!> Structure to store the density / potential distribution among processors.
  type, public :: denspot_distribution
     integer :: n3d,n3p,n3pi,i3xcsh,i3s,nrhodim,i3rho_add
     integer :: ndimpot,ndimgrid,ndimrhopot 
     integer, dimension(3) :: ndims !< box containing the grid dimensions in ISF basis
     real(gp), dimension(3) :: hgrids !< grid spacings of the box (half of wavelet ones)
     integer, dimension(:,:), pointer :: nscatterarr, ngatherarr
  end type denspot_distribution

!>  Structures of basis of gaussian functions
  type, public :: gaussian_basis
     integer :: nat,ncoeff,nshltot,nexpo
     integer, dimension(:), pointer :: nshell,ndoc,nam
     real(gp), dimension(:), pointer :: xp,psiat
     real(gp), dimension(:,:), pointer :: rxyz
  end type gaussian_basis

!>   Structures of basis of gaussian functions of the form exp(-a*r2)cos/sin(b*r2)
  type, public :: gaussian_basis_c
     integer :: nat,ncoeff,nshltot,nexpo
     integer, dimension(:), pointer :: nshell,ndoc,nam
     complex(gp), dimension(:), pointer :: expof,psiat
     real(gp), dimension(:,:), pointer :: rxyz
  end type gaussian_basis_c

!>   contains all array necessary to apply preconditioning projectors 
  type, public :: pcproj_data_type
     type(nonlocal_psp_descriptors) :: pc_nlpspd
     real(gp), pointer :: pc_proj(:)
     integer , pointer , dimension(:):: ilr_to_mproj, iproj_to_l
     real(gp) , pointer ::  iproj_to_ene(:)
     real(gp) , pointer ::  iproj_to_factor(:)
     integer, pointer :: iorbtolr(:)
     integer :: mprojtot
     type(gaussian_basis)  :: G          
     real(gp), pointer :: gaenes(:)
     real(gp) :: ecut_pc
     logical :: DistProjApply
  end type pcproj_data_type

!>   contains all array necessary to apply preconditioning projectors 
  type, public :: PAWproj_data_type
     type(nonlocal_psp_descriptors) :: paw_nlpspd

     integer , pointer , dimension(:):: iproj_to_paw_nchannels
     integer , pointer , dimension(:):: ilr_to_mproj, iproj_to_l
     integer , pointer , dimension(:):: iprojto_imatrixbeg

     integer :: mprojtot
     real(gp), pointer :: paw_proj(:)
     type(gaussian_basis_c)  :: G          
     integer, pointer :: iorbtolr(:)
     logical :: DistProjApply
  end type PAWproj_data_type


!> All the parameters which are important for describing the orbitals
!! Add also the objects related to k-points sampling, after symmetries applications
  type, public :: orbitals_data 
     integer :: norb,norbp,norbu,norbd,nspin,nspinor,isorb
     integer :: npsidim_orbs,nkpts,nkptsp,iskpts,npsidim_comp
     real(gp) :: efermi,HLgap, eTS
     integer, dimension(:), pointer :: iokpt,ikptproc,isorb_par,ispot
     integer, dimension(:), pointer :: inwhichlocreg,onWhichMPI,onwhichatom
     integer, dimension(:,:), pointer :: norb_par
     real(wp), dimension(:), pointer :: eval
     real(gp), dimension(:), pointer :: occup,spinsgn,kwgts
     real(gp), dimension(:,:), pointer :: kpts
  end type orbitals_data

!> Contains the information needed for communicating the wavefunctions
!! between processors for the transposition
  type, public :: communications_arrays
     integer, dimension(:), pointer :: ncntd,ncntt,ndspld,ndsplt
     integer, dimension(:,:), pointer :: nvctr_par
  end type communications_arrays


!> Contains the pointers to be handled to control GPU information
!! Given that they are pointers on GPU address, they are C pointers
!! which take 8 bytes
!! So they are declared as kind=8 variables either if the GPU works in simple precision
!! Also other information concerning the GPU runs can be stored in this structure
  type, public :: GPU_pointers
     logical :: useDynamic,full_locham
     integer :: id_proc,ndevices
     real(kind=8) :: keys,work1,work2,work3,rhopot,r,d
     real(kind=8) :: rhopot_down, rhopot_up
     real(kind=8) :: work1_i,work2_i,work3_i,d_i
     real(kind=8) :: pinned_in,pinned_out
     real(kind=8), dimension(:), pointer :: psi
     real(kind=8) :: psi_c,psi_f
     real(kind=8) :: psi_c_i,psi_f_i
     real(kind=8) :: psi_c_r,psi_f_r,psi_c_b,psi_f_b,psi_c_d,psi_f_d
     real(kind=8) :: psi_c_r_i,psi_f_r_i,psi_c_b_i,psi_f_b_i,psi_c_d_i,psi_f_d_i
     real(kind=8) :: keyg_c,keyg_f,keyv_c,keyv_f
     real(kind=8) :: context,queue
     real(gp), dimension(:,:), pointer :: ekin, epot !< values of the kinetic and potential energies to be passed to local_hamiltonian
     real(wp), dimension(:), pointer :: hpsi_ASYNC !<pointer to the wavefunction allocated in the case of asyncronous local_hamiltonian
  end type GPU_pointers

  !> Contains all the descriptors necessary for splitting the calculation in different locregs 
  type,public:: local_zone_descriptors
     logical :: linear                         !< if true, use linear part of the code
     integer :: nlr                            !< Number of localization regions 
     integer :: lintyp                         !< if 0 cubic, 1 locreg and 2 TMB
!    integer :: Lpsidimtot, lpsidimtot_der     !< Total dimension of the wavefunctions in the locregs, the same including the derivatives
     integer:: ndimpotisf                      !< total dimension of potential in isf (including exctX)
!     integer :: Lnprojel                       !< Total number of projector elements
     real(gp), dimension(3) :: hgrids          !<grid spacings of wavelet grid
!     real(gp), dimension(:,:),pointer :: rxyz  !< Centers for the locregs
     logical,dimension(:),pointer:: doHamAppl  !< if entry i is true, apply the Hamiltonian to orbitals in locreg i
     type(locreg_descriptors) :: Glr           !< Global region descriptors
!    type(nonlocal_psp_descriptors) :: Gnlpspd !< Global nonlocal pseudopotential descriptors
     type(locreg_descriptors),dimension(:),pointer :: Llr                !< Local region descriptors (dimension = nlr)
    !!!real(8),dimension(:,:),pointer:: cutoffweight
  end type local_zone_descriptors

!> Contains the work arrays needed for expressing wavefunction in real space
!!  with all the BC
  type, public :: workarr_sumrho
     integer :: nw1,nw2,nxc,nxf
     real(wp), dimension(:), pointer :: x_c,x_f,w1,w2
  end type workarr_sumrho


!> Contains the work arrays needed for hamiltonian application with all the BC
  type, public :: workarr_locham
     integer :: nw1,nw2,nxc,nyc,nxf1,nxf2,nxf3,nxf,nyf
     real(wp), dimension(:), pointer :: w1,w2
     !for the periodic BC case, these arrays substitute 
     !psifscf,psifscfk,psig,ww respectively
     real(wp), dimension(:,:), pointer :: x_c,y_c,x_f1,x_f2,x_f3,x_f,y_f
  end type workarr_locham


!> Contains the work arrays needed for th preconditioner with all the BC
!! Take different pointers depending on the boundary conditions
  type, public :: workarr_precond
     integer, dimension(:), pointer :: modul1,modul2,modul3
     real(wp), dimension(:), pointer :: psifscf,ww,x_f1,x_f2,x_f3,kern_k1,kern_k2,kern_k3
     real(wp), dimension(:,:), pointer :: af,bf,cf,ef
     real(wp), dimension(:,:,:), pointer :: xpsig_c,ypsig_c,x_c
     real(wp), dimension(:,:,:,:), pointer :: xpsig_f,ypsig_f,x_f,y_f
     real(wp), dimension(:,:,:,:,:), pointer :: z1,z3 ! work array for FFT
  end type workarr_precond


!> Contains the arguments needed for the application of the hamiltonian
  type, public :: lanczos_args
     !arguments for the hamiltonian
     integer :: iproc,nproc,ndimpot,nspin, in_iat_absorber, Labsorber
     real(gp) :: hx,hy,hz
     type(energy_terms) :: energs
     !real(gp) :: ekin_sum,epot_sum,eexctX,eproj_sum,eSIC_DC
     type(atoms_data), pointer :: at
     type(orbitals_data), pointer :: orbs
     type(communications_arrays) :: comms
     type(nonlocal_psp_descriptors), pointer :: nlpspd
     type(local_zone_descriptors), pointer :: Lzd
     type(gaussian_basis), pointer :: Gabsorber    
     type(SIC_data), pointer :: SIC
     integer, dimension(:,:), pointer :: ngatherarr 
     real(gp), dimension(:,:),  pointer :: rxyz,radii_cf
     real(wp), dimension(:), pointer :: proj
     !real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%nspinor*orbs%norbp), pointer :: psi
     real(wp), dimension(:), pointer :: potential
     real(wp), dimension(:), pointer :: Gabs_coeffs
     !real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,orbs%nspinor*orbs%norbp) :: hpsi
     type(GPU_pointers), pointer :: GPU
     type(pcproj_data_type), pointer :: PPD
     type(pawproj_data_type), pointer :: PAWD
  end type lanczos_args


  !> Contains all parameters needed for point to point communication
  type,public:: p2pComms
    integer,dimension(:),pointer:: noverlaps, overlaps
    real(8),dimension(:),pointer:: sendBuf, recvBuf
    integer,dimension(:,:,:),pointer:: comarr
    integer:: nsendBuf, nrecvBuf, nrecv, nsend
    integer,dimension(:,:),pointer:: ise3 ! starting / ending index of recvBuf in z dimension after communication (glocal coordinates)
    integer,dimension(:,:),pointer:: requests
    logical:: communication_complete, messages_posted
  end type p2pComms

!! Contains the parameters for calculating the overlap matrix for the orthonormalization etc...
  type,public:: overlapParameters
      integer:: ndim_lphiovrlp, noverlapsmax, noverlapsmaxp, nsubmax
      integer,dimension(:),pointer:: noverlaps !, indexExpand, indexExtract
      integer,dimension(:,:),pointer:: overlaps
      integer,dimension(:,:),pointer:: indexInRecvBuf
      integer,dimension(:,:),pointer:: indexInSendBuf
      type(wavefunctions_descriptors),dimension(:,:),pointer:: wfd_overlap
  end type overlapParameters


  type,public:: matrixLocalizationRegion
      integer:: norbinlr
      integer,dimension(:),pointer:: indexInGlobal
  end type matrixLocalizationRegion


  type,public:: overlap_parameters_matrix
      integer,dimension(:),pointer:: noverlap
      integer,dimension(:,:),pointer:: overlaps
      integer,dimension(:,:,:),pointer:: olrForExpansion
      type(matrixLocalizationRegion),dimension(:,:),pointer:: olr
  end type overlap_parameters_matrix

  !!type,public:: p2pCommsOrthonormalityMatrix
  !!    integer:: nrecvBuf, nsendBuf, nrecv, nsend
  !!    integer,dimension(:),pointer:: noverlap
  !!    integer,dimension(:,:),pointer:: overlaps, requests
  !!    integer,dimension(:,:,:),pointer:: comarr
  !!    real(8),dimension(:),pointer:: recvBuf, sendBuf
  !!    logical:: communication_complete
  !!end type p2pCommsOrthonormalityMatrix

  type,public:: matrixMinimization
    type(matrixLocalizationRegion),dimension(:),pointer:: mlr
    integer:: norbmax ! maximal matrix size handled by a given process
    integer:: nlrp ! number of localization regions handled by a given process
    integer,dimension(:),pointer:: inWhichLocregExtracted
    integer,dimension(:),pointer:: inWhichLocregOnMPI
    integer,dimension(:),pointer:: indexInLocreg
  end type matrixMinimization

  type,public:: matrixDescriptors
      integer:: nvctr, nseg, nvctrmatmul, nsegmatmul, nseglinemax
      integer,dimension(:),pointer:: keyv, keyvmatmul, nsegline
      integer,dimension(:,:),pointer:: keyg, keygmatmul
      integer,dimension(:,:,:),pointer:: keygline
  end type matrixDescriptors


  !> Contains arrays for collective communications
  type,public:: collectiveComms
      integer,dimension(:,:),pointer:: nvctr_par
      integer,dimension(:),pointer:: sendcnts, senddspls, recvcnts, recvdspls, indexarray
  end type collectiveComms

  type:: collective_comms
    integer,dimension(:),pointer:: nsendcounts_c, nsenddspls_c, nrecvcounts_c, nrecvdspls_c
    integer,dimension(:),pointer:: isendbuf_c, iextract_c, iexpand_c, irecvbuf_c
    integer,dimension(:),pointer:: norb_per_gridpoint_c, indexrecvorbital_c
    integer:: nptsp_c, ndimpsi_c, ndimind_c, ndimind_f
    integer,dimension(:),pointer:: nsendcounts_f, nsenddspls_f, nrecvcounts_f, nrecvdspls_f
    integer,dimension(:),pointer:: isendbuf_f, iextract_f, iexpand_f, irecvbuf_f
    integer,dimension(:),pointer:: norb_per_gridpoint_f, indexrecvorbital_f
    integer:: nptsp_f, ndimpsi_f
  end type collective_comms


!!!!> Contains all parameters for the basis with which we calculate the properties
!!!!! like energy and forces. Since we may also use the derivative of the trace
!!!!! minimizing orbitals, this basis may be larger than only the trace minimizing
!!!!! orbitals. In case we don't use the derivatives, these parameters are identical
!!!!! from those in lin%orbs etc.
!!!type,public:: largeBasis
!!!    type(communications_arrays):: comms, gcomms
!!!    type(orbitals_data):: orbs, gorbs
!!!    !type(local_zone_descriptors):: lzd
!!!    !type(p2pCommsRepartition):: comrp
!!!    type(p2pComms):: comrp
!!!    !type(p2pCommsOrthonormality):: comon
!!!    type(p2pComms):: comon
!!!    type(overlapParameters):: op
!!!    !type(p2pCommsGatherPot):: comgp
!!!    type(p2pComms):: comgp
!!!    type(matrixDescriptors):: mad
!!!    type(collectiveComms):: collComms
!!!    !type(p2pCommsSumrho):: comsr
!!!    type(p2pComms):: comsr
!!!end type largeBasis


type,public:: workarrays_quartic_convolutions
  real(wp),dimension(:,:,:),pointer:: xx_c, xy_c, xz_c
  real(wp),dimension(:,:,:),pointer:: xx_f1
  real(wp),dimension(:,:,:),pointer:: xy_f2
  real(wp),dimension(:,:,:),pointer:: xz_f4
  real(wp),dimension(:,:,:,:),pointer:: xx_f, xy_f, xz_f
  real(wp),dimension(:,:,:),pointer:: y_c
  real(wp),dimension(:,:,:,:),pointer:: y_f
end type workarrays_quartic_convolutions

type:: linear_scaling_control_variables
  integer:: nit_highaccuracy, nit_scc, nit_scc_when_optimizing, mix_hist, info_basis_functions, idecrease, ifail
  real(8):: pnrm_out, decrease_factor_total, alpha_mix, increase_locreg, self_consistent
  logical:: lowaccur_converged, withder, locreg_increased, exit_outer_loop, variable_locregs, compare_outer_loop
  logical:: reduce_convergence_tolerance, enlarge_locreg
  real(8),dimension(:),allocatable:: locrad
end type linear_scaling_control_variables


  type,public:: localizedDIISParameters
    integer:: is, isx, mis, DIISHistMax, DIISHistMin
    integer:: icountSDSatur, icountDIISFailureCons, icountSwitch, icountDIISFailureTot, itBest
    real(8),dimension(:),pointer:: phiHist, hphiHist
    real(8),dimension(:,:,:),pointer:: mat
    real(8):: trmin, trold, alphaSD, alphaDIIS
    logical:: switchSD, immediateSwitchToSD, resetDIIS
  end type localizedDIISParameters

  type,public:: mixrhopotDIISParameters
    integer:: is, isx, mis
    real(8),dimension(:),pointer:: rhopotHist, rhopotresHist
    real(8),dimension(:,:),pointer:: mat
  end type mixrhopotDIISParameters


!> Contains all parameters related to the linear scaling version.
  !!!type,public:: linearParameters
  !!!  integer:: DIISHistMin, DIISHistMax, nItPrecond
  !!!  integer :: nItSCCWhenOptimizing, confPotOrder, norbsPerProcIG, nItBasis_lowaccuracy, nItBasis_highaccuracy
  !!!  integer:: nItInguess, nlr, nLocregOverlap, nItOrtho, mixHist_lowaccuracy, mixHist_highaccuracy
  !!!  integer:: methTransformOverlap, blocksize_pdgemm, blocksize_pdsyev
  !!!  integer:: correctionOrthoconstraint, nproc_pdsyev, nproc_pdgemm, memoryForCommunOverlapIG, nItSCCWhenFixed
  !!!  integer:: nItSCCWhenOptimizing_lowaccuracy, nItSCCWhenFixed_lowaccuracy
  !!!  integer:: nItSCCWhenOptimizing_highaccuracy, nItSCCWhenFixed_highaccuracy
  !!!  integer:: nItInnerLoop, nit_lowaccuracy, nit_highaccuracy
  !!!  real(8):: convCrit, alphaSD, alphaDIIS, alphaMixWhenFixed_lowaccuracy, alphaMixWhenFixed_highaccuracy
  !!!  real(kind=8) :: alphaMixWhenOptimizing_lowaccuracy, alphaMixWhenOptimizing_highaccuracy, convCritMix
  !!!  real(8):: lowaccuray_converged
  !!!  real(8),dimension(:),pointer:: potentialPrefac, locrad, locrad_lowaccuracy, locrad_highaccuracy
  !!!  real(8),dimension(:),pointer:: lphiold
  !!!  real(8),dimension(:),pointer:: potentialPrefac_lowaccuracy, potentialPrefac_highaccuracy
  !!!  type(orbitals_data):: orbs, gorbs
  !!!  type(communications_arrays):: comms, gcomms
  !!!  integer,dimension(:),pointer:: norbsPerType
  !!!  !type(arraySizes):: as
  !!!  logical:: plotBasisFunctions, useDerivativeBasisFunctions, transformToGlobal
  !!!  logical:: newgradient, mixedmode
  !!!  character(len=4):: mixingMethod
  !!!  !type(p2pCommsSumrho):: comsr
  !!!  type(p2pComms):: comsr
  !!!  !type(p2pCommsGatherPot):: comgp
  !!!  type(p2pComms):: comgp
  !!!  type(largeBasis):: lb
  !!!  type(local_zone_descriptors):: lzd
  !!!  !type(p2pCommsOrthonormality):: comon
  !!!  type(p2pComms):: comon
  !!!  type(overlapParameters):: op
  !!!  type(matrixDescriptors):: mad
  !!!  character(len=1):: locregShape
  !!!  type(collectiveComms):: collComms
  !!!end type linearParameters

  type,public:: basis_specifications
    logical:: update_phi !<shall phi be optimized or not
    logical:: use_derivative_basis !<use derivatives or not
    logical:: communicate_phi_for_lsumrho !<communicate phi for the calculation of the charge density
    real(8):: conv_crit !<convergence criterion for the basis functions
    real(8):: locreg_enlargement !<enlargement factor for the second locreg (optimization of phi)
    integer:: target_function !<minimize trace or energy
    integer:: meth_transform_overlap !<exact or Taylor approximation
    integer:: nit_precond !<number of iterations for preconditioner
    integer:: nit_basis_optimization !<number of iterations for optimization of phi
    integer:: nit_unitary_loop !<number of iterations in inner unitary optimization loop
    integer:: confinement_decrease_mode !<decrase confining potential linearly or abrupt at the end
  end type basis_specifications

  type,public:: basis_performance_options
    integer:: blocksize_pdgemm !<block size for pdgemm (scalapck)
    integer:: blocksize_pdsyev !<block size for pdsyev (scalapck)
    integer:: nproc_pdsyev !,number of processors used for pdsyev (scalapck)
    integer:: communication_strategy_overlap
  end type basis_performance_options

  type,public:: wfn_metadata
    integer:: nphi !<size of phi without derivative
    integer:: ld_coeff !<leading dimension of coeff
    real(8),dimension(:,:),pointer:: coeff !<expansion coefficients, with or without derivatives
    real(8),dimension(:,:),pointer::  coeff_proj !<expansion coefficients, without derivatives
    real(8),dimension(:,:),pointer:: coeffp !<coefficients distributed over processes
    type(basis_specifications):: bs !<contains parameters describing the basis functions
    type(basis_performance_options):: bpo !<contains performance parameters
    real(8),dimension(:),pointer:: alpha_coeff !<step size for optimization of coefficients
    real(8),dimension(:,:),pointer:: grad_coeff_old !coefficients gradient of previous iteration
    integer:: it_coeff_opt !<counts the iterations of the optimization of the coefficients
  end type wfn_metadata


!> Contains the arguments needed for the diis procedure
  type, public :: diis_objects
     logical :: switchSD
     integer :: idiistol,mids,ids,idsx
     real(gp) :: energy_min,energy_old,energy,alpha,alpha_max
     real(tp), dimension(:), pointer :: psidst
     real(tp), dimension(:), pointer :: hpsidst
     real(tp), dimension(:,:,:,:,:,:), pointer :: ads
  end type diis_objects

!> Contains the information needed for the preconditioner
  type, public :: precond_data
    integer :: confPotOrder                           !< The order of the algebraic expression for Confinement potential
    integer :: ncong                                  !< Number of CG iterations for the preconditioning equation
    logical, dimension(:), pointer :: withConfPot     !< Use confinement potentials
    real(8), dimension(:), pointer :: potentialPrefac !< Prefactor for the potential: Prefac * f(r) 
  end type precond_data

!> Information for the confining potential to be used in TMB scheme
!! The potential is supposed to be defined as prefac*(r-rC)**potorder
  type, public :: confpot_data
     integer :: potorder !< order of the confining potential
     integer, dimension(3) :: ioffset !< offset for the coordinates of potential lr in global region
     real(gp) :: prefac !< prefactor
     real(gp), dimension(3) :: hh !< grid spacings in ISF grid
     real(gp), dimension(3) :: rxyzConf !< confining potential center in global coordinates
  end type confpot_data

  !> Densities and potentials, and related metadata, needed for their creation/application
  !! Not all these quantities are available, some of them may point to the same memory space
  type, public :: DFT_local_fields
     real(dp), dimension(:), pointer :: rhov !< generic workspace. What is there is indicated by rhov_is
     
     type(ab6_mixing_object), pointer :: mix          !< History of rhov, allocated only when using diagonalisation
     !local fields which are associated to their name
     !normally given in parallel distribution
     real(dp), dimension(:,:), pointer :: rho_psi !< density as given by square of el. WFN
     real(dp), dimension(:,:,:,:), pointer :: rho_C   !< core density
     real(wp), dimension(:,:,:,:), pointer :: V_ext   !< local part of pseudopotientials
     real(wp), dimension(:,:,:,:), pointer :: V_XC    !< eXchange and Correlation potential (local)
     real(wp), dimension(:,:,:,:), pointer :: Vloc_KS !< complete local potential of KS Hamiltonian (might point on rho_psi)
     real(wp), dimension(:,:,:,:), pointer :: f_XC !< dV_XC[rho]/d_rho
     !temporary arrays
     real(wp), dimension(:), pointer :: rho_work,pot_work !<full grid arrays
     !metadata
     integer :: rhov_is
     real(gp) :: psoffset !< offset of the Poisson Solver in the case of Periodic BC
     type(rho_descriptors) :: rhod !< descriptors of the density for parallel communication
     type(denspot_distribution) :: dpbox !< distribution of density and potential box
     character(len=3) :: PSquiet
     !real(gp), dimension(3) :: hgrids !<grid spacings of denspot grid (half of the wvl grid)
     real(dp), dimension(:), pointer :: pkernel !< kernel of the Poisson Solverm used for V_H[rho]
     real(dp), dimension(:), pointer :: pkernelseq !<for monoproc PS (useful for exactX, SIC,...)

     integer(kind = 8) :: c_obj = 0                !< Storage of the C wrapper object.
  end type DFT_local_fields

  !> Flags for rhov status
  integer, parameter, public :: EMPTY              = -1980
  integer, parameter, public :: ELECTRONIC_DENSITY = -1979
  integer, parameter, public :: CHARGE_DENSITY     = -1978
  integer, parameter, public :: KS_POTENTIAL       = -1977
  integer, parameter, public :: HARTREE_POTENTIAL  = -1976

  !> The wavefunction which have to be considered at the DFT level
  type, public :: DFT_wavefunction
     !coefficients
     real(wp), dimension(:), pointer :: psi,hpsi,psit,psit_c,psit_f !< orbitals, or support functions, in wavelet basis
     real(wp), dimension(:), pointer :: spsi !< Metric operator applied to psi (To be used for PAW)
     real(wp), dimension(:,:), pointer :: gaucoeffs !orbitals in gbd basis
     !basis sets
     type(gaussian_basis) :: gbd !<gaussian basis description, if associated
     type(local_zone_descriptors) :: Lzd !< data on the localisation regions, if associated

     !data properties
     logical:: can_use_transposed !< true if the transposed quantities are allocated and can be used
     type(orbitals_data) :: orbs !<wavefunction specification in terms of orbitals
     type(communications_arrays) :: comms !< communication objects for the cubic approach
     type(diis_objects) :: diis
     type(confpot_data), dimension(:), pointer :: confdatarr !<data for the confinement potential
     type(SIC_data) :: SIC !<control the activation of SIC scheme in the wavefunction
     type(orthon_data) :: orthpar !< control the application of the orthogonality scheme for cubic DFT wavefunction
     character(len=4) :: exctxpar !< Method for exact exchange parallelisation for the wavefunctions, in case
     type(wfn_metadata) :: wfnmd !<specifications of the kind of wavefunction
     type(p2pComms):: comon !<describing p2p communications for orthonormality
     type(overlapParameters):: op !<describing the overlaps
     type(p2pComms):: comgp !<describing p2p communications for distributing the potential
     type(p2pComms):: comrp !<describing the repartition of the orbitals (for derivatives)
     type(p2pComms):: comsr !<describing the p2p communications for sumrho
     type(matrixDescriptors):: mad !<describes the structure of the matrices
     type(collective_comms):: collcom ! describes collective communication
     integer(kind = 8) :: c_obj !< Storage of the C wrapper object. it has to be initialized to zero
  end type DFT_wavefunction

  !> Flags for optimization loop id
  integer, parameter, public :: OPTLOOP_HAMILTONIAN   = 0
  integer, parameter, public :: OPTLOOP_SUBSPACE      = 1
  integer, parameter, public :: OPTLOOP_WAVEFUNCTIONS = 2
  integer, parameter, public :: OPTLOOP_N_LOOPS       = 3

  !> Used to control the optimization of wavefunctions
  type, public :: DFT_optimization_loop
     integer :: iscf !< Kind of optimization scheme.

     integer :: itrpmax !< specify the maximum number of mixing cycle on potential or density
     integer :: nrepmax !< specify the maximum number of restart after re-diagonalization
     integer :: itermax !< specify the maximum number of minimization iterations, self-consistent or not

     integer :: itrp    !< actual number of mixing cycle.
     integer :: itrep   !< actual number of re-diagonalisation runs.
     integer :: iter    !< actual number of minimization iterations.

     integer :: infocode !< return value after optimization loop.

     real(gp) :: gnrm   !< actual value of cv criterion of the minimization loop.
     real(gp) :: rpnrm  !< actual value of cv criterion of the mixing loop.

     real(gp) :: gnrm_cv       !< convergence criterion of the minimization loop.
     real(gp) :: rpnrm_cv      !< convergence criterion of the mixing loop.
     real(gp) :: gnrm_startmix !< gnrm value to start mixing after.

     integer(kind = 8) :: c_obj = 0 !< Storage of the C wrapper object.
  end type DFT_optimization_loop

  !>  Used to restart a new DFT calculation or to save information 
  !!  for post-treatment
  type, public :: restart_objects
     integer :: n1,n2,n3
     real(gp) :: hx_old,hy_old,hz_old
     !real(wp), dimension(:), pointer :: psi 
     !real(wp), dimension(:,:), pointer :: gaucoeffs
     real(gp), dimension(:,:), pointer :: rxyz_old,rxyz_new
     type(DFT_wavefunction) :: KSwfn !< Kohn-Sham wavefunctions
     !type(locreg_descriptors) :: Glr
     !type(local_zone_descriptors), target :: Lzd
     !type(gaussian_basis), target :: gbd
     !type(orbitals_data) :: orbs
     type(GPU_pointers) :: GPU 
  end type restart_objects


contains


!!$!> Allocate communications_arrays
!!$  subroutine allocate_comms(nproc,orbs,comms,subname)
!!$    use module_base
!!$    implicit none
!!$    character(len=*), intent(in) :: subname
!!$    integer, intent(in) :: nproc
!!$    type(orbitals_data), intent(in) :: orbs
!!$    type(communications_arrays), intent(out) :: comms
!!$    !local variables
!!$    integer :: i_stat
!!$
!!$    allocate(comms%nvctr_par(0:nproc-1,orbs%nkptsp+ndebug),stat=i_stat)
!!$    call memocc(i_stat,comms%nvctr_par,'nvctr_par',subname)
!!$    allocate(comms%ncntd(0:nproc-1+ndebug),stat=i_stat)
!!$    call memocc(i_stat,comms%ncntd,'ncntd',subname)
!!$    allocate(comms%ncntt(0:nproc-1+ndebug),stat=i_stat)
!!$    call memocc(i_stat,comms%ncntt,'ncntt',subname)
!!$    allocate(comms%ndspld(0:nproc-1+ndebug),stat=i_stat)
!!$    call memocc(i_stat,comms%ndspld,'ndspld',subname)
!!$    allocate(comms%ndsplt(0:nproc-1+ndebug),stat=i_stat)
!!$    call memocc(i_stat,comms%ndsplt,'ndsplt',subname)
!!$  END SUBROUTINE allocate_comms


!> De-Allocate communications_arrays
  subroutine deallocate_comms(comms,subname)
    use module_base
    implicit none
    character(len=*), intent(in) :: subname
    type(communications_arrays), intent(inout) :: comms
    !local variables
    integer :: i_all,i_stat

    i_all=-product(shape(comms%nvctr_par))*kind(comms%nvctr_par)
    deallocate(comms%nvctr_par,stat=i_stat)
    call memocc(i_stat,i_all,'nvctr_par',subname)
    i_all=-product(shape(comms%ncntd))*kind(comms%ncntd)
    deallocate(comms%ncntd,stat=i_stat)
    call memocc(i_stat,i_all,'ncntd',subname)
    i_all=-product(shape(comms%ncntt))*kind(comms%ncntt)
    deallocate(comms%ncntt,stat=i_stat)
    call memocc(i_stat,i_all,'ncntt',subname)
    i_all=-product(shape(comms%ndspld))*kind(comms%ndspld)
    deallocate(comms%ndspld,stat=i_stat)
    call memocc(i_stat,i_all,'ndspld',subname)
    i_all=-product(shape(comms%ndsplt))*kind(comms%ndsplt)
    deallocate(comms%ndsplt,stat=i_stat)
    call memocc(i_stat,i_all,'ndsplt',subname)
  END SUBROUTINE deallocate_comms


  subroutine deallocate_abscalc_input(in, subname)
    use module_base
    implicit none
    type(input_variables) :: in
    character(len=*), intent(in) :: subname

    !local variables
    integer :: i_all,i_stat

    i_all=-product(shape(in%Gabs_coeffs))*kind(in%Gabs_coeffs)
    deallocate(in%Gabs_coeffs, stat=i_stat)
    call memocc(i_stat,i_all,'in%Gabs_coeffs',subname)

  END SUBROUTINE deallocate_abscalc_input


!> De-Allocate orbitals data structure, except eval pointer
!! which is not allocated in the orbitals_descriptor routine
subroutine deallocate_orbs(orbs,subname)
  use module_base
  implicit none
    character(len=*), intent(in) :: subname
    type(orbitals_data), intent(inout) :: orbs
    !local variables
    integer :: i_all,i_stat

    i_all=-product(shape(orbs%norb_par))*kind(orbs%norb_par)
    deallocate(orbs%norb_par,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%norb_par',subname)
    i_all=-product(shape(orbs%occup))*kind(orbs%occup)
    deallocate(orbs%occup,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%occup',subname)
    i_all=-product(shape(orbs%spinsgn))*kind(orbs%spinsgn)
    deallocate(orbs%spinsgn,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%spinsgn',subname)
    i_all=-product(shape(orbs%kpts))*kind(orbs%kpts)
    deallocate(orbs%kpts,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%kpts',subname)
    i_all=-product(shape(orbs%kwgts))*kind(orbs%kwgts)
    deallocate(orbs%kwgts,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%kwgts',subname)
    i_all=-product(shape(orbs%iokpt))*kind(orbs%iokpt)
    deallocate(orbs%iokpt,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%iokpt',subname)
    i_all=-product(shape(orbs%ikptproc))*kind(orbs%ikptproc)
    deallocate(orbs%ikptproc,stat=i_stat)
    call memocc(i_stat,i_all,'ikptproc',subname)
    i_all=-product(shape(orbs%inwhichlocreg))*kind(orbs%inwhichlocreg)
    deallocate(orbs%inwhichlocreg,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%inwhichlocreg',subname)
    i_all=-product(shape(orbs%onwhichatom))*kind(orbs%onwhichatom)
    deallocate(orbs%onwhichatom,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%onwhichatom',subname)
    i_all=-product(shape(orbs%isorb_par))*kind(orbs%isorb_par)
    deallocate(orbs%isorb_par,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%isorb_par',subname)
    i_all=-product(shape(orbs%onWhichMPI))*kind(orbs%onWhichMPI)
    deallocate(orbs%onWhichMPI,stat=i_stat)
    call memocc(i_stat,i_all,'orbs%onWhichMPI',subname)
    if (associated(orbs%ispot)) then
       i_all=-product(shape(orbs%ispot))*kind(orbs%ispot)
       deallocate(orbs%ispot,stat=i_stat)
       call memocc(i_stat,i_all,'orbs%ispot',subname)
    end if

END SUBROUTINE deallocate_orbs


!> Allocate and nullify restart objects
  subroutine init_restart_objects(iproc,iacceleration,atoms,rst,subname)
    use module_base
    implicit none
    !Arguments
    character(len=*), intent(in) :: subname
    integer, intent(in) :: iproc,iacceleration
    type(atoms_data), intent(in) :: atoms
    type(restart_objects), intent(out) :: rst
    !local variables
    integer :: i_stat

    !allocate pointers
    allocate(rst%rxyz_new(3,atoms%nat+ndebug),stat=i_stat)
    call memocc(i_stat,rst%rxyz_new,'rxyz_new',subname)
    allocate(rst%rxyz_old(3,atoms%nat+ndebug),stat=i_stat)
    call memocc(i_stat,rst%rxyz_old,'rxyz_old',subname)

    !nullify unallocated pointers
    rst%KSwfn%c_obj = 0
    nullify(rst%KSwfn%psi)
    nullify(rst%KSwfn%orbs%eval)

    nullify(rst%KSwfn%gaucoeffs)

    nullify(rst%KSwfn%Lzd%Glr%wfd%keyglob)
    nullify(rst%KSwfn%Lzd%Glr%wfd%keygloc)
    nullify(rst%KSwfn%Lzd%Glr%wfd%keyvloc)
    nullify(rst%KSwfn%Lzd%Glr%wfd%keyvglob)
                
    nullify(rst%KSwfn%gbd%nshell)
    nullify(rst%KSwfn%gbd%ndoc)
    nullify(rst%KSwfn%gbd%nam)
    nullify(rst%KSwfn%gbd%xp)
    nullify(rst%KSwfn%gbd%psiat)
    nullify(rst%KSwfn%gbd%rxyz)

    !initialise the acceleration strategy if required
    call init_material_acceleration(iproc,iacceleration,rst%GPU)

  END SUBROUTINE init_restart_objects


!>  De-Allocate restart_objects
  subroutine free_restart_objects(rst,subname)
    use module_base
    implicit none
    character(len=*), intent(in) :: subname
    type(restart_objects) :: rst
    !local variables
    integer :: i_all,i_stat

    call deallocate_locreg_descriptors(rst%KSwfn%Lzd%Glr,subname)

    if (associated(rst%KSwfn%psi)) then
       i_all=-product(shape(rst%KSwfn%psi))*kind(rst%KSwfn%psi)
       deallocate(rst%KSwfn%psi,stat=i_stat)
       call memocc(i_stat,i_all,'psi',subname)
    end if

    if (associated(rst%KSwfn%orbs%eval)) then
       i_all=-product(shape(rst%KSwfn%orbs%eval))*kind(rst%KSwfn%orbs%eval)
       deallocate(rst%KSwfn%orbs%eval,stat=i_stat)
       call memocc(i_stat,i_all,'eval',subname)
    end if

    if (associated(rst%rxyz_old)) then
       i_all=-product(shape(rst%rxyz_old))*kind(rst%rxyz_old)
       deallocate(rst%rxyz_old,stat=i_stat)
       call memocc(i_stat,i_all,'rxyz_old',subname)
    end if

    if (associated(rst%rxyz_new)) then
       i_all=-product(shape(rst%rxyz_new))*kind(rst%rxyz_new)
       deallocate(rst%rxyz_new,stat=i_stat)
       call memocc(i_stat,i_all,'rxyz_new',subname)
    end if

    !The gaussian basis descriptors are always allocated together
    !with the gaussian coefficients
    if (associated(rst%KSwfn%gbd%rxyz)) then
       nullify(rst%KSwfn%gbd%rxyz)
       call deallocate_gwf(rst%KSwfn%gbd,subname)
    end if

    if (associated(rst%KSwfn%gaucoeffs)) then
       i_all=-product(shape(rst%KSwfn%gaucoeffs))*kind(rst%KSwfn%gaucoeffs)
       deallocate(rst%KSwfn%gaucoeffs,stat=i_stat)
       call memocc(i_stat,i_all,'gaucoeffs',subname)
    end if

    !finalise the material accelearion usage
    call release_material_acceleration(rst%GPU)

  END SUBROUTINE free_restart_objects


!> Allocate wavefunctions_descriptors
  subroutine allocate_wfd(wfd,subname)
    use module_base
    implicit none
    type(wavefunctions_descriptors), intent(inout) :: wfd
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_stat

    allocate(wfd%keyglob(2,max(1,wfd%nseg_c+wfd%nseg_f+ndebug)),stat=i_stat)
    call memocc(i_stat,wfd%keyglob,'keyglob',subname)
    allocate(wfd%keygloc(2,max(1,wfd%nseg_c+wfd%nseg_f+ndebug)),stat=i_stat)
    call memocc(i_stat,wfd%keygloc,'keygloc',subname)
    allocate(wfd%keyvloc(max(1,wfd%nseg_c+wfd%nseg_f+ndebug)),stat=i_stat)
    call memocc(i_stat,wfd%keyvloc,'keyvloc',subname)
    allocate(wfd%keyvglob(max(1,wfd%nseg_c+wfd%nseg_f+ndebug)),stat=i_stat)
    call memocc(i_stat,wfd%keyvglob,'keyvglob',subname)

  END SUBROUTINE allocate_wfd


!> De-Allocate wavefunctions_descriptors
  subroutine deallocate_wfd(wfd,subname)
    use module_base
    implicit none
    type(wavefunctions_descriptors) :: wfd
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_all,i_stat

    if (associated(wfd%keyglob, target = wfd%keygloc)) then
       i_all=-product(shape(wfd%keyglob))*kind(wfd%keyglob)
       deallocate(wfd%keyglob,stat=i_stat)
       call memocc(i_stat,i_all,'wfd%keyglob',subname)
       nullify(wfd%keyglob)
    else
       if(associated(wfd%keyglob)) then
          i_all=-product(shape(wfd%keyglob))*kind(wfd%keyglob)
          deallocate(wfd%keyglob,stat=i_stat)
          call memocc(i_stat,i_all,'wfd%keyglob',subname)
          nullify(wfd%keyglob)
       end if
       if(associated(wfd%keygloc)) then 
          i_all=-product(shape(wfd%keygloc))*kind(wfd%keygloc)
          deallocate(wfd%keygloc,stat=i_stat)
          call memocc(i_stat,i_all,'wfd%keygloc',subname)
          nullify(wfd%keygloc)
       end if
    end if
    if (associated(wfd%keyvloc, target= wfd%keyvglob)) then
       i_all=-product(shape(wfd%keyvloc))*kind(wfd%keyvloc)
       deallocate(wfd%keyvloc,stat=i_stat)
       call memocc(i_stat,i_all,'wfd%keyvloc',subname)
       nullify(wfd%keyvloc)
    else
       if (associated(wfd%keyvloc)) then
          i_all=-product(shape(wfd%keyvloc))*kind(wfd%keyvloc)
          deallocate(wfd%keyvloc,stat=i_stat)
          call memocc(i_stat,i_all,'wfd%keyvloc',subname)
          nullify(wfd%keyvloc)
       end if
       if (associated(wfd%keyvglob)) then
          i_all=-product(shape(wfd%keyvglob))*kind(wfd%keyvglob)
          deallocate(wfd%keyvglob,stat=i_stat)
          call memocc(i_stat,i_all,'wfd%keyvglob',subname)
          nullify(wfd%keyvglob)
       end if
    end if
  END SUBROUTINE deallocate_wfd

  subroutine deallocate_rho_descriptors(rhodsc,subname)
    use module_base
    implicit none
    type(rho_descriptors) :: rhodsc
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_all,i_stat

    if (associated(rhodsc%spkey))then
       i_all=-product(shape(rhodsc%spkey))*kind(rhodsc%spkey)
       deallocate(rhodsc%spkey,stat=i_stat)
       call memocc(i_stat,i_all,'spkey',subname)
    end if
    if (associated(rhodsc%dpkey))then
       i_all=-product(shape(rhodsc%dpkey))*kind(rhodsc%dpkey)
       deallocate(rhodsc%dpkey,stat=i_stat)
       call memocc(i_stat,i_all,'dpkey',subname)
    end if
    if (associated(rhodsc%cseg_b))then
       i_all=-product(shape(rhodsc%cseg_b))*kind(rhodsc%cseg_b)
       deallocate(rhodsc%cseg_b,stat=i_stat)
       call memocc(i_stat,i_all,'csegb',subname)
    end if
    if (associated(rhodsc%fseg_b))then
       i_all=-product(shape(rhodsc%fseg_b))*kind(rhodsc%fseg_b)
       deallocate(rhodsc%fseg_b,stat=i_stat)
       call memocc(i_stat,i_all,'fsegb',subname)
    end if

  end subroutine deallocate_rho_descriptors


!> De-Allocate gaussian_basis type
  subroutine deallocate_gwf(G,subname)
    use module_base
    implicit none
    type(gaussian_basis) :: G
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_all,i_stat

    !normally positions should be deallocated outside
    
    i_all=-product(shape(G%ndoc))*kind(G%ndoc)
    deallocate(G%ndoc,stat=i_stat)
    call memocc(i_stat,i_all,'ndoc',subname)
    i_all=-product(shape(G%nam))*kind(G%nam)
    deallocate(G%nam,stat=i_stat)
    call memocc(i_stat,i_all,'nam',subname)
    i_all=-product(shape(G%nshell))*kind(G%nshell)
    deallocate(G%nshell,stat=i_stat)
    call memocc(i_stat,i_all,'nshell',subname)
    i_all=-product(shape(G%psiat))*kind(G%psiat)
    deallocate(G%psiat,stat=i_stat)
    call memocc(i_stat,i_all,'psiat',subname)
    i_all=-product(shape(G%xp))*kind(G%xp)
    deallocate(G%xp,stat=i_stat)
    call memocc(i_stat,i_all,'xp',subname)

  END SUBROUTINE deallocate_gwf




!>   De-Allocate gaussian_basis type

  subroutine deallocate_gwf_c(G,subname)
    use module_base
    implicit none
    type(gaussian_basis_c) :: G
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_all,i_stat

    !normally positions should be deallocated outside
    
    i_all=-product(shape(G%ndoc))*kind(G%ndoc)
    deallocate(G%ndoc,stat=i_stat)
    call memocc(i_stat,i_all,'G%ndoc',subname)
    i_all=-product(shape(G%nam))*kind(G%nam)
    deallocate(G%nam,stat=i_stat)
    call memocc(i_stat,i_all,'nam',subname)
    i_all=-product(shape(G%nshell))*kind(G%nshell)
    deallocate(G%nshell,stat=i_stat)
    call memocc(i_stat,i_all,'G%nshell',subname)
    i_all=-product(shape(G%psiat))*kind(G%psiat)
    deallocate(G%psiat,stat=i_stat)
    call memocc(i_stat,i_all,'G%psiat',subname)

    i_all=-product(shape(G%expof))*kind(G%expof)
    deallocate(G%expof,stat=i_stat)
    call memocc(i_stat,i_all,'G%expof',subname)

    i_all=-product(shape(G%rxyz))*kind(G%rxyz)
    deallocate(G%rxyz,stat=i_stat)
    call memocc(i_stat,i_all,'G%rxyz',subname)

  END SUBROUTINE 






!> De-Allocate convolutions_bounds type, depending of the geocode and the hybrid_on
  subroutine deallocate_bounds(geocode,hybrid_on,bounds,subname)
    use module_base
    implicit none
    character(len=1), intent(in) :: geocode
    logical, intent(in) :: hybrid_on 
    type(convolutions_bounds) :: bounds
    character(len=*), intent(in) :: subname
    !local variables
    integer :: i_all,i_stat

    if ((geocode == 'P' .and. hybrid_on) .or. geocode == 'F') then
       ! Just test the first one...
       if (associated(bounds%kb%ibyz_f)) then
          i_all=-product(shape(bounds%kb%ibyz_f))*kind(bounds%kb%ibyz_f)
          deallocate(bounds%kb%ibyz_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibyz_f',subname)
          i_all=-product(shape(bounds%kb%ibxz_f))*kind(bounds%kb%ibxz_f)
          deallocate(bounds%kb%ibxz_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibxz_f',subname)
          i_all=-product(shape(bounds%kb%ibxy_f))*kind(bounds%kb%ibxy_f)
          deallocate(bounds%kb%ibxy_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibxy_f',subname)

          i_all=-product(shape(bounds%sb%ibxy_ff))*kind(bounds%sb%ibxy_ff)
          deallocate(bounds%sb%ibxy_ff,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%sb%ibxy_ff',subname)
          i_all=-product(shape(bounds%sb%ibzzx_f))*kind(bounds%sb%ibzzx_f)
          deallocate(bounds%sb%ibzzx_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%sb%ibzzx_f',subname)
          i_all=-product(shape(bounds%sb%ibyyzz_f))*kind(bounds%sb%ibyyzz_f)
          deallocate(bounds%sb%ibyyzz_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%sb%ibyyzz_f',subname)
          i_all=-product(shape(bounds%gb%ibyz_ff))*kind(bounds%gb%ibyz_ff)
          deallocate(bounds%gb%ibyz_ff,stat=i_stat)

          call memocc(i_stat,i_all,'bounds%gb%ibyz_ff',subname)
          i_all=-product(shape(bounds%gb%ibzxx_f))*kind(bounds%gb%ibzxx_f)
          deallocate(bounds%gb%ibzxx_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%gb%ibzxx_f',subname)
          i_all=-product(shape(bounds%gb%ibxxyy_f))*kind(bounds%gb%ibxxyy_f)
          deallocate(bounds%gb%ibxxyy_f,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%gb%ibxxyy_f',subname)

          nullify(bounds%kb%ibyz_f)
          nullify(bounds%kb%ibxz_f)
          nullify(bounds%kb%ibxy_f)
          nullify(bounds%sb%ibxy_ff)
          nullify(bounds%sb%ibzzx_f)
          nullify(bounds%sb%ibyyzz_f)
          nullify(bounds%gb%ibyz_ff)
          nullify(bounds%gb%ibzxx_f)
          nullify(bounds%gb%ibxxyy_f)
       end if
    end if

    !the arrays which are needed only for free BC
    if (geocode == 'F') then
       ! Just test the first one...
       if (associated(bounds%kb%ibyz_c)) then
          i_all=-product(shape(bounds%kb%ibyz_c))*kind(bounds%kb%ibyz_c)
          deallocate(bounds%kb%ibyz_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibyz_c',subname)
          i_all=-product(shape(bounds%kb%ibxz_c))*kind(bounds%kb%ibxz_c)
          deallocate(bounds%kb%ibxz_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibxz_c',subname)
          i_all=-product(shape(bounds%kb%ibxy_c))*kind(bounds%kb%ibxy_c)
          deallocate(bounds%kb%ibxy_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%kb%ibxy_c',subname)
          i_all=-product(shape(bounds%sb%ibzzx_c))*kind(bounds%sb%ibzzx_c)
          deallocate(bounds%sb%ibzzx_c,stat=i_stat)

          call memocc(i_stat,i_all,'bounds%sb%ibzzx_c',subname)
          i_all=-product(shape(bounds%sb%ibyyzz_c))*kind(bounds%sb%ibyyzz_c)
          deallocate(bounds%sb%ibyyzz_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%sb%ibyyzz_c',subname)
          i_all=-product(shape(bounds%gb%ibzxx_c))*kind(bounds%gb%ibzxx_c)
          deallocate(bounds%gb%ibzxx_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%gb%ibzxx_c',subname)
          i_all=-product(shape(bounds%gb%ibxxyy_c))*kind(bounds%gb%ibxxyy_c)
          deallocate(bounds%gb%ibxxyy_c,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%gb%ibxxyy_c',subname)

          i_all=-product(shape(bounds%ibyyzz_r))*kind(bounds%ibyyzz_r)
          deallocate(bounds%ibyyzz_r,stat=i_stat)
          call memocc(i_stat,i_all,'bounds%ibyyzz_r',subname)

          nullify(bounds%kb%ibyz_c)
          nullify(bounds%kb%ibxz_c)
          nullify(bounds%kb%ibxy_c)
          nullify(bounds%sb%ibzzx_c)
          nullify(bounds%sb%ibyyzz_c)
          nullify(bounds%gb%ibzxx_c)
          nullify(bounds%gb%ibxxyy_c)
          nullify(bounds%ibyyzz_r)
       end if
    end if

  END SUBROUTINE deallocate_bounds


  !> todo: remove this function.
  subroutine deallocate_lr(lr,subname)
    use module_base
    character(len=*), intent(in) :: subname
    type(locreg_descriptors) :: lr
!    integer :: i_all,i_stat

    write(0,*) "TODO, remove me"
    
    call deallocate_wfd(lr%wfd,subname)

    call deallocate_bounds(lr%geocode,lr%hybrid_on,lr%bounds,subname)

!    if (associated(lr%projflg)) then
!       i_all=-product(shape(lr%projflg)*kind(lr%projflg))
!       deallocate(lr%projflg,stat=i_stat)
!       call memocc(i_stat,i_all,'lr%projflg',subname)
!    end if
  END SUBROUTINE deallocate_lr

  subroutine deallocate_denspot_distribution(denspotd, subname)
    use module_base
    implicit none
    type(denspot_distribution), intent(inout) :: denspotd
    character(len = *), intent(in) :: subname

    integer :: i_stat, i_all

    if (associated(denspotd%nscatterarr)) then
       i_all=-product(shape(denspotd%nscatterarr))*kind(denspotd%nscatterarr)
       deallocate(denspotd%nscatterarr,stat=i_stat)
       call memocc(i_stat,i_all,'nscatterarr',subname)
    end if

    if (associated(denspotd%ngatherarr)) then
       i_all=-product(shape(denspotd%ngatherarr))*kind(denspotd%ngatherarr)
       deallocate(denspotd%ngatherarr,stat=i_stat)
       call memocc(i_stat,i_all,'ngatherarr',subname)
    end if
  END SUBROUTINE deallocate_denspot_distribution

  subroutine deallocate_symmetry(sym, subname)
    use module_base
    use m_ab6_symmetry
    implicit none
    type(symmetry_data), intent(inout) :: sym
    character(len = *), intent(in) :: subname

    integer :: i_stat, i_all

    if (sym%symObj >= 0) then
       call symmetry_free(sym%symObj)
    end if

    if (associated(sym%irrzon)) then
       i_all=-product(shape(sym%irrzon))*kind(sym%irrzon)
       deallocate(sym%irrzon,stat=i_stat)
       call memocc(i_stat,i_all,'irrzon',subname)
       nullify(sym%irrzon)
    end if

    if (associated(sym%phnons)) then
       i_all=-product(shape(sym%phnons))*kind(sym%phnons)
       deallocate(sym%phnons,stat=i_stat)
       call memocc(i_stat,i_all,'phnons',subname)
       nullify(sym%phnons)
    end if
  end subroutine deallocate_symmetry

  subroutine deallocate_Lzd(Lzd,subname)
    use module_base
    character(len=*), intent(in) :: subname
    type(local_zone_descriptors) :: Lzd
    integer :: ilr

!   nullify the bounds of Glr
    if ((Lzd%Glr%geocode == 'P' .and. Lzd%Glr%hybrid_on) .or. Lzd%Glr%geocode == 'F') then
       nullify(Lzd%Glr%bounds%kb%ibyz_f)
       nullify(Lzd%Glr%bounds%kb%ibxz_f)
       nullify(Lzd%Glr%bounds%kb%ibxy_f)
       nullify(Lzd%Glr%bounds%sb%ibxy_ff)
       nullify(Lzd%Glr%bounds%sb%ibzzx_f)
       nullify(Lzd%Glr%bounds%sb%ibyyzz_f)
       nullify(Lzd%Glr%bounds%gb%ibyz_ff)
       nullify(Lzd%Glr%bounds%gb%ibzxx_f)
       nullify(Lzd%Glr%bounds%gb%ibxxyy_f)
    end if
    !the arrays which are needed only for free BC
    if (Lzd%Glr%geocode == 'F') then
       nullify(Lzd%Glr%bounds%kb%ibyz_c)
       nullify(Lzd%Glr%bounds%kb%ibxz_c)
       nullify(Lzd%Glr%bounds%kb%ibxy_c)
       nullify(Lzd%Glr%bounds%sb%ibzzx_c)
       nullify(Lzd%Glr%bounds%sb%ibyyzz_c)
       nullify(Lzd%Glr%bounds%gb%ibzxx_c)
       nullify(Lzd%Glr%bounds%gb%ibxxyy_c)
       nullify(Lzd%Glr%bounds%ibyyzz_r)
    end if

! nullify the wfd of Glr
   nullify(Lzd%Glr%wfd%keyglob)
   nullify(Lzd%Glr%wfd%keygloc)
!   nullify(Lzd%Glr%wfd%keyv)
   nullify(Lzd%Glr%wfd%keyvloc)
   nullify(Lzd%Glr%wfd%keyvglob)

! nullify the Gnlpspd
!   call deallocate_proj_descr(Lzd%Gnlpspd,subname)
!!$   nullify(Lzd%Gnlpspd%nvctr_p)
!!$   nullify(Lzd%Gnlpspd%nseg_p)
!!$   nullify(Lzd%Gnlpspd%keyv_p)
!!$   nullify(Lzd%Gnlpspd%keyg_p)
!!$   nullify(Lzd%Gnlpspd%nboxp_c)
!!$   nullify(Lzd%Gnlpspd%nboxp_f)
 
!Now destroy the Llr
    do ilr = 1, Lzd%nlr 
       call deallocate_lr(Lzd%Llr(ilr),subname)
!       call deallocate_Lnlpspd(Lzd%Lnlpspd(ilr),subname)
    end do
     nullify(Lzd%Llr)
!     nullify(Lzd%Lnlpspd)

  END SUBROUTINE deallocate_Lzd


  function input_psi_names(id)
    integer, intent(in) :: id
    character(len = 14) :: input_psi_names

    select case(id)
    case(INPUT_PSI_EMPTY)
       write(input_psi_names, "(A)") "empty"
    case(INPUT_PSI_RANDOM)
       write(input_psi_names, "(A)") "random"
    case(INPUT_PSI_CP2K)
       write(input_psi_names, "(A)") "CP2K"
    case(INPUT_PSI_LCAO)
       write(input_psi_names, "(A)") "LCAO"
    case(INPUT_PSI_MEMORY_WVL)
       write(input_psi_names, "(A)") "wvl. in mem."
    case(INPUT_PSI_DISK_WVL)
       write(input_psi_names, "(A)") "wvl. on disk"
    case(INPUT_PSI_LCAO_GAUSS)
       write(input_psi_names, "(A)") "LCAO + gauss."
    case(INPUT_PSI_MEMORY_GAUSS)
       write(input_psi_names, "(A)") "gauss. in mem."
    case(INPUT_PSI_DISK_GAUSS)
       write(input_psi_names, "(A)") "gauss. on disk"
    case(INPUT_PSI_LINEAR)
       write(input_psi_names, "(A)") "Linear LCAO"
    case(INPUT_PSI_MEMORY_LINEAR)
       write(input_psi_names, "(A)") "Linear on disk"
    case default
       write(input_psi_names, "(A)") "Error"
    end select
  end function input_psi_names

  subroutine input_psi_help()
    integer :: i

    write(*, "(1x,A)") "Available values of inputPsiId are:"
    do i = 1, size(input_psi_values)
       write(*, "(1x,A,I5,A,A)") " | ", input_psi_values(i), &
            & " - ", input_psi_names(input_psi_values(i))
    end do
  end subroutine input_psi_help

  function input_psi_validate(id)
    integer, intent(in) :: id
    logical :: input_psi_validate

    integer :: i

    input_psi_validate = .false.
    do i = 1, size(input_psi_values)
       if (id == input_psi_values(i)) then
          input_psi_validate = .true.
          return
       end if
    end do
  end function input_psi_validate

  subroutine output_wf_format_help()
    integer :: i

    write(*, "(1x,A)") "Available values of output_wf are:"
    do i = 0, size(wf_format_names) - 1
       write(*, "(1x,A,I5,A,A)") " | ", i, &
            & " - ", wf_format_names(i)
    end do
  end subroutine output_wf_format_help

  function output_wf_format_validate(id)
    integer, intent(in) :: id
    logical :: output_wf_format_validate

    output_wf_format_validate = (id >= 0 .and. id < size(wf_format_names))
  end function output_wf_format_validate

  subroutine output_denspot_help()
    integer :: i, j

    write(*, "(1x,A)") "Available values of output_denspot are:"
    do i = 0, size(output_denspot_format_names) - 1
       do j = 0, size(output_denspot_names) - 1
          if (j == 0 .and. i == 0) then
             write(*, "(1x,A,I5,A,A,A)") " | ", i * 10 + j, &
                  & " - ", trim(output_denspot_names(j)), "."
          else if (j /= 0) then
             write(*, "(1x,A,I5,A,A,A,A,A)") " | ", i * 10 + j, &
                  & " - ", trim(output_denspot_names(j)), &
                  & " in ", trim(output_denspot_format_names(i)), " format."
          end if
       end do
    end do
  end subroutine output_denspot_help

  function output_denspot_validate(id, fid)
    integer, intent(in) :: id, fid
    logical :: output_denspot_validate

    output_denspot_validate = (id >= 0 .and. id < size(output_denspot_names)) .and. &
         & (fid >= 0 .and. fid < size(output_denspot_format_names))
  end function output_denspot_validate
!!
  subroutine deallocate_pawproj_data(pawproj_data,subname)
    use module_base
    implicit none
    character(len=*), intent(in) :: subname
    type(pawproj_data_type), intent(inout) :: pawproj_data
    !local variables
    integer :: i_all,i_stat
    if(associated(pawproj_data%paw_proj)) then

       i_all=-product(shape(  pawproj_data% paw_proj ))*kind( pawproj_data% paw_proj  )
       deallocate(pawproj_data%  paw_proj  ,stat=i_stat)
       call memocc(i_stat,i_all,'paw_proj',subname)

       i_all=-product(shape( pawproj_data%ilr_to_mproj   ))*kind(pawproj_data% ilr_to_mproj   )
       deallocate( pawproj_data% ilr_to_mproj  ,stat=i_stat)
       call memocc(i_stat,i_all,'ilr_to_mproj',subname)

       i_all=-product(shape( pawproj_data% iproj_to_l  ))*kind( pawproj_data% iproj_to_l  )
       deallocate(pawproj_data%  iproj_to_l  ,stat=i_stat)
       call memocc(i_stat,i_all,'iproj_to_l',subname)

       i_all=-product(shape( pawproj_data% iproj_to_paw_nchannels  ))*kind( pawproj_data% iproj_to_paw_nchannels  )
       deallocate(pawproj_data%  iproj_to_paw_nchannels  ,stat=i_stat)
       call memocc(i_stat,i_all,'iproj_to_paw_nchannels',subname)

       i_all=-product(shape( pawproj_data% iprojto_imatrixbeg  ))*kind( pawproj_data% iprojto_imatrixbeg  )
       deallocate(pawproj_data%  iprojto_imatrixbeg  ,stat=i_stat)
       call memocc(i_stat,i_all,'iorbto_imatrixbeg',subname)

       i_all=-product(shape( pawproj_data% iorbtolr   ))*kind( pawproj_data% iorbtolr  )
       deallocate(pawproj_data%  iorbtolr  ,stat=i_stat)
       call memocc(i_stat,i_all,'iorbtolr',subname)

       call deallocate_proj_descr(pawproj_data%paw_nlpspd,subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%nboxp_c))*kind(pawproj_data%paw_nlpspd%nboxp_c)
!!$       deallocate(pawproj_data%paw_nlpspd%nboxp_c,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nboxp_c',subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%nboxp_f))*kind(pawproj_data%paw_nlpspd%nboxp_f)
!!$       deallocate(pawproj_data%paw_nlpspd%nboxp_f,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nboxp_f',subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%keyg_p))*kind(pawproj_data%paw_nlpspd%keyg_p)
!!$       deallocate(pawproj_data%paw_nlpspd%keyg_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'keyg_p',subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%keyv_p))*kind(pawproj_data%paw_nlpspd%keyv_p)
!!$       deallocate(pawproj_data%paw_nlpspd%keyv_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'keyv_p',subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%nvctr_p))*kind(pawproj_data%paw_nlpspd%nvctr_p)
!!$       deallocate(pawproj_data%paw_nlpspd%nvctr_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nvctr_p',subname)
!!$       i_all=-product(shape(pawproj_data%paw_nlpspd%nseg_p))*kind(pawproj_data%paw_nlpspd%nseg_p)
!!$       deallocate(pawproj_data%paw_nlpspd%nseg_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nseg_p',subname)

       if(pawproj_data%DistProjApply) then
          call deallocate_gwf_c(pawproj_data%G,subname)
       endif
       nullify(pawproj_data%paw_proj)
    end if
  END SUBROUTINE deallocate_pawproj_data


  !> deallocate_pcproj_data
  subroutine deallocate_pcproj_data(pcproj_data,subname)
    use module_base
    implicit none
    character(len=*), intent(in) :: subname
    type(pcproj_data_type), intent(inout) :: pcproj_data
    !local variables
    integer :: i_all,i_stat
    if(associated(pcproj_data%pc_proj)) then

       i_all=-product(shape(  pcproj_data% pc_proj ))*kind( pcproj_data% pc_proj  )
       deallocate(pcproj_data%  pc_proj  ,stat=i_stat)
       call memocc(i_stat,i_all,'pc_proj',subname)
       
       i_all=-product(shape( pcproj_data%ilr_to_mproj   ))*kind(pcproj_data% ilr_to_mproj   )
       deallocate( pcproj_data% ilr_to_mproj  ,stat=i_stat)
       call memocc(i_stat,i_all,'ilr_to_mproj',subname)
       
       i_all=-product(shape( pcproj_data% iproj_to_ene  ))*kind( pcproj_data% iproj_to_ene  )
       deallocate(  pcproj_data% iproj_to_ene ,stat=i_stat)
       call memocc(i_stat,i_all,'iproj_to_ene',subname)

       i_all=-product(shape( pcproj_data% iproj_to_factor  ))*kind( pcproj_data% iproj_to_factor  )
       deallocate(  pcproj_data% iproj_to_factor ,stat=i_stat)
       call memocc(i_stat,i_all,'iproj_to_factor',subname)
       
       i_all=-product(shape( pcproj_data% iproj_to_l  ))*kind( pcproj_data% iproj_to_l  )
       deallocate(pcproj_data%  iproj_to_l  ,stat=i_stat)
       call memocc(i_stat,i_all,'iproj_to_l',subname)
       
       i_all=-product(shape( pcproj_data% iorbtolr   ))*kind( pcproj_data% iorbtolr  )
       deallocate(pcproj_data%  iorbtolr  ,stat=i_stat)
       call memocc(i_stat,i_all,'iorbtolr',subname)
       
       i_all=-product(shape( pcproj_data% gaenes   ))*kind( pcproj_data% gaenes  )
       deallocate(pcproj_data%  gaenes  ,stat=i_stat)
       call memocc(i_stat,i_all,'gaenes',subname)
       

       call deallocate_proj_descr(pcproj_data%pc_nlpspd,subname)

!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%nboxp_c))*kind(pcproj_data%pc_nlpspd%nboxp_c)
!!$       deallocate(pcproj_data%pc_nlpspd%nboxp_c,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nboxp_c',subname)
!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%nboxp_f))*kind(pcproj_data%pc_nlpspd%nboxp_f)
!!$       deallocate(pcproj_data%pc_nlpspd%nboxp_f,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nboxp_f',subname)
!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%keyg_p))*kind(pcproj_data%pc_nlpspd%keyg_p)
!!$       deallocate(pcproj_data%pc_nlpspd%keyg_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'keyg_p',subname)
!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%keyv_p))*kind(pcproj_data%pc_nlpspd%keyv_p)
!!$       deallocate(pcproj_data%pc_nlpspd%keyv_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'keyv_p',subname)
!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%nvctr_p))*kind(pcproj_data%pc_nlpspd%nvctr_p)
!!$       deallocate(pcproj_data%pc_nlpspd%nvctr_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nvctr_p',subname)
!!$       i_all=-product(shape(pcproj_data%pc_nlpspd%nseg_p))*kind(pcproj_data%pc_nlpspd%nseg_p)
!!$       deallocate(pcproj_data%pc_nlpspd%nseg_p,stat=i_stat)
!!$       call memocc(i_stat,i_all,'nseg_p',subname)


       if(pcproj_data%DistProjApply) then
          call deallocate_gwf(pcproj_data%G,subname)
       endif


    end if
  END SUBROUTINE deallocate_pcproj_data



end module module_types
