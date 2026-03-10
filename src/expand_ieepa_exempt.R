#!/usr/bin/env Rscript
# =============================================================================
# Expand IEEPA Exempt Products
# =============================================================================
# Three fixes:
#   1. Expand all existing HTS8 prefixes to full HTS10 codes using HTS JSON
#   2. Add Ch98 exempt codes (US Notes (v)(i) exempts Ch98 except 9802.00.40/50/60/80)
#   3. Expand ITA prefix entries (8471, 8473.30, 8486, 8523, 8524, 8541, 8542)
# =============================================================================

library(tidyverse)
library(here)

cat("=== Expanding IEEPA Exempt Products ===\n\n")

# --- Load current exempt list ---
exempt_file <- here('resources', 'ieepa_exempt_products.csv')
current <- read_csv(exempt_file, col_types = cols(hts10 = col_character()))
cat("Current exempt products:", nrow(current), "\n")

# --- Load all HTS10 codes from parsed products RDS (memory-efficient) ---
# Load one at a time, extract hts10, then discard
rds_files <- c(
  here('data', 'processed', 'products_rev_32.rds'),
  here('data', 'timeseries', 'products_2026_rev_4.rds')
)

all_hts10 <- character()
for (f in rds_files) {
  if (file.exists(f)) {
    prods <- readRDS(f)
    cat("  Loaded", nrow(prods), "products from", basename(f), "\n")
    all_hts10 <- c(all_hts10, prods$hts10)
    rm(prods); gc(verbose = FALSE)
  }
}
all_hts10 <- unique(all_hts10)
cat("Total unique HTS10 codes:", length(all_hts10), "\n\n")

# --- Fix 1: Expand existing HTS8 prefixes to full HTS10 ---
current_hts8 <- unique(substr(current$hts10, 1, 8))
cat("Unique HTS8 prefixes in current list:", length(current_hts8), "\n")

expanded_from_existing <- all_hts10[substr(all_hts10, 1, 8) %in% current_hts8]
new_from_expansion <- setdiff(expanded_from_existing, current$hts10)
cat("Fix 1 - HTS8->HTS10 expansion: +", length(new_from_expansion), "codes\n")

# --- Fix 2: Add Ch98 codes ---
# US Notes subdivision (v)(i) explicitly exempts Ch98 from IEEPA,
# except 9802.00.40, 9802.00.50, 9802.00.60, 9802.00.80
ch98_excluded_hts8 <- c("98020040", "98020050", "98020060", "98020080")
ch98_all <- all_hts10[substr(all_hts10, 1, 2) == "98"]
ch98_exempt <- ch98_all[!substr(ch98_all, 1, 8) %in% ch98_excluded_hts8]
new_ch98 <- setdiff(ch98_exempt, current$hts10)
cat("Fix 2 - Ch98 statutory exemption: +", length(new_ch98), "codes",
    "(of", length(ch98_exempt), "total Ch98 exempt)\n")

# --- Fix 3: Expand ITA prefix entries ---
# US Notes page 183 subdivision (v)(iii) lists these broad ITA prefixes as exempt
ita_prefixes <- c("8471", "847330", "8486", "8523", "8524", "8541", "8542")
ita_matches <- character()
for (prefix in ita_prefixes) {
  matches <- all_hts10[substr(all_hts10, 1, nchar(prefix)) == prefix]
  cat("  ITA prefix", prefix, ":", length(matches), "products\n")
  ita_matches <- c(ita_matches, matches)
}
ita_matches <- unique(ita_matches)
new_ita <- setdiff(ita_matches, c(current$hts10, expanded_from_existing, ch98_exempt))
cat("Fix 3 - ITA prefix expansion: +", length(new_ita), "codes\n")

# --- Combine all ---
all_exempt <- sort(unique(c(current$hts10, new_from_expansion, new_ch98, new_ita)))
cat("\nTotal after all fixes:", length(all_exempt),
    "(was", nrow(current), ", +", length(all_exempt) - nrow(current), ")\n")

# --- Write back ---
write_csv(tibble(hts10 = all_exempt), exempt_file)
cat("Written to:", exempt_file, "\n")

cat("\n=== Done ===\n")
