# =============================================================================
# Step 12: Parse US Note Product Lists from Chapter 99 PDF
# =============================================================================
#
# Extracts Section 301 product lists from US Notes 20 and 31 in the USITC
# Chapter 99 PDF. These notes enumerate HTS subheadings covered by
# 9903.88.xx and 9903.91.xx entries that cannot be extracted from individual
# HTS JSON footnotes.
#
# Downloads the Chapter 99 PDF from USITC, parses the text with pdftools,
# and outputs updated resources/s301_product_lists.csv.
#
# Usage:
#   Rscript src/12_scrape_us_notes.R              # Full run
#   Rscript src/12_scrape_us_notes.R --dry-run    # Report without writing
#
# Dependencies: pdftools
#
# =============================================================================

library(tidyverse)


# =============================================================================
# Configuration: ch99 code -> list label mapping
# =============================================================================
#
# Product lists in the PDF are identified by "Heading 9903.XX.XX applies to"
# anchor text. This mapping assigns list labels for the output CSV.
#
# Note 20 (Original Section 301, Lists 1-4A):
#   Subdivisions (b), (d), (f) enumerate HTS8 codes for Lists 1-3.
#   Subdivision (s) enumerates HTS8 codes for List 4A.
#   9903.88.04 (List 3 reduced 7.5%) has no separate product enumeration
#   — its products are a subset of 9903.88.03 with specific exclusions.
#
# Note 31 (Biden 301 acceleration):
#   Subdivisions (b)-(j) enumerate products for 9903.91.xx headings.
#
CH99_TO_LIST <- tribble(
  ~ch99_code,    ~list,              ~note,
  '9903.88.01',  '1',               20,     # List 1 (25%)
  '9903.88.02',  '2',               20,     # List 2 (25%)
  '9903.88.03',  '3',               20,     # List 3 (25%)
  '9903.88.15',  '4A',              20,     # List 4A (7.5%)
  '9903.91.01',  'biden_25',        31,     # Biden 25%
  '9903.91.02',  'biden_50',        31,     # Biden 50%
  '9903.91.03',  'biden_100',       31,     # Biden 100%
  '9903.91.05',  'biden_50_jan25',  31,     # Biden 50% (Jan 2025)
  '9903.91.06',  'biden_jan26',     31,     # Biden (Jan 2026)
  '9903.91.07',  'biden_jan26',     31,     # Biden (Jan 2026)
  '9903.91.08',  'biden_jan26',     31,     # Biden (Jan 2026)
  '9903.91.11',  'biden_25_jan25',  31,     # Biden 25% (Jan 2025)
)


# =============================================================================
# PDF Download
# =============================================================================

#' Download Chapter 99 PDF from USITC
#'
#' @param dest_dir Directory to save PDF
#' @param force Re-download even if file exists
#' @return Path to downloaded PDF
download_chapter99_pdf <- function(dest_dir = 'data/us_notes', force = FALSE) {
  dest_path <- file.path(dest_dir, 'chapter99.pdf')

  if (file.exists(dest_path) && !force) {
    file_age_days <- as.numeric(difftime(Sys.time(), file.info(dest_path)$mtime, units = 'days'))
    if (file_age_days < 30) {
      message('Using cached PDF (', round(file_age_days, 1), ' days old): ', dest_path)
      return(dest_path)
    }
    message('PDF is ', round(file_age_days, 1), ' days old, re-downloading...')
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  url <- 'https://hts.usitc.gov/reststop/file?release=currentRelease&filename=Chapter+99'
  message('Downloading Chapter 99 PDF from USITC...')
  message('  URL: ', url)

  tryCatch({
    download.file(url, dest_path, mode = 'wb', quiet = FALSE)
    file_size_mb <- file.info(dest_path)$size / (1024 * 1024)
    message('  Downloaded: ', round(file_size_mb, 1), ' MB')

    if (file_size_mb < 0.5) {
      warning('PDF is suspiciously small (', round(file_size_mb, 2), ' MB). May be an error page.')
    }

    return(dest_path)
  }, error = function(e) {
    stop('Failed to download Chapter 99 PDF: ', conditionMessage(e))
  })
}


# =============================================================================
# PDF Text Extraction
# =============================================================================

#' Extract text from Chapter 99 PDF
#'
#' @param pdf_path Path to chapter99.pdf
#' @return Character vector (one element per page)
extract_pdf_text <- function(pdf_path) {
  if (!requireNamespace('pdftools', quietly = TRUE)) {
    stop('pdftools package required. Install with: install.packages("pdftools")')
  }

  message('Extracting text from PDF...')
  pages <- pdftools::pdf_text(pdf_path)
  message('  Pages extracted: ', length(pages))

  return(pages)
}


# =============================================================================
# Anchor-based Product List Extraction
# =============================================================================

#' Find all product list anchors in the PDF
#'
#' Scans for "Heading 9903.XX.XX applies to" patterns, which mark the start
#' of an HTS code enumeration. Returns a table of anchors with page numbers.
#'
#' @param pages Character vector of page texts
#' @return Tibble with ch99_code, page, char_pos columns
find_product_list_anchors <- function(pages) {
  anchors <- tibble(ch99_code = character(), page = integer(), char_pos = integer())

  for (i in seq_along(pages)) {
    # Match "Heading 9903.XX.XX applies to" — the definitive product list start
    matches <- gregexpr('Heading\\s+(9903\\.[0-9]{2}\\.[0-9]{2})\\s+applies\\s+to', pages[i])
    if (matches[[1]][1] != -1) {
      # Extract the ch99 codes from each match
      match_text <- regmatches(pages[i], matches)[[1]]
      codes <- str_extract(match_text, '9903\\.[0-9]{2}\\.[0-9]{2}')
      positions <- as.integer(matches[[1]])

      for (j in seq_along(codes)) {
        anchors <- bind_rows(anchors, tibble(
          ch99_code = codes[j],
          page = i,
          char_pos = positions[j]
        ))
      }
    }
  }

  return(anchors)
}


#' Extract HTS codes from text between two positions
#'
#' Extracts all HTS-format codes (4.2 or 4.2.2-4 digits) from a text span.
#' Filters out Chapter 99 self-references and date-like patterns.
#'
#' @param text Character string to search
#' @return Character vector of HTS codes
extract_hts_codes <- function(text) {
  codes <- str_extract_all(text, '[0-9]{4}\\.[0-9]{2}(?:\\.[0-9]{2,4})?')[[1]]
  codes <- unique(codes)

  # Filter out ch99 self-references
  codes <- codes[!grepl('^99(01|02|03|04)\\.', codes)]
  # Filter out date-like patterns (year.month)
  codes <- codes[!grepl('^(19|20)[0-9]{2}\\.', codes)]
  # Filter out page/section numbers that look like codes
  codes <- codes[nchar(gsub('\\.', '', codes)) >= 6]

  return(codes)
}


#' Extract product list for a specific ch99 heading
#'
#' Given a starting anchor (page + position), extracts HTS codes until the
#' next anchor or note boundary is reached.
#'
#' @param pages Character vector of page texts
#' @param start_page Page where anchor is
#' @param start_pos Character position within start_page
#' @param end_page Page of next anchor (or last page to scan)
#' @param end_pos Character position of next anchor on end_page
#' @return Character vector of HTS codes
extract_product_list <- function(pages, start_page, start_pos, end_page, end_pos) {
  all_codes <- character()

  for (p in start_page:end_page) {
    text <- pages[p]

    if (p == start_page && p == end_page) {
      text <- substring(text, start_pos, end_pos - 1)
    } else if (p == start_page) {
      text <- substring(text, start_pos)
    } else if (p == end_page) {
      text <- substring(text, 1, end_pos - 1)
    }

    codes <- extract_hts_codes(text)
    all_codes <- c(all_codes, codes)
  }

  return(unique(all_codes))
}


# =============================================================================
# HTS Code Normalization
# =============================================================================

#' Normalize parsed HTS codes to 8-digit format
#'
#' Codes from PDF may be 6-digit (heading level) or 8-10 digit (subheading).
#' For consistency with s301_product_lists.csv, normalize to 8 digits.
#'
#' @param codes Character vector of HTS codes with dots
#' @return Character vector of 8-digit HTS codes (no dots)
normalize_to_hts8 <- function(codes) {
  clean <- gsub('\\.', '', codes)
  clean <- str_pad(clean, 8, side = 'right', pad = '0')
  clean <- substr(clean, 1, 8)
  return(clean)
}


# =============================================================================
# Main Pipeline
# =============================================================================

#' Parse US Notes and extract Section 301 product lists
#'
#' @param pdf_path Path to Chapter 99 PDF (or NULL to download)
#' @param existing_csv Path to current s301_product_lists.csv
#' @param output_csv Path to write updated CSV (NULL = same as existing)
#' @param dry_run Report without writing
#' @return Tibble of all products (existing + new)
parse_us_note_products <- function(
  pdf_path = NULL,
  existing_csv = 'resources/s301_product_lists.csv',
  output_csv = NULL,
  dry_run = FALSE
) {
  if (is.null(output_csv)) output_csv <- existing_csv

  message('\n', strrep('=', 70))
  message('US NOTE 301 PRODUCT LIST PARSER')
  message(strrep('=', 70))

  # ---- Download PDF if needed ----
  if (is.null(pdf_path)) {
    pdf_path <- download_chapter99_pdf()
  }
  stopifnot(file.exists(pdf_path))

  # ---- Extract text ----
  pages <- extract_pdf_text(pdf_path)

  # ---- Find all product list anchors ----
  message('\nScanning for product list anchors...')
  anchors <- find_product_list_anchors(pages)
  message('  Found ', nrow(anchors), ' anchor(s)')

  if (nrow(anchors) > 0) {
    message('  Anchors: ', paste(anchors$ch99_code, collapse = ', '))
  }

  # ---- Filter to Section 301 ch99 codes we care about ----
  target_codes <- CH99_TO_LIST$ch99_code
  s301_anchors <- anchors %>%
    filter(ch99_code %in% target_codes) %>%
    arrange(page, char_pos)

  message('  Section 301 anchors: ', nrow(s301_anchors))

  if (nrow(s301_anchors) == 0) {
    message('WARNING: No Section 301 product list anchors found.')
    message('The PDF format may have changed. Check anchor detection.')
    return(invisible(NULL))
  }

  # ---- Extract product lists between consecutive anchors ----
  message('\nExtracting product lists...')
  all_parsed <- tibble(hts_code = character(), ch99_code = character())

  # Sort all anchors (including non-301) for boundary detection
  all_anchors_sorted <- anchors %>% arrange(page, char_pos)

  for (i in seq_len(nrow(s301_anchors))) {
    row <- s301_anchors[i, ]

    # Find the next anchor AFTER this one (from all anchors, not just 301)
    later <- all_anchors_sorted %>%
      filter(page > row$page | (page == row$page & char_pos > row$char_pos))

    if (nrow(later) > 0) {
      next_anchor <- later[1, ]
      end_page <- next_anchor$page
      end_pos <- next_anchor$char_pos
    } else {
      # Last anchor — scan to end of Note area (limit to ~50 pages ahead)
      end_page <- min(row$page + 50, length(pages))
      end_pos <- nchar(pages[end_page])
    }

    codes <- extract_product_list(pages, row$page, row$char_pos, end_page, end_pos)

    if (length(codes) > 0) {
      list_label <- CH99_TO_LIST %>%
        filter(ch99_code == row$ch99_code) %>%
        pull(list) %>%
        first()
      message('  ', row$ch99_code, ' [', list_label, ']: ', length(codes),
              ' HTS codes (pages ', row$page, '-', end_page, ')')
      all_parsed <- bind_rows(all_parsed, tibble(
        hts_code = codes,
        ch99_code = row$ch99_code
      ))
    } else {
      message('  ', row$ch99_code, ': no HTS codes found')
    }
  }

  message('\nTotal HTS codes parsed from US Notes: ', nrow(all_parsed))
  message('  Unique HTS codes: ', n_distinct(all_parsed$hts_code))

  if (nrow(all_parsed) == 0) {
    message('WARNING: No HTS codes parsed. PDF format may have changed.')
    return(invisible(NULL))
  }

  # ---- Normalize to 8-digit format and add list labels ----
  all_parsed <- all_parsed %>%
    left_join(CH99_TO_LIST %>% select(ch99_code, list), by = 'ch99_code') %>%
    mutate(hts8 = normalize_to_hts8(hts_code)) %>%
    select(hts8, list, ch99_code) %>%
    distinct()

  message('After normalization to HTS8: ', nrow(all_parsed), ' unique entries')

  # ---- Cross-reference with existing CSV ----
  message('\nCross-referencing with existing s301_product_lists.csv...')

  if (file.exists(existing_csv)) {
    existing <- read_csv(existing_csv, col_types = cols(
      hts8 = col_character(),
      list = col_character(),
      ch99_code = col_character()
    ))
    message('  Existing entries: ', nrow(existing))

    # Find new entries (not already in existing by hts8 + ch99_code)
    new_entries <- all_parsed %>%
      anti_join(existing, by = c('hts8', 'ch99_code'))

    message('  New entries from US Notes: ', nrow(new_entries))

    if (nrow(new_entries) > 0) {
      message('  Breakdown by list:')
      new_summary <- new_entries %>% count(list, ch99_code) %>% arrange(list)
      for (j in seq_len(nrow(new_summary))) {
        message('    ', new_summary$list[j], ' (', new_summary$ch99_code[j], '): ',
                new_summary$n[j], ' new codes')
      }

      message('  Sample new HTS8 codes:')
      sample_codes <- head(new_entries$hts8, 10)
      message('    ', paste(sample_codes, collapse = ', '))
    }

    # Count overlap (already present)
    overlap <- all_parsed %>%
      semi_join(existing, by = c('hts8', 'ch99_code'))
    message('  Already in existing CSV: ', nrow(overlap))

    # Merge: existing + new
    combined <- bind_rows(existing, new_entries) %>%
      distinct(hts8, ch99_code, .keep_all = TRUE) %>%
      arrange(hts8, ch99_code)

  } else {
    message('  No existing CSV found. Writing all parsed entries.')
    combined <- all_parsed %>%
      arrange(hts8, ch99_code)
    new_entries <- combined
  }

  message('\nFinal product list: ', nrow(combined), ' entries')
  message('  Unique HTS8 codes: ', n_distinct(combined$hts8))
  message('  Lists represented: ', paste(sort(unique(combined$list)), collapse = ', '))

  # ---- Write output ----
  if (!dry_run && nrow(new_entries) > 0) {
    write_csv(combined, output_csv)
    message('\nWrote updated CSV: ', output_csv)
  } else if (dry_run) {
    message('\n[DRY RUN] Would write ', nrow(combined), ' entries to ', output_csv)
  } else {
    message('\nNo new entries found. CSV unchanged.')
  }

  return(invisible(combined))
}


# =============================================================================
# Main Execution
# =============================================================================

if (sys.nframe() == 0) {
  library(here)
  source(here('src', 'helpers.R'))

  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  dry_run <- '--dry-run' %in% args

  result <- parse_us_note_products(dry_run = dry_run)
}
