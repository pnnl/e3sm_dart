#!/bin/bash -fe
main() {

# For debugging, uncomment libe below
#set -x

# EAMxx (SCREAMv1) run template, adapted from hyma's GoAmazon run script
# run_GoAmazonx32v1pg2_NoNudge_20151106_en001.csh. Step 1 copies it to
# runtmp/run_scripts/ and fills in the my_* placeholders below.

# --- Configuration flags ----

# Machine and project
readonly MACHINE=my_machine #pm-gpu
readonly PROJECT=my_project #"m4849"
readonly JOB_SLURM=my_jobqueue #"regular"
readonly JOB_NTASKS=my_task_per_node
# Empty unless my_compiler is set (e.g. gnugpu on pm-gpu)
readonly COMPILER="${my_compiler:+--compiler ${my_compiler}}"

# Simulation
readonly DATE=`date +"%m-%d-%y"`
readonly COMPSET=my_compset #"F2010-SCREAMv1"
readonly RESOLUTION=my_resolution #"GoAmazonx32v1pg2_GoAmazonx32v1pg2"
readonly CASE_NAME=my_casename

# Code and compilation
readonly CHECKOUT="20151106"
readonly BRANCH=""
readonly CHERRY=( )
readonly DEBUG_COMPILE=false

# Run options: EAMxx cold-starts from an initial-condition file
readonly START_DATE=my_casedate
readonly START_TOD=my_casetod

# Set by Step 1; unused by a startup run
readonly GET_REFCASE=FALSE
readonly RUN_REFDATE=my_refdate
readonly RUN_REFTOD=my_reftod
readonly RUN_REFCASE=my_refcase
readonly RUN_REFDIR=my_refdir

readonly MODEL_START_TYPE="initial"
readonly atm_init="${my_refeam_in:?my_refeam_in is not set}"
readonly lnd_init="${my_refelm_in:?my_refelm_in is not set}"
echo $atm_init
echo $lnd_init

# EAMxx vertical levels and tracers (SCREAM_CMAKE_OPTIONS)
readonly eamxx_nlev="${my_eamxx_nlev:-128}"
readonly eamxx_ntracers="${my_eamxx_ntracers:-10}"
readonly output_yaml_dir="${my_eamxx_output_yaml_dir:?my_eamxx_output_yaml_dir is not set}"

# Prescribed SST and sea ice (data ocean stream)
readonly sst_data="${my_eamxx_sst_data:?my_eamxx_sst_data is not set}"
readonly sst_domain="${my_eamxx_sst_domain:?my_eamxx_sst_domain is not set}"
readonly sst_syear="${my_eamxx_sst_year_first:?my_eamxx_sst_year_first is not set}"
readonly sst_eyear="${my_eamxx_sst_year_last:?my_eamxx_sst_year_last is not set}"

# Set paths
readonly CODE_ROOT=my_e3sm_code
readonly CASE_ROOT=my_case_root
readonly CASE_BUILD_DIR=my_case_build
readonly CASE_RUN_DIR=my_case_run
readonly CASE_ARCHIVE_DIR=my_case_archive
readonly CASE_SCRIPTS_DIR=my_case_script

readonly run=my_layout #'512x1_1x6_nhours'

if [ "${run}" != "production" ]; then
  # Short test simulations
  tmp=($(echo $run | tr "_" " "))
  layout=${tmp[0]}
  units=${tmp[2]}
  resubmit=$(( ${tmp[1]%%x*} -1 ))
  length=${tmp[1]##*x}
  readonly PELAYOUT=${layout}
  readonly WALLTIME="00:30:00"
  readonly STOP_OPTION=${units}
  readonly STOP_N=${length}
  readonly REST_OPTION=${STOP_OPTION}
  readonly REST_N=${STOP_N}
  readonly RESUBMIT=${resubmit}
  readonly DO_SHORT_TERM_ARCHIVING=true
else
  # Production simulation
  readonly PELAYOUT="512x1"
  readonly WALLTIME="00:30:00"
  readonly STOP_OPTION="ndays"
  readonly STOP_N="2"
  readonly REST_OPTION="ndays"
  readonly REST_N="1"
  readonly RESUBMIT="0"
  readonly DO_SHORT_TERM_ARCHIVING=false
fi

# Coupler history
readonly HIST_OPTION="nmonths"
readonly HIST_N="1"

# Leave empty (unless you understand what it does)
readonly OLD_EXECUTABLE=old_modelexe

# --- Now, do the work ---

# Make directories created by this script world-readable
umask 022

# CIME in E3SM_RRM needs Python 3.9 or newer
cime_python

# Fetch code from Github
fetch_code

# Create case
create_newcase

# Custom PE layout
custom_pelayout

# Setup
case_setup

# Build
case_build

# Configure runtime options
runtime_options

# Copy script into case_script directory for provenance
copy_script

# Submit
case_submit

# All done
echo $'\n----- All done -----\n'

}

# =======================
# Custom user_nl settings
# =======================

user_nl() {

echo "+++ Configuring EAMxx for ${eamxx_nlev} vertical levels and ${eamxx_ntracers} tracers +++"
./xmlchange SCREAM_CMAKE_OPTIONS="SCREAM_NP 4 SCREAM_NUM_VERTICAL_LEV ${eamxx_nlev} SCREAM_NUM_TRACERS ${eamxx_ntracers}"

cat << EOF >> user_nl_elm
 finidat = '${lnd_init}'
 hist_empty_htapes = .true.
 check_finidat_pct_consistency = .false.
 hist_fincl1 = 'FCEV','FCTR','FGEV','FSH_G','FSH_R','FSH_U','FSH_V','FSNO','H2OSNO',
               'QDRAI','QINFL','QOVER','QRGWL','QRUNOFF','QSNWCPICE','RAIN','SNOW',
               'SOILWATER_10CM','TLAI','TSOI_10CM','TWS'
 hist_fincl2 = 'H2OSOI','TSOI'
 hist_nhtfrq = 9,-1
 hist_mfilt  = 3000,3000
EOF

cat << EOF >> user_nl_cpl
 ocn_surface_flux_scheme = 2
EOF

cat << EOF >> user_nl_cice
 stream_fldfilename = '${sst_data}'
 stream_domfilename = '${sst_domain}'
 model_year_align = ${sst_syear}
 stream_year_first = ${sst_syear}
 stream_year_last = ${sst_eyear}
EOF

cat << EOF >> user_nl_docn
 streams = "docn.streams.txt.prescribed ${sst_syear} ${sst_syear} ${sst_eyear}"
EOF

cat << EOF >> user_docn.streams.txt.prescribed
<?xml version="1.0"?>
<file id="stream" version="1.0">
<dataSource>
   GENERIC
</dataSource>
<domainInfo>
  <variableNames>
     time    time
        xc      lon
        yc      lat
        area    area
        mask    mask
  </variableNames>
  <filePath>
     $(dirname "${sst_domain}")
  </filePath>
  <fileNames>
     $(basename "${sst_domain}")
  </fileNames>
</domainInfo>
<fieldInfo>
   <variableNames>
     SST_cpl t
   </variableNames>
   <filePath>
     $(dirname "${sst_data}")
   </filePath>
   <fileNames>
     $(basename "${sst_data}")
   </fileNames>
   <offset>
      0
   </offset>
</fieldInfo>
</file>
EOF

}

# =====================================================
# EAMxx runtime settings (atmchange) and output streams
# =====================================================

eamxx_options() {

    # Set temperature cut off in dycore threshold to 180K
    ./atmchange vtheta_thresh=180

    ./atmchange physics::atm_procs_list="mac_aero_mic,rrtmgp"

    # Turn on rainfrac
    ./atmchange set_cld_frac_r_to_one=true

    # Atmosphere initial condition
    ./atmchange initial_conditions::filename="${atm_init}"

    # use GHG levels more appropriate for 2019
    ./atmchange co2vmr=410.5e-6
    ./atmchange ch4vmr=1877.0e-9
    ./atmchange n2ovmr=332.0e-9
    ./atmchange orbital_year=2019
    # use CO2 the same in land model
    ./xmlchange CCSM_CO2_PPMV=410.5

    # Output streams: each member writes files named after its own case
    local yaml stream
    for yaml in "${output_yaml_dir}"/scream_output.*.yaml; do
        stream=$(basename "${yaml}" .yaml)
        stream=${stream#scream_output.}
        sed "s#^filename_prefix:.*#filename_prefix: ${CASE_NAME}.${stream}#" "${yaml}" > "./$(basename "${yaml}")"
        ./atmchange output_yaml_files+="./$(basename "${yaml}")"
    done

}

# =====================================================
# Python for CIME: load my_cime_python_module if set
# =====================================================

cime_python() {

if [ -n "${my_cime_python_module:-}" ]; then
    . /etc/profile.d/modules.sh
    module unload anaconda3 > /dev/null 2>&1 || true
    module load ${my_cime_python_module}
fi
echo "CIME uses $(python3 --version 2>&1)"

}

# =====================================================
# Custom PE layout: custom-N where N is number of nodes
# =====================================================

custom_pelayout() {

if [[ ${PELAYOUT} == custom-* ]];
then
    echo $'\n CUSTOMIZE PROCESSOR CONFIGURATION:'

    # Number of MPI tasks per node (machine specific)
    if [ "${MACHINE}" == "pm-gpu" ]; then
        ncore=4
    elif [ "${MACHINE}" == "pm-cpu" ]; then
        ncore=128
    elif [ "${MACHINE}" == "compy" ]; then
        ncore=40
    else
        echo 'ERROR: MACHINE = '${MACHINE}' is not supported for custom PE layout.'
        exit 400
    fi

    # Extract number of nodes
    tmp=($(echo ${PELAYOUT} | tr "-" " "))
    nnodes=${tmp[1]}

    # Customize
    pushd ${CASE_SCRIPTS_DIR}
    ./xmlchange NTASKS=$(( $nnodes * ${JOB_NTASKS} ))
    ./xmlchange NTHRDS=1
    ./xmlchange MAX_MPITASKS_PER_NODE=$ncore
    ./xmlchange MAX_TASKS_PER_NODE=$ncore
    popd

fi

}

######################################################
### Most users won't need to change anything below ###
######################################################

#-----------------------------------------------------
fetch_code() {

    if [ "${do_fetch_code,,}" != "true" ]; then
        echo $'\n----- Skipping fetch_code -----\n'
        return
    fi

    echo $'\n----- Starting fetch_code -----\n'
    local path=${CODE_ROOT}
    local repo=E3SM

    echo "Cloning $repo repository branch $BRANCH under $path"
    if [ -d "${path}" ]; then
        echo "ERROR: Directory already exists. Not overwriting"
        exit 20
    fi
    mkdir -p ${path}
    pushd ${path}

    # This will put repository, with all code
    git clone git@github.com:E3SM-Project/${repo}.git .

    # Check out desired branch
    git checkout ${BRANCH}

    # Custom addition
    if [ "${CHERRY}" != "" ]; then
        echo ----- WARNING: adding git cherry-pick -----
        for commit in "${CHERRY[@]}"
        do
            echo ${commit}
            git cherry-pick ${commit}
        done
        echo -------------------------------------------
    fi

    # Bring in all submodule components
    git submodule update --init --recursive

    popd
}

#-----------------------------------------------------
create_newcase() {

    if [ "${do_create_newcase,,}" != "true" ]; then
        echo $'\n----- Skipping create_newcase -----\n'
        return
    fi

    echo $'\n----- Starting create_newcase -----\n'

    if [[ ${PELAYOUT} == custom-* ]];
    then
        layout="M" # temporary placeholder for create_newcase
    else
        layout=${PELAYOUT}

    fi

    ${CODE_ROOT}/cime/scripts/create_newcase \
        --case ${CASE_NAME} \
        --output-root ${CASE_ROOT} \
        --script-root ${CASE_SCRIPTS_DIR} \
        --handle-preexisting-dirs u \
        --compset ${COMPSET} \
        --res ${RESOLUTION} \
        --machine ${MACHINE} ${COMPILER} \
        --project ${PROJECT} \
        --walltime ${WALLTIME} \
        --pecount ${layout}

    if [ $? != 0 ]; then
      echo $'\nNote: if create_newcase failed because sub-directory already exists:'
      echo $'  * delete old case_script sub-directory'
      echo $'  * or set do_newcase=false\n'
      exit 35
    fi

}

#-----------------------------------------------------
case_setup() {

    if [ "${do_case_setup,,}" != "true" ]; then
        echo $'\n----- Skipping case_setup -----\n'
        return
    fi

    echo $'\n----- Starting case_setup -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Setup some CIME directories
    ./xmlchange EXEROOT=${CASE_BUILD_DIR}
    ./xmlchange RUNDIR=${CASE_RUN_DIR}

    # Short term archiving
    ./xmlchange DOUT_S=${DO_SHORT_TERM_ARCHIVING^^}
    ./xmlchange DOUT_S_ROOT=${CASE_ARCHIVE_DIR}

    # Change the calendar
    ./xmlchange --id CALENDAR  --val 'GREGORIAN'

    # Extracts input_data_dir in case it is needed for user edits to the namelist later
    local input_data_dir=`./xmlquery DIN_LOC_ROOT --value`

    # Custom user_nl
    user_nl

    # GPU nodes: land and sea ice run threaded on the CPU cores beside the
    # one MPI task per GPU. CPU nodes use every core for MPI, so no threads.
    if [[ "${MACHINE}" == *-gpu ]]; then
        ./xmlchange --file env_mach_pes.xml NTHRDS="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_ATM="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_LND="16"
        ./xmlchange --file env_mach_pes.xml NTHRDS_ICE="16"
        ./xmlchange --file env_mach_pes.xml NTHRDS_OCN="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_ROF="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_CPL="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_GLC="1"
        ./xmlchange --file env_mach_pes.xml NTHRDS_WAV="1"
    fi

    ./xmlchange PIO_NETCDF_FORMAT="64bit_data"

    # Finally, run CIME case.setup
    ./case.setup --reset

    popd
}

#-----------------------------------------------------
case_build() {

    pushd ${CASE_SCRIPTS_DIR}

    # do_case_build = false
    if [ "${do_case_build,,}" != "true" ]; then

        echo $'\n----- case_build -----\n'

        if [ "${OLD_EXECUTABLE}" == "" ]; then
            # Ues previously built executable, make sure it exists
            if [ -x ${CASE_BUILD_DIR}/e3sm.exe ]; then
                echo 'Skipping build because $do_case_build = '${do_case_build}
            else
                echo 'ERROR: $do_case_build = '${do_case_build}' but no executable exists for this case.'
                exit 297
            fi
        else
            # If absolute pathname exists and is executable, reuse pre-exiting executable
            if [ -x ${OLD_EXECUTABLE} ]; then
                echo 'Using $OLD_EXECUTABLE = '${OLD_EXECUTABLE}
                cp -fp ${OLD_EXECUTABLE} ${CASE_BUILD_DIR}/
            else
                echo 'ERROR: $OLD_EXECUTABLE = '$OLD_EXECUTABLE' does not exist or is not an executable file.'
                exit 297
            fi
        fi
        echo 'WARNING: Setting BUILD_COMPLETE = TRUE.  This is a little risky, but trusting the user.'
        ./xmlchange BUILD_COMPLETE=TRUE

    # do_case_build = true
    else

        echo $'\n----- Starting case_build -----\n'

        # Turn on debug compilation option if requested
        if [ "${DEBUG_COMPILE^^}" == "TRUE" ]; then
            ./xmlchange DEBUG=${DEBUG_COMPILE^^}
        fi

        # Increase parallelism on compute nodes
        if [ -z "${SLURMD_NODENAME}" ]
        then
            echo $'\nCompiling on login node: GMAKE_J=8\n'
            ./xmlchange GMAKE_J=8
        else
            echo $'\nCompiling on compute node: GMAKE_J=64\n'
            ./xmlchange GMAKE_J=64
        fi

        # Run CIME case.build
        ./case.build

    fi

    # Some user_nl settings won't be updated to *_in files under the run directory
    # Call preview_namelists to make sure *_in and user_nl files are consistent.
    echo $'\n----- Preview namelists -----\n'
    ./preview_namelists

    popd
}

#-----------------------------------------------------
runtime_options() {

    echo $'\n----- Starting runtime_options -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Set simulation start date
    ./xmlchange RUN_STARTDATE=${START_DATE}
    ./xmlchange START_TOD=${START_TOD}

    # EAMxx settings and output streams
    eamxx_options

    # Segment length
    ./xmlchange STOP_OPTION=${STOP_OPTION,,},STOP_N=${STOP_N}

    # Restart frequency
    ./xmlchange REST_OPTION=${REST_OPTION,,},REST_N=${REST_N}

    # Coupler history
    ./xmlchange HIST_OPTION=${HIST_OPTION,,},HIST_N=${HIST_N}

    # Coupler budgets (always on)
    ./xmlchange BUDGETS=TRUE

    # Job Queue
    ./xmlchange JOB_QUEUE="${JOB_SLURM}"

    # Set resubmissions
    if (( RESUBMIT > 0 )); then
        ./xmlchange RESUBMIT=${RESUBMIT}
    fi

    # Run type
    # Start from default of user-specified initial conditions
    if [ "${MODEL_START_TYPE,,}" == "initial" ]; then
        ./xmlchange RUN_TYPE="startup"
        ./xmlchange CONTINUE_RUN="FALSE"

    # Continue existing run
    elif [ "${MODEL_START_TYPE,,}" == "continue" ]; then
        ./xmlchange CONTINUE_RUN="TRUE"

    else
        echo 'ERROR: $MODEL_START_TYPE = '${MODEL_START_TYPE}' is unrecognized. Exiting.'
        exit 380
    fi

    popd
}

#-----------------------------------------------------
case_submit() {

    if [ "${do_case_submit,,}" != "true" ]; then
        echo $'\n----- Skipping case_submit -----\n'
        return
    fi

    echo $'\n----- Starting case_submit -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Run CIME case.submit
    ./case.submit

    popd
}

#-----------------------------------------------------
copy_script() {

    echo $'\n----- Saving run script for provenance -----\n'

    local script_provenance_dir=${CASE_SCRIPTS_DIR}/run_script_provenance
    mkdir -p ${script_provenance_dir}
    local this_script_name=`basename $0`
    local script_provenance_name=${this_script_name}.`date +%Y%m%d-%H%M%S`
    cp -vp ${this_script_name} ${script_provenance_dir}/${script_provenance_name}

}

#-----------------------------------------------------
# Silent versions of popd and pushd
pushd() {
    command pushd "$@" > /dev/null
}
popd() {
    command popd "$@" > /dev/null
}

# Now, actually run the script
#-----------------------------------------------------
main
