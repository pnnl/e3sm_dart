# Shared configuration for all numbered workflow stages.
# This file is sourced; it should define settings without running workflow work.

################################################################################
# --- Locale ------------------------------------------------------------------
# Jobs inherit the submitting shell's locale. If this machine does not have it
# (for example LANG=C.UTF-8 from VS Code on RHEL 7), the Intel compilers stop
# with "could not set locale", so fall back to the first locale it does have.
if command -v locale >/dev/null 2>&1 && [[ -n "$(locale 2>&1 >/dev/null)" ]]; then
  for _my_locale in C.UTF-8 en_US.UTF-8 C; do
    if [[ -z "$(LC_ALL="${_my_locale}" locale 2>&1 >/dev/null)" ]]; then
      export LC_ALL="${_my_locale}"
      break
    fi
  done
  unset _my_locale
fi

################################################################################
# --- Workflow and runtime paths ---------------------------------------------
# The workflow root is resolved from this configuration file at source time.
_my_config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export my_workflow_root="${_my_config_dir}"
export my_repository_root="$(cd -- "${_my_config_dir}/../.." && pwd -P)"
unset _my_config_dir
export my_workflow_lib="${my_workflow_root}/workflow_lib"
export my_runtime_dir="${my_workflow_root}/runtmp"
export my_log_dir="${my_runtime_dir}/logs"
export my_status_dir="${my_runtime_dir}/status"
export my_lock_dir="${my_runtime_dir}/locks"
export my_handoff_dir="${my_runtime_dir}/handoff"
export my_run_script_dir="${my_runtime_dir}/run_scripts"

################################################################################
# --- Machine ----------------------------------------------------------------
# Step 4 --nodes must match my_job_nnodes; other stages use their own allocations.
# my_layout is <pecount>_<segments>x<length>_<units> (e.g. 512x1_1x6_nhours is
# 512 tasks, one 6-hour segment) or custom-<nodes>_<segments>x<length>_<units>.
# Set my_machine to choose one of the blocks below:
#   compy   CPU test on Compy (Intel); GoAmazon inputs copied to /compyfs
#   pm-gpu  Perlmutter GPU nodes, 4 MPI tasks (one per GPU) per node, as in
#           hyma's GoAmazon run script `run_GoAmazonx32v1pg2_NoNudge_20151106_en001.csh`
#   pm-cpu  Perlmutter CPU nodes
# my_cime_python_module: module the run template loads before calling CIME,
# which in E3SM_RRM needs Python 3.9 or newer (Compy's default is 3.7).
# my_eamxx_input_dir holds the experiment's EAMxx IC, ELM finidat and SST files.
################################################################################
export my_machine=compy
case "${my_machine}" in
  compy)
    export my_compiler=intel
    export my_project="esmd"
    export my_jobqueue="slurm"
    export my_walltime="06:00:00"
    export my_task_per_node=40
    export my_job_nnodes=40
    export my_layout="custom-40_1x6_nhours"
    export my_cime_python_module="python/3.11.5"
    export my_runpath_root="/compyfs/zhan391"
    export my_eamxx_input_dir="/compyfs/zhan391/acme_init/EAMxx_GoAmazon"
    export my_inputdata_root="/compyfs/inputdata"
    export my_analysis_env_file="/share/apps/E3SM/conda_envs/load_latest_e3sm_unified_compy.sh"
    ;;
  pm-gpu)
    export my_compiler=gnugpu
    export my_project="m4849"
    export my_jobqueue="regular"
    export my_walltime="00:30:00"
    export my_task_per_node=4
    export my_job_nnodes=128
    export my_layout="512x1_1x6_nhours"
    export my_cime_python_module=""
    export my_runpath_root="/pscratch/sd/z/zhan391/e3sm_dart"
    export my_eamxx_input_dir=""
    export my_inputdata_root="/global/cfs/cdirs/e3sm/inputdata"
    export my_analysis_env_file="/global/common/software/e3sm/anaconda_envs/load_latest_e3sm_unified_pm-cpu.sh"
    ;;
  pm-cpu)
    export my_compiler=gnu
    export my_project="m4849"
    export my_jobqueue="regular"
    export my_walltime="01:00:00"
    export my_task_per_node=128
    export my_job_nnodes=16
    export my_layout="custom-16_1x6_nhours"
    export my_cime_python_module=""
    export my_runpath_root="/pscratch/sd/z/zhan391/e3sm_dart"
    export my_eamxx_input_dir=""
    export my_inputdata_root="/global/cfs/cdirs/e3sm/inputdata"
    export my_analysis_env_file="/global/common/software/e3sm/anaconda_envs/load_latest_e3sm_unified_pm-cpu.sh"
    ;;
  *)
    echo "ERROR: create_and_setup_case.sh has no settings for my_machine=${my_machine}" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

################################################################################
# --- Machine and Slurm defaults ---------------------------------------------
# Analysis environment (NCO and related tools) sourced by Steps 2, 7 and 8
# (my_analysis_env_file, set per machine above): the shared E3SM-Unified
# environment. Point it at a versioned load_e3sm_unified_<version>_<machine>.sh
# to pin an experiment.
################################################################################
# Same machine environment used to build DART, so runtime modules match the build.
# DART runs on CPU nodes, so Perlmutter GPU runs use the pm-cpu environment.
export my_dart_env_file="${my_repository_root}/models/mach_env/env_${my_machine/pm-gpu/pm-cpu}_specific.sh"
# DART version profile this workflow requires, and the build directory under
# models/<interface>/ holding executables compiled with it. Build with:
#   tools/checkout-version baseline && (cd models/eamxx/work && ./quickbuild.sh)
# (EAM-only: the ELM DART interface is not used.)
# Steps 3, 4 and 6 refuse a build compiled with a different DART.
export my_dart_version_profile="baseline"
export my_dart_build_dir_name="work"
export my_eam_filter_nml="${my_workflow_lib}/namelists/eam/filter.nml"
export my_eam_perturb_nml="${my_workflow_lib}/namelists/eam/perturb.nml"
export my_eam_diag_nml="${my_workflow_lib}/namelists/eam/diagnostics.nml"

################################################################################
# --- Ensemble and cycle execution -------------------------------------------
# Initial model time, ensemble size, concurrency, retries, and cycle batching.
################################################################################
export my_ensnum=1
export my_casedate="2015-11-06"
export my_casetod="00000"
export my_forecast_ready_for_da="FALSE"
export my_nodes_per_member=${my_job_nnodes}
export my_retry_forecast_timeout_sec=2400
export my_wait_poll_interval_sec=20
export my_skip_completed_members=FALSE
export my_max_parallel_setup=4
# Members whose Step 2 initial conditions are prepared at once (I/O bound).
export my_max_parallel_icbc=4
export my_max_parallel_handoff=4
# Cycles attempted in one Step 4 allocation; use 1 for one cycle per job.
export my_cycles_per_job=3
# Start another cycle only when this runtime plus the shutdown margin remains.
export my_min_cycle_time_sec=2400
export my_cycle_shutdown_margin_sec=600

################################################################################
# --- E3SM experiment identity and output paths -------------------------------
# my_runtype must be Full-CPL or AMIP; keep compset and reference files consistent.
################################################################################
# EAMxx uses the E3SM_RRM submodule (hyma68/E3SM, hyma/THREAD_RRM), which has
# the GoAmazon regionally refined grids; the other workflows use E3SM/.
export my_e3sm_code="${my_repository_root}/E3SM_RRM"
# E3SM source overrides (SourceMods) for DA cases; see the README there.
# These are the maint-3.0 MPAS fixes, which the EAMxx template does not install.
export my_e3sm_sourcemods_dir="${my_repository_root}/models/e3sm_sourcemods/e3sm_maint_3.0"
export my_runtype="AMIP"
export my_compset="F2010-SCREAMv1"
export my_resolution="GoAmazonx32v1pg2_GoAmazonx32v1pg2"
export my_runpath="${my_runpath_root}/dart_eamxx_test"
export my_casename="EAMXXEN${my_ensnum}_${my_compset}_${my_resolution}_${my_machine}"

################################################################################
# Model experiment directory and shared executable. Step 1 builds E3SM once
# and reuses that executable for the ensemble members.
################################################################################
export my_modeldir="${my_runpath}/${my_casename}"
export my_modelcase="${my_modeldir}/case_scripts"
export my_modelexe="${my_modeldir}/build/e3sm.exe"
export my_eam_topography_file="/global/cfs/cdirs/e3sm/inputdata/atm/cam/topo/USGS-gtopo30_ne30np4pg2_x6t-SGH.c20210614.nc"
export my_eam_se_mapping_file="${my_repository_root}/models/homme/SEMapping.nc"
export my_eam_cs_grid_file="${my_repository_root}/models/eamxx/work/SEMapping_cs_grid_NE30.nc"
export my_eam_post_map_file="/global/cfs/cdirs/m4849/zhan391/reference/regrid_maps/map_ne30pg2_to_cmip6_180x360_aave.20200201.nc"
export my_elm_post_map_file="/global/cfs/cdirs/m4849/zhan391/reference/regrid_maps/map_r05_to_cmip6_180x360_aave.20200901.nc"
# ne30np4 (DART state grid) to 1 deg, for the Step 9 DART pressure-level products
export my_eam_dart_post_map_file="/global/cfs/cdirs/m4849/zhan391/reference/regrid_maps/map_ne30np4_to_cmip6_180x360_aave.c231227.nc"
export my_amip_sst_data="/global/cfs/cdirs/m4849/zhan391/DART_INIT/SST_forcing/sst_ice_NOAA_AVHRR_E3SM_1x1_c20231225.nc"
export my_amip_sst_grid="/global/cfs/cdirs/m4849/zhan391/DART_INIT/SST_forcing/domain.ocn.1x1.111007.nc"

################################################################################
# --- EAMxx (compile_and_setup_e3sm.F2010-SCREAMv1.sh) -------------------------
# Levels and tracers for SCREAM_CMAKE_OPTIONS, the output stream YAML files
# (each member's filename_prefix is set to its case name), and the daily
# prescribed SST/sea-ice stream read by the data ocean and CICE.
################################################################################
export my_eamxx_nlev=128
export my_eamxx_ntracers=10
export my_eamxx_output_yaml_dir="${my_workflow_lib}/run_template/eamxx_output"
export my_eamxx_sst_data="${my_eamxx_input_dir:-/global/cfs/cdirs/mp193/CAPT/BC/SST}/sst_ice_daily_OSTIA-UKMO-L4-GLOB-v2.0_2014-01-01-2015-12-31.nc"
export my_eamxx_sst_domain="${my_inputdata_root}/ocn/docn7/domain.ocn.3600x7200.230522.nc"
export my_eamxx_sst_year_first=2014
export my_eamxx_sst_year_last=2015

################################################################################
# --- Reference initial conditions -------------------------------------------
# Full-CPL uses the coupled component restart set below. AMIP does not require
# MPAS-O, but the active initialization checks still require MPAS-I and coupler.
################################################################################
export my_refcase="20251024_s2d_spinup"
export my_refdate=${my_casedate}
export my_reftod=${my_casetod}
export my_refdir="/global/cfs/cdirs/e3sm/zhan391/v3.LR.S2D.ENSINT/BruteForce/${my_refdate}-${my_reftod}"
# Every member starts from the same full-variable EN00 state; Step 3 perturbs it.
# EAMxx: the ERA5 initial condition and ELM finidat of the GoAmazon sample run
# (in my_eamxx_input_dir when set, otherwise their NERSC locations).
export my_refeam_in="${my_eamxx_input_dir:-/global/cfs/cdirs/e3sm/hyma/RRM/ICcpp}/IC_ERA5_GoAmazonne32x32v1_eamxx_2015110600.nc"
export my_refeam_ic="${my_refeam_in}"
export my_refelm_in="${my_eamxx_input_dir:-/global/cfs/cdirs/e3sm/hyma/RRM/IC}/IELM.GoAmazonx32v1pg2_GoAmazonx32v1pg2.20151101.001.elm.r.2015-11-06-00000.nc"
export my_refrof_in="${my_refdir}/${my_refcase}.mosart.r.${my_refdate}-${my_reftod}.nc"
export my_refocn_in="${my_refdir}/${my_refcase}.mpaso.rst.${my_refdate}_${my_reftod}.nc"
export my_refice_in="${my_refdir}/${my_refcase}.mpassi.rst.${my_refdate}_${my_reftod}.nc"
export my_refcpl_in="${my_refdir}/${my_refcase}.cpl.r.${my_refdate}-${my_reftod}.nc"

################################################################################
# --- Shared E3SM cycling controls -------------------------------------------
# Live completed-cycle counter. Step 4 updates this value transactionally.
################################################################################
export my_e3sm_completed_cycles=0
export my_e3sm_cycle_hours=6
# Fixed workflow invariant; all archive readers and writers use ENxx/archive.
export my_dart_root="${my_modeldir}/dart_en$(printf '%02d' "${my_ensnum}")"
export my_e3sm_start_date=${my_casedate}
export my_e3sm_start_tod=${my_casetod}
export my_e3sm_end_date="2011-11-01"
export my_e3sm_end_tod="64800"

################################################################################
# --- EAM DART assimilation --------------------------------------------------
# Step 4 derives component nodes from my_job_nnodes and both DA switches:
# both enabled = equal halves; one enabled = all nodes; both disabled = no DA launch.
################################################################################
export my_eam_dart_da="on"
export my_eam_dart_cycle_hours=6
export my_eam_dart_end_date="${my_e3sm_end_date}"
export my_eam_dart_end_tod="${my_e3sm_end_tod}"
export my_eam_dart_run_dir="${my_dart_root}/eam"
export my_eam_dart_model="eamxx"
export my_eam_dart_pgrid=".true."
# E3SM-specific interfaces are maintained in this repository; upstream DART is
# the DART submodule. Keep both roots explicit for workflow and upstream data.
export my_dart_code="${my_repository_root}/DART"
export my_eam_dart_code="${my_repository_root}"
# Lowest EAM model level at which observations may be assimilated; levels
# above it (smaller indices) are excluded near the diffusive model top.
export my_eam_no_obs_assim_above_level=5
export my_eam_use_log_vertical_scale=".true."
export my_eam_vert_normalization_scale_height="1.5"
# Use a workflow-owned loader rather than a generated file in DARTs work tree.
export my_eam_dart_obsdir="/global/cfs/cdirs/m4849/zhan391/reference/NCEP+ACARS+GPS+AIRS"
# Optional per-cycle EAM DA settings. Keys combine the exact valid time and
# parameter name. Omitted parameters retain their normal defaults.
declare -Ag my_eam_cycle_overrides=(
)




################################################################################
# --- EAM DART diagnostic defaults ------------------------------------------
# Step 6 uses this range when DIAG_START and DIAG_END are empty.
################################################################################
export my_eam_dart_diag_start="2011-11-01-21600"
export my_eam_dart_diag_end="2011-11-01-64800"
# Diagnostic switches use Fortran logical strings because the workers pass them to DART tools.
export my_eam_dart_diag_use_custom_range=".true."
export my_eam_dart_diag_run_closest_member=".false."
export my_eam_dart_diag_run_obs2netcdf=".false."
export my_eam_dart_diag_run_obs_diag=".true."
