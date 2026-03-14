testthat::test_that("validate_renewables_ninja_params validates supported shapes", {
  params <- list(
    technology = "wind",
    sites = list(list(lat = 52.1, lon = -1.5), list(lat = 53.2, lon = -2.0)),
    capacity = c(100, 150),
    date_from = "2015-01-01",
    date_to = "2015-01-02",
    sum_sites = TRUE
  )

  testthat::expect_invisible(validate_renewables_ninja_params(params))
  testthat::expect_error(
    validate_renewables_ninja_params(within(params, technology <- "hydro")),
    "must be either 'wind' or 'solar'"
  )
  testthat::expect_error(
    validate_renewables_ninja_params(within(params, capacity <- c(1, 2, 3))),
    "length 1 or match number of sites"
  )
})

testthat::test_that("get_renewables_ninja_token reads token and rejects placeholder", {
  good <- tempfile(fileext = ".yaml")
  bad <- tempfile(fileext = ".yaml")
  writeLines(c("renewables_ninja:", "  token: ABC"), good)
  writeLines(c("renewables_ninja:", "  token: YOUR_TOKEN_HERE"), bad)

  testthat::expect_equal(get_renewables_ninja_token(good), "ABC")
  testthat::expect_error(
    get_renewables_ninja_token(bad),
    "Replace placeholder"
  )
})

testthat::test_that("build_renewables_ninja_site_request builds endpoint and defaults", {
  params <- list(
    technology = "solar",
    sites = list(list(lat = 52.1, lon = -1.5)),
    capacity = 100,
    date_from = "2015-01-01",
    date_to = "2015-01-02"
  )
  req <- build_renewables_ninja_site_request(params, params$sites[[1]], 100)

  testthat::expect_true(grepl("/api/data/pv$", req$url))
  testthat::expect_equal(req$query$lat, 52.1)
  testthat::expect_equal(req$query$interpolate, TRUE)
  testthat::expect_equal(req$query$format, "json")
  testthat::expect_equal(req$query$system_loss, 0.1)
  testthat::expect_equal(req$query$tilt, 35)
  testthat::expect_equal(req$query$azim, 180)
})

testthat::test_that("parse_renewables_ninja_payload parses JSON and CSV shapes", {
  json_payload <- list(
    content_type = "application/json",
    body = '{"data":{"2015-01-01 00:00:00":1.5,"2015-01-01 01:00:00":2.5},"metadata":{"units":"kW"}}'
  )
  csv_payload <- list(
    content_type = "text/csv",
    body = paste(
      "# Some header",
      "# {\"units\":{\"time\":\"UTC\",\"electricity\":\"kW\"}}",
      "time,electricity",
      "2015-01-01 00:00,1.5",
      "2015-01-01 01:00,2.5",
      sep = "\n"
    )
  )

  parsed_json <- parse_renewables_ninja_payload(json_payload)
  parsed_csv <- parse_renewables_ninja_payload(csv_payload)

  testthat::expect_equal(length(parsed_json$series), 2)
  testthat::expect_equal(parsed_json$units, "kW")
  testthat::expect_equal(parsed_csv$series[[1]]$timestamp, "2015-01-01 00:00:00")
  testthat::expect_equal(parsed_csv$units, "kW")
})

testthat::test_that("parse_renewables_ninja_payload converts epoch timestamps to UTC text", {
  payload <- list(
    content_type = "application/json",
    body = '{"data":{"1420070400000":1.5,"1420074000000":2.5},"metadata":{"units":"kW"}}'
  )

  parsed <- parse_renewables_ninja_payload(payload)
  testthat::expect_equal(parsed$series[[1]]$timestamp, "2015-01-01 00:00:00")
  testthat::expect_equal(parsed$series[[2]]$timestamp, "2015-01-01 01:00:00")
})

testthat::test_that("sum_renewables_ninja_site_series aggregates by timestamp", {
  site_series <- list(
    list(
      list(timestamp = "2015-01-01 00:00:00", value = 1),
      list(timestamp = "2015-01-01 01:00:00", value = 2)
    ),
    list(
      list(timestamp = "2015-01-01 00:00:00", value = 3),
      list(timestamp = "2015-01-01 01:00:00", value = NA_real_)
    )
  )

  out <- sum_renewables_ninja_site_series(site_series)
  testthat::expect_equal(out[[1]]$value, 4)
  testthat::expect_true(is.na(out[[2]]$value))
})

testthat::test_that("normalize_renewables_ninja_query_params applies defaults", {
  params <- list(
    technology = "wind",
    sites = list(list(lat = 1, lon = 1), list(lat = 2, lon = 2)),
    capacity = 100,
    date_from = "2015-01-01",
    date_to = "2015-01-02"
  )
  out <- normalize_renewables_ninja_query_params(params)

  testthat::expect_equal(length(out$capacity), 2)
  testthat::expect_equal(out$sum_sites, FALSE)
  testthat::expect_equal(out$interpolate, TRUE)
  testthat::expect_equal(out$height, 100)
  testthat::expect_equal(out$turbine, "Vestas V80 2000")

  solar <- normalize_renewables_ninja_query_params(within(params, technology <- "solar"))
  testthat::expect_equal(solar$system_loss, 0.1)
  testthat::expect_equal(solar$tilt, 35)
  testthat::expect_equal(solar$azim, 180)
  testthat::expect_equal(solar$raw, FALSE)
})

testthat::test_that("normalize_renewables_ninja_timestamp handles epoch and text", {
  testthat::expect_equal(
    normalize_renewables_ninja_timestamp("1420070400000"),
    "2015-01-01 00:00:00"
  )
  testthat::expect_equal(
    normalize_renewables_ninja_timestamp("2015-01-01 00:00:00"),
    "2015-01-01 00:00:00"
  )
})

testthat::test_that("fetch_renewables_ninja calls one API request per site", {
  params <- list(
    technology = "wind",
    sites = list(list(lat = 52.1, lon = -1.5), list(lat = 53.2, lon = -2.0)),
    capacity = c(100, 150),
    date_from = "2015-01-01",
    date_to = "2015-01-02",
    sum_sites = TRUE
  )
  calls <- 0L

  raw <- with_temp_bindings(
    list(
      renewables_ninja_http_get = function(url, query, token) {
        calls <<- calls + 1L
        list(
          status_code = 200,
          content_type = "application/json",
          body = '{"data":{"2015-01-01 00:00:00":1.0,"2015-01-01 01:00:00":2.0},"metadata":{"units":"kW"}}'
        )
      }
    ),
    fetch_renewables_ninja(params, token = "TOKEN")
  )
  testthat::expect_equal(calls, 2L)
  testthat::expect_equal(length(raw$sites), 2)
})

testthat::test_that("normalize_renewables_ninja_result builds summed and unsummed data", {
  params_sum <- list(
    technology = "wind",
    sites = list(list(lat = 52.1, lon = -1.5), list(lat = 53.2, lon = -2.0)),
    capacity = c(100, 150),
    date_from = "2015-01-01",
    date_to = "2015-01-02",
    sum_sites = TRUE
  )
  params_unsum <- params_sum
  params_unsum$sum_sites <- FALSE

  raw <- list(
    query = list(params = normalize_renewables_ninja_query_params(params_sum)),
    sites = list(
      list(
        site_id = 1,
        site = list(lat = 52.1, lon = -1.5),
        request = list(url = "u1", query = list()),
        parsed = list(
          series = list(
            list(timestamp = "2015-01-01 00:00:00", value = 1),
            list(timestamp = "2015-01-01 01:00:00", value = 2)
          ),
          metadata = list(),
          units = "kW"
        )
      ),
      list(
        site_id = 2,
        site = list(lat = 53.2, lon = -2.0),
        request = list(url = "u2", query = list()),
        parsed = list(
          series = list(
            list(timestamp = "2015-01-01 00:00:00", value = 3),
            list(timestamp = "2015-01-01 01:00:00", value = 4)
          ),
          metadata = list(),
          units = "kW"
        )
      )
    )
  )

  summed <- normalize_renewables_ninja_result(raw, params_sum)
  unsummed <- normalize_renewables_ninja_result(raw, params_unsum)

  testthat::expect_equal(names(summed$data), c("timestamp", "value"))
  testthat::expect_equal(length(summed$data$timestamp), 2)
  testthat::expect_equal(summed$data$timestamp[[1]], "2015-01-01 00:00:00")
  testthat::expect_equal(summed$data$value[[1]], 4)

  testthat::expect_equal(names(unsummed$data), c("site_id", "lat", "lon", "timestamp", "value"))
  testthat::expect_equal(length(unsummed$data$timestamp), 4)
  testthat::expect_equal(unsummed$data$site_id[[1]], 1)
  testthat::expect_equal(unsummed$data$value[[4]], 4)
})

testthat::test_that("renewables_ninja_records_to_columns reshapes records", {
  records <- list(
    list(timestamp = "t1", value = 1),
    list(timestamp = "t2", value = 2)
  )

  out <- renewables_ninja_records_to_columns(records, c("timestamp", "value"))
  testthat::expect_equal(names(out), c("timestamp", "value"))
  testthat::expect_equal(out$timestamp[[2]], "t2")
  testthat::expect_equal(out$value[[1]], 1)
})

testthat::test_that("renewables_ninja_http_get handles httr2 wrappers", {
  testthat::local_mocked_bindings(
    request = function(url) list(url = url),
    req_url_query = function(req, ...) {
      req$query <- list(...)
      req
    },
    req_headers = function(req, ...) {
      req$headers <- list(...)
      req
    },
    req_error = function(req, is_error) req,
    req_perform = function(req) list(req = req),
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) "{\"data\":{\"a\":1}}",
    resp_header = function(resp, name) "application/json",
    .package = "httr2"
  )

  out <- renewables_ninja_http_get("https://example", list(a = 1), "TOKEN")
  testthat::expect_equal(out$status_code, 200)
  testthat::expect_true(grepl("json", tolower(out$content_type)))
})
