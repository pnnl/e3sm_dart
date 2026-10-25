# EAMxx DART interface (in development)

This directory will hold the DART interface for EAMxx (SCREAMv1), the C++
atmosphere in E3SM. It starts as a copy of `models/eam-se` (2026-10-24) and
builds and behaves exactly like it until the items below are ported, so it
does not read EAMxx files yet.

- `model_mod.f90`, `model_mod.nml`: the EAM-SE interface, renamed only.
- `work/`: DART build (`./quickbuild.sh`) and namelists. The `SEMapping*.nc`
  cubed-sphere files are the same as for EAM-SE; EAMxx dynamics use the same
  ne30np4 GLL grid.
- `nml_template/`, `chem_tables.txt`, `column_rand.f90`,
  `qceff_table_template.csv`: copied unchanged.
- Shared code still comes from `models/eam-common-code`.

The matching workflow is `scripts/eamxx/`, a copy of `scripts/eamv3.0/`.

## EAMxx file format

From the default ne30 initial condition in the pinned E3SM (maint-3.0),
`atm/scream/init/screami_ne30np4L128_20221004.nc`:

```text
dimensions: time = 1, ncol = 48602, lev = 128, ilev = 129, dim2 = 2
float T_mid(time, ncol, lev)              EAM: T(time, lev, ncol)
float qv, qc, qi, nc, ni (time, ncol, lev)  EAM: Q, CLDLIQ, CLDICE, NUMLIQ, NUMICE
float horiz_winds(time, ncol, dim2, lev)  EAM: U and V as separate variables
float ps(time, ncol), phis(time, ncol)    EAM: PS; PHIS from a separate file
hyam, hybm, hyai, hybi, lat, lon, lev, pref_mid
```

## Porting checklist

- [ ] Variable names in `model_mod.nml` / `input.nml` (`state_variables`) and
      any names hard-coded in `model_mod.f90` (PS, PHIS, T, Q).
- [ ] Dimension order: EAMxx puts `ncol` before `lev`; the state index
      mapping and column extraction assume `(lev, ncol)`.
- [ ] Winds: read and write the two components of `horiz_winds`, or have
      the workflow split them into U and V before filter and merge after.
- [ ] Surface geopotential from `phis` in the state file.
- [ ] Vertical levels: L128 (or L72) hybrid coefficients from the file.
- [ ] Which EAMxx file DART updates: initial condition (`screami_*`) or
      restart (`*.scream.r.*`), and whether EAMxx can start from DART's
      output each cycle.
- [ ] `model_mod_check` and a single-member `filter` test on an EAMxx file.
