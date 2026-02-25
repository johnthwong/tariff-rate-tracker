# Next Steps for Improving Tariff Rate Accuracy

*Updated 2026-02-24 from TPC validation analysis of rev_32*

## Current Validation Status (rev_32 → TPC 2025-11-17)

| Metric | Value (pre-fix) | Est. post-fix |
|--------|-----------------|---------------|
| Total comparisons | 268,742 | ~174K (excl. phantom countries) |
| Exact match (<0.5pp) | 52.0% | ~57-60% |
| Within 2pp | 53.3% | ~60-63% |
| Within 5pp | 58.6% | ~65-68% |
| Mean abs diff | 8.1 pp | ~5-6 pp |

*Post-fix estimates reflect China IEEPA correction (+14pp on ~17K products) and phantom country exclusion (~95K pairs removed from denominator). Re-run `test_tpc_comparison.R` to get exact numbers.*

## Tier 1: High Impact (affects 10,000+ product-country pairs)

### 1. India Rate Discrepancy (9,595 products, -25pp)
- **Gap**: TPC shows 50%, we show 25%
- **Root cause**: India's reciprocal rate may have been raised from 26% to 50% in a later executive action or Phase 2 update, and our extraction isn't capturing the update.
- **Fix**: Check India's Phase 2 rate in the ch99 description text. May also need to verify Phase 1 vs Phase 2 rate precedence logic for India specifically.

### 2. Brazil Specific Tariff (4,300 products, -40pp)
- **Gap**: TPC shows 50%, we show 10%
- **Pattern**: 12,306 products where TPC=0% and ours=10% (we over-apply); 4,300 where TPC=50% and ours=10% (we under-apply)
- **Root cause**: Brazil's IEEPA rate should be ~40-50% (CBO model confirms 40% Brazil surcharge). We're extracting only the 10% universal baseline rather than Brazil's country-specific rate.
- **Fix**: Debug `extract_ieepa_rates()` for Brazil (census code 3510). The Phase 2 ch99 entry for Brazil may use a different description format.

## Tier 2: Medium Impact (1,000-10,000 pairs)

### 3. Canada/Mexico Non-USMCA Stacking (~1,700 products, -25pp)
- **Gap**: TPC shows 50%, we show 25% (917 CA + 798 MX products)
- **Also**: 310 CA products where TPC=35% but ours=0%
- **Root cause**: For non-USMCA products, fentanyl (35% CA, 25% MX) should stack with IEEPA reciprocal. Our stacking may be zeroing out fentanyl when USMCA doesn't apply, or there's a missing IEEPA component for CA/MX.
- **Fix**: Verify stacking rules for CA/MX non-USMCA products. The 35% gap for Canada suggests fentanyl is being zeroed out when it shouldn't be.

### 4. Singapore & Small Trading Partners (~2,000 products, -20pp+)
- **Gap**: Singapore TPC=10-30%, ours=0%; similar for Dominican Republic, UAE, Colombia, Australia
- **Root cause**: These countries may have IEEPA Phase 2 rates that our extraction classifies as "passthrough" (no rate applied).
- **Fix**: Review Phase 2 extraction for these countries. The "passthrough" classification may be too aggressive.

### 5. Switzerland IEEPA Over-Application (5,543 products, +24pp)
- **Gap**: Our rate 39%, TPC 13.6%
- **Root cause**: We apply a +39% IEEPA surcharge (9903.02.58). TPC shows much lower. Switzerland is EFTA, not EU -- not a floor/surcharge selection issue (Switzerland has only surcharge entries). May reflect a rate reduction not yet in our revision data.
- **Fix**: Check Switzerland (4419) in IEEPA extraction. Verify its Phase 2 rate against executive order text.

## Tier 3: Refinement (product-level accuracy)

### 6. China 301 Biden + 232 Stacking (~550 products, -43pp)
- **Gap**: TPC=93%, ours=50%
- **Root cause**: Products subject to both Biden 301 (50%) and 232 (25%) where stacking should produce ~93%. Our stacking rules may not correctly combine all components for these products.
- **Fix**: Check `apply_stacking_rules()` for China products with both rate_301 > 0 and rate_232 > 0.

### 7. Section 301 Exclusions (9903.89.xx) -- 61 remaining products
- **Gap**: 61 China products where TPC > us and our rate_301 = 0
- **Root cause**: Products excluded from 301 via 9903.89.xx US Note lists but still in our blanket list, OR products at 10-digit specificity not captured by our 8-digit matching
- **Fix**: Lower priority since only 61 products.

### 8. EU Floor Rate Residual (~4pp systematic, ~35-42% exact match)
- **Gap**: EU countries average 35-42% exact match with ~4pp mean excess
- **Root cause**: Floor formula `max(0, floor_rate - base_rate)` is correct. Residual gap may be from TPC using slightly different floor mechanics or base rate parsing differences.
- **Note**: Japan/S. Korea floor selection bug has been **fixed** (was picking surcharge instead of floor when both existed). Japan now at 42.1%, S. Korea at 40.1% exact match, in line with EU countries.

## Tier 4: Structural / Data Quality

### 9. TPC Country Coverage Alignment
- We generate rates for 240 countries; TPC covers ~209. Products for the ~31 countries TPC doesn't cover contribute to the "extra in ours" count but don't affect match rates.
- **Fix**: Low priority -- our broader coverage is correct by design.

### 10. 2026 HTS Revision Support
- Pipeline handles `2026_basic` as a special case but has no support for `2026_rev_1`, `2026_rev_2`, etc.
- `resolve_json_path()` and `list_available_revisions()` need updating before 2026 revisions appear.

## Priority Ordering

| Priority | Item | Est. Impact on rev_32 Exact Match |
|----------|------|-----------------------------------|
| P1 | #1 India rate | +3-4pp |
| P1 | #2 Brazil rate | +1-2pp |
| P1 | #3 CA/MX stacking | +0.5-1pp |
| P2 | #4 Singapore et al. | +0.5pp |
| P2 | #5 Switzerland | removes false positives |
| P3 | #6-8 Refinements | <0.5pp each |

## Recently Resolved

- **China IEEPA reciprocal rate (34% → 10%)**: Post-Geneva suspension of 9903.01.63 (`[Compiler's note: provision suspended.]`) was not detected due to encoding/format variation. Added robust secondary regex check in `extract_ieepa_rates()`. China's Phase 1 rate now correctly caps to the 10% universal baseline. Impact: ~17K China products, est. +5-8pp on overall exact match.
- **Phantom IEEPA countries**: Syria (5020), Moldova (4641), Laos (5530), Falkland Islands (3720), DR Congo (7660) have legitimate HTS IEEPA entries but TPC doesn't model them. Added `tpc_excluded_countries` in `config/policy_params.yaml` and exclusion filters in validation scripts. Removes ~95K false-positive product-country pairs from validation. Actual rates unchanged.
- **Section 232 derivative products**: ~130 aluminum-containing articles now covered with metal content scaling (flat 50% default, CBO buckets available). Stacking rules updated for non-metal portion.
- **Floor country IEEPA selection (Japan/S. Korea)**: Fixed tie-breaking to prefer floor over surcharge when both exist. S. Korea mean diff dropped to 0.1pp.
- **Section 301 blanket coverage**: ~10,400 HTS8 product codes now applied as blanket tariff for China, closing most of the 301 product gap.
