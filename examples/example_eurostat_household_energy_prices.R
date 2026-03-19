# example_eurostat_household_energy_prices.R
#
# Runnable Eurostat example:
# - loads broker runtime through main.R
# - fetches annual average household electricity and gas prices
# - returns both datasets across all reported countries for 2017 to 2024

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Please run install.packages('here').", call. = FALSE)
}

suppressMessages(here::i_am("examples/example_eurostat_household_energy_prices.R"))
source(here::here("main.R"))

years <- 2017:2024
semester_periods <- unlist(
  lapply(years, function(year) paste0(year, c("-S1", "-S2"))),
  use.names = FALSE
)

common_filters <- list(
  currency = "EUR",
  tax = "I_TAX",
  time = semester_periods
)

electricity_request <- list(
  source = "eurostat",
  params = list(
    dataset_code = "nrg_pc_204",
    filters = c(
      list(
        siec = "E7000",
        nrg_cons = "TOT_KWH",
        unit = "KWH"
      ),
      common_filters
    ),
    aggregate_time = "annual_mean"
  ),
  output = list(
    format = "yaml",
    file = here::here("outputs", "example_eurostat_household_electricity_prices.yaml")
  )
)

gas_request <- list(
  source = "eurostat",
  params = list(
    dataset_code = "nrg_pc_202",
    filters = c(
      list(
        siec = "G3000",
        nrg_cons = "TOT_GJ",
        unit = "KWH"
      ),
      common_filters
    ),
    aggregate_time = "annual_mean"
  ),
  output = list(
    format = "yaml",
    file = here::here("outputs", "example_eurostat_household_gas_prices.yaml")
  )
)

electricity_result <- run_mack(electricity_request)
gas_result <- run_mack(gas_request)

household_energy_prices <- list(
  electricity = electricity_result$data,
  gas = gas_result$data
)

cat("Eurostat household energy price example completed.\n")
cat("Electricity rows returned:", length(electricity_result$data), "\n")
cat("Gas rows returned:", length(gas_result$data), "\n")
cat("Electricity output file:", electricity_request$output$file, "\n")
cat("Gas output file:", gas_request$output$file, "\n")
