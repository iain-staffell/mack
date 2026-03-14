testthat::test_that("read_request_file reads wrapped and unwrapped request files", {
  wrapped <- tempfile(fileext = ".yaml")
  json_file <- tempfile(fileext = ".json")
  no_output <- tempfile(fileext = ".yaml")

  writeLines(
    c(
      "request:",
      "  source: world_bank",
      "  params:",
      "    country: GBR",
      "    indicator:",
      "      - EG.USE.ELEC.KH",
      "    years:",
      "      - 2000",
      "      - 2020",
      "  output:",
      "    format: json"
    ),
    wrapped
  )

  jsonlite::write_json(
    list(
      source = "world_bank",
      params = list(country = "GBR", indicator = list("EG.USE.ELEC.KH"), years = list(2000, 2020)),
      output = list(format = "yaml")
    ),
    path = json_file,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  writeLines(
    c(
      "source: world_bank",
      "params:",
      "  country: GBR",
      "  indicator: NY.GDP.MKTP.KD"
    ),
    no_output
  )

  wrapped_request <- read_request_file(wrapped)
  json_request <- read_request_file(json_file)
  no_output_request <- read_request_file(no_output)

  testthat::expect_equal(wrapped_request$source, "world_bank")
  testthat::expect_equal(json_request$output$format, "yaml")
  testthat::expect_null(no_output_request$output)
})

testthat::test_that("read_request_file errors for malformed files", {
  malformed <- tempfile(fileext = ".yaml")
  writeLines(c("source: world_bank"), malformed)

  testthat::expect_error(
    read_request_file(malformed),
    "missing required fields"
  )
})

testthat::test_that("read_request_file gives helpful message for malformed JSON", {
  bad_json <- tempfile(fileext = ".json")
  writeLines(
    c(
      "\"request\": {",
      "  \"source\": \"world_bank\"",
      "}"
    ),
    bad_json
  )

  testthat::expect_error(
    read_request_file(bad_json),
    "outer object wrapper"
  )
})

testthat::test_that("read_secrets reads yaml and handles empty files", {
  populated <- tempfile(fileext = ".yaml")
  empty <- tempfile(fileext = ".yaml")

  writeLines(c("renewables_ninja:", "  token: ABC123"), populated)
  writeLines(character(0), empty)

  parsed <- read_secrets(populated)
  parsed_empty <- read_secrets(empty)

  testthat::expect_equal(parsed$renewables_ninja$token, "ABC123")
  testthat::expect_equal(parsed_empty, list())
})

testthat::test_that("utc_timestamp_iso8601 formats UTC timestamp correctly", {
  ts <- as.POSIXct("2020-01-02 03:04:05", tz = "UTC")
  out <- utc_timestamp_iso8601(ts)

  testthat::expect_equal(out, "2020-01-02T03:04:05Z")
})

testthat::test_that("build_standard_output builds required fields and optionals", {
  out <- build_standard_output(
    connector = "world_bank",
    query = list(country = "GBR"),
    data = list(list(value = 1)),
    units = "kWh",
    dimensions = list(temporal = list(), spatial = list()),
    warnings = "partial data",
    source_metadata = list(source = "wb")
  )

  testthat::expect_equal(out$connector, "world_bank")
  testthat::expect_true("timestamp" %in% names(out))
  testthat::expect_true("warnings" %in% names(out))
  testthat::expect_false("schema_version" %in% names(out))
})

testthat::test_that("build_standard_output validates dimensions", {
  testthat::expect_error(
    build_standard_output(
      connector = "x",
      query = list(),
      data = list(),
      units = NULL,
      dimensions = list(temporal = list())
    ),
    "temporal.*spatial"
  )
})

testthat::test_that("stop_with_connector_error includes connector and status code", {
  testthat::expect_error(
    stop_with_connector_error("world_bank", "failure", status_code = 500),
    "\\[world_bank\\] HTTP 500: failure"
  )
})
