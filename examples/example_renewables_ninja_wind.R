# example_renewables_ninja.R
#
# Runnable Renewables.ninja wind example:
# - loads broker runtime through main.R
# - checks for secrets file
# - executes run_mack()

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Install with install.packages('here').", call. = FALSE)
}

suppressMessages(here::i_am("examples/example_renewables_ninja_wind.R"))
source(here::here("main.R"))

secrets_path <- here::here("config", "secrets.yaml")
if (!file.exists(secrets_path)) {
  stop(
    "Missing secrets file: ", secrets_path,
    "\nCreate it from config/secrets_template.yaml before running this example.",
    call. = FALSE
  )
}

request <- list(
  source = "renewables_ninja",
  params = list(
    technology = "wind",
    sites = list(
      list(lat = 52.1, lon = -1.5),
      list(lat = 53.2, lon = -2.0)
    ),
    capacity = c(100, 150),
    date_from = "2015-01-01",
    date_to = "2015-12-31",
    dataset = "merra2",
    interpolate = TRUE,
    sum_sites = TRUE
  ),
  output = list(
    format = "json",
    file = here::here("outputs", "example_ninja_wind_sum.json")
  )
)

result <- run_mack(request, secrets_path = secrets_path)
cat("Renewables.ninja wind example completed.\n")
cat("Rows returned:", length(result$data$value), "\n")
cat("Output file:", request$output$file, "\n")


### NOT RUN
#
# # Demonstrate plotting the results
# plot(
#   lubridate::ymd_hms(unlist(result$data$timestamp)),
#   unlist(result$data$value),
#   type='l'
# )
