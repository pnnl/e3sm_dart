E3SM SourceMods for E3SM-DART on E3SM maint-3.0
===============================================

These files change E3SM source files for DA cases. They are compiled into
E3SM (e3sm.exe), not DART. The workflow run templates install them when the
case is built:

  Directory    Installed into                              Installed by
  src.mpassi   E3SM/components/mpas-seaice/driver/         all workflows
  src.mpaso    E3SM/components/mpas-ocean/driver/          all workflows, WCYCL20TR only
  src.elm      <caseroot>/SourceMods/src.elm/              e3smv3.0_wcp, e3smv3.0_scp

The directory is set by my_e3sm_sourcemods_dir in create_and_setup_case.sh;
the coupled workflows set my_elm_sourcemods_dir to its src.elm subdirectory.

src.elm is installed as ordinary case SourceMods. CIME requires the files
directly under SourceMods/src.elm/; do not reproduce ELM source subdirectories.

The MPAS drivers cannot be: E3SM's MPAS build (components/mpas-*/src/*.cmake)
compiles them from the E3SM source tree and ignores Fortran SourceMods. The
build step (install_mpas_driver_fixes in the run templates) therefore copies
them into the E3SM checkout just before case.build. MPAS_DRIVERS lists each
file with the git blob id of the E3SM original it was made from; a file is
replaced only if it matches that id, so another E3SM version stops the build
instead of silently compiling an old driver. Afterwards `git -C E3SM status`
shows the drivers as modified. tools/validate-repository and
tools/checkout-version accept exactly these changes (each file identical to
its fix) and still report any other local E3SM change; checkout-version
restores the original drivers before it moves E3SM to a different commit.
To restore them by hand:

  git -C E3SM checkout -- components/mpas-seaice/driver/ice_comp_mct.F \
                          components/mpas-ocean/driver/ocn_comp_mct.F

Based on: the E3SM submodule of this repository, v3.0.2-97-gbc1af56a9b.
Each file is a full copy of the E3SM file of the same name with only the
changes listed below.


src.mpassi/ice_comp_mct.F, src.mpaso/ocn_comp_mct.F
----------------------------------------------------

Reference: components/mpas-seaice/driver/ice_comp_mct.F
           components/mpas-ocean/driver/ocn_comp_mct.F

PURPOSE: Start MPAS at the time of each hybrid DA cycle.

Each DA cycle restarts E3SM as a hybrid run from the analysis at the cycle
time (RUN_STARTDATE + START_TOD, e.g. 2011-12-01 21600). The coupler maps a
hybrid run to start_type "startup", so the MPAS drivers take their "initial"
path, which builds the model start time as

  trim(config_start_time) // "0:00:00"

That gives the right time only for 00Z starts. MPAS reads its restart_ic file
at this time, before the clocks are synchronized with the coupler, so a cycle
starting at 06Z either looks for the wrong time ('2011-12-01_6' becomes
2011-12-01_60:00:00, i.e. 2011-12-03 12Z) or stops on an invalid time string
('2011-12-01_06:00:00' becomes 2011-12-01_06:00:000:00:00).

See E3SM issue #6132. The code is unchanged on E3SM master as of 2026-10-21.

MODIFICATION: In the "initial" branch of ice_init_mct / ocn_init_mct only, the
start time is set from the coupler clock instead:

  call seq_timemgr_EClockGetData(EClock, start_ymd=start_ymd, start_tod=start_tod)
  write(tempCharConfig, '(i4.4,"-",i2.2,"-",i2.2,"_",i2.2,":",i2.2,":",i2.2)') ...

so config_start_time in user_nl_mpassi / user_nl_mpaso is no longer used and
the cycling scripts do not set it. Continue and branch runs are unchanged.


src.elm/EcosystemBalanceCheckMod.F90
------------------------------------

Reference: components/elm/src/biogeochem/EcosystemBalanceCheckMod.F90

PURPOSE: Skip C/N/P balance checks on the first restart step after a DART
assimilation. DART may create or destroy mass during the update step, so
the balance error check on startup is expected and should not abort the run.

MODIFICATION: Added is_first_restart_step() guard to all err_found checks
in ColCBalanceCheck, ColNBalanceCheck, ColPBalanceCheck, and GridCBalanceCheck.


src.elm/SurfaceRadiationMod.F90
-------------------------------

Reference: components/elm/src/biogeophys/SurfaceRadiationMod.F90

PURPOSE: Expose the PARVEG (absorbed PAR by vegetation) history variable.
DART's QTY_ABSORBED_PAR forward operator (obs_def_land_mod.f90) requires
the 'PARVEG' history variable. ELM computes this value internally but only
stores 'PARVEGLN' (local noon value).

MODIFICATION: Added parveg_patch member, allocation, history registration,
and assignment from the existing parveg local variable.


ELM files required but not yet ported (TODO)
--------------------------------------------

src.elm/CanopyFluxesMod.F90
src.elm/PhotosynthesisMod.F90
  PURPOSE: Required to support the Solar-Induced Fluorescence (SIF) DART
  forward operator (QTY_SOLAR_INDUCED_FLUORESCENCE). In the legacy CLM
  SourceMods (recoverable from Git commit d4009d7c4), these files were
  modified to expose the per-patch sun-lit and shaded net assimilation rates
  (anetsun_patch, anetsha_patch) used by the SIF forward operator. ELM does
  not currently have these variables. Porting these modifications requires
  adding the SIF-related state variables to ELM's photosynthesis data
  structures. Skip these if you do not plan to assimilate SIF observations.


Updating E3SM
-------------

These are full copies of E3SM files. If the E3SM submodule is moved to a
different revision, diff each file against the new E3SM version, copy the new
file here and reapply the change above; for the MPAS drivers also update the
blob id in MPAS_DRIVERS (git -C E3SM rev-parse HEAD:<E3SM path>). Remove the
MPAS driver copies once E3SM fixes the hybrid start time upstream.
