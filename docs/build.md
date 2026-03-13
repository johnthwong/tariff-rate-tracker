# Build Guide

Full instructions for setting up and running the Tariff Rate Tracker pipeline.

---

## Prerequisites

- **R 4.3+** with packages: `tidyverse`, `jsonlite`, `yaml`, `here`
- **Optional packages:** `pdftools` (Ch99 PDF parsing), `rvest` (USITC web scraping), `arrow` (Parquet export)
- **Internet access** for downloading HTS JSON archives from USITC (first run only)

---

## First-Run Checklist

### 1. Verify environment

```bash
Rscript src/preflight.R
```

This checks all R packages, config files, resource files, HTS JSON availability, and optional external data. It reports which run modes are available:

| Mode | Requirements | Outputs |
|------|-------------|---------|
| `core` | R packages + config + resources + HTS JSON | Timeseries, unweighted daily series, quality report |
| `core_plus_weights` | Core + import weights (via `local_paths.yaml`) | Above + weighted ETR by partner/authority/sector |
| `compare_tpc` | Core + TPC benchmark CSV | Above + TPC validation reports |
| `compare_etrs` | Core + Tariff-ETRs repo path | Above + cross-repo comparison |

### 2. Install R packages

```bash
Rscript src/install_dependencies.R        # Required only (tidyverse, jsonlite, yaml, here)
Rscript src/install_dependencies.R --all   # Required + optional (pdftools, rvest, arrow, httr)
```

### 3. Download HTS JSON archives

```bash
Rscript src/02_download_hts.R --dry-run    # Check what's missing
Rscript src/02_download_hts.R              # Download all missing files
```

Downloads ~39 JSON files (~13–14 MB each) from USITC into `data/hts_archives/`. Only downloads files not already present.

### 4. (Optional) Configure external file paths

For weighted ETR outputs and TPC comparison, create a local paths config:

```bash
cp config/local_paths.yaml.example config/local_paths.yaml
```

Edit `config/local_paths.yaml` and set:
- `import_weights`: Path to Census import data RDS (HS10 x country x GTAP sector). Required for weighted ETR.
- `tpc_benchmark`: Path to TPC benchmark CSV. Default `data/tpc/tariff_by_flow_day.csv` (not publicly available).
- `tariff_etrs_repo`: Path to Tariff-ETRs repo (for cross-repo comparison only).

This file is gitignored. Not required for the core build.

### 5. Build

```bash
# Full rebuild — processes all 39 revisions, runs downstream scripts
Rscript src/00_build_timeseries.R --full

# Core only — skip weighted ETR (no import weights needed)
Rscript src/00_build_timeseries.R --full --core-only
```

Expected runtime: ~15–30 minutes for a full rebuild (depending on hardware).

---

## Build Modes

| Flag | Description |
|------|-------------|
| *(default)* | Auto-update: detect new revisions, download, build incrementally, run downstream |
| `--full` | Full rebuild from scratch (all 39 revisions) |
| `--start-from REV` | Incremental build from a specific revision |
| `--build-only` | Build timeseries only, skip downstream scripts (daily, ETR, quality) |
| `--core-only` | Build + unweighted daily series + quality report, skip weighted ETR |
| `--with-alternatives` | Also run rebuild alternatives (USMCA 2024, flat metal content, nonzero duty-free) |

Flags can be combined: `--full --core-only` rebuilds everything but skips weighted outputs. Post-build alternative series (scenario-based: `no_ieepa`, `no_301`, etc.) always run in the normal downstream phase; `--with-alternatives` adds the slower rebuild variants that require re-processing all revisions with modified policy parameters.

---

## Expected Outputs

### Core build (`data/timeseries/`)

| File | Description |
|------|-------------|
| `rate_timeseries.rds` | Combined long-format panel (~170M rows across 39 revisions) |
| `metadata.rds` | Last revision processed, build timestamp |
| `snapshot_*.rds` | Per-revision rate snapshots (~4.5M rows each) |
| `delta_*.rds` | Changes between consecutive revisions |
| `validation_*.rds` | TPC comparison at matched dates (if TPC data available) |

### Daily aggregates (`output/daily/`)

| File | Description |
|------|-------------|
| `daily_overall.csv` | Per-day import-weighted average ETR |
| `daily_by_country.csv` | Per-day ETR by Census country code |
| `daily_by_authority.csv` | Per-day ETR decomposed by tariff authority |
| `daily_aggregates.rds` | All daily outputs as R list |

### Alternative daily series (`output/alternative/`)

| File | Description |
|------|-------------|
| `daily_overall_no_ieepa.csv` | Zero IEEPA reciprocal + fentanyl |
| `daily_overall_no_ieepa_recip.csv` | Zero IEEPA reciprocal only |
| `daily_overall_no_301.csv` | Zero Section 301 |
| `daily_overall_no_232.csv` | Zero Section 232 |
| `daily_overall_no_s122.csv` | Zero Section 122 |
| `daily_overall_pre_2025.csv` | Only pre-2025 tariffs (232 + legacy 301) |
| `daily_overall_tpc_stacking.csv` | TPC additive stacking (no mutual exclusion) |
| `daily_overall_usmca_2024.csv` | Rebuild with 2024 USMCA shares (`--with-alternatives` only) |
| `daily_overall_metal_flat.csv` | Rebuild with flat 50% metal content (`--with-alternatives` only) |
| `daily_overall_dutyfree_nonzero.csv` | Rebuild with nonzero duty-free treatment (`--with-alternatives` only) |

Same schema as `daily_overall.csv` plus a `variant` column.

### Weighted ETR (`output/etr/`) — requires import weights

| File | Description |
|------|-------------|
| `etr_overall.csv` | Weighted ETR at policy regime dates (with TPC overlay if available) |
| `etr_by_partner.csv` | Weighted ETR by partner group |
| `etr_by_authority.csv` | Weighted ETR decomposed by authority |
| `etr_by_gtap.csv` | Weighted ETR by GTAP sector |
| `etr_*.png` | Visualization plots |

### Quality report (`output/quality/`)

Schema checks, per-revision quality metrics, anomaly detection.

---

## Updating When New HTS Revisions Are Published

```bash
# 1. Check for new USITC releases
curl -s "https://hts.usitc.gov/reststop/releaseList" | head -c 500

# 2. Download new JSON
Rscript src/02_download_hts.R

# 3. If Chapter 99 PDF was updated, regenerate resource files
Rscript src/scrape_us_notes.R --all

# 4. Add rows to config/revision_dates.csv for new revisions

# 5. Run auto-update (incrementally builds only new revisions)
Rscript src/00_build_timeseries.R
```

---

## Running Comparison Workflows

Comparisons are separate from the core build. Use `run_comparisons.R`:

```bash
Rscript src/run_comparisons.R              # All available comparisons
Rscript src/run_comparisons.R --tpc        # TPC validation only
Rscript src/run_comparisons.R --etr        # Weighted ETR with TPC overlay only
```

Requires TPC benchmark data and/or import weights configured in `config/local_paths.yaml`. Outputs to `output/comparisons/`.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `preflight.R` shows missing packages | Run `Rscript src/install_dependencies.R --all` |
| No HTS JSON files | Run `Rscript src/02_download_hts.R` |
| Weighted ETR skipped | Set `import_weights` in `config/local_paths.yaml` |
| TPC comparison skipped | Ensure TPC CSV exists at path in `config/local_paths.yaml` |
| Build fails at a specific revision | Try `--start-from` with the failing revision to isolate the issue |
| `here()` not finding project root | Ensure `.here` or `*.Rproj` exists in the repo root |

---

## Querying Built Data

After a successful build, query rates programmatically:

```r
source('src/helpers.R')
source('src/09_daily_series.R')

ts <- readRDS('data/timeseries/rate_timeseries.rds')
pp <- load_policy_params()

# Point-in-time query
snapshot <- get_rates_at_date(ts, '2026-06-15', policy_params = pp)

# Export filtered daily slice
export_daily_slice(ts, c('2026-06-01', '2026-06-30'),
                   countries = '5700', policy_params = pp,
                   output_path = 'output/exports/china_june.csv')
```

See [README: Querying and Exporting Daily Data](../README.md#querying-and-exporting-daily-data) for more examples.
