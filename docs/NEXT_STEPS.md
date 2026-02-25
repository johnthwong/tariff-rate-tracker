# Next Steps for Improving Tariff Rate Accuracy

*Updated 2026-02-25 from TPC validation analysis of rev_32*

## Current Validation Status (rev_32 → TPC 2025-11-17)

| Metric | Value |
|--------|-------|
| Total comparisons | 312,710 |
| Exact match (<0.5pp) | 60.5% |
| Within 2pp | 61.5% |
| Within 5pp | 65.9% |
| Mean abs diff | 6.1 pp |

**CA/MX breakdown (rev_32):**

| Group | N | Our rate | TPC rate | Match% |
|-------|---|----------|----------|--------|
| CA non-USMCA, no 232 | 7,556 | 35% | 23.6% | 51.3% |
| CA non-USMCA, 232 | 1,060 | 60% | 47.5% | 0.2% |
| CA USMCA | 2,522 | ~1% | 11.9% | 36.7% |
| MX non-USMCA, no 232 | 6,254 | 25% | 16.2% | 48.9% |
| MX non-USMCA, 232 | 932 | 50% | 46.7% | 80.2% |
| MX USMCA | 2,230 | ~1% | 9.3% | 43.3% |

## Tier 1: High Impact

### 1. USMCA Classification Mismatch (~5,700 CA/MX products)
- **Gap**: ~2,855 products per direction: we classify as USMCA (rate=0%) but TPC applies tariffs (~18%), and vice versa (we apply 35%/25% fentanyl, TPC shows 0%). Almost exactly symmetric.
- **Root cause**: Our USMCA flag comes from the HTS `special` field ("S"/"S+"). TPC likely uses a different USMCA eligibility source or methodology.
- **Impact**: CA non-USMCA non-232: 51.3% match (7,556 products). MX non-USMCA non-232: 48.9% match (6,254 products).
- **Fix**: Investigate alternative USMCA classification sources. May require external USMCA utilization data.

### 2. Switzerland IEEPA Over-Application (5,544 products, +24.6pp)
- **Gap**: Our rate 39%, TPC ~15%
- **Root cause**: We apply +39% IEEPA surcharge (9903.02.58). TPC shows much lower. Switzerland is EFTA, not EU — not a floor/surcharge selection issue (Switzerland has only surcharge entries). May reflect a rate reduction not yet in our revision data.
- **Fix**: Check Switzerland (4419) in IEEPA extraction. Verify its Phase 2 rate against executive order text.

### 3. EU Floor Rate Residual (~4pp systematic, ~33-40% exact match)
- **Gap**: EU countries average 33-40% exact match with ~3-5pp mean excess
- **Root cause**: Floor formula `max(0, floor_rate - base_rate)` is correct. Residual gap may be from TPC using slightly different floor mechanics or base rate parsing differences.
- **Note**: Japan/S. Korea floor selection bug has been **fixed**. S. Korea now at 40.1% exact match, in line with EU countries.

### 4. CA/MX Fentanyl Product-Level Carve-Outs (~1,765 products)
- **Gap**: ~915 CA + ~850 MX products where TPC shows 0-10% but we apply blanket 35%/25%.
- **Root cause**: HTS has lower fentanyl rates for energy products (9903.01.13: CA crude oil/natural gas/critical minerals at +10%; 9903.01.04: MX energy) and potash (9903.01.15: +10%). We take the general rate per country instead of product-specific carve-outs.
- **Fix**: Differentiate fentanyl rates by product category in `extract_ieepa_fentanyl_rates()` instead of taking first entry per country.

## Tier 2: Refinement (product-level accuracy)

### 5. China 301 Biden + 232 Stacking (~550 products, -43pp)
- **Gap**: TPC=93%, ours=50%
- **Root cause**: Products subject to both Biden 301 (50%) and 232 (25%) where stacking should produce ~93%. Our stacking rules may not correctly combine all components for these products.
- **Fix**: Check `apply_stacking_rules()` for China products with both rate_301 > 0 and rate_232 > 0.

### 6. Section 301 Exclusions (9903.89.xx) -- 61 remaining products
- **Gap**: 61 China products where TPC > us and our rate_301 = 0
- **Root cause**: Products excluded from 301 via 9903.89.xx US Note lists but still in our blanket list, OR products at 10-digit specificity not captured by our 8-digit matching
- **Fix**: Lower priority since only 61 products.

## Tier 3: Structural / Data Quality

### 7. TPC Country Coverage Alignment
- We generate rates for 240 countries; TPC covers ~209. Products for the ~31 countries TPC doesn't cover contribute to the "extra in ours" count but don't affect match rates.
- **Fix**: Low priority — our broader coverage is correct by design.

### 8. 2026 HTS Revision Support
- Pipeline handles `2026_basic` as a special case but has no support for `2026_rev_1`, `2026_rev_2`, etc.
- `resolve_json_path()` and `list_available_revisions()` need updating before 2026 revisions appear.

## Priority Ordering

| Priority | Item | Est. Impact on rev_32 Exact Match |
|----------|------|-----------------------------------|
| P1 | #1 USMCA classification mismatch | +5-8pp CA/MX |
| P1 | #2 Switzerland | removes false positives |
| P2 | #3 EU floor residual | +2-3pp |
| P2 | #4 Fentanyl product carve-outs | +2-3pp CA/MX |
| P3 | #5-6 Refinements | <0.5pp each |

## Recently Resolved

- **232+fentanyl stacking for CA/MX**: Fentanyl was multiplied by `nonmetal_share` (0 for base 232 products), zeroing it out. Fixed to add `rate_ieepa_fent` directly. Mexico 232 exact match: ~5% → 80.2%. Canada 232 gap remains at 10pp (our 60% vs TPC 50%) because TPC appears to use 25% CA fentanyl for 232 products while HTS JSON shows 35%.
- **India & Brazil rate discrepancy**: Both countries had country-specific EO entries in 9903.01.76-89 (outside extraction range) that stack with Phase 2. Brazil: +40% (EO 14323, 9903.01.77) + 10% (Phase 2) = 50%. India: +25% (9903.01.84) + 25% (Phase 2) = 50%. Expanded extraction range to 43-89, added `country_eo` phase label, updated rate selection to sum across phases. India 84.4%, Brazil 73.6% exact match.
- **Universal IEEPA baseline for unlisted countries**: ~143 countries with no individual entries now get the 10% universal baseline (9903.01.25) as default. CA/MX excluded (fentanyl-only regime). Also fixed within-phase dedup (take best entry, not sum) — fixed Tunisia from 0.2% to 91.6%.
- **China IEEPA reciprocal rate (34% → 10%)**: Post-Geneva suspension of 9903.01.63 not detected due to encoding variation. Added robust secondary regex check. China now 79.7% exact match.
- **Phantom IEEPA countries**: Syria, Moldova, Laos, Falkland Islands, DR Congo excluded from TPC validation. Removes ~95K false-positive pairs.
- **Section 232 derivative products**: ~130 aluminum-containing articles now covered with metal content scaling.
- **Floor country IEEPA selection (Japan/S. Korea)**: Fixed tie-breaking to prefer floor over surcharge.
- **Section 301 blanket coverage**: ~10,400 HTS8 product codes applied as blanket tariff for China.
