# example_renewables_ninja_solar.R
#
# Runnable Renewables.ninja solar PV example:
# - loads broker runtime through main.R
# - checks for secrets file
# - executes run_mack()

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required. Install with install.packages('here').", call. = FALSE)
}

suppressMessages(here::i_am("examples/example_renewables_ninja_solar.R"))
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
    technology = "solar",
    sites = list(
      list(lat = 45.0, lon = 22.0)
    ),
    capacity = 1,
    date_from = "2014-01-01",
    date_to = "2014-01-31",
    dataset = "merra2",
    tracking = 0,
    format = "csv",
    sum_sites = TRUE
    # Defaults applied automatically if omitted:
    # system_loss = 0.1
    # tilt = 35
    # azim = 180
  ),
  output = list(
    format = "json",
    file = here::here("outputs", "example_ninja_solar.json")
  )
)

result <- run_mack(request, secrets_path = secrets_path)
cat("Renewables.ninja solar PV example completed.\n")
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
