testthat::test_that("validate_request accepts valid request and no-export variants", {
  req_no_output <- list(
    source = "world_bank",
    params = list(country = "GBR")
  )
  req_null <- list(
    source = "world_bank",
    params = list(country = "GBR"),
    output = list(format = "json", file = NULL)
  )
  req_empty <- list(
    source = "world_bank",
    params = list(country = "GBR"),
    output = list(format = "json", file = "")
  )
  req_missing <- list(
    source = "world_bank",
    params = list(country = "GBR"),
    output = list(format = "json")
  )

  testthat::expect_invisible(validate_request(req_no_output))
  testthat::expect_invisible(validate_request(req_null))
  testthat::expect_invisible(validate_request(req_empty))
  testthat::expect_invisible(validate_request(req_missing))
})

testthat::test_that("validate_request_source rejects bad values", {
  testthat::expect_error(validate_request_source(NULL), "non-empty character scalar")
  testthat::expect_error(validate_request_source("unknown"), "not supported")
})

testthat::test_that("validate_request_params requires list", {
  testthat::expect_error(validate_request_params(NULL), "must be a list")
  testthat::expect_error(validate_request_params("x"), "must be a list")
})

testthat::test_that("validate_request_output validates format and file", {
  testthat::expect_error(
    validate_request_output(list(format = "txt")),
    "must be one of: json, yaml"
  )
  testthat::expect_error(
    validate_request_output(list(format = "json", file = NA_character_)),
    "non-NA character scalar"
  )
})
