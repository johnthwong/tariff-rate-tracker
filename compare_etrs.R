## Compare Tracker ETRs vs Tariff-ETRs at 3 dates
## Uses daily series output (already aggregated) + per-date snapshot computation

library(tidyverse)
library(here)

source(here('src', 'helpers.R'))

# ---- Tariff-ETRs benchmark data (from 2-21_temp scenario) ----
etrs_path <- 'C:/Users/ji252/Documents/GitHub/Tariff-ETRs/output/2-21_temp/levels_by_census_country.csv'
etrs <- read_csv(etrs_path, col_types = cols(
  date = col_date(),
  cty_code = col_character(),
  country_name = col_character(),
  level = col_double()
))

cat('Tariff-ETRs data loaded:', nrow(etrs), 'rows\n')
cat('Dates:', paste(unique(etrs$date), collapse = ', '), '\n')

# ---- Load our imports for weighting ----
# Uses same Census import data as 08_weighted_etr.R (from Tariff-ETRs cache)
imports_raw <- readRDS(file.path('..', 'Tariff-ETRs', 'cache', 'hs10_by_country_gtap_2024_con.rds'))
imports <- imports_raw %>%
  group_by(hs10, cty_code) %>%
  summarise(value = sum(imports), .groups = 'drop') %>%
  filter(value > 0) %>%
  rename(hts10 = hs10, country_code = cty_code)

# ---- Policy params for partner groupings ----
pp <- load_policy_params()

eu27 <- pp$EU27_CODES
partner_labels <- c('China' = '5700', 'Canada' = '1220', 'Mexico' = '2010',
                     'Japan' = '5880', 'UK' = '4120')

# ---- Process each date by loading the appropriate snapshot ----
# Map dates to revisions
rev_dates <- load_revision_dates(here('config', 'revision_dates.csv'))

# For each ETRs date, find the active revision
comparison_dates <- unique(etrs$date)

results <- list()

for (d in comparison_dates) {
  d <- as.Date(d, origin = '1970-01-01')
  cat('\n', strrep('=', 60), '\n')
  cat('Date:', as.character(d), '\n')
  cat(strrep('=', 60), '\n')

  # Find active revision for this date
  active_rev <- rev_dates %>%
    filter(effective_date <= d) %>%
    slice_max(effective_date, n = 1) %>%
    pull(revision)

  cat('Active revision:', active_rev, '\n')

  # Load snapshot for this revision
  snap_path <- here('data', 'timeseries', paste0('snapshot_', active_rev, '.rds'))
  if (!file.exists(snap_path)) {
    cat('  Snapshot not found:', snap_path, '\n')
    next
  }

  rates <- readRDS(snap_path)
  cat('  Snapshot rows:', nrow(rates), '\n')

  # Apply S122 expiry if date is past expiry
  s122_cfg <- pp$section_122
  if (!is.null(s122_cfg)) {
    s122_expiry <- as.Date(s122_cfg$expiry_date)
    s122_effective <- as.Date(s122_cfg$effective_date)

    if (d >= s122_effective && d <= s122_expiry) {
      cat('  S122 active (', as.character(s122_effective), ' to ', as.character(s122_expiry), ')\n')
    } else if (d > s122_expiry) {
      cat('  S122 expired — zeroing rate_s122\n')
      if ('rate_s122' %in% names(rates)) {
        # Recalculate total_additional and total_rate without s122
        rates <- rates %>%
          mutate(
            total_additional = total_additional - rate_s122,
            total_rate = base_rate + total_additional,
            rate_s122 = 0
          )
      }
    } else {
      cat('  S122 not yet active\n')
    }
  }

  # Apply IEEPA invalidation if calendar date >= invalidation date
  # (snapshot may be from an earlier revision whose effective_date < invalidation)
  ieepa_inv <- pp$ieepa_invalidation_date
  if (!is.null(ieepa_inv)) {
    ieepa_inv <- as.Date(ieepa_inv)
    if (d >= ieepa_inv) {
      cat('  IEEPA invalidated as of', as.character(ieepa_inv), '— zeroing reciprocal + fentanyl\n')
      if ('rate_ieepa_recip' %in% names(rates)) {
        rates <- rates %>%
          mutate(
            total_additional = total_additional - rate_ieepa_recip - rate_ieepa_fent,
            total_rate = base_rate + total_additional,
            rate_ieepa_recip = 0,
            rate_ieepa_fent = 0
          )
      }
    } else {
      cat('  IEEPA active (invalidation:', as.character(ieepa_inv), ')\n')
    }
  }

  # Join with imports
  merged <- rates %>%
    inner_join(imports %>% select(hts10, country = country_code, value),
               by = c('hts10', 'country'))

  total_imports <- sum(merged$value)

  # Overall weighted ETR
  overall_etr <- sum(merged$total_rate * merged$value) / total_imports
  cat('  Overall ETR:', round(overall_etr * 100, 2), '%\n')

  # By country (census-weighted) — match ETRs format
  country_etrs <- merged %>%
    group_by(country) %>%
    summarise(
      imports = sum(value),
      etr = sum(total_rate * value) / sum(value),
      .groups = 'drop'
    ) %>%
    arrange(desc(etr))

  # Compare with Tariff-ETRs
  etrs_at_date <- etrs %>%
    filter(date == d) %>%
    select(country = cty_code, etrs_level = level) %>%
    mutate(etrs_level = etrs_level / 100)  # Convert from pct to decimal

  comparison <- country_etrs %>%
    inner_join(etrs_at_date, by = 'country') %>%
    mutate(
      diff_pp = (etr - etrs_level) * 100,
      import_share = imports / total_imports
    )

  # Print key partners
  cat('\n  Country-Level Comparison (Census-weighted ETR):\n')
  cat(sprintf('  %-15s %8s %8s %8s\n', 'Country', 'Tracker', 'ETRs', 'Diff(pp)'))
  cat('  ', strrep('-', 45), '\n')

  for (pname in names(partner_labels)) {
    cty <- partner_labels[pname]
    row <- comparison %>% filter(country == cty)
    if (nrow(row) > 0) {
      cat(sprintf('  %-15s %7.2f%% %7.2f%% %+7.2f\n',
                  pname, row$etr * 100, row$etrs_level * 100, row$diff_pp))
    }
  }

  # EU aggregate
  eu_data <- merged %>% filter(country %in% eu27)
  if (nrow(eu_data) > 0) {
    eu_etr <- sum(eu_data$total_rate * eu_data$value) / sum(eu_data$value)
    # ETRs EU aggregate
    eu_etrs <- etrs_at_date %>%
      filter(country %in% eu27) %>%
      inner_join(country_etrs %>% select(country, imports), by = 'country')
    if (nrow(eu_etrs) > 0) {
      eu_etrs_agg <- sum(eu_etrs$etrs_level * eu_etrs$imports) / sum(eu_etrs$imports)
      cat(sprintf('  %-15s %7.2f%% %7.2f%% %+7.2f\n',
                  'EU', eu_etr * 100, eu_etrs_agg * 100, (eu_etr - eu_etrs_agg) * 100))
    }
  }

  # Overall
  etrs_overall <- sum(comparison$etrs_level * comparison$imports) / sum(comparison$imports)
  cat(sprintf('  %-15s %7.2f%% %7.2f%% %+7.2f\n',
              'OVERALL', overall_etr * 100, etrs_overall * 100, (overall_etr - etrs_overall) * 100))

  results[[as.character(d)]] <- list(
    date = d,
    revision = active_rev,
    overall_tracker = overall_etr,
    overall_etrs = etrs_overall,
    comparison = comparison
  )

  rm(rates, merged)
  gc()
}

# ---- Summary table ----
cat('\n\n', strrep('=', 60), '\n')
cat('SUMMARY: Tracker vs Tariff-ETRs\n')
cat(strrep('=', 60), '\n\n')

cat(sprintf('%-12s %10s %10s %10s\n', 'Date', 'Tracker', 'ETRs', 'Diff(pp)'))
cat(strrep('-', 45), '\n')
for (r in results) {
  cat(sprintf('%-12s %9.2f%% %9.2f%% %+9.2f\n',
              as.character(r$date),
              r$overall_tracker * 100, r$overall_etrs * 100,
              (r$overall_tracker - r$overall_etrs) * 100))
}

# Save comparison data
val_dir <- here('output', 'validation')
if (!dir.exists(val_dir)) dir.create(val_dir, recursive = TRUE)

all_comparisons <- map_dfr(results, function(r) {
  r$comparison %>% mutate(date = r$date, revision = r$revision)
})
write_csv(all_comparisons, file.path(val_dir, 'etrs_comparison_by_country.csv'))

cat('\nSaved to:', file.path(val_dir, 'etrs_comparison_by_country.csv'), '\n')
