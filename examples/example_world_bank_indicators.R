# example_world_bank.R
#
# Runnable World Bank example:
# - loads broker runtime through main.R
# - executes run_mack()
# - writes output to outputs/

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Please run install.packages('here').", call. = FALSE)
}

suppressMessages(here::i_am("examples/example_world_bank_indicators.R"))
source(here::here("main.R"))

request <- list(
  source = "world_bank",
  params = list(
    country = "GBR",
    indicator = "NY.GDP.MKTP.KD",
    years = c(1960, 2024)
  ),
  output = list(
    format = "yaml",
    file = here::here("outputs", "example_world_bank_gdp.yaml")
  )
)

result <- run_mack(request)
cat("World Bank example completed.\n")
cat("Rows returned:", length(result$data), "\n")
cat("Output file:", request$output$file, "\n")


### NOT RUN
#
# # Demonstrate plotting the results
# plot(
#   sapply(result$data, function(x) { x$year }),
#   sapply(result$data, function(x) { x$value / 1e9 }),
#   xlab='Year', ylab='GDP (£bn)',
#   type='l'
# )
