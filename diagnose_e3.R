## Diagnose E3: Trade preference / base rate methodology divergence
## Compares tracker vs ETRs at HTS2 × country level for Jul 24 date
## Then extracts HS10-level ETRs data for product-level comparison

library(tidyverse)
library(here)

source(here('src', 'helpers.R'))

# ---- Config ----
etrs_dir <- 'C:/Users/ji252/Documents/GitHub/Tariff-ETRs'
target_date <- as.Date('2026-07-24')  # Best date: only 232 + 301 + MFN active

focus_countries <- c(
  'Japan' = '5880', 'UK' = '4120', 'Mexico' = '2010',
  'Canada' = '1220', 'China' = '5700'
)

pp <- load_policy_params()
eu27 <- pp$EU27_CODES

# ---- Load ETRs HTS2 × country data ----
etrs_hts2 <- read_csv(
  file.path(etrs_dir, 'output', '2-21_temp', 'levels_by_census_country_hts2.csv'),
  col_types = cols(date = col_date(), cty_code = col_character(), country_name = col_character(),
                   .default = col_double())
)

etrs_jul <- etrs_hts2 %>%
  filter(date == target_date) %>%
  select(-date, -country_name) %>%
  pivot_longer(-cty_code, names_to = 'hts2', values_to = 'etrs_rate') %>%
  mutate(etrs_rate = etrs_rate / 100)  # Convert from pct to decimal

cat('ETRs HTS2 data:', nrow(etrs_jul), 'rows\n')

# ---- Load our imports (same source as ETRs) ----
imports_raw <- readRDS(file.path(etrs_dir, 'cache', 'hs10_by_country_gtap_2024_con.rds'))
imports <- imports_raw %>%
  group_by(hs10, cty_code) %>%
  summarise(value = sum(imports), .groups = 'drop') %>%
  filter(value > 0) %>%
  rename(hts10 = hs10, country = cty_code) %>%
  mutate(hts2 = substr(hts10, 1, 2))

# ---- Load our snapshot at Jul 24 ----
rev_dates <- load_revision_dates(here('config', 'revision_dates.csv'))
active_rev <- rev_dates %>%
  filter(effective_date <= target_date) %>%
  slice_max(effective_date, n = 1) %>%
  pull(revision)

cat('Active revision:', active_rev, '\n')

snap_path <- here('data', 'timeseries', paste0('snapshot_', active_rev, '.rds'))
rates <- readRDS(snap_path)

# Apply S122 expiry and IEEPA invalidation for Jul 24
s122_cfg <- pp$section_122
s122_expiry <- as.Date(s122_cfg$expiry_date)
if (target_date > s122_expiry && 'rate_s122' %in% names(rates)) {
  rates <- rates %>%
    mutate(
      total_additional = total_additional - rate_s122,
      total_rate = base_rate + total_additional,
      rate_s122 = 0
    )
  cat('S122 expired — zeroed\n')
}

ieepa_inv <- as.Date(pp$ieepa_invalidation_date)
if (target_date >= ieepa_inv && 'rate_ieepa_recip' %in% names(rates)) {
  rates <- rates %>%
    mutate(
      total_additional = total_additional - rate_ieepa_recip - rate_ieepa_fent,
      total_rate = base_rate + total_additional,
      rate_ieepa_recip = 0,
      rate_ieepa_fent = 0
    )
  cat('IEEPA invalidated — zeroed\n')
}

cat('Snapshot rows:', nrow(rates), '\n')

# ---- Merge tracker with imports at product level ----
merged <- rates %>%
  inner_join(imports %>% select(hts10, country, value, hts2),
             by = c('hts10', 'country'))

cat('Merged rows:', nrow(merged), '\n')

# ---- Aggregate tracker to HTS2 × country ----
tracker_hts2 <- merged %>%
  group_by(country, hts2) %>%
  summarise(
    tracker_rev = sum(total_rate * value),
    tracker_imports = sum(value),
    .groups = 'drop'
  )

# Total imports by country × HTS2 (including unmatched products)
total_hts2_imports <- imports %>%
  group_by(country, hts2) %>%
  summarise(total_value = sum(value), .groups = 'drop')

tracker_hts2 <- tracker_hts2 %>%
  left_join(total_hts2_imports, by = c('country', 'hts2')) %>%
  mutate(tracker_rate = tracker_rev / total_value)

# ---- Join tracker and ETRs at HTS2 × country ----
comparison <- tracker_hts2 %>%
  inner_join(etrs_jul, by = c('country' = 'cty_code', 'hts2')) %>%
  mutate(
    diff_pp = (tracker_rate - etrs_rate) * 100,
    tariff_rev_diff = (tracker_rate - etrs_rate) * total_value
  )

# ===================================================================
# Part 1: Overall gap decomposition by chapter
# ===================================================================
cat('\n', strrep('=', 70), '\n')
cat('PART 1: HTS2 Chapter Contribution to Overall Gap (Jul 24)\n')
cat(strrep('=', 70), '\n\n')

chapter_contrib <- comparison %>%
  group_by(hts2) %>%
  summarise(
    total_imports = sum(total_value),
    tracker_rev = sum(tracker_rev),
    etrs_rev = sum(etrs_rate * total_value),
    rev_diff = sum(tariff_rev_diff),
    .groups = 'drop'
  ) %>%
  mutate(
    tracker_rate = tracker_rev / total_imports * 100,
    etrs_rate = etrs_rev / total_imports * 100,
    diff_pp = tracker_rate - etrs_rate
  ) %>%
  arrange(rev_diff)

total_imports_all <- sum(imports$value)

cat(sprintf('%-6s %12s %8s %8s %8s %12s\n',
            'Ch', 'Imports($M)', 'Tracker', 'ETRs', 'Diff', 'Rev Diff($M)'))
cat(strrep('-', 60), '\n')

# Top 10 chapters pushing tracker DOWN (negative diff)
top_neg <- chapter_contrib %>% head(10)
for (i in seq_len(nrow(top_neg))) {
  r <- top_neg[i, ]
  cat(sprintf('%-6s %12.0f %7.2f%% %7.2f%% %+7.2f %+12.0f\n',
              r$hts2, r$total_imports / 1e6, r$tracker_rate, r$etrs_rate,
              r$diff_pp, r$rev_diff / 1e6))
}
cat('...\n')
# Top 5 chapters pushing tracker UP
top_pos <- chapter_contrib %>% tail(5)
for (i in seq_len(nrow(top_pos))) {
  r <- top_pos[i, ]
  cat(sprintf('%-6s %12.0f %7.2f%% %7.2f%% %+7.2f %+12.0f\n',
              r$hts2, r$total_imports / 1e6, r$tracker_rate, r$etrs_rate,
              r$diff_pp, r$rev_diff / 1e6))
}

cat(sprintf('\nTotal rev diff: $%.1fB\n', sum(chapter_contrib$rev_diff) / 1e9))

# ===================================================================
# Part 2: Country-level gap decomposition by chapter (focus countries)
# ===================================================================
cat('\n', strrep('=', 70), '\n')
cat('PART 2: Country × Chapter Detail (Jul 24, Top Gap Contributors)\n')
cat(strrep('=', 70), '\n')

for (cname in names(focus_countries)) {
  cty <- focus_countries[cname]
  cty_data <- comparison %>%
    filter(country == cty) %>%
    arrange(tariff_rev_diff)

  if (nrow(cty_data) == 0) next

  total_cty_imports <- sum(cty_data$total_value)
  cty_tracker <- sum(cty_data$tracker_rev) / total_cty_imports * 100
  cty_etrs <- sum(cty_data$etrs_rate * cty_data$total_value) / total_cty_imports * 100

  cat(sprintf('\n--- %s (overall: tracker %.2f%%, ETRs %.2f%%, diff %+.2fpp) ---\n',
              cname, cty_tracker, cty_etrs, cty_tracker - cty_etrs))
  cat(sprintf('%-6s %10s %8s %8s %8s %10s\n',
              'Ch', 'Imp($M)', 'Tracker', 'ETRs', 'Diff', 'RevD($M)'))
  cat(strrep('-', 55), '\n')

  # Show top 5 negative and top 3 positive
  top_neg <- cty_data %>% head(5)
  for (i in seq_len(nrow(top_neg))) {
    r <- top_neg[i, ]
    cat(sprintf('%-6s %10.0f %7.2f%% %7.2f%% %+7.2f %+10.1f\n',
                r$hts2, r$total_value / 1e6, r$tracker_rate * 100, r$etrs_rate * 100,
                r$diff_pp, r$tariff_rev_diff / 1e6))
  }
  if (nrow(cty_data) > 8) cat('  ...\n')
  top_pos <- cty_data %>% tail(3)
  for (i in seq_len(nrow(top_pos))) {
    r <- top_pos[i, ]
    cat(sprintf('%-6s %10.0f %7.2f%% %7.2f%% %+7.2f %+10.1f\n',
                r$hts2, r$total_value / 1e6, r$tracker_rate * 100, r$etrs_rate * 100,
                r$diff_pp, r$tariff_rev_diff / 1e6))
  }
}

# ===================================================================
# Part 3: Decompose tracker rates into base vs additional
# ===================================================================
cat('\n', strrep('=', 70), '\n')
cat('PART 3: Base Rate vs Additional Tariff Decomposition (Jul 24)\n')
cat(strrep('=', 70), '\n\n')

# For focus countries, show base_rate vs total_additional
for (cname in names(focus_countries)) {
  cty <- focus_countries[cname]
  cty_merged <- merged %>% filter(country == cty)
  if (nrow(cty_merged) == 0) next

  total_cty_imp <- total_hts2_imports %>%
    filter(country == cty) %>%
    pull(total_value) %>%
    sum()

  base_etr <- sum(cty_merged$base_rate * cty_merged$value) / total_cty_imp * 100
  addl_etr <- sum(cty_merged$total_additional * cty_merged$value) / total_cty_imp * 100

  # Decompose additional by authority if columns exist
  s232_etr <- if ('rate_232' %in% names(cty_merged))
    sum(cty_merged$rate_232 * cty_merged$value) / total_cty_imp * 100 else 0
  s301_etr <- if ('rate_301' %in% names(cty_merged))
    sum(cty_merged$rate_301 * cty_merged$value) / total_cty_imp * 100 else 0

  cat(sprintf('%-8s  base=%.2f%%  addl=%.2f%% (232=%.2f%%, 301=%.2f%%)  total=%.2f%%\n',
              cname, base_etr, addl_etr, s232_etr, s301_etr, base_etr + addl_etr))
}

# ===================================================================
# Part 4: Distribution of product-level gaps (requires ETRs HS10 data)
# ===================================================================
cat('\n', strrep('=', 70), '\n')
cat('PART 4: Product-Level Gap Distribution\n')
cat(strrep('=', 70), '\n\n')

# Extract HS10-level ETRs rates if the extraction file exists
etrs_hs10_path <- file.path(etrs_dir, 'output', '2-21_temp', 'hs10_country_levels_2026-07-24.csv')

if (file.exists(etrs_hs10_path)) {
  cat('Loading ETRs HS10-level data...\n')
  etrs_hs10 <- read_csv(etrs_hs10_path, col_types = cols(
    hs10 = col_character(), cty_code = col_character(),
    level = col_double(), imports = col_double()
  ))

  # Merge with tracker at HS10 × country
  hs10_compare <- merged %>%
    select(hts10, country, tracker_rate = total_rate, tracker_base = base_rate,
           tracker_addl = total_additional, value) %>%
    inner_join(
      etrs_hs10 %>% select(hs10, cty_code, etrs_rate = level),
      by = c('hts10' = 'hs10', 'country' = 'cty_code')
    ) %>%
    mutate(
      etrs_rate = etrs_rate / 100,
      diff = tracker_rate - etrs_rate,
      diff_pp = diff * 100,
      abs_diff = abs(diff_pp)
    )

  cat('HS10 matches:', nrow(hs10_compare), '\n\n')

  # Distribution
  cat('Gap distribution (all countries):\n')
  cat(sprintf('  Within 1pp:  %.1f%%\n', mean(hs10_compare$abs_diff < 1) * 100))
  cat(sprintf('  Within 2pp:  %.1f%%\n', mean(hs10_compare$abs_diff < 2) * 100))
  cat(sprintf('  Within 5pp:  %.1f%%\n', mean(hs10_compare$abs_diff < 5) * 100))
  cat(sprintf('  >10pp:       %.1f%%\n', mean(hs10_compare$abs_diff > 10) * 100))

  # By focus country
  cat('\nImport-weighted mean absolute gap by country:\n')
  for (cname in names(focus_countries)) {
    cty <- focus_countries[cname]
    cty_hs10 <- hs10_compare %>% filter(country == cty)
    if (nrow(cty_hs10) == 0) next
    wmae <- sum(abs(cty_hs10$diff) * cty_hs10$value) / sum(cty_hs10$value) * 100
    cat(sprintf('  %-8s  %.2fpp  (n=%d products)\n', cname, wmae, nrow(cty_hs10)))
  }

  # Decompose: base rate gap vs additional tariff gap
  cat('\nBase rate vs additional tariff gap (import-weighted, focus countries):\n')
  for (cname in names(focus_countries)) {
    cty <- focus_countries[cname]
    cty_hs10 <- hs10_compare %>% filter(country == cty)
    if (nrow(cty_hs10) == 0) next

    # ETRs total = etrs_rate. Tracker base = tracker_base. Tracker addl = tracker_addl.
    # If ETRs base ≈ tracker base, gap is in additional tariffs.
    # We can infer: etrs_addl = etrs_rate - tracker_base (assuming same base rates)
    total_imp <- sum(cty_hs10$value)
    tracker_base_wt <- sum(cty_hs10$tracker_base * cty_hs10$value) / total_imp
    tracker_total_wt <- sum(cty_hs10$tracker_rate * cty_hs10$value) / total_imp
    etrs_total_wt <- sum(cty_hs10$etrs_rate * cty_hs10$value) / total_imp

    cat(sprintf('  %-8s  tracker: base=%.2f%% + addl=%.2f%% = %.2f%%  |  ETRs: %.2f%%  |  gap: %+.2fpp\n',
                cname,
                tracker_base_wt * 100,
                (tracker_total_wt - tracker_base_wt) * 100,
                tracker_total_wt * 100,
                etrs_total_wt * 100,
                (tracker_total_wt - etrs_total_wt) * 100))
  }

  # Top 20 products by revenue difference (Japan)
  cat('\nTop 20 Japan products by tariff revenue gap (tracker - ETRs):\n')
  japan_top <- hs10_compare %>%
    filter(country == '5880') %>%
    mutate(rev_diff = diff * value) %>%
    arrange(rev_diff) %>%
    head(20)

  cat(sprintf('%-12s %8s %8s %8s %10s\n', 'HTS10', 'Tracker', 'ETRs', 'Diff', 'RevD($M)'))
  cat(strrep('-', 55), '\n')
  for (i in seq_len(nrow(japan_top))) {
    r <- japan_top[i, ]
    cat(sprintf('%-12s %7.2f%% %7.2f%% %+7.2f %+10.1f\n',
                r$hts10, r$tracker_rate * 100, r$etrs_rate * 100, r$diff_pp, r$rev_diff / 1e6))
  }
} else {
  cat('ETRs HS10-level data not yet extracted.\n')
  cat('Run extract_etrs_hs10.R in the Tariff-ETRs repo first:\n')
  cat('  source("', etrs_hs10_path, '")\n')
  cat('\nProceeding with HTS2-level analysis only (Parts 1-3).\n')
}

cat('\nDone.\n')
