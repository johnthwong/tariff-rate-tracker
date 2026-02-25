# Tariff Rate Tracker: To-Do List

## High Priority

### 1. Scrape US Note 20/21/31 product lists
~5,000 China products are defined by US Note product lists but lack individual footnote references to 9903.88-89.xx/9903.91.xx entries. Parsing these product lists from the USITC HTS General Notes would close the remaining ~22K product-country 301 gap.

- **US Note 20**: Original Section 301 lists (Lists 1-4)
- **US Note 21**: List 4A (additional products)
- **US Note 31**: Biden acceleration (Lists b-j with phased effective dates)
- Source: HTS General Notes or USITC online subchapter notes

## Medium Priority

### 2. Map dates of HTS revision updates
Build a verified timeline of policy changes mapped to HTS revisions. Currently `config/revision_dates.csv` has effective dates but doesn't track *what changed* at each revision. Needed for:

- Correct TPC comparison (currently rev_18 effective 2025-08-07 is paired with TPC date 2025-10-17, a 2+ month gap)
- Building a daily rate dataset with proper interpolation between revision points
- Documenting when Phase 1 terminated, Phase 2 started, 232 increased, etc.

### 3. 2026 HTS revision naming convention
The pipeline handles `2026_basic` as a special case but has no support for `2026_rev_1`, `2026_rev_2`, etc. Before 2026 revisions appear:

- Update `resolve_json_path()` and `list_available_revisions()` to handle 2026 naming
- Add logic to `update_pipeline.R` to detect and download 2026 revisions
- Ensure `revision_dates.csv` format accommodates the year prefix

### 4. EU floor rate residual (~4pp systematic)
EU countries show 35-42% exact match with ~4pp mean excess. The floor formula `max(0, 15% - base_rate)` is correct, but residual discrepancies remain. Possible causes: TPC using slightly different floor mechanics, base rate parsing differences, or passthrough classification.

### 5. Switzerland IEEPA over-application (+24pp)
Our rate 39%, TPC 13.6% for 5,543 products. Switzerland has a +39% surcharge (9903.02.58) but TPC shows much lower. May be a rate reduction not yet reflected in our revision data, or different TPC methodology. Not a floor/surcharge selection issue — Switzerland genuinely has only surcharge entries.

### 6. CA/MX non-USMCA stacking (~1,700 products)
TPC shows 50%, we show 25% for non-USMCA Canada/Mexico products. Fentanyl (35% CA, 25% MX) should stack with IEEPA reciprocal. Our stacking may be zeroing out fentanyl when USMCA doesn't apply.

## Low Priority / Future

### 7. USMCA utilization rate adjustment
USMCA eligibility is binary (from HTS `special` field). A utilization-rate adjustment would improve accuracy for Canada/Mexico. Requires external data on USMCA claim rates by product.

### 8. Clean up legacy v1 pipeline
The v1 pipeline files (prefixed `v1_*`) are superseded by the v2 timeseries pipeline. Consider:

- Removing entirely if no longer referenced
- Removing `config/authority_mapping.yaml` and `config/country_rules.yaml` (v1 only)

### 9. Counterfactual scenario validation
`08_apply_scenarios.R` exists but hasn't been tested against the full timeseries. Verify:

- `apply_scenario(ts, 'baseline')` equals raw rates
- `apply_scenario(ts, 'no_ieepa')` zeros IEEPA columns
- Scenario totals are internally consistent after re-stacking

### 10. Automated HTS revision detection
Currently new revisions are manually downloaded and added to `config/revision_dates.csv`. Consider:

- Scraping `hts.usitc.gov` for new revision notifications
- Auto-downloading JSON when new revisions appear
- Running incremental pipeline on detection

## Done

### ~~China IEEPA reciprocal rate: 34% vs ~20%~~ (Fixed)
Post-Geneva (rev_17+), 9903.01.63 is marked `[Compiler's note: provision suspended.]` in HTS JSON. Suspension detection in `extract_ieepa_rates()` was not triggering due to encoding/format variation. Added robust secondary regex check (`\\[Compiler.*suspended`). China's Phase 1 rate now correctly caps to the 10% universal baseline. Expected impact: ~17K China products drop from 34% to 10% IEEPA reciprocal.

### ~~Phantom IEEPA countries (~95K false positive pairs)~~ (Fixed)
Countries with legitimate IEEPA entries that TPC doesn't model — Syria (5020), Moldova (4641), Laos (5530), Falkland Islands (3720), DR Congo (7660) — were inflating validation discrepancies. Added `tpc_excluded_countries` list to `config/policy_params.yaml` and exclusion filters in `test_tpc_comparison.R` and `07_validate_tpc.R`. Actual calculated rates unchanged; only validation comparisons affected.

### ~~Section 232 derivative products~~ (Implemented)
~130 aluminum-containing articles outside chapter 76 now covered via blanket matching using `resources/s232_derivative_products.csv`. Metal content scaling configurable (flat 50% default, CBO product-level buckets). Stacking rules updated for non-metal portion.

### ~~Floor country IEEPA rate selection (Japan/S. Korea)~~ (Fixed)
When both surcharge and floor entries existed for the same country/phase, tie-breaking now correctly prefers floor entries. Products with base_rate > 15% correctly get `rate_ieepa_recip = 0`.

### ~~India & Brazil rate discrepancy~~ (Fixed)
Both countries had country-specific Executive Order entries in 9903.01.76-89 (outside extraction range 43-75) that stack with Phase 2 rates. Brazil: EO 14323 at +40% (9903.01.77) + Phase 2 +10% (9903.02.09) = 50%. India: +25% (9903.01.84) + Phase 2 +25% (9903.02.26) = 50%. Expanded extraction range to 43-89, added `country_eo` phase label, updated rate selection to sum across phases but pick best within phase. India: 84.4% exact match. Brazil: 73.6%.

### ~~Universal IEEPA baseline for unlisted countries~~ (Fixed)
~143 countries with no individual IEEPA entries were getting 0% reciprocal instead of the 10% universal baseline (9903.01.25). Now apply universal baseline as default for all countries not in any IEEPA entry, excluding CA/MX (fentanyl-only regime). Fixed Tunisia from 0.2% to 91.6% exact match (within-phase dedup: take best entry per phase, not sum). Overall rev_32 exact match: 52% → 60.3%.

### ~~Section 301 blanket coverage~~ (Implemented)
~10,400 HTS8 product codes now applied as blanket tariff for China, closing most of the 301 product gap.
