# Tariff-Rate-Tracker vs Tariff-ETRs Comparison

**Last updated:** 2026-03-11
**Tariff-ETRs scenario:** 2-21_temp (3 dates: 2026-01-01, 2026-02-24, 2026-07-24)
**Tracker build:** Mar 11, 2026 (base rate inheritance + 301 supersession + total-imports denominator)

---

## Overall ETR Comparison

| Date | Tracker | Tariff-ETRs | Diff (pp) | Regime |
|------|---------|-------------|-----------|--------|
| 2026-01-01 | 15.93% | 14.25% | **+1.68** | IEEPA + fentanyl + 232 + 301 |
| 2026-02-24 | 10.79% | 10.49% | **+0.30** | S122 + 232 + 301 (IEEPA zeroed) |
| 2026-07-24 | 6.40% | 7.29% | **-0.90** | 232 + 301 + MFN only |

Both use total imports ($3,124B) as denominator, treating unmatched products as 0% tariff. The two repos are within 2pp at every date, and within 0.3pp at the S122 date.

### Denominator note

The tracker snapshot only contains products with Ch99 tariff exposure. Unmatched products (27.5% of imports at 2026-01-01, 5.2% at 2026-02-24) have zero additional tariff. The correct ETR denominator is total imports across all products, not just the matched subset. Prior versions of this comparison used matched-only imports, which inflated the tracker ETR to 21.96% at 2026-01-01 — an artifact, not a real divergence.

The matched share rises from 72.5% to 94.8% between Jan 1 and Feb 24 because `2026_rev_4` adds S122 entries that cover nearly all products.

---

## IEEPA Period (2026-01-01): Tracker +1.68pp

### Country-level detail

| Country | Tracker | ETRs | Diff (pp) | Primary driver |
|---------|---------|------|-----------|----------------|
| China | 38.81% | 32.80% | +6.01 | 301 rate treatment |
| Canada | 16.89% | 7.21% | +9.68 | USMCA share granularity |
| Mexico | 13.01% | 11.37% | +1.63 | USMCA share granularity |
| Japan | 12.15% | 13.60% | -1.45 | MFN preference shares |
| UK | 6.56% | 6.29% | +0.27 | Near-match |
| EU | 8.81% | 9.30% | -0.49 | Near-match |

The +1.68pp overall gap reflects large offsetting country-level differences: China and Canada push the tracker up; Japan, EU, and others pull it down.

### Divergence source 1: USMCA share granularity (+9.7pp Canada, +1.6pp Mexico)

ETRs applies USMCA exemption rates from a 47-row GTAP sector file (~85-90% shares). The tracker uses product-level Census SPI data (~41% Canada, ~47% Mexico). TPC independently validates the tracker's approach:

| Source | Canada share | Mexico share |
|--------|-------------|-------------|
| TPC (benchmark) | 45.5% | 50.7% |
| Tracker (Census SPI) | 41.2% | 47.3% |
| ETRs (GTAP sectors) | ~85-90% | ~75-85% |

**Assessment:** Tracker is correct. ETRs over-exempts CA/MX by ~2x. Proposed ETRs fix: E1.

### Divergence source 2: Section 301 rate treatment (+6.0pp China)

ETRs applies a flat 301 rate per product. The tracker applies per-list rates (MAX across ch99 codes; Biden supersedes Trump on 8 overlapping products). TPC confirms multi-list rates — 85%+ rates require it:

| TPC rate cluster | Count | Decomposition |
|-----------------|-------|---------------|
| ~35% | 9,290 (64%) | fentanyl(10%) + 301_Trump(25%) |
| ~60% | 3,982 (28%) | 232(25%) + fentanyl(10%) + 301(25%) |
| ~85% | 421 (3%) | fentanyl(10%) + 301_Trump(25%) + 301_Biden(50%) |
| ~95% | 528 (4%) | recip(10%) + fentanyl(10%) + 301_Trump(25%) + 301_Biden(50%) |

**Assessment:** Tracker is correct. Proposed ETRs fix: E2.

### Divergence source 3: MFN preference methodology (-1 to -4pp Japan and others)

The tracker applies Census-based MFN exemption shares that reduce applied MFN rates for FTA/GSP-eligible trade. ETRs uses GTAP-level trade preferences. At this date (with IEEPA active), MFN base rates are a smaller share of total rates, so the impact is modest. Japan -1.45pp and EU -0.49pp are partially driven by this.

**Assessment:** Unclear which is more accurate. Not yet validated against a third source.

### Why the gap is small overall (+1.68pp)

The USMCA and 301 divergences (tracker high) are offset by MFN preference shares and other country-level differences (tracker low). The IEEPA duty-free treatment question — previously identified as a major gap — is not visible at the overall level because products with 0% base rate are a small share of total imports when using the correct denominator.

---

## Non-IEEPA Period

### 2026-02-24: S122 + 232 + 301 (tracker +0.30pp)

| Country | Tracker | ETRs | Diff (pp) |
|---------|---------|------|-----------|
| China | 27.27% | 22.72% | +4.55 |
| Canada | 4.88% | 5.04% | -0.17 |
| Mexico | 7.35% | 9.29% | -1.94 |
| Japan | 11.12% | 11.85% | -0.72 |
| UK | 6.89% | 6.72% | +0.17 |
| EU | 8.15% | 8.05% | +0.09 |

Near-perfect alignment. The +0.30pp overall gap is essentially zero. Non-China countries are all within 2pp. China's +4.55pp is 301 rate treatment. S122 coverage is high (94.8% of imports matched), so the denominator issue is minimal.

### 2026-07-24: 232 + 301 + MFN only (tracker -0.90pp)

| Country | Tracker | ETRs | Diff (pp) |
|---------|---------|------|-----------|
| China | 21.55% | 17.60% | +3.94 |
| Canada | 2.81% | 4.62% | -1.82 |
| Mexico | 4.88% | 8.43% | -3.55 |
| Japan | 4.03% | 8.23% | -4.20 |
| UK | 1.45% | 3.35% | -1.90 |
| EU | 2.99% | 4.12% | -1.13 |

With S122 expired and IEEPA zeroed, only 232, 301, and MFN remain. The tracker is lower for most countries. China's +3.94pp (301) is offset by Japan -4.20pp, Mexico -3.55pp, and broad MFN preference divergence. This is where the MFN preference methodology difference is most visible — it's the dominant rate component for non-232/non-301 products.

---

## TPC Product-Level Validation

TPC benchmark provides product-level rates at 5 dates during the IEEPA period. Import-weighted comparison using total imports denominator:

| Date | Tracker | TPC | Diff (pp) | Rev |
|------|---------|-----|-----------|-----|
| 2025-03-17 | 10.42% | 7.99% | +2.44 | rev_6 |
| 2025-04-17 | 15.20% | 23.48% | -8.28 | rev_10 |
| 2025-07-17 | 16.43% | 15.35% | +1.08 | rev_17 |
| 2025-10-17 | 16.19% | 18.20% | -2.01 | rev_18 |
| 2025-11-17 | 15.93% | 16.14% | -0.21 | rev_32 |

The tracker is within ~1pp of TPC at the latest two dates. The rev_10 outlier (-8.28pp) reflects the April 9 reciprocal suspension period — the tracker may understate the brief window when high Liberation Day rates were active.

### Within-2pp product-level match rates

| Revision | TPC Date | Within 2pp |
|----------|----------|------------|
| rev_6 | 2025-03-17 | **82.3%** |
| rev_10 | 2025-04-17 | **93.1%** |
| rev_17 | 2025-07-17 | **90.6%** |
| rev_18 | 2025-10-17 | **79.9%** |
| rev_32 | 2025-11-17 | **84.9%** |

---

## Summary of Divergences

| # | Source | Direction | Magnitude | Who's right | Fix |
|---|--------|-----------|-----------|-------------|-----|
| 1 | USMCA share granularity | Tracker high (CA/MX) | +9.7pp CA, +1.6pp MX | **Tracker** (TPC validates) | ETRs E1 |
| 2 | 301 rate treatment | Tracker high (China) | +4-6pp China | **Tracker** (TPC validates) | ETRs E2 |
| 3 | MFN preference methodology | Tracker low (broad) | -1 to -4pp per country | Unclear | Joint investigation |

Divergences #1 and #2 are ETRs-side issues confirmed by TPC. Divergence #3 is unresolved and most visible when MFN is the dominant rate (post-IEEPA/S122 expiry).

---

## Proposed Changes

### Tariff-ETRs

| # | Change | Status | Est. impact |
|---|--------|--------|-------------|
| E1 | Replace GTAP-level USMCA shares with product-level Census SPI data | Open | +4-8pp Canada, +2-3pp Mexico |
| E2 | Implement per-list 301 rates (Biden supersedes Trump on overlap) | Open | +4-6pp China |

### Tracker

All identified tracker-side issues have been resolved. Remaining gaps are ETRs-side (E1, E2) or joint investigation (MFN preferences).

---

## Resolved Issues

| Issue | Resolution | Date |
|-------|-----------|------|
| ETR denominator | Use total imports ($3,124B), not matched-only. Matched-only inflated tracker ETR from 15.93% to 21.96% at 2026-01-01 | 2026-03-11 |
| Base rate inheritance | Statistical suffixes (~59% of HTS10) inherit MFN from parent indent. 11,558 products fixed | 2026-03-11 |
| 301 Biden supersession | Biden supersedes Trump on 8 overlapping products (MAX, not SUM) | 2026-03-11 |
| S122 timing alignment | Effective 2026-02-24, expiry 2026-07-23 (matching ETRs) | 2026-03-10 |
| IEEPA invalidation | Calendar-date zeroing in compare_etrs.R | 2026-03-10 |
| IEEPA exempt products | Expanded 1,087 to 4,325 HTS10 | 2026-03-09 |
| 232 USMCA shares | Product-level Census SPI replaces binary exemption | 2026-03-09 |
| 232 auto deal rates | 12 entries: UK surcharge/floor, JP/EU/KR 15% floor | 2026-03-09 |
| 232 auto/MHD parts lists | Auto: 130 codes (CBP, Note 33(g)). MHD: 182 codes (Note 34(i)) | 2026-03-10 |
| S122 exempt products | Confirmed identical (1,656 HTS8 codes) | 2026-03-09 |
| Swiss framework | EO 14346, 15% floor, date-bounded | 2026-02 |
| CA/MX fentanyl carve-outs | 308 prefixes | 2026-02 |
| China IEEPA (34% to 10%) | Post-Geneva suspension detection | 2026-02 |
| Universal IEEPA baseline | ~143 unlisted countries get 10% default | 2026-02 |
| 232 derivatives | ~130 aluminum articles with BEA metal content scaling | 2026-02 |
