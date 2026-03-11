# Tariff-Rate-Tracker vs Tariff-ETRs Comparison

**Last updated:** 2026-03-11
**Tariff-ETRs scenario:** 2-21_temp (3 dates: 2026-01-01, 2026-02-24, 2026-07-24)
**Tracker build:** Mar 11, 2026 (base rate inheritance + 301 supersession + S122 alignment)

---

## Overall ETR Comparison

| Date | Tracker | Tariff-ETRs | Diff (pp) | Regime |
|------|---------|-------------|-----------|--------|
| 2026-01-01 | 21.96% | 15.60% | **+6.36** | IEEPA + fentanyl + 232 + 301 |
| 2026-02-24 | 11.39% | 10.50% | **+0.88** | S122 + 232 + 301 (IEEPA zeroed) |
| 2026-07-24 | 6.75% | 7.34% | **-0.58** | 232 + 301 + MFN only |

The two repos diverge for different reasons depending on whether IEEPA authorities are active. Stripping IEEPA away (Feb 24 and Jul 24) brings the overall gap to under 1pp, isolating the IEEPA-period divergence as the primary challenge.

---

## IEEPA Period (2026-01-01): Tracker +6.36pp

When all IEEPA authorities are active, the tracker is systematically higher than ETRs for every major partner.

### Country-level detail

| Country | Tracker | ETRs | Diff (pp) | Primary driver |
|---------|---------|------|-----------|----------------|
| China | 39.27% | 32.80% | +6.47 | 301 rate treatment |
| Canada | 17.06% | 7.21% | +9.85 | USMCA share granularity |
| Mexico | 13.19% | 11.37% | +1.82 | USMCA share granularity |
| Japan | 16.02% | 13.60% | +2.42 | IEEPA duty-free treatment |
| UK | 11.52% | 6.29% | +5.23 | IEEPA duty-free treatment |
| EU | 16.78% | 10.55% | +6.22 | IEEPA duty-free treatment |

### Divergence source 1: USMCA share granularity (+9.9pp Canada, +1.8pp Mexico)

ETRs applies USMCA exemption rates from a 47-row GTAP sector file, producing shares of ~85-90% for Canada and ~75-85% for Mexico. The tracker uses product-level Census SPI data, producing shares of ~41% (Canada) and ~47% (Mexico). TPC's independent product-level data shows 45.5% (Canada) and 50.7% (Mexico), validating the tracker.

| Source | Canada share | Mexico share |
|--------|-------------|-------------|
| TPC (benchmark) | 45.5% | 50.7% |
| Tracker (Census SPI) | 41.2% | 47.3% |
| ETRs (GTAP sectors) | ~85-90% | ~75-85% |

**Assessment:** Tracker is correct. ETRs systematically over-exempts CA/MX by roughly 2x. This is the single largest driver of the IEEPA-period gap. Proposed ETRs fix: E1.

### Divergence source 2: Section 301 rate treatment (+6.5pp China)

ETRs applies a flat 301 rate per product. The tracker applies per-list rates — each product's 301 rate is the maximum rate across all ch99 codes it appears on. Products on both a Trump list (e.g., 9903.88.03 at 25%) and a Biden list (e.g., 9903.91.05 at 50%) receive the Biden rate (supersession, not stacking). Products on Trump lists only receive the Trump rate; products on Biden lists only receive the Biden rate. TPC's rate distribution confirms this approach — rates of 85%+ are only possible with multi-list 301 application:

| TPC rate cluster | Count | Decomposition |
|-----------------|-------|---------------|
| ~35% | 9,290 (64%) | fentanyl(10%) + 301_Trump(25%) |
| ~60% | 3,982 (28%) | 232(25%) + fentanyl(10%) + 301(25%) |
| ~85% | 421 (3%) | fentanyl(10%) + 301_Trump(25%) + 301_Biden(50%) |
| ~95% | 528 (4%) | recip(10%) + fentanyl(10%) + 301_Trump(25%) + 301_Biden(50%) |

**Assessment:** Tracker is correct. ETRs understates China 301 by ~6pp. Proposed ETRs fix: E2.

### Divergence source 3: IEEPA duty-free treatment (+2-6pp EU/UK/Japan)

The tracker applies IEEPA surcharges to all products including those with 0% MFN base rates (following the legal text of the IEEPA orders, which do not exempt duty-free products). TPC shows a continuous distribution of rates 0-14.9% for duty-free products in floor countries, suggesting either (a) a larger exempt product list, or (b) a trade-weighted partial-credit methodology.

The tracker exempts 4,325 HTS10 products from IEEPA (sourced from HTS footnotes, Ch98 statutory exemptions, and ITA zero-binding prefixes). TPC appears to exempt ~22% of Japan products vs the tracker's ~1-2%.

**Assessment:** Ambiguous. The tracker follows the legal text; TPC may reflect administrative practice or analytical convention. This gap disappears entirely when IEEPA is zeroed (Feb 24 and Jul 24 dates).

---

## Non-IEEPA Period: S122 (2026-02-24, +0.88pp) and Post-S122 (2026-07-24, -0.58pp)

With IEEPA zeroed, the three IEEPA-period divergences drop out and different dynamics emerge.

### 2026-02-24: S122 + 232 + 301 (tracker +0.88pp)

| Country | Tracker | ETRs | Diff (pp) |
|---------|---------|------|-----------|
| China | 28.99% | 22.72% | +6.27 |
| Canada | 5.00% | 5.04% | -0.05 |
| Mexico | 7.53% | 9.29% | -1.76 |
| Japan | 11.59% | 11.85% | -0.25 |
| UK | 7.22% | 6.72% | +0.50 |
| EU | 8.76% | 8.15% | +0.62 |

Non-China countries align well (within 2pp). The +0.88pp overall gap is almost entirely China's 301 treatment (+6.27pp), partially offset by Mexico (-1.76pp, USMCA shares dampening the S122 effect). Canada is essentially exact (-0.05pp).

### 2026-07-24: 232 + 301 + MFN only (tracker -0.58pp)

| Country | Tracker | ETRs | Diff (pp) |
|---------|---------|------|-----------|
| China | 22.90% | 17.60% | +5.30 |
| Canada | 2.88% | 4.62% | -1.75 |
| Mexico | 5.00% | 8.43% | -3.43 |
| Japan | 4.20% | 8.23% | -4.02 |
| UK | 1.52% | 3.35% | -1.83 |
| EU | 3.22% | 4.19% | -0.97 |

With S122 expired, only 232, 301, and MFN base rates remain. China is still higher (+5.30pp, 301 treatment). Every other major partner is lower, exposing two non-IEEPA divergences:

### Divergence source 4: MFN preference methodology (-2 to -4pp broad)

The tracker applies Census-based MFN exemption shares (`mfn_exemption_shares.csv`, 4,695 HS2 x country pairs from Tariff-ETRs) that reduce applied MFN rates for FTA/GSP-eligible trade. ETRs uses GTAP-level trade preferences, which appear to produce higher effective MFN rates.

This gap is most visible at Jul 24 when MFN is the dominant rate component. It affects the majority of countries — the tracker is lower for most non-China partners.

**Assessment:** Needs investigation. The tracker's Census-based shares may be more aggressive than warranted; ETRs' GTAP shares may be insufficiently granular. Neither has been validated against a third source for MFN preferences specifically.

### Divergence source 5: USMCA effect on non-IEEPA authorities (-1.8pp CA, -3.4pp MX)

The same USMCA share divergence from the IEEPA period persists here, but now works in the opposite direction relative to ETRs. With IEEPA gone, USMCA primarily reduces 232 auto exposure and S122/MFN rates. The tracker's lower USMCA shares mean less exemption from 232 and MFN, yet ETRs' higher GTAP shares show higher rates at this date — suggesting the USMCA effect is interacting with the MFN preference divergence.

Japan's -4.02pp gap is notable: with no IEEPA, no fentanyl, and no 301 exposure, Japan's rate is nearly pure 232 + MFN. The tracker's lower rate suggests the MFN exemption shares or 232 auto deal treatment differs meaningfully for Japan.

---

## TPC Product-Level Validation

TPC benchmark data (`data/tpc/tariff_by_flow_day.csv`) provides product-level rates at 5 pre-S122 dates during the IEEPA period.

| Revision | TPC Date | Within 2pp |
|----------|----------|------------|
| rev_6 | 2025-03-17 | **82.3%** |
| rev_10 | 2025-04-17 | **93.1%** |
| rev_17 | 2025-07-17 | **90.6%** |
| rev_18 | 2025-10-17 | **79.9%** |
| rev_32 | 2025-11-17 | **84.9%** |

Rev_10/17 are peak accuracy (>90%). Rev_18/32 improved substantially (+9.3pp, +11.1pp respectively) with the base rate inheritance fix. Rev_6 is pre-IEEPA reciprocal (differences dominated by 232 auto/USMCA treatment).

### TPC remaining discrepancy patterns

1. **Floor country product exemptions** (~48,000 EU mismatches): TPC shows a continuous 0-14.9% distribution for duty-free products in floor countries vs the tracker's binary 0% or 15%. Likely reflects TPC's larger exempt product list or partial-credit methodology.

2. **232 + IEEPA stacking** (~25,800 products): TPC stacks IEEPA reciprocal on top of 232 (no mutual exclusion). The tracker follows ETRs' legal authority structure with mutual exclusion. Documented analytical choice, not a bug.

---

## Summary of Divergences

| # | Source | IEEPA period | Non-IEEPA period | Who's right | Fix |
|---|--------|-------------|-------------------|-------------|-----|
| 1 | USMCA share granularity | +9.9pp CA, +1.8pp MX | -1.8pp CA, -3.4pp MX | **Tracker** (TPC validates) | ETRs E1 |
| 2 | 301 rate treatment | +6.5pp China | +5.3pp China | **Tracker** (TPC validates) | ETRs E2 |
| 3 | IEEPA duty-free treatment | +2-6pp EU/UK/JP | N/A | Ambiguous | — |
| 4 | MFN preference methodology | masked by IEEPA | -2 to -4pp broad | Unclear | Investigation needed |

The IEEPA-period gap (+6.36pp) is dominated by known, tracker-correct divergences (#1, #2) plus an ambiguous IEEPA duty-free question (#3). The non-IEEPA gap (-0.58pp) is small overall but masks offsetting errors: China 301 (+5.3pp) vs MFN preferences and USMCA effects pulling the other direction.

---

## Proposed Changes

### Tariff-ETRs

| # | Change | Status | Est. impact |
|---|--------|--------|-------------|
| E1 | Replace GTAP-level USMCA shares with product-level Census SPI data | Open | +4-8pp Canada, +2-3pp Mexico |
| E2 | Implement per-list 301 rates (Biden supersedes Trump on overlap) | Open | +5-6pp China |

### Tracker

All identified tracker issues have been resolved. Remaining gaps are either ETRs-side (E1, E2) or require joint investigation (MFN preferences, IEEPA duty-free treatment).

---

## Resolved Issues

| Issue | Resolution | Date |
|-------|-----------|------|
| Base rate inheritance | Statistical suffixes (~59% of HTS10) inherit MFN from parent indent. 11,558 products fixed. TPC match: rev_18 +9.3pp, rev_32 +11.1pp | 2026-03-11 |
| 301 Biden supersession | Biden supersedes Trump on 8 overlapping products (MAX, not SUM). Semiconductors: 75% → 50% | 2026-03-11 |
| S122 timing alignment | Effective 2026-02-24, expiry 2026-07-23 (matching ETRs) | 2026-03-10 |
| IEEPA invalidation | Calendar-date zeroing of IEEPA reciprocal + fentanyl in compare_etrs.R | 2026-03-10 |
| IEEPA exempt products | Expanded 1,087 → 4,325 HTS10 (HTS8→10, Ch98, ITA prefixes) | 2026-03-09 |
| 232 USMCA shares | Product-level Census SPI replaces binary exemption | 2026-03-09 |
| 232 auto deal rates | 12 entries: UK surcharge/floor, JP/EU/KR 15% floor | 2026-03-09 |
| 232 auto/MHD parts lists | Auto: 130 codes (CBP source, Note 33(g)). MHD: 182 codes (Note 34(i)) | 2026-03-10 |
| S122 exempt products | Confirmed identical (1,656 HTS8 codes) | 2026-03-09 |
| Brazil/India EO stacking | Confirmed correct (country_eo + Phase 2) | 2026-03-09 |
| Swiss framework | EO 14346, 15% floor, date-bounded | 2026-02 |
| CA/MX fentanyl carve-outs | 308 prefixes from fentanyl_carveout_products.csv | 2026-02 |
| China IEEPA (34% → 10%) | Post-Geneva suspension detection | 2026-02 |
| Universal IEEPA baseline | ~143 unlisted countries get 10% default | 2026-02 |
| 232 derivatives | ~130 aluminum articles with BEA metal content scaling | 2026-02 |
