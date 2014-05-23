#ifndef INPUT_KEYS_H
#define INPUT_KEYS_H

static const gchar* _input_keys[] = {
  "dft",
  "hgrids",
  "rmult",
  "ixc",
  "ncharge",
  "elecfield",
  "nspin",
  "mpol",
  "gnrm_cv",
  "itermax",
  "nrepmax",
  "ncong",
  "idsx",
  "dispersion",
  "inputpsiid",
  "output_wf",
  "output_denspot",
  "rbuf",
  "ncongt",
  "norbv",
  "nvirt",
  "nplot",
  "disablesym",
  "kpt",
  "method",
  "kptrlen",
  "ngkpt",
  "shiftk",
  "kpt",
  "wkpt",
  "bands",
  "iseg",
  "kptv",
  "ngranularity",
  "band_structure_filename",
  "geopt",
  "method",
  "ncount_cluster_x",
  "frac_fluct",
  "forcemax",
  "randdis",
  "ionmov",
  "dtion",
  "mditemp",
  "mdftemp",
  "noseinert",
  "friction",
  "mdwall",
  "nnos",
  "qmass",
  "bmass",
  "vmass",
  "betax",
  "history",
  "dtinit",
  "dtmax",
  "mix",
  "iscf",
  "itrpmax",
  "rpnrm_cv",
  "norbsempty",
  "Tel",
  "occopt",
  "alphamix",
  "alphadiis",
  "sic",
  "sic_approach",
  "sic_alpha",
  "sic_fref",
  "tddft",
  "tddft_approach",
  "perf",
  "debug",
  "fftcache",
  "accel",
  "ocl_platform",
  "ocl_devices",
  "blas",
  "projrad",
  "exctxpar",
  "ig_diag",
  "ig_norbp",
  "ig_blocks",
  "ig_tol",
  "methortho",
  "rho_commun",
  "psolver_groupsize",
  "psolver_accel",
  "unblock_comms",
  "linear",
  "tolsym",
  "signaling",
  "signaltimeout",
  "domain",
  "inguess_geopt",
  "store_index",
  "verbosity",
  "outdir",
  "psp_onfly",
  "multipole_preserving",
  "pdsyev_blocksize",
  "pdgemm_blocksize",
  "maxproc_pdsyev",
  "maxproc_pdgemm",
  "ef_interpol_det",
  "ef_interpol_chargediff",
  "mixing_after_inputguess",
  "iterative_orthogonalization"
};

static const BigDFT_InputsKeyIds _input_files[] = {
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_DFT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_KPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_GEOPT_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_MIX_VARIABLES,
  INPUTS_SIC_VARIABLES,
  INPUTS_SIC_VARIABLES,
  INPUTS_SIC_VARIABLES,
  INPUTS_SIC_VARIABLES,
  INPUTS_TDDFT_VARIABLES,
  INPUTS_TDDFT_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES,
  INPUTS_PERF_VARIABLES
};

#endif
