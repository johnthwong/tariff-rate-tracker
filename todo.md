# Tracker Logic TODO

## 1. Empty revisions can collapse to zero rows

### Issue

In [src/06_calculate_rates.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/06_calculate_rates.R), `calculate_rates_for_revision()` returns immediately when the initial footnote-based pass is empty. That happens before the blanket-authority logic for IEEPA, Section 232, Section 301, Section 122, and post-IEEPA grid expansion runs.

### Why it matters

A footnote parse miss, or a revision that relies mainly on blanket authorities, can produce a fully empty revision even though the repo has enough information to build most of the rates.

### Proposed solution

- Remove the early return on `nrow(rates) == 0`.
- Initialize `rates` as an empty schema-conforming tibble instead.
- Let the blanket-authority steps populate rows even when the footnote seed is empty.
- At the end of the function, decide explicitly whether a truly empty revision means:
  - no tariffed pairs, or
  - a zero-duty base grid should be emitted.

### Files to update

- [src/06_calculate_rates.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/06_calculate_rates.R)
- possibly [src/helpers.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/helpers.R) for a small helper like `empty_rates_schema()`

### Tests to add

- A revision fixture with no footnote-linked pairs but active blanket Section 122 or IEEPA
- A revision fixture with no active authorities at all

---

## 2. Country-specific auto deals can become a global auto tariff

**Priority: Low (mitigated by config default_rate)**

### Issue

In [src/05_parse_policy_params.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/05_parse_policy_params.R), `extract_section232_rates()` falls back to `max(s232_auto$rate)` when there is no blanket auto row and only country-specific deal rows exist. That value is then reused downstream as if it were the default auto tariff.

### Investigation findings (2026-03-13)

The fallback triggers in **every revision** (rev_6 through rev_32) because the blanket entry `9903.94.01` has no parseable rate in the `general` field from the raw Ch99 parser. The rate is filled in later by downstream processing into `chapter99_rates.rds`.

However, the bug has **no practical impact** on current outputs because:
1. `config/policy_params.yaml` defines `default_rate: 0.25` for `autos_passenger` and `autos_light_trucks`.
2. In `06_calculate_rates.R` (line 894), the rate assignment uses `cfg$default_rate %||% s232_rates$auto_rate` — the config default takes precedence over the parsed `auto_rate`.
3. The heading gate (`auto_rate > 0`) still activates correctly because the fallback max is >0 whenever country-specific deal entries exist.

The risk is limited to a hypothetical future scenario where the config `default_rate` is removed and the blanket Ch99 entry still fails to parse. Given the current config-first architecture, this is defensive cleanup rather than a bug fix.

### Proposed solution (unchanged, but lower priority)

- Split auto logic into `auto_blanket_rate` (from true blanket entry, default 0) and `auto_deal_rates` (country-specific overrides).
- Update heading gate to check for deal rows OR blanket rate.
- No immediate impact expected due to config `default_rate` override.

### Files to update

- [src/05_parse_policy_params.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/05_parse_policy_params.R)
- [src/06_calculate_rates.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/06_calculate_rates.R)

### Tests to add

- A fixture where the auto block contains only country-specific deal entries and no blanket auto row
- A regression test that confirms non-deal countries stay at zero auto 232 in that case

---

## 3. ~~Country applicability is fail-open~~ (DONE 2026-03-13)

Fixed: `check_country_applies()` now returns `FALSE` for `'unknown'` and `NA` country_type values. The parser already returned `'unknown'` as default (not `'all'`); the only change needed was in `06_calculate_rates.R`. Quality report now flags any `'unknown'` entries. Test 12 covers all country_type branches. Zero impact on current outputs (no `'unknown'` entries in parsed data). Note: the raw `parse_chapter99()` output shows 377-423 `'unknown'` entries per revision, but these are handled by specialized extractors in `05_parse_policy_params.R`, not by the generic `check_country_applies()` path.

---

## 4. Section 301 scope is inconsistent across stacking and decomposition

### Issue

The live builder only applies blanket Section 301 to China in [src/06_calculate_rates.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/06_calculate_rates.R). But [src/helpers.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/helpers.R) still includes `rate_301` in non-China branches of `apply_stacking_rules()`, while `compute_net_authority_contributions()` zeroes `net_301` outside China.

### Why it matters

If any non-China `rate_301` ever enters the panel, total rates and authority decomposition will disagree.

### Proposed solution

- Make `apply_stacking_rules()` exclude `rate_301` from non-China branches.
- Add a validation check that flags any non-China row with `rate_301 > 0`.
- If the repo later models non-China Section 301 branches, represent them with a separate authority column instead of reusing the China 301 field.

### Files to update

- [src/helpers.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/helpers.R)
- [src/quality_report.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/quality_report.R)
- [docs/methodology.md](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/docs/methodology.md), if needed

### Tests to add

- A synthetic row with off-China `rate_301 > 0`
- A reconciliation test ensuring `total_additional` and net authority contributions remain aligned

---

## 5. Unweighted daily means use a sparse denominator

### Issue

The unweighted daily series in [src/09_daily_series.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/09_daily_series.R) averages over the rows present in the sparse tariff panel, not over a stable all-products × all-countries denominator.

### Why it matters

The unweighted means move with panel coverage as well as policy. That makes them easy to misread as unconditional averages across all product-country pairs.

### Proposed solution

- Decide whether the intended statistic is:
  - mean across all product-country pairs, or
  - mean across tariff-exposed pairs only.
- Ideally support both.
- If keeping both:
  - add explicit `*_all_pairs` and `*_exposed_pairs` outputs, or similar naming
  - document the denominator clearly in the methodology and README
- If the repo wants a true all-pairs mean, compute revision-level aggregates on a complete product-country grid without making that huge grid the canonical stored panel.

### Files to update

- [src/09_daily_series.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/09_daily_series.R)
- [docs/methodology.md](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/docs/methodology.md)
- [README.md](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/README.md)
- possibly [src/diagnostics.R](/C:/Users/ji252/Documents/GitHub/tariff-rate-tracker/src/diagnostics.R)

### Tests to add

- A toy revision where many zero-duty pairs are omitted from the sparse panel
- A regression test showing the expected difference between all-pairs and exposed-pairs averages

---

## Suggested order

1. ~~Fix fail-open country applicability.~~ (DONE)
2. Remove the empty-revision early return.
3. Harmonize Section 301 scope across stacking and decomposition.
4. Fix country-specific auto deals versus blanket auto rates. (low priority, mitigated by config)
5. Redefine and document the unweighted daily mean denominator.
