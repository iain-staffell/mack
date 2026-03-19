testthat::test_that("validate_eurostat_params validates required fields", {
  params <- list(
    dataset_code = "nrg_pc_204",
    filters = list(
      geo = c("DE", "FR"),
      time = c("2024-S1", "2024-S2")
    ),
    aggregate_time = "annual_mean"
  )

  testthat::expect_invisible(validate_eurostat_params(params))
  testthat::expect_error(
    validate_eurostat_params(within(params, dataset_code <- "nrg-pc-204")),
    "letters, numbers, and underscores"
  )
  bad_filters <- params
  bad_filters$filters <- list("DE")
  names(bad_filters$filters) <- ""
  testthat::expect_error(
    validate_eurostat_params(bad_filters),
    "non-empty names"
  )
  testthat::expect_error(
    validate_eurostat_params(within(params, aggregate_time <- "sum")),
    "annual_mean"
  )
})

testthat::test_that("normalize_eurostat_query_params applies defaults", {
  out <- normalize_eurostat_query_params(list(
    dataset_code = "nrg_pc_204",
    filters = list(geo = "DE")
  ))

  testthat::expect_equal(out$lang, "EN")
  testthat::expect_null(out$aggregate_time)
})

testthat::test_that("build_eurostat_request builds full url with repeated filters", {
  req <- build_eurostat_request(list(
    dataset_code = "nrg_pc_204",
    filters = list(
      geo = c("DE", "FR"),
      time = c("2024-S1", "2024-S2"),
      tax = "I_TAX"
    ),
    lang = "en"
  ))

  testthat::expect_true(grepl("/nrg_pc_204\\?", req$full_url))
  testthat::expect_match(req$full_url, "lang=EN")
  testthat::expect_match(req$full_url, "geo=DE")
  testthat::expect_match(req$full_url, "geo=FR")
  testthat::expect_match(req$full_url, "time=2024-S1")
  testthat::expect_match(req$full_url, "time=2024-S2")
  testthat::expect_match(req$full_url, "tax=I_TAX")
})

testthat::test_that("decode_eurostat_index decodes flattened positions", {
  coords <- decode_eurostat_index(5, c(1, 1, 2, 1, 3, 1))
  testthat::expect_equal(coords, c(0, 0, 1, 0, 2, 0))
})

testthat::test_that("parse_eurostat_payload parses sparse JSON-stat response", {
  payload <- list(
    label = "Example dataset",
    updated = "2026-03-11T23:00:00+0100",
    source = "ESTAT",
    id = c("freq", "geo", "time"),
    size = c(1, 2, 2),
    dimension = list(
      freq = list(
        label = "Frequency",
        category = list(
          index = list(S = 0),
          label = list(S = "Semesterly")
        )
      ),
      geo = list(
        label = "Country",
        category = list(
          index = list(DE = 0, FR = 1),
          label = list(DE = "Germany", FR = "France")
        )
      ),
      time = list(
        label = "Time",
        category = list(
          index = list("2024-S1" = 0, "2024-S2" = 1),
          label = list("2024-S1" = "2024-S1", "2024-S2" = "2024-S2")
        )
      )
    ),
    value = c("0" = 1.1, "1" = 1.2, "2" = 2.1, "3" = 2.2)
  )

  parsed <- parse_eurostat_payload(payload)

  testthat::expect_equal(parsed$label, "Example dataset")
  testthat::expect_equal(length(parsed$rows), 4)
  testthat::expect_equal(parsed$rows[[1]]$geo, "DE")
  testthat::expect_equal(parsed$rows[[1]]$time, "2024-S1")
  testthat::expect_equal(parsed$rows[[4]]$geo, "FR")
  testthat::expect_equal(parsed$rows[[4]]$time, "2024-S2")
  testthat::expect_equal(parsed$rows[[4]]$value, 2.2)
})

testthat::test_that("aggregate_eurostat_rows_by_year averages by non-time dimensions", {
  rows <- list(
    list(geo = "DE", unit = "KWH", time = "2024-S1", value = 10),
    list(geo = "DE", unit = "KWH", time = "2024-S2", value = 14),
    list(geo = "FR", unit = "KWH", time = "2024-S1", value = 20),
    list(geo = "FR", unit = "KWH", time = "2024-S2", value = 24)
  )

  out <- aggregate_eurostat_rows_by_year(rows)

  testthat::expect_equal(length(out$rows), 2)
  testthat::expect_equal(out$rows[[1]]$year, "2024")
  testthat::expect_equal(out$rows[[1]]$period_count, 2)
  testthat::expect_equal(out$rows[[1]]$value, 12)
  testthat::expect_equal(out$rows[[2]]$value, 22)
  testthat::expect_true(length(out$warnings) >= 1)
})

testthat::test_that("extract_eurostat_units returns unit labels", {
  dims <- list(
    unit = list(
      label = "Unit",
      codes = c("KWH", "GJ_GCV"),
      labels = list(KWH = "Kilowatt-hour", GJ_GCV = "Gigajoule (gross calorific value - GCV)")
    )
  )

  out <- extract_eurostat_units(dims)
  testthat::expect_equal(out$KWH, "Kilowatt-hour")
  testthat::expect_equal(out$GJ_GCV, "Gigajoule (gross calorific value - GCV)")
})

testthat::test_that("fetch_eurostat builds request and parses payload", {
  params <- list(
    dataset_code = "nrg_pc_204",
    filters = list(geo = "DE", time = "2024-S1")
  )
  called_url <- NULL

  out <- with_temp_bindings(
    list(
      eurostat_http_get = function(url) {
        called_url <<- url
        list(
          status_code = 200L,
          body = list(
            label = "Example dataset",
            updated = "2026-03-11T23:00:00+0100",
            source = "ESTAT",
            id = c("geo", "time"),
            size = c(1, 1),
            dimension = list(
              geo = list(
                label = "Country",
                category = list(index = list(DE = 0), label = list(DE = "Germany"))
              ),
              time = list(
                label = "Time",
                category = list(index = list("2024-S1" = 0), label = list("2024-S1" = "2024-S1"))
              )
            ),
            value = c("0" = 1.23)
          )
        )
      }
    ),
    fetch_eurostat(params)
  )

  testthat::expect_match(called_url, "nrg_pc_204")
  testthat::expect_equal(out$parsed$rows[[1]]$geo, "DE")
  testthat::expect_equal(out$parsed$rows[[1]]$value, 1.23)
})

testthat::test_that("normalize_eurostat_result builds standard annualized output", {
  params <- list(
    dataset_code = "nrg_pc_204",
    filters = list(geo = c("DE", "FR"), time = c("2024-S1", "2024-S2")),
    aggregate_time = "annual_mean"
  )
  raw <- list(
    request = list(
      url = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_204",
      full_url = "https://example.test",
      query = list(lang = "EN", filters = params$filters)
    ),
    parsed = list(
      label = "Example dataset",
      updated = "2026-03-11T23:00:00+0100",
      source = "ESTAT",
      annotations = list(list(type = "OBS_COUNT", title = "4")),
      dimension_metadata = list(
        freq = list(label = "Frequency", codes = "S", labels = list(S = "Semesterly")),
        geo = list(label = "Country", codes = c("DE", "FR"), labels = list(DE = "Germany", FR = "France")),
        unit = list(label = "Unit", codes = "KWH", labels = list(KWH = "Kilowatt-hour"))
      ),
      rows = list(
        list(freq = "S", geo = "DE", unit = "KWH", time = "2024-S1", value = 10),
        list(freq = "S", geo = "DE", unit = "KWH", time = "2024-S2", value = 14),
        list(freq = "S", geo = "FR", unit = "KWH", time = "2024-S1", value = 20),
        list(freq = "S", geo = "FR", unit = "KWH", time = "2024-S2", value = 24)
      )
    )
  )

  out <- normalize_eurostat_result(raw, params)

  testthat::expect_equal(out$connector, "eurostat")
  testthat::expect_false("schema_version" %in% names(out))
  testthat::expect_equal(length(out$data), 2)
  testthat::expect_equal(out$data[[1]]$year, "2024")
  testthat::expect_equal(out$data[[1]]$value, 12)
  testthat::expect_equal(out$dimensions$temporal$resolution, "annual")
  testthat::expect_equal(out$units, "Kilowatt-hour")
  testthat::expect_true(length(out$warnings) >= 1)
})

testthat::test_that("eurostat_http_get handles httr2 wrappers and errors", {
  testthat::local_mocked_bindings(
    request = function(url) list(url = url),
    req_error = function(req, is_error) req,
    req_perform = function(req) list(req = req),
    resp_status = function(resp) 200L,
    resp_body_json = function(resp, simplifyVector = FALSE) list(id = c("geo"), size = c(1), dimension = list(), value = c("0" = 1)),
    .package = "httr2"
  )

  out <- eurostat_http_get("https://example")
  testthat::expect_equal(out$status_code, 200)
  testthat::expect_true(is.list(out$body))
})
