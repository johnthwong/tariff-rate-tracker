# Tariff Rate Tracker — TODO

## Pipeline bugs

### MHD vehicle/bus 232 rates not applied (9903.74)

MHD 232 entries (`9903.74.xx`) first appear in the HTS JSON at rev_26 (Oct 6, 2025). Two issues:

1. **No HTS entries before rev_26.** Jul 23 – Oct 5 has zero MHD coverage. By design (tracker follows HTS, not announcements).
2. **Rates may still be zero after rev_26** if built from stale ch99 data. Current full rebuild (2026-03-23) should resolve. Verify after rebuild.

Also: `docs/revision_changelog.md` mislabels rev_26's `9903.74.xx` entries as "Copper 232" — should be "MHD vehicles/buses 232 + copper 232".

**Files:** `src/06_calculate_rates.R` (heading gates ~line 836), `config/policy_params.yaml` (MHD config ~line 120-138), `docs/revision_changelog.md` (rev_26 label)

## Pipeline rebuild

- [ ] Verify MHD 232 rates appear after rebuild (check rev_26+ for `rate_232 > 0` on MHD products)
- [ ] Fix `revision_changelog.md` rev_26 label
- [ ] Re-run `compare_etrs.R` after rebuild to confirm gap closure
- [ ] Add generic pharma country-specific exemption shares (per TPC feedback; low priority)

## Blog publication (`blog_april2/`)

- [ ] Regenerate all figures after pipeline rebuild completes
- [ ] Regenerate docx from final `.md` before publication

## Concordance builder

Matching in `src/build_hts_concordance.R` may overstate splits/merges. Suitable for `compare_etrs.R` but not authoritative. Tighten with reciprocal-best or capped matching if needed.

## Small-country outliers

Persistent large gaps on low-import countries (Azerbaijan -26pp, Bahrain -22pp, UAE -8pp, Georgia +14pp, New Caledonia +22pp). Not material to aggregates. Investigate after rebuild.
