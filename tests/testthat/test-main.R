testthat::test_that("run_mack delegates to broker_fetch and returns result", {
  req <- list(source = "world_bank", params = list())

  out <- with_temp_bindings(
    list(
      broker_fetch = function(request, secrets_path, schema_version = "0.1.0") {
        list(connector = "mock", request = request, secrets_path = secrets_path, schema_version = schema_version)
      }
    ),
    run_mack(req, secrets_path = "config/x.yaml")
  )
  testthat::expect_equal(out$connector, "mock")
  testthat::expect_equal(out$request$source, "world_bank")
})

testthat::test_that("run_mack exports when output format and file are set", {
  req <- list(
    source = "world_bank",
    params = list(),
    output = list(format = "json", file = "out.json")
  )
  calls <- list(export = FALSE)

  out <- with_temp_bindings(
    list(
      broker_fetch = function(request, secrets_path, schema_version = "0.1.0") {
        list(connector = "world_bank")
      },
      export_result = function(result, format, file) {
        calls$export <<- TRUE
        testthat::expect_equal(format, "json")
        testthat::expect_equal(file, "out.json")
        invisible(file)
      }
    ),
    run_mack(req, secrets_path = "config/x.yaml")
  )

  testthat::expect_true(calls$export)
  testthat::expect_equal(out$connector, "world_bank")
})

testthat::test_that("run_mack does not export when output is absent or file is blank", {
  req_no_output <- list(source = "world_bank", params = list())
  req_blank_file <- list(
    source = "world_bank",
    params = list(),
    output = list(format = "json", file = "")
  )
  calls <- list(export = FALSE)

  with_temp_bindings(
    list(
      broker_fetch = function(request, secrets_path, schema_version = "0.1.0") {
        list(connector = "world_bank")
      },
      export_result = function(result, format, file) {
        calls$export <<- TRUE
        invisible(file)
      }
    ),
    run_mack(req_no_output, secrets_path = "config/x.yaml")
  )

  with_temp_bindings(
    list(
      broker_fetch = function(request, secrets_path, schema_version = "0.1.0") {
        list(connector = "world_bank")
      },
      export_result = function(result, format, file) {
        calls$export <<- TRUE
        invisible(file)
      }
    ),
    run_mack(req_blank_file, secrets_path = "config/x.yaml")
  )

  testthat::expect_false(calls$export)
})

testthat::test_that("run_mack reads request file path then dispatches", {
  out <- with_temp_bindings(
    list(
      read_request_file = function(path) list(source = "world_bank", params = list()),
      broker_fetch = function(request, secrets_path, schema_version = "0.1.0") list(connector = request$source)
    ),
    run_mack("request.yaml", secrets_path = "config/s.yaml")
  )
  testthat::expect_equal(out$connector, "world_bank")
})
