testthat::test_that("validate_world_bank_params validates required fields", {
  params <- list(
    country = "GBR",
    indicator = c("EG.USE.ELEC.KH", "NY.GDP.MKTP.KD"),
    years = c(2000, 2020)
  )

  testthat::expect_invisible(validate_world_bank_params(params))
  testthat::expect_error(
    validate_world_bank_params(within(params, country <- "GB")),
    "ISO3"
  )
  testthat::expect_error(
    validate_world_bank_params(within(params, years <- c(2020, 2000))),
    "start must be <="
  )
})

testthat::test_that("build_world_bank_request creates url and query", {
  params <- list(country = "gbr", indicator = c("A", "B"), years = c(2000, 2020))
  req <- build_world_bank_request(params, page = 2, per_page = 500)

  testthat::expect_true(grepl("/country/GBR/indicator/A;B$", req$url))
  testthat::expect_equal(req$query$date, "2000:2020")
  testthat::expect_equal(req$query$page, 2)
  testthat::expect_equal(req$query$per_page, 500)
})

testthat::test_that("parse_world_bank_payload parses metadata and rows", {
  payload <- list(
    list(page = "1", pages = "3", per_page = "50", total = "120"),
    list(list(countryiso3code = "GBR"))
  )

  parsed <- parse_world_bank_payload(payload)

  testthat::expect_equal(parsed$metadata$page, 1)
  testthat::expect_equal(parsed$metadata$pages, 3)
  testthat::expect_equal(length(parsed$rows), 1)
})

testthat::test_that("parse_world_bank_payload surfaces API message errors clearly", {
  payload <- list(
    list(
      message = list(
        list(id = "175", key = "Invalid format", value = "The indicator was not found.")
      )
    )
  )

  testthat::expect_error(
    parse_world_bank_payload(payload),
    "\\[world_bank\\].*indicator was not found"
  )
})

testthat::test_that("extract_world_bank_units returns scalar or list", {
  parsed_single <- list(
    rows = list(
      list(indicator = list(id = "A"), unit = "kWh")
    )
  )
  parsed_multi <- list(
    rows = list(
      list(indicator = list(id = "A"), unit = "kWh"),
      list(indicator = list(id = "B"), unit = "USD")
    )
  )

  testthat::expect_equal(extract_world_bank_units(parsed_single), "kWh")
  units <- extract_world_bank_units(parsed_multi)
  testthat::expect_equal(units$A, "kWh")
  testthat::expect_equal(units$B, "USD")
})

testthat::test_that("fetch_world_bank paginates and combines rows", {
  params <- list(country = "GBR", indicator = "A", years = c(2000, 2001), per_page = 1)
  pages_called <- integer(0)

  out <- with_temp_bindings(
    list(
      world_bank_http_get = function(url, query) {
        pages_called <<- c(pages_called, query$page)
        if (query$page == 1) {
          return(list(
            status_code = 200,
            body = list(
              list(page = 1, pages = 2, per_page = 1, total = 2),
              list(list(countryiso3code = "GBR", indicator = list(id = "A"), date = "2001", value = 2))
            )
          ))
        }
        list(
          status_code = 200,
          body = list(
            list(page = 2, pages = 2, per_page = 1, total = 2),
            list(list(countryiso3code = "GBR", indicator = list(id = "A"), date = "2000", value = 1))
          )
        )
      }
    ),
    fetch_world_bank(params)
  )
  testthat::expect_equal(pages_called, c(1, 2))
  testthat::expect_equal(length(out$rows), 2)
  testthat::expect_equal(out$pages_fetched, 2)
})

testthat::test_that("normalize_world_bank_result maps rows into standard output", {
  params <- list(country = "GBR", indicator = "A", years = c(2000, 2001))
  raw <- list(
    request = list(url = "https://api.worldbank.org", query = list(format = "json")),
    rows = list(
      list(countryiso3code = "GBR", indicator = list(id = "A"), date = "2001", value = 2, unit = "kWh"),
      list(countryiso3code = "GBR", indicator = list(id = "A"), date = "2000", value = NULL, unit = "kWh")
    ),
    page_metadata = list(page = 1, pages = 1),
    pages_fetched = 1
  )

  out <- normalize_world_bank_result(raw, params)
  testthat::expect_equal(out$connector, "world_bank")
  testthat::expect_equal(out$data[[1]]$country, "GBR")
  testthat::expect_equal(out$dimensions$temporal$resolution, "annual")
  testthat::expect_false("schema_version" %in% names(out))
})

testthat::test_that("world_bank_http_get handles status and parsing through httr2 wrappers", {
  testthat::local_mocked_bindings(
    request = function(url) list(url = url),
    req_url_query = function(req, ...) {
      req$query <- list(...)
      req
    },
    req_perform = function(req) list(req = req),
    resp_status = function(resp) 200L,
    resp_body_json = function(resp, simplifyVector = FALSE) {
      list(list(page = 1, pages = 1, per_page = 50, total = 0), list())
    },
    .package = "httr2"
  )

  out <- world_bank_http_get("https://example", list(page = 1))
  testthat::expect_equal(out$status_code, 200)
  testthat::expect_true(is.list(out$body))
})
