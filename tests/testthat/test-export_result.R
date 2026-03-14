testthat::test_that("serialize_result writes JSON and YAML strings", {
  obj <- list(a = 1, b = NULL, c = list(x = "y"))

  json_txt <- serialize_result(obj, "json")
  yaml_txt <- serialize_result(obj, "yaml")

  parsed_json <- jsonlite::fromJSON(json_txt, simplifyVector = FALSE)
  testthat::expect_equal(parsed_json$a, 1)
  testthat::expect_true(grepl("^a:", yaml_txt))
})

testthat::test_that("serialize_result errors for unsupported format", {
  testthat::expect_error(serialize_result(list(a = 1), "csv"), "Unsupported format")
})

testthat::test_that("export_result writes file and creates parent directory", {
  td <- tempfile()
  out_file <- file.path(td, "nested", "result.json")

  export_result(
    result = list(x = 1),
    format = "json",
    file = out_file
  )

  testthat::expect_true(file.exists(out_file))
  content <- paste(readLines(out_file, warn = FALSE), collapse = "\n")
  testthat::expect_true(grepl("\"x\"", content))
})

