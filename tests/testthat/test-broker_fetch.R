testthat::test_that("validate_normalized_result enforces required contract", {
  good <- list(
    connector = "world_bank",
    timestamp = "2026-01-01T00:00:00Z",
    query = list(),
    data = list(),
    units = NULL,
    dimensions = list(temporal = list(), spatial = list())
  )

  validated <- validate_normalized_result(good, "world_bank")
  testthat::expect_equal(validated$connector, "world_bank")

  bad <- good
  bad$schema_version <- "0.1.0"
  testthat::expect_error(
    validate_normalized_result(bad, "world_bank"),
    "must not set schema_version"
  )
})

testthat::test_that("broker_fetch routes world bank and injects schema version", {
  calls <- list(validate = FALSE, fetch = FALSE, normalize = FALSE)

  req <- list(
    source = "world_bank",
    params = list(country = "GBR"),
    output = list(format = "json", file = "")
  )

  out <- with_temp_bindings(
    list(
      validate_world_bank_params = function(params) {
        calls$validate <<- TRUE
        invisible(TRUE)
      },
      fetch_world_bank = function(params) {
        calls$fetch <<- TRUE
        list(raw = TRUE)
      },
      normalize_world_bank_result = function(raw_result, params) {
        calls$normalize <<- TRUE
        list(
          connector = "world_bank",
          timestamp = "2026-01-01T00:00:00Z",
          query = list(),
          data = list(),
          units = NULL,
          dimensions = list(temporal = list(), spatial = list())
        )
      }
    ),
    broker_fetch(req, schema_version = "1.2.3")
  )

  testthat::expect_true(calls$validate)
  testthat::expect_true(calls$fetch)
  testthat::expect_true(calls$normalize)
  testthat::expect_equal(out$schema_version, "1.2.3")
})

testthat::test_that("broker_fetch routes renewables and injects schema version", {
  req <- list(
    source = "renewables_ninja",
    params = list(technology = "wind"),
    output = list(format = "json", file = "")
  )

  out <- with_temp_bindings(
    list(
      validate_renewables_ninja_params = function(params) invisible(TRUE),
      get_renewables_ninja_token = function(secrets_path) "TOKEN",
      fetch_renewables_ninja = function(params, token) list(raw = TRUE),
      normalize_renewables_ninja_result = function(raw_result, params) {
        list(
          connector = "renewables_ninja",
          timestamp = "2026-01-01T00:00:00Z",
          query = list(),
          data = list(),
          units = NULL,
          dimensions = list(temporal = list(), spatial = list())
        )
      }
    ),
    broker_fetch(req, schema_version = "9.9.9")
  )
  testthat::expect_equal(out$connector, "renewables_ninja")
  testthat::expect_equal(out$schema_version, "9.9.9")
})
