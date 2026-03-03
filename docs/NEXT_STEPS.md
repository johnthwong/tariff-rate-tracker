# Next Steps for Improving Tariff Rate Accuracy

*Updated 2026-03-02 from comprehensive TPC gap analysis*

## Current Validation Status (rev_32 → TPC 2025-11-17)

| Metric | Value |
|--------|-------|
| Total comparisons | 298,341 |
| Exact match (<0.5pp) | 66.1% |
| Within 2pp | 67.0% |
| Within 5pp | 71.3% |
| Mean abs diff | 4.93 pp |

**Directional breakdown (rev_32):**

| Direction | N | % of total | Mean diff |
|-----------|---|-----------|-----------|
| We higher than TPC | 61,906 | 20.8% | +11.4pp |
| TPC higher than us | 39,274 | 13.2% | -19.5pp |
| Exact match | 197,161 | 66.1% | 0pp |

**By country group (rev_32):**

| Group | N | Exact match | Our rate | TPC rate | Mean diff |
|-------|---|------------|----------|----------|-----------|
| EU-27 | 86,960 | 44.7% | 15.1% | 13.8% | +1.3pp |
| Floor (JP/KR/CH) | 21,574 | 43.8% | 15.1% | 14.6% | +0.5pp |
| China | 14,183 | 72.4% | 40.2% | 41.7% | -1.5pp |
| Canada | 12,105 | 79.4% | 20.2% | 22.6% | -2.4pp |
| Mexico | 10,187 | 83.9% | 13.9% | 16.8% | -2.9pp |
| Other surcharge | 153,332 | 78.6% | 19.5% | 20.2% | -0.7pp |

**Contribution to overall mismatches:**

| Group | Mismatches | % of all mismatches | Mean gap (when wrong) |
|-------|-----------|--------------------|-----------------------|
| EU-27 | 48,120 | 47.6% | 12.1pp |
| Other surcharge | 32,882 | 32.5% | 17.8pp |
| Floor (JP/KR/CH) | 12,132 | 12.0% | 11.9pp |
| China | 3,913 | 3.9% | 18.6pp |
| Canada | 2,494 | 2.5% | 18.1pp |
| Mexico | 1,641 | 1.6% | 22.1pp |

## Tier 1: High Impact

### 1. EU/Floor Duty-Free Products (~48,120 EU mismatches = 47.6% of all mismatches)
- **Gap**: 86,960 EU-27 products at only 44.7% exact match. The problem is concentrated in **61,601 duty-free products** (base_rate = 0%) where we apply the 15% floor but only 37.1% match TPC. Products with positive base rates match well (92-99%).
- **Root cause**: TPC's rate distribution for these duty-free products reveals a fundamentally different methodology:
  - 37.1% — TPC also gives 15% (exact match)
  - 37.7% — TPC gives between 0.1-14.9% (continuous distribution, not binary)
  - 17.8% — TPC gives **0%** (~11,000 products with no tariff at all)
  - 7.3% — TPC gives >15%
- **Cross-revision evidence**: EU match was **92.1% at rev_10** (April 2025, pre-floor) and dropped to **45.3% at rev_18** (October 2025, post-floor introduction), confirming floor rate implementation as the divergence point.
- **Same pattern for Japan/S. Korea/Swiss**: 21,574 products at 43.8% exact match.
- **Hypotheses to investigate**:
  1. **Larger IEEPA exemption list**: The 17.8% at 0% suggests TPC has many more exempt products than our 1,087 Annex A + 1,681 floor-specific exemptions
  2. **Different floor formula**: The 37.7% with continuous rates (0.1-14.9%) suggests TPC may use trade-weighted or partial-credit methodology rather than a simple `max(0, 15% - base_rate)` formula
  3. **Ad-valorem equivalent differences**: Some products with specific-rate duties may have different base rate conversions

### ~~2. Switzerland IEEPA Over-Application (5,544 products, +24.6pp)~~ (RESOLVED)
Fixed via Swiss framework implementation (EO 14346). Switzerland (4419) and Liechtenstein (4411) now use 15% floor structure matching EU/Japan/S. Korea. HTS 2026_basic has native floor entries (9903.02.82-91). Surcharge-to-floor override applies to pre-2026 revisions within the framework window (Nov 14, 2025 → March 31, 2026). Product exemptions (PTAAP, civil aircraft, pharma) in `resources/floor_exempt_products.csv`.

### ~~3. EU Floor Rate Residual~~ (Superseded by #1)
Merged into #1 above with more detailed analysis. Pattern A (product exemptions) was partially addressed via `floor_exempt_products.csv`. Patterns B (continuous rate distribution) and C (232 interaction) remain open within #1.

### ~~4. CA/MX Fentanyl Product-Level Carve-Outs (~1,765 products)~~ (RESOLVED)
Fixed via product-level carve-out implementation. `extract_ieepa_fentanyl_rates()` now returns all entries with `entry_type` column ('general' vs 'carveout'). Product lists in `resources/fentanyl_carveout_products.csv` (308 HTS8 prefixes). Step 3 in `calculate_rates_for_revision()` applies carve-out rates (10%) to matching products, falling back to the general blanket rate (CA 35%, MX 25%).

## Tier 2: Methodological Differences

### 5. Section 232 + IEEPA Stacking (~25,800 products across all groups)
- **Gap**: All 232 products have poor match rates (6-24% exact) because **TPC stacks IEEPA reciprocal on top of 232** while we apply mutual exclusion:

  | Group | N | Exact match | Our rate | TPC rate | Diff |
  |-------|---|------------|----------|----------|------|
  | CA 232 | 1,181 | 8.1% | 26.1% | 47.1% | -21pp |
  | MX 232 | 1,051 | 13.3% | 25.9% | 46.5% | -21pp |
  | China 232+301 | 1,211 | 8.3% | 59.4% | 81.1% | -22pp |
  | EU-27 232 | 8,830 | 6.2% | 26.0% | 36.3% | -10pp |
  | Other 232 | 11,203 | 24.3% | 27.5% | 41.5% | -14pp |

- **Status**: **Methodological difference, not a bug.** Our approach follows the Tariff-ETRs legal authority structure. TPC sums all authorities without mutual exclusion. No fix planned — this is a documented analytical choice. Accounts for ~25% of all mismatches.

### ~~6. USMCA Classification Mismatch~~ (Partially resolved)
Census SPI product-level utilization shares implemented. Residual: CA 230 products where we apply rate but TPC says USMCA; 82 products vice versa. MX: 119/97. Small enough to be within noise for product-level SPI data. CA: 79.4%, MX: 83.9% exact match.

## Tier 3: Refinement

### 7. Gulf State / Middle East IEEPA Rates (~1,500 products)
- **Gap**: Several Middle East countries show TPC systematically 2-3pp higher:
  - Oman (5230): 52.7% match, us 13.6% vs TPC 17.2% (-3.6pp)
  - Qatar (5180): 57.4% match, us 12.2% vs TPC 14.3% (-2.1pp)
  - UAE (5170): 65.9% match, us 11.7% vs TPC 14.0% (-2.3pp)
  - Iraq (5050): 54.7% match, us 34.9% vs TPC 23.6% (+11.3pp — our rate may be wrong)
- **Root cause**: TPC may capture an additional authority or ad-valorem equivalent we miss. Iraq's 35% IEEPA rate warrants verification.
- **Impact**: Small overall (~0.5pp potential improvement).

### 8. China Non-301 Product Coverage (~170 products)
- **Gap**: 618 China products with rate_301 = 0; of these, 171 have TPC showing ~20% where we show ~10-17%.
- **Root cause**: TPC may apply 301 to these products via a broader product list, or 10-digit specificity not captured by our 8-digit matching.
- **Impact**: Negligible (<0.1pp overall).

### 9. Section 301 Exclusions (9903.89.xx) -- 61 remaining products
- **Gap**: 61 China products where TPC > us and our rate_301 = 0
- **Root cause**: Products excluded from 301 via 9903.89.xx US Note lists but still in our blanket list, OR products at 10-digit specificity not captured by our 8-digit matching
- **Impact**: Negligible.

### 10. TPC Country Coverage Alignment
- We generate rates for 240 countries; TPC covers ~209. Products for the ~31 countries TPC doesn't cover contribute to the "extra in ours" count but don't affect match rates.
- **Fix**: Low priority — our broader coverage is correct by design.

### ~~11. 2026 HTS Revision Support~~ (RESOLVED)
Pipeline fully supports 2026 revisions via `parse_revision_id()` which dynamically extracts year from revision IDs (e.g., `2026_rev_3` → year=2026, rev=rev_3). All infrastructure (`resolve_json_path`, `list_available_revisions`, `build_download_url`) handles multi-year data. Currently processing 2026_basic + 2026_rev_1-4 (through Feb 25, 2026). USITC API change: `build_download_url()` updated to use `www.usitc.gov/sites/default/files/tata/hts/` after the old `getJSON` endpoint was deprecated.

## Priority Ordering

| Priority | Issue | Products | Potential match gain |
|----------|-------|----------|---------------------|
| **P1** | #1 EU/Floor duty-free products | ~48,120 mismatches | +12-15pp overall |
| P2 | #5 232+IEEPA stacking (methodological) | ~25,800 | +8pp (policy decision) |
| P3 | #7 Gulf state IEEPA rates | ~1,500 | ~0.5pp |
| P4 | #6 USMCA residual | ~530 | <0.2pp |
| P4 | #8-9 China 301 coverage | ~230 | <0.1pp |

## Recently Resolved

- **232+fentanyl stacking for CA/MX**: Fentanyl was multiplied by `nonmetal_share` (0 for base 232 products), zeroing it out. Fixed to add `rate_ieepa_fent` directly. Mexico 232 exact match: ~5% → 80.2%. Canada 232 gap remains at 10pp (our 60% vs TPC 50%) because TPC appears to use 25% CA fentanyl for 232 products while HTS JSON shows 35%.
- **India & Brazil rate discrepancy**: Both countries had country-specific EO entries in 9903.01.76-89 (outside extraction range) that stack with Phase 2. Brazil: +40% (EO 14323, 9903.01.77) + 10% (Phase 2) = 50%. India: +25% (9903.01.84) + 25% (Phase 2) = 50%. Expanded extraction range to 43-89, added `country_eo` phase label, updated rate selection to sum across phases. India 84.4%, Brazil 73.6% exact match.
- **Universal IEEPA baseline for unlisted countries**: ~143 countries with no individual entries now get the 10% universal baseline (9903.01.25) as default. CA/MX excluded (fentanyl-only regime). Also fixed within-phase dedup (take best entry, not sum) — fixed Tunisia from 0.2% to 91.6%.
- **China IEEPA reciprocal rate (34% → 10%)**: Post-Geneva suspension of 9903.01.63 not detected due to encoding variation. Added robust secondary regex check. China now 79.7% exact match.
- **Phantom IEEPA countries**: Syria, Moldova, Laos, Falkland Islands, DR Congo excluded from TPC validation. Removes ~95K false-positive pairs.
- **Section 232 derivative products**: ~130 aluminum-containing articles now covered with metal content scaling.
- **Floor country IEEPA selection (Japan/S. Korea)**: Fixed tie-breaking to prefer floor over surcharge.
- **Section 301 blanket coverage and generation stacking**: Expanded from ~10,400 to ~11,000 unique HTS8 codes (~12,200 entries) by adding List 4B (9903.88.16, 1,519 products). Rate aggregation changed from `max()` to generation-based stacking (MAX within generation, SUM across). Added missing ch99 rates: 9903.91.06 (25%), 9903.91.07 (50%), 9903.91.08 (100%), 9903.92.10 (25%). Rev_32 overall improvement: 60.5% → 66.1% exact match; China: 72.4% exact.
- **Switzerland IEEPA over-application (+24pp)**: Fixed via Swiss framework (EO 14346). 15% floor structure replaces +39% surcharge, with product exemptions. See `docs/active_hts_changes.md`.
- **CA/MX fentanyl product-level carve-outs**: Implemented via `resources/fentanyl_carveout_products.csv` (308 HTS8 prefixes). Carve-out products get 10% instead of general rate.
- **2026 HTS revision support**: Pipeline extended through 2026_rev_4 (Feb 25, 2026). USITC download URL updated after `getJSON` deprecation. 4 new policy milestones: semiconductor tariffs (rev_1), Argentina beef quota (rev_3), Section 122 Phase 3 (rev_4).
- **USMCA utilization rates**: Census SPI product-level shares implemented. Rev_32 overall: 63.6% → 66.4% exact match. CA: 44.3% → 79.4%, MX: 44.5% → 83.9%.
