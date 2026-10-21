#!/usr/bin/env bash

# DART software - Copyright UCAR. This open source software is provided
# by UCAR, "as is", without charge, subject to all terms of use at
# http://www.image.ucar.edu/DAReS/DART/DART_download

main() {

# DART is a submodule of this repo (checked out at the top level as DART/),
export DART="$(git rev-parse --show-toplevel)/DART"
source "$DART"/build_templates/buildfunctions.sh

# DART passes its version as -DDART_VERSION="'<version>'". Intel Fortran's
# preprocessor (ifort 19 on Compy) drops those single quotes, so version_mod.F90
# does not compile. A double-quoted Fortran string works with Intel, GNU and
# Cray compilers, so redefine the version string here rather than editing DART.
dartversion() {
  local git_version
  git_version=$(cd "$DART" && git describe --tags --dirty --always 2>/dev/null || echo "version_unknown")
  version_def="-DDART_VERSION='\"${git_version}\"'"
}
dartversion   # buildfunctions.sh already ran DART's version; replace it now

# This is where the model directory is relative to DART
MODEL="../../models/eam-se"
LOCATION=threed_sphere
# Absolute path: DART runs mkmf with -a $DART, so a relative path would be
# resolved against DART/ rather than this directory.
EXTRA="$(git rev-parse --show-toplevel)/models/eam-common-code"

programs=(
closest_member_tool
filter
model_mod_check
perfect_model_obs
perturb_single_instance
wakeup_filter
)

serial_programs=(
advance_time
create_fixed_network_seq
create_obs_sequence
fill_inflation_restart
obs_common_subset
obs_diag
obs_impact_tool
obs_selection
obs_seq_coverage
obs_seq_to_netcdf
obs_seq_verify
obs_sequence_tool
compare_states
compute_error
)

model_serial_programs=(
column_rand
)

arguments "$@"

# clean the directory; a build that does not finish leaves no build stamp
\rm -f -- *.o *.mod Makefile .cppdefs dart_build_info.txt

# build and run preprocess before making any other DART executables
buildpreprocess

# build DART
buildit

# clean up
\rm -f -- *.o *.mod

# Record the DART version these executables were built with. The E3SM-DART
# workflows compare it with their version profile before running.
{
  echo "dart_sha=$(cd "$DART" && git rev-parse HEAD)"
  echo "dart_local_changes=$( [[ -n "$(cd "$DART" && git status --porcelain --untracked-files=no)" ]] && echo yes || echo no )"
  echo "built_at=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "build_dir=$(pwd -P)"
} > dart_build_info.txt

}

main "$@"
