# =============================================================================
# Tests: Daily Series Infrastructure
# =============================================================================
#
# Validates horizon, expiry, decomposition, and schema behavior.
# Uses base R stopifnot() assertions — no external test framework required.
#
# Usage:
#   Rscript tests/run_tests_daily_series.R
#
# =============================================================================

library(tidyverse)
library(here)
source(here('src', 'helpers.R'))
source(here('src', '09_daily_series.R'))

pass_count <- 0
fail_count <- 0

run_test <- function(name, expr) {
  tryCatch({
    force(expr)
    message('  PASS: ', name)
    pass_count <<- pass_count + 1
  }, error = function(e) {
    message('  FAIL: ', name, ' — ', conditionMessage(e))
    fail_count <<- fail_count + 1
  })
}


# =============================================================================
# Test fixtures
# =============================================================================

# Minimal synthetic timeseries: 2 products, 2 countries, 2 revisions
make_test_ts <- function(horizon_end = as.Date('2026-12-31')) {
  expand_grid(
    hts10 = c('7208100000', '8703230000'),
    country = c('5700', '4280'),
    revision = c('rev_a', 'rev_b')
  ) %>%
    mutate(
      base_rate = 0.05,
      statutory_base_rate = 0.05,
      rate_232 = if_else(hts10 == '7208100000', 0.50, 0),
      rate_301 = if_else(country == '5700' & hts10 == '8703230000', 0.25, 0),
      rate_ieepa_recip = case_when(
        country == '5700' ~ 0.34,
        country == '4280' ~ 0.15,
        TRUE ~ 0.10
      ),
      rate_ieepa_fent = 0,
      rate_s122 = 0.10,
      rate_section_201 = if_else(hts10 == '8703230000', 0.02, 0),
      rate_other = 0,
      metal_share = if_else(hts10 == '7208100000', 1.0, 0),
      usmca_eligible = FALSE,
      effective_date = if_else(revision == 'rev_a',
                               as.Date('2026-01-01'), as.Date('2026-06-01')),
      valid_from = effective_date,
      valid_until = if_else(revision == 'rev_a',
                            as.Date('2026-05-31'), horizon_end)
    ) %>%
    apply_stacking_rules()
}

make_test_policy_params <- function() {
  list(
    CTY_CHINA = '5700',
    SECTION_122 = list(
      effective_date = as.Date('2026-02-24'),
      expiry_date = as.Date('2026-07-23'),
      finalized = FALSE
    ),
    SWISS_FRAMEWORK = list(
      effective_date = as.Date('2025-11-14'),
      expiry_date = as.Date('2026-03-31'),
      finalized = FALSE,
      countries = c('4419', '4411')
    ),
    SERIES_HORIZON_END = as.Date('2026-12-31')
  )
}


# =============================================================================
# Test 1: Final revision gets valid_until = horizon, not Sys.Date()
# =============================================================================

message('\n--- Test 1: Horizon end date ---')

run_test('final valid_until equals horizon', {
  ts <- make_test_ts(horizon_end = as.Date('2026-12-31'))
  final <- ts %>% filter(revision == 'rev_b') %>% pull(valid_until) %>% unique()
  stopifnot(final == as.Date('2026-12-31'))
})

run_test('series_horizon parsed from YAML', {
  pp <- load_policy_params()
  stopifnot(!is.null(pp$SERIES_HORIZON_END))
  stopifnot(pp$SERIES_HORIZON_END == as.Date('2026-12-31'))
})


# =============================================================================
# Test 2: get_rates_at_date() returns non-empty for future dates
# =============================================================================

message('\n--- Test 2: Future date queries ---')

run_test('get_rates_at_date returns data for 2026-12-15', {
  ts <- make_test_ts()
  result <- get_rates_at_date(ts, '2026-12-15')
  stopifnot(nrow(result) > 0)
})

run_test('get_rates_at_date returns data for mid-2026', {
  ts <- make_test_ts()
  result <- get_rates_at_date(ts, '2026-06-15')
  stopifnot(nrow(result) > 0)
  # Should be from rev_b
  stopifnot(all(result$revision == 'rev_b'))
})


# =============================================================================
# Test 3: Section 122 expiry zeroing
# =============================================================================

message('\n--- Test 3: Section 122 expiry ---')

run_test('rate_s122 zeroed after expiry date', {
  ts <- make_test_ts()
  pp <- make_test_policy_params()
  # Before expiry: s122 should be active
  before <- get_rates_at_date(ts, '2026-07-20', policy_params = pp)
  stopifnot(any(before$rate_s122 > 0))
  # After expiry: s122 should be zero
  after <- get_rates_at_date(ts, '2026-07-24', policy_params = pp)
  stopifnot(all(after$rate_s122 == 0))
})

run_test('total_rate recomputed after s122 zeroing', {
  ts <- make_test_ts()
  pp <- make_test_policy_params()
  before <- get_rates_at_date(ts, '2026-07-20', policy_params = pp)
  after <- get_rates_at_date(ts, '2026-07-24', policy_params = pp)
  # For products where s122 contributed, total should be lower
  non_232 <- before %>% filter(rate_232 == 0)
  non_232_after <- after %>% filter(rate_232 == 0)
  if (nrow(non_232) > 0 && any(non_232$rate_s122 > 0)) {
    # total_additional should differ
    stopifnot(all(non_232_after$total_additional < non_232$total_additional |
                  non_232$rate_s122 == 0))
  }
})


# =============================================================================
# Test 4: Authority decomposition sums to total_additional
# =============================================================================

message('\n--- Test 4: Authority decomposition reconciliation ---')

run_test('net authorities sum to total_additional', {
  ts <- make_test_ts()
  net <- compute_net_authority_contributions(ts, cty_china = '5700')
  decomp_sum <- net$net_232 + net$net_ieepa + net$net_fentanyl +
    net$net_301 + net$net_s122 + net$net_section_201 + net$net_other
  residual <- abs(decomp_sum - net$total_additional)
  max_residual <- max(residual)
  stopifnot(max_residual < 1e-10)
})

run_test('decomposition works with tpc_additive mode', {
  ts <- make_test_ts()
  net <- compute_net_authority_contributions(ts, stacking_method = 'tpc_additive')
  stopifnot('net_section_201' %in% names(net))
  stopifnot(all(net$net_section_201 == net$rate_section_201))
})


# =============================================================================
# Test 5: rate_section_201 preserved by enforce_rate_schema()
# =============================================================================

message('\n--- Test 5: Schema enforcement ---')

run_test('rate_section_201 in RATE_SCHEMA', {
  stopifnot('rate_section_201' %in% RATE_SCHEMA)
})

run_test('enforce_rate_schema preserves rate_section_201', {
  df <- tibble(
    hts10 = '1234567890', country = '5700',
    base_rate = 0.05, rate_section_201 = 0.10,
    rate_232 = 0, rate_301 = 0, rate_ieepa_recip = 0, rate_ieepa_fent = 0,
    rate_s122 = 0, rate_other = 0,
    total_additional = 0.10, total_rate = 0.15,
    metal_share = 1.0, usmca_eligible = FALSE,
    revision = 'test', effective_date = as.Date('2026-01-01')
  )
  result <- enforce_rate_schema(df)
  stopifnot('rate_section_201' %in% names(result))
  stopifnot(result$rate_section_201 == 0.10)
})

run_test('enforce_rate_schema fills missing rate_section_201 with 0', {
  df <- tibble(
    hts10 = '1234567890', country = '5700',
    base_rate = 0.05,
    rate_232 = 0, rate_301 = 0, rate_ieepa_recip = 0, rate_ieepa_fent = 0,
    rate_s122 = 0, rate_other = 0,
    total_additional = 0, total_rate = 0.05,
    metal_share = 1.0, usmca_eligible = FALSE,
    revision = 'test', effective_date = as.Date('2026-01-01')
  )
  result <- enforce_rate_schema(df)
  stopifnot('rate_section_201' %in% names(result))
  stopifnot(result$rate_section_201 == 0)
})


# =============================================================================
# Test 6: Expiry split points
# =============================================================================

message('\n--- Test 6: Generic expiry split points ---')

run_test('split points detected for spanning interval', {
  pp <- make_test_policy_params()
  splits <- get_expiry_split_points(
    as.Date('2026-01-01'), as.Date('2026-12-31'), pp)
  # Should find both s122 (2026-07-23) and swiss (2026-03-31)
  stopifnot(as.Date('2026-07-23') %in% splits)
  stopifnot(as.Date('2026-03-31') %in% splits)
})

run_test('no split points for interval before all expiries', {
  pp <- make_test_policy_params()
  splits <- get_expiry_split_points(
    as.Date('2026-01-01'), as.Date('2026-03-01'), pp)
  stopifnot(length(splits) == 0)
})

run_test('apply_expiry_zeroing zeros s122 after expiry', {
  ts <- make_test_ts() %>% filter(revision == 'rev_b') %>% head(4)
  pp <- make_test_policy_params()
  adjusted <- apply_expiry_zeroing(ts, as.Date('2026-07-24'), pp)
  stopifnot(all(adjusted$rate_s122 == 0))
})


# =============================================================================
# Test 7: product-country-day expansion paths
# =============================================================================

message('\n--- Test 7: product-country-day expansion paths ---')

run_test('export_daily_slice requires filter or full_export', {
  ts <- make_test_ts()
  err <- tryCatch({
    export_daily_slice(ts, c('2026-06-01', '2026-06-30'))
    FALSE
  }, error = function(e) TRUE)
  stopifnot(err)
})

run_test('export_daily_slice returns data for filtered query', {
  ts <- make_test_ts()
  pp <- make_test_policy_params()
  result <- export_daily_slice(ts, c('2026-06-01', '2026-06-30'),
                                countries = '5700', policy_params = pp)
  stopifnot(nrow(result) > 0)
  stopifnot(all(result$country == '5700'))
  stopifnot(all(result$date >= as.Date('2026-06-01')))
  stopifnot(all(result$date <= as.Date('2026-06-30')))
})

run_test('export_daily_slice applies s122 expiry', {
  ts <- make_test_ts()
  pp <- make_test_policy_params()
  result <- export_daily_slice(ts, c('2026-07-20', '2026-07-27'),
                                countries = '4280', policy_params = pp)
  before_expiry <- result %>% filter(date <= as.Date('2026-07-23'))
  after_expiry <- result %>% filter(date > as.Date('2026-07-23'))
  if (nrow(before_expiry) > 0) stopifnot(any(before_expiry$rate_s122 > 0))
  if (nrow(after_expiry) > 0) stopifnot(all(after_expiry$rate_s122 == 0))
})

run_test('expand_to_daily applies the same expiry logic as export_daily_slice', {
  ts <- make_test_ts()
  pp <- make_test_policy_params()
  expanded <- expand_to_daily(
    ts,
    c('2026-07-20', '2026-07-27'),
    countries = '4280',
    products = c('7208100000', '8703230000'),
    policy_params = pp
  ) %>%
    arrange(date, hts10, country)
  exported <- export_daily_slice(
    ts,
    c('2026-07-20', '2026-07-27'),
    countries = '4280',
    products = c('7208100000', '8703230000'),
    policy_params = pp
  ) %>%
    arrange(date, hts10, country)
  stopifnot(nrow(expanded) == nrow(exported))
  stopifnot(identical(expanded, exported))
})


# =============================================================================
# Summary
# =============================================================================

message('\n', strrep('=', 50))
message('Tests: ', pass_count, ' passed, ', fail_count, ' failed')
message(strrep('=', 50))
if (fail_count > 0) stop(fail_count, ' test(s) failed')
