#!/usr/bin/env Rscript
# =============================================================================
# Compute product-level USMCA utilization shares from Census SPI data
# =============================================================================
#
# Computes per-HTS10 x country USMCA utilization shares based on the
# Rate Provision (RP) field:
#
#   RP = 18 → entered under USMCA preference
#
# For each HTS10 x country (Canada/Mexico):
#   usmca_share = sum(con_val where RP = 18) / sum(con_val all provisions)
#
# This directly replicates TPC's methodology: "Canadian- and Mexican-origin
# goods face a rate that is multiplied by the complement of the USMCA share
# for each product."
#
# Data sources (in priority order):
#   1. Local Census IMP_DETL.TXT files (from monthly IMDByymm.ZIP archives)
#   2. Census Bureau International Trade API (automatic fallback)
#      Endpoint: api.census.gov/data/timeseries/intltrade/imports/hs
#
# Output: resources/usmca_product_shares.csv
#   Columns: hts10, cty_code, usmca_share
#   All CA/MX products with positive imports (share = 0 if no USMCA claiming)
#
# Usage: Rscript src/compute_usmca_shares.R
#        Rscript src/compute_usmca_shares.R --year 2024
#        Rscript src/compute_usmca_shares.R --import-path /path/to/census/zips
#        Rscript src/compute_usmca_shares.R --source api
#        Rscript src/compute_usmca_shares.R --source local
# =============================================================================

library(tidyverse)
library(here)
library(jsonlite)

# --- Constants ---
USMCA_RATE_PROV <- '18'
CTY_CANADA <- '1220'
CTY_MEXICO <- '2010'
CENSUS_API_BASE <- 'https://api.census.gov/data/timeseries/intltrade/imports/hs'

# --- Parse arguments ---
args <- commandArgs(trailingOnly = TRUE)
import_data_path <- if ('--import-path' %in% args) {
  args[which(args == '--import-path') + 1]
} else {
  here('data', 'raw')
}
year <- if ('--year' %in% args) {
  as.integer(args[which(args == '--year') + 1])
} else {
  2025L
}
source_mode <- if ('--source' %in% args) {
  match.arg(args[which(args == '--source') + 1], c('auto', 'api', 'local'))
} else {
  'auto'
}

message('Computing product-level USMCA shares from Census SPI data...')
message('  Year: ', year)

# =============================================================================
# Data loading: local files or Census API
# =============================================================================

#' Load import records from local Census ZIP files (IMP_DETL.TXT)
#' @return tibble with hs10, cty_code, rate_prov, con_val_mo
load_from_local <- function(import_data_path, year) {
  yy <- substr(as.character(year), 3, 4)
  file_pattern <- sprintf('IMDB%s\\d{2}\\.ZIP', yy)
  zip_files <- list.files(
    path = import_data_path,
    pattern = file_pattern,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(zip_files) == 0) return(NULL)

  message('  Source: local files (', import_data_path, ')')
  message('  Found ', length(zip_files), ' ZIP file(s)')

  col_positions <- readr::fwf_positions(
    start     = c(1,  11,  21,  74),
    end       = c(10, 14,  22,  88),
    col_names = c('hs10', 'cty_code', 'rate_prov', 'con_val_mo')
  )

  map_df(zip_files, function(zip_path) {
    message('  Processing: ', basename(zip_path))

    zip_contents <- unzip(zip_path, list = TRUE)
    detl_file <- zip_contents$Name[grepl('IMP_DETL\\.TXT$', zip_contents$Name,
                                          ignore.case = TRUE)]

    if (length(detl_file) == 0) {
      warning('No IMP_DETL.TXT found in ', basename(zip_path), ', skipping')
      return(tibble())
    }
    if (length(detl_file) > 1) detl_file <- detl_file[1]

    temp_dir <- tempdir()
    extracted_path <- unzip(zip_path, files = detl_file, exdir = temp_dir, overwrite = TRUE)

    records <- read_fwf(
      file = extracted_path,
      col_positions = col_positions,
      col_types = cols(
        hs10       = col_character(),
        cty_code   = col_character(),
        rate_prov  = col_character(),
        con_val_mo = col_double()
      ),
      progress = FALSE
    )

    file.remove(extracted_path)

    records %>%
      filter(cty_code %in% c(CTY_CANADA, CTY_MEXICO))
  })
}

#' Load import records from Census Bureau International Trade API
#' Endpoint: api.census.gov/data/timeseries/intltrade/imports/hs
#' Variables: I_COMMODITY (HS10), CTY_CODE, CON_VAL_MO, RP (Rate Provision)
#' @return tibble with hs10, cty_code, rate_prov, con_val_mo
load_from_api <- function(year) {
  message('  Source: Census Bureau API (', CENSUS_API_BASE, ')')

  months <- sprintf('%02d', 1:12)
  countries <- c(CTY_CANADA, CTY_MEXICO)

  all_records <- map_df(countries, function(cty) {
    cty_label <- if (cty == CTY_CANADA) 'Canada' else 'Mexico'
    cty_records <- map_df(months, function(mo) {
      url <- paste0(
        CENSUS_API_BASE,
        '?get=I_COMMODITY,CTY_CODE,CON_VAL_MO,RP',
        '&COMM_LVL=HS10',
        '&CTY_CODE=', cty,
        '&time=', year, '-', mo,
        '&SUMMARY_LVL=DET'
      )

      result <- tryCatch({
        raw <- fromJSON(url, simplifyVector = TRUE)
        if (is.null(raw) || nrow(raw) < 2) return(tibble())

        # API returns matrix: row 1 = header, rows 2+ = data
        # Header: I_COMMODITY, CTY_CODE, CON_VAL_MO, RP, COMM_LVL, CTY_CODE, time, SUMMARY_LVL
        # Use positional indexing (columns 1-4) to avoid duplicate name issues
        header <- raw[1, ]
        i_comm <- which(header == 'I_COMMODITY')[1]
        i_cty  <- which(header == 'CTY_CODE')[1]
        i_val  <- which(header == 'CON_VAL_MO')[1]
        i_rp   <- which(header == 'RP')[1]

        if (anyNA(c(i_comm, i_cty, i_val, i_rp))) {
          warning('Unexpected API columns for ', cty_label, ' ', year, '-', mo,
                  ': ', paste(header, collapse = ', '))
          return(tibble())
        }

        data_rows <- raw[-1, , drop = FALSE]
        tibble(
          hs10       = as.character(data_rows[, i_comm]),
          cty_code   = as.character(data_rows[, i_cty]),
          rate_prov  = as.character(data_rows[, i_rp]),
          con_val_mo = as.double(data_rows[, i_val])
        )
      }, error = function(e) {
        warning('API error for ', cty_label, ' ', year, '-', mo, ': ', e$message)
        tibble()
      })

      result
    })
    message('  ', cty_label, ': ', nrow(cty_records), ' records from ',
            year, '-01 through ', year, '-12')
    cty_records
  })

  if (nrow(all_records) == 0) {
    stop('No data returned from Census API for year ', year)
  }

  # Normalize rate_prov: API returns "-" for no provision, "18" for USMCA
  all_records %>%
    mutate(rate_prov = if_else(rate_prov == '-', '00', rate_prov))
}

# --- Resolve data source ---
all_records <- NULL

if (source_mode == 'local') {
  all_records <- load_from_local(import_data_path, year)
  if (is.null(all_records) || nrow(all_records) == 0) {
    stop('No local Census files found and --source local was specified')
  }
} else if (source_mode == 'api') {
  all_records <- load_from_api(year)
} else {
  # auto: try local first, fall back to API
  all_records <- load_from_local(import_data_path, year)
  if (is.null(all_records) || nrow(all_records) == 0) {
    message('  No local Census files found — falling back to API')
    all_records <- load_from_api(year)
  }
}

message('  Total CA/MX records: ', nrow(all_records))

# =============================================================================
# Aggregate and compute shares
# =============================================================================

product_shares <- all_records %>%
  group_by(hs10, cty_code) %>%
  summarise(
    total_value = sum(con_val_mo),
    usmca_value = sum(con_val_mo[rate_prov == USMCA_RATE_PROV]),
    .groups = 'drop'
  ) %>%
  filter(total_value > 0) %>%
  mutate(usmca_share = usmca_value / total_value) %>%
  mutate(hts10 = str_pad(hs10, 10, pad = '0')) %>%
  select(-hs10)

message('\nProduct-level USMCA shares (Census RP = 18, year = ', year, '):')
message('  Total product-country pairs: ', nrow(product_shares))
message('  CA products: ', sum(product_shares$cty_code == CTY_CANADA))
message('  MX products: ', sum(product_shares$cty_code == CTY_MEXICO))

# --- Summary statistics ---
message('\n  Overall value shares:')
summary_by_country <- product_shares %>%
  group_by(cty_code) %>%
  summarise(
    total_value = sum(total_value),
    usmca_value = sum(usmca_value),
    overall_share = usmca_value / total_value,
    n_products = n(),
    n_with_usmca = sum(usmca_share > 0),
    n_full_usmca = sum(usmca_share > 0.99),
    n_zero_usmca = sum(usmca_share == 0),
    .groups = 'drop'
  )
print(summary_by_country)

message('\n  Share distribution (CA):')
print(summary(product_shares$usmca_share[product_shares$cty_code == CTY_CANADA]))
message('  Share distribution (MX):')
print(summary(product_shares$usmca_share[product_shares$cty_code == CTY_MEXICO]))

message('\n  Share deciles (CA):')
ca_shares <- product_shares$usmca_share[product_shares$cty_code == CTY_CANADA]
print(quantile(ca_shares, probs = seq(0, 1, 0.1)))
message('  Share deciles (MX):')
mx_shares <- product_shares$usmca_share[product_shares$cty_code == CTY_MEXICO]
print(quantile(mx_shares, probs = seq(0, 1, 0.1)))

# --- Save ---
out <- product_shares %>%
  select(hts10, cty_code, usmca_share) %>%
  arrange(hts10, cty_code)

stopifnot(!anyNA(out$usmca_share))
stopifnot(all(out$usmca_share >= 0 & out$usmca_share <= 1))

out_path <- here('resources', paste0('usmca_product_shares_', year, '.csv'))
write_csv(out, out_path)
message('\nSaved ', nrow(out), ' product-country pairs to: ', out_path)
message('Data year: ', year, ' | Source: ', source_mode)
