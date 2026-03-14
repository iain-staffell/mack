# export_result.R
#
# Serialization and file export helpers for broker results.

#' Export standard broker result
#'
#' @description Writes the full standard broker output object to disk in JSON
#' or YAML format.
#' @param result Standard broker output object as a named list.
#' @param format Character output format: `"json"` or `"yaml"`.
#' @param file Character output file path to write.
#' @return Invisibly returns output file path.
export_result <- function(result, format, file) {
  payload <- NULL
  output_dir <- NULL

  if (!is.list(result)) {
    stop("result must be a list.", call. = FALSE)
  }

  if (!is.character(format) || length(format) != 1L || is.na(format)) {
    stop("format must be a character scalar.", call. = FALSE)
  }
  format <- tolower(format)

  if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) {
    stop("file must be a non-empty character scalar.", call. = FALSE)
  }

  payload <- serialize_result(result = result, format = format)

  output_dir <- dirname(file)
  if (!identical(output_dir, ".") && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  writeLines(text = payload, con = file, useBytes = TRUE)

  return(invisible(file))
}

#' Serialize result to text
#'
#' @description Converts standard broker output object into JSON or YAML text.
#' @param result Standard broker output object as a named list.
#' @param format Character output format: `"json"` or `"yaml"`.
#' @return Character scalar containing serialized payload.
serialize_result <- function(result, format) {
  format <- tolower(format)

  if (!is.list(result)) {
    stop("result must be a list.", call. = FALSE)
  }

  if (!is.character(format) || length(format) != 1L || is.na(format)) {
    stop("format must be a character scalar.", call. = FALSE)
  }

  if (identical(format, "json")) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      stop("Package 'jsonlite' is required for JSON serialization.", call. = FALSE)
    }
    return(as.character(jsonlite::toJSON(
      x = result,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    )))
  }

  if (identical(format, "yaml")) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop("Package 'yaml' is required for YAML serialization.", call. = FALSE)
    }
    return(yaml::as.yaml(result))
  }

  stop("Unsupported format: ", format, call. = FALSE)
}
