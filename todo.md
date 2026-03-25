# Tariff Rate Tracker — TODO

## Pipeline rebuild

- [x] Full rebuild with copper + MHD fixes — completed 2026-03-24
- [x] Regenerate blog figures — completed 2026-03-24
- [x] Re-run `compare_etrs.R` after rebuild — completed 2026-03-24
  - timing-sensitive comparison rerun completed against the rebuilt artifacts
  - `src/compare_etrs.R` now uses the canonical timing fields (`pp$SECTION_122`, `pp$IEEPA_INVALIDATION_DATE`) for post-snapshot adjustments
  - residual tracker-vs-ETRs overall gaps remain: `+2.12pp` (`2026-01-01`), `+1.32pp` (`2026-02-24`), `+1.35pp` (`2026-07-24`)
  - large China residuals persist (`+6.24pp`, `+6.48pp`, `+6.53pp` respectively), so this rerun did not "close" the comparison gap
- [ ] Add generic pharma country-specific exemption shares (per TPC feedback; low priority)
  - planning note saved at `docs/analysis/generic_pharma_exemption_share_plan_2026-03-24.md`

## HTS status

- [x] `config/revision_dates.csv` now keeps raw HTS dates for the full 38-revision schedule and uses `policy_effective_date` overrides only for the two HTS-late revisions:
  - `rev_16`: `2025-06-06` (HTS) -> `2025-06-04` (policy)
  - `2026_rev_4`: `2026-02-24` (HTS) -> `2026-02-20` (policy)
- [x] The current built artifacts now reflect the cleaned schedule:
  - `rev_6` / `rev_7` no longer have invalid tied-date intervals in `data/timeseries/rate_timeseries.rds`
  - the saved April 2025 interval order is monotone again (`rev_6` -> `rev_7` -> `rev_8` -> `rev_9`)
- [x] Documented repo-vs-USITC archive reconciliation note completed 2026-03-24
  - see `docs/analysis/hts_archive_reconciliation_2026-03-24.md`
  - result: the repo matches the official 2025-2026 archive release sequence one-to-one (38 revisions), but `config/revision_dates.csv` should be treated as a modeled tariff chronology rather than a verbatim archive calendar

## Open investigations

### China gap vs Tariff-ETRs

Follow-up note saved at `docs/analysis/compare_etrs_china_gap_followup_2026-03-24.md`.

Current read:

- the residual China gap is stable across `2026-01-01`, `2026-02-24`, and `2026-07-24` (`~6.2-6.5pp`)
- the gap persists before and after both IEEPA invalidation and Section 122 activation/expiry
- the biggest positive chapter-level contributors are large China import chapters `84`, `85`, and `95`
- those chapters are strongly Section 301-driven in the tracker

So the next China-specific comparison task should focus on Section 301 scope / coverage differences, not on broad timing logic.

### rev_16 shows -0.06pp 232 change (expected ~+1pp for 50% increase)

9903.81.87 exists in earlier revisions with a 25% rate (matching the old fallback), so the rate doesn't change at rev_16. The 50% rate may only appear in the HTS JSON at a later revision. Low priority — the rate is correctly 50% by rev_32.

## Code review follow-up

### ~~1. Policy-date default inconsistent~~ — FIXED (f2bdfc3)
`build_full_timeseries()` default changed to `use_policy_dates = TRUE`.

### ~~2. `--use-hts-dates` propagation~~ — FIXED IN CODE + TESTED
The main calculator now accepts an explicit `policy_params` object, and `src/00_build_timeseries.R` passes one canonical build-time policy object into `calculate_rates_for_revision()`. This removes the mixed-regime path where revision ordering used one date mode but the calculator still relied on a hidden module-global `load_policy_params()`.

Implemented:
- `src/00_build_timeseries.R`
  - loads one canonical `pp_build <- load_policy_params(use_policy_dates = use_policy_dates)` object near the start of the build
  - passes `policy_params = pp_build` into `calculate_rates_for_revision(...)`
  - reuses that same object for interval construction
- `src/06_calculate_rates.R`
  - `calculate_rates_for_revision(...)` now accepts `policy_params = NULL`
  - local `pp <- policy_params %||% load_policy_params()` replaces the old hidden `.pp` path for date-sensitive behavior
  - the internal `load_policy_params()` reload in the IEEPA / floor-country block is gone
  - Section 122, IEEPA invalidation, MFN-exemption handling, 232 config, and 301 config now read from the passed policy object inside the calculator
- `tests/run_tests_daily_series.R`
  - added a regression using `2026_rev_4` that verifies:
    - policy-date mode invalidates IEEPA and activates Section 122 on `2026-02-20`
    - HTS-date mode keeps IEEPA active and delays Section 122 until the raw HTS date

Validation:
- `Rscript tests/run_tests_daily_series.R` now passes with the new propagation test.

Still worth doing later:
- add a broader end-to-end run-mode consistency suite (item 8) covering saved snapshots, point queries, and daily outputs across both date modes
- re-run the full build plus `compare_etrs.R` after the next rebuild to validate timing-sensitive output diffs on real artifacts

### ~~3. Concordance/utility reordering~~ — FIXED (1eb7200)
HTS-order utilities (`build_hts_concordance.R`, `02_download_hts.R`, `01_scrape_revision_dates.R`, `scrape_us_notes.R`, `revision_changelog.R`) explicitly pass `use_policy_dates = FALSE`.

### ~~4. Docs inconsistency~~ — FIXED (2026-03-24)
The opening of `docs/policy_timing.md` now matches the current implementation:
- default = curated tracker chronology with policy-date overrides only for the two HTS-late revisions;
- opt-out = `--use-hts-dates`;
- `config/revision_dates.csv` is explicitly described as a modeling schedule rather than a verbatim archive calendar.

### ~~5. Tied policy dates~~ — FIXED + REBUILT (f2bdfc3)
`policy_effective_date` is now restricted to HTS-late revisions only (`rev_16`, `2026_rev_4`), and the current built artifacts now reflect that fix. The saved intervals in `data/timeseries/` no longer show the earlier invalid April 2025 collisions.

### ~~6. Point query defaults~~ — FIXED (1eb7200)
`get_rates_at_date()` now loads `load_policy_params()` when `policy_params = NULL`. Spot checks after Section 122 expiry now match between the default call and the explicit-policy-params call. This also fixes the default behavior of `export_for_etrs.R`.

### ~~7. Auto-incremental mode~~ — FIXED (1eb7200)
`detect_incremental_start()` accepts and forwards `use_policy_dates`.

### ~~8. Run-mode consistency tests~~ — FIXED (2026-03-24)
Added regression coverage in `tests/run_tests_daily_series.R` for:
- snapshots vs `get_rates_at_date()` (`rev_16`, `2026_rev_4`)
- daily outputs vs direct aggregation from the built timeseries on timing-sensitive dates
- policy-date vs HTS-date mode on `2026_rev_4`

Validation:
- `Rscript tests/run_tests_daily_series.R` passes with the expanded run-mode consistency coverage.

## Blog publication (`blog_april2/`)

- [x] Regenerate docx from final `.md` before publication — completed 2026-03-24
  - rendered `blog_april2/Daily Tariff Rate Blog - April 2 2026.md`
  - output: `blog_april2/Daily-Tariff-Rate-Blog---April-2-2026.docx`

## Low priority

- **Concordance builder**: Matching may overstate splits/merges. Tighten with reciprocal-best or capped matching if needed.
- **Small-country outliers**: Persistent large gaps on low-import countries (Azerbaijan -26pp, Bahrain -22pp, UAE -8pp, Georgia +14pp, New Caledonia +22pp). Not material to aggregates.
