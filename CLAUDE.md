# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Tariff Rate Tracker - An R-based system for constructing statutory U.S. tariff rates at the HTS-10 x country level. Parses HTS JSON archives iteratively across all revisions to build a time series of tariff rates. All rates derived from HTS source data -- TPC benchmark data is for validation only.

## Key Commands

```bash
# Full backfill: process all 34 HTS revisions
Rscript src/00_build_timeseries.R

# Incremental: process only new revisions after rev_32
Rscript src/00_build_timeseries.R --start-from rev_32

# Single-revision pipeline (quick check)
Rscript src/run_pipeline.R

# TPC validation across all 5 dates
Rscript test_tpc_comparison.R
```

## Architecture

```
For each HTS revision (basic, rev_1, ..., rev_32, 2026_basic):
  JSON -> Parse Ch99 -> Parse Products -> Extract Policy Params -> Calculate Rates -> Snapshot
All snapshots -> rate_timeseries.rds
```

**Active Pipeline (v2 timeseries):**
- `helpers.R`: Shared utilities (rate parsing, HTS codes, revision/archive helpers)
- `00_build_timeseries.R`: Multi-revision orchestrator (iterates revisions)
- `run_pipeline.R`: Single-revision orchestrator
1. `01_scrape_revision_dates.R`: Scrape USITC for revision effective dates
2. `02_download_hts.R`: Download missing HTS JSON archives from USITC
3. `03_parse_chapter99.R`: Extract Ch99 entries (rates, authority, countries)
4. `04_parse_products.R`: Extract product lines (base rates, footnote refs)
5. `05_parse_policy_params.R`: Extract IEEPA, fentanyl, 232, USMCA from JSON
6. `06_calculate_rates.R`: Join products to authorities, apply stacking
7. `07_validate_tpc.R`: TPC benchmark comparison
8. `08_apply_scenarios.R`: Counterfactual scenarios (zero out authorities)
9. `09_diagnostics.R`: Debugging and validation utilities
10. `10_weighted_etr.R`: Import-weighted effective tariff rates

**Key Configuration:**
- `config/revision_dates.csv`: revision -> effective_date -> tpc_date mapping
- `config/scenarios.yaml`: Counterfactual scenario definitions

**Legacy (v1, config-driven):**
- `v1_run_daily.R`, `v1_ingest_hts.R` through `v1_write_outputs.R`
- `config/authority_mapping.yaml`, `config/country_rules.yaml`

## Stacking Rules

```r
# China (5700)
total = max(232, reciprocal) + fentanyl + 301

# Canada/Mexico (1220, 2010)
total = 232 + (reciprocal + fentanyl) * usmca_factor

# All Others
total = (232 > 0 ? 232 : reciprocal + fentanyl)
```

## Census Country Codes

Key codes: 5700 (China), 1220 (Canada), 2010 (Mexico), 4120 (UK), 5880 (Japan), 5820 (Hong Kong)

Full list: `resources/census_codes.csv`

## Style Guidelines

- Single quotes for strings
- Tidyverse-first (dplyr/tidyr over base R)
- Never use `na.rm = TRUE` - missing values indicate bugs
- Use `%>%` pipes
- Explicit `return()` at function end
- 2-space indentation
- Main orchestrator files use `00_` prefix (never "master")

## Related Repositories

- [Tariff-Model](../Tariff-Model) - Economic impact modeling
- [Tariff-ETRs](../Tariff-ETRs) - ETR calculations
