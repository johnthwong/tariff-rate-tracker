# Active HTS Changes

Changes from Federal Register notices that override or supplement HTS JSON data. These entries track policy changes that have been enacted but may not yet be reflected in the HTS JSON archives downloaded from USITC.

When USITC publishes an HTS revision incorporating a change listed here, the override becomes redundant and the entry can be moved to the "Resolved" section.

---

## 1. US-Switzerland-Liechtenstein Framework (15% floor)

**Source**: [90 FR 59281](https://www.federalregister.gov/documents/2025/12/18/2025-23316), FR Doc. 2025-23316, December 18, 2025

**Authority**: Executive Order 14346 (September 5, 2025), implementing the Framework for a United States-Switzerland-Liechtenstein Agreement on Fair, Balanced, and Reciprocal Trade

**Effective**: November 14, 2025 (retroactive)

**Summary**: Replaces the +39% surcharge (Switzerland) and +15% surcharge (Liechtenstein) with a 15% floor structure, matching the EU/Japan/South Korea pattern. Products with base rate >= 15% pay no additional duty; products with base rate < 15% are raised to 15%. Three categories of products are fully exempt: PTAAP agricultural/natural resources, civil aircraft, and non-patented pharmaceuticals.

**HTS modifications**:

| Action | Code | Description |
|--------|------|-------------|
| Terminate | 9903.02.36 | Liechtenstein +15% surcharge |
| Terminate | 9903.02.58 | Switzerland +39% surcharge |
| New | 9903.02.82 | Switzerland passthrough (base >= 15%) |
| New | 9903.02.83 | Switzerland 15% floor (base < 15%) |
| New | 9903.02.84 | Switzerland PTAAP exempt (agricultural/natural resources) |
| New | 9903.02.85 | Switzerland civil aircraft exempt |
| New | 9903.02.86 | Switzerland non-patented pharma exempt |
| New | 9903.02.87 | Liechtenstein passthrough (base >= 15%) |
| New | 9903.02.88 | Liechtenstein 15% floor (base < 15%) |
| New | 9903.02.89 | Liechtenstein PTAAP exempt |
| New | 9903.02.90 | Liechtenstein civil aircraft exempt |
| New | 9903.02.91 | Liechtenstein non-patented pharma exempt |
| Modify | 9903.01.25 | Universal baseline range updated: 9903.02.81 -> 9903.02.91 |

**Pipeline handling** (updated Feb 2026):

1. **Extraction range expanded**: `extract_ieepa_rates()` range extended from 9903.02.02-81 to 9903.02.02-91, so native Swiss floor entries (9903.02.82-91) are parsed when present in HTS JSON. Confirmed present in `2026_basic`.

2. **Surcharge-to-floor override**: Switzerland (4419) and Liechtenstein (4411) in `floor_countries` config. Override in `06_calculate_rates.R` converts surcharge → floor for revisions where the HTS JSON only has the old surcharge entries (.02.36/.58). When native floor entries exist (and win rate selection over surcharges), the override is a no-op.

3. **Date-bounded**: Override governed by `swiss_framework` config in `policy_params.yaml`. Only applies when revision effective_date is within the framework window (Nov 14, 2025 → March 31, 2026). If `finalized: true`, no expiry constraint. If framework lapses, override automatically stops — surcharge rates resume.

4. **Product exemptions**: 1,681 exempt products (PTAAP, civil aircraft, pharma) in `resources/floor_exempt_products.csv`, applied in step 2 of rate calculation.

**HTS status (March 2026)**: Native floor entries (9903.02.82-91) are present in HTS JSON starting from `2026_basic` (Jan 1, 2026) and persist through `2026_rev_4` (Feb 25, 2026). The surcharge-to-floor override in `06_calculate_rates.R` is now a no-op for these revisions since the native entries win rate selection. The override remains necessary for `rev_32` (Nov 15, 2025) and earlier revisions within the framework window.

**Conditional expiry**: The Framework agreement must be finalized by **March 31, 2026** (22 days from today). If not, rates revert to +39% (Switzerland) / +15% (Liechtenstein) surcharges. When confirmed, set `swiss_framework.finalized: true` in `config/policy_params.yaml` to make the floor treatment permanent. **Action required by late March.**

---

## 2. Section 122 Phase 3 (10% blanket)

**Source**: Trade Act of 1974 §122; Executive Order (Phase 3)

**Authority**: Section 122 of the Trade Act of 1974

**Effective**: February 25, 2026

**Statutory limit**: 150 days from initial effective date → expires July 25, 2026

**Summary**: 10% blanket tariff on all imports from all countries. Exempt products listed in Annex II (1,656 HTS8 codes in `resources/s122_exempt_products.csv`). USMCA-eligible products reduced by `(1 - usmca_share)`. Mutually exclusive with Section 232 (232 takes precedence).

**HTS modifications** (2026_rev_4):

| Action | Code | Description |
|--------|------|-------------|
| New | 9903.03.01 | 10% blanket on all countries |
| New | 9903.03.02-11 | Exemptions: transit, IEEPA exempt, civil aircraft, 232, CA/MX, CAFTA-DR, donations, informational materials |

**Pipeline handling**: Implemented in `06_calculate_rates.R` (rate calculation), `09_daily_series.R` (interval splitting at S122 effective/expiry dates), and `helpers.R:get_rates_at_date()` (expiry enforcement). Config: `section_122` block in `policy_params.yaml`.

---

## 3. Semiconductor Tariffs (25%)

**Source**: US Note 39 to Chapter 99

**Authority**: Section 232 / IEEPA (semiconductor-specific)

**Effective**: January 16, 2026

**Summary**: 25% tariff on semiconductor articles. New subchapter 9903.79 with country-specific exemptions.

**HTS modifications** (2026_rev_1):

| Action | Code | Description |
|--------|------|-------------|
| New | 9903.79.01 | Semiconductor articles 25% |
| New | 9903.79.02-09 | Exemptions: transit, USMCA, country-specific |

**Pipeline handling**: Parsed automatically via standard Chapter 99 extraction. No special handling required.

---

## Resolved

### R1. 232 Auto Parts Product List (official CBP source)

**Source**: CBP "Automobile Parts HTS List" (Attachment 2), published May 1, 2025 via GovDelivery.
Direct PDF: https://content.govdelivery.com/attachments/USDHSCBP/2025/05/01/file_attachments/3248126/Attachment%202_Auto%20Parts%20HTS%20List.pdf

**Authority**: U.S. Note 33 to subchapter III of Chapter 99, subdivisions (g) and (h), heading 9903.94.05 (dutiable parts) and 9903.94.06 (USMCA-content exempt parts).

**Summary**: 130 HTS codes defining automobile parts subject to Section 232. Replaces the previous reverse-engineered list (136 prefixes from Tariff-ETRs). Changes: removed 7 codes that belong to MHD parts only (8708.99.03/.06/.23/.27/.31/.41, 8708.99.4850), added 1 missing prefix (8483.10.30). Note: the CBP list confirms '8471' as an official auto parts prefix (previously flagged as overly broad).

**Resolution**: Updated `resources/s232_auto_parts.txt` (March 2026). No code changes required — the file is loaded dynamically via `prefixes_file` in `policy_params.yaml`.

**MHD parts verified**: `s232_mhd_parts.txt` (182 codes) confirmed to match live HTSUS US Note 34, subdivision (i), heading 9903.74.08 exactly (verified against `chapter99_2026_rev_4.pdf`, page 541). No changes needed.
