# utils.R
#
# Small shared utilities used across dispatcher and connectors.

#' Read request file
#'
#' @description Reads a JSON/YAML request document and returns a canonical
#' request list with top-level `source`, `params`, and optional `output`. Supports
#' either wrapped form (`request: { ... }`) or unwrapped top-level form.
#' @param path Character path to a request file.
#' @return Named list containing broker request fields.
read_request_file <- function(path) {
  request_object <- NULL
  payload <- NULL
  ext <- NULL

  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("path must be a non-empty character scalar.", call. = FALSE)
  }

  if (!file.exists(path)) {
    stop("Request file does not exist: ", path, call. = FALSE)
  }

  ext <- tolower(tools::file_ext(path))
  if (identical(ext, "json")) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      stop("Package 'jsonlite' is required to read JSON request files.", call. = FALSE)
    }
    payload <- tryCatch(
      jsonlite::fromJSON(path, simplifyVector = FALSE),
      error = function(e) {
        stop(
          "Failed to parse JSON request file: ", path,
          ". Ensure valid JSON with an outer object wrapper, e.g. ",
          "{\"request\": {...}}. Parser message: ", conditionMessage(e),
          call. = FALSE
        )
      }
    )
  } else if (ext %in% c("yaml", "yml")) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
      stop("Package 'yaml' is required to read YAML request files.", call. = FALSE)
    }
    payload <- yaml::read_yaml(path)
  } else {
    stop("Unsupported request file extension. Use .json, .yaml, or .yaml.", call. = FALSE)
  }

  if (!is.list(payload)) {
    stop("Request file must parse to a list-like object.", call. = FALSE)
  }

  if ("request" %in% names(payload)) {
    request_object <- payload$request
  } else {
    request_object <- payload
  }

  if (!is.list(request_object)) {
    stop("Request payload must be a list.", call. = FALSE)
  }

  required_fields <- c("source", "params")
  missing_fields <- setdiff(required_fields, names(request_object))
  if (length(missing_fields) > 0L) {
    stop(
      "Request payload is missing required fields: ",
      paste(missing_fields, collapse = ", "),
      call. = FALSE
    )
  }

  return(request_object)
}

#' Read secrets file
#'
#' @description Reads connector credentials from a local YAML file.
#' @param path Character path to secrets YAML file.
#' @return Named list containing secrets grouped by connector.
read_secrets <- function(path = "config/secrets.yaml") {
  secrets <- NULL

  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("path must be a non-empty character scalar.", call. = FALSE)
  }

  if (!file.exists(path)) {
    stop("Secrets file does not exist: ", path, call. = FALSE)
  }

  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to read secrets files.", call. = FALSE)
  }

  secrets <- yaml::read_yaml(path)
  if (is.null(secrets)) {
    return(list())
  }

  if (!is.list(secrets)) {
    stop("Secrets file must parse to a named list.", call. = FALSE)
  }

  return(secrets)
}

#' Build UTC timestamp
#'
#' @description Returns current UTC time formatted as ISO 8601 text.
#' @param time Optional `POSIXct` value to format; defaults to current time.
#' @return Character scalar UTC timestamp in ISO 8601 format.
utc_timestamp_iso8601 <- function(time = Sys.time()) {
  time_utc <- NULL

  if (!inherits(time, "POSIXt") || length(time) != 1L || is.na(time)) {
    stop("time must be a non-NA POSIXt scalar.", call. = FALSE)
  }

  time_utc <- as.POSIXct(time, tz = "UTC")
  return(format(time_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC", usetz = FALSE))
}

#' Build standard output object
#'
#' @description Creates the broker's standard output list structure that all
#' connectors must return. This helper builds connector output before
#' dispatcher-injected fields such as `schema_version`.
#' @param connector Character connector name.
#' @param query Named list of final query parameters used.
#' @param data List-like normalized data payload.
#' @param units Unit metadata as character scalar or named list.
#' @param dimensions List describing temporal and spatial dimensions.
#' @param warnings Optional list of non-fatal warning messages.
#' @param source_metadata Optional source metadata list.
#' @return Named list in the broker standard output schema.
build_standard_output <- function(connector,
                                  query,
                                  data,
                                  units,
                                  dimensions,
                                  warnings = NULL,
                                  source_metadata = NULL) {
  result <- NULL

  if (!is.character(connector) || length(connector) != 1L) {
    stop("connector must be a character scalar.", call. = FALSE)
  }
  if (is.na(connector) || !nzchar(connector)) {
    stop("connector must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.list(query)) {
    stop("query must be a list.", call. = FALSE)
  }

  if (!is.list(data)) {
    stop("data must be a list.", call. = FALSE)
  }

  if (!is.null(units) && !is.character(units) && !is.list(units)) {
    stop("units must be NULL, a character value, or a list.", call. = FALSE)
  }

  if (!is.list(dimensions)) {
    stop("dimensions must be a list.", call. = FALSE)
  }
  if (!all(c("temporal", "spatial") %in% names(dimensions))) {
    stop("dimensions must include `temporal` and `spatial`.", call. = FALSE)
  }

  if (!is.null(warnings) && !is.character(warnings) && !is.list(warnings)) {
    stop("warnings must be NULL, character, or a list.", call. = FALSE)
  }

  if (!is.null(source_metadata) && !is.list(source_metadata)) {
    stop("source_metadata must be NULL or a list.", call. = FALSE)
  }

  result <- list(
    connector = connector,
    timestamp = utc_timestamp_iso8601(),
    query = query,
    data = data,
    units = units,
    dimensions = dimensions
  )

  if (!is.null(warnings)) {
    result$warnings <- warnings
  }
  if (!is.null(source_metadata)) {
    result$source_metadata <- source_metadata
  }

  return(result)
}

#' Raise connector error
#'
#' @description Stops with a standardized connector error message, optionally
#' including an HTTP status code.
#' @param connector Character connector name.
#' @param message Character error message.
#' @param status_code Optional numeric HTTP status code.
#' @return This function does not return; it always errors.
stop_with_connector_error <- function(connector, message, status_code = NULL) {
  full_message <- NULL

  if (!is.character(connector) || length(connector) != 1L) {
    stop("connector must be a character scalar.", call. = FALSE)
  }
  if (is.na(connector) || !nzchar(connector)) {
    stop("connector must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.character(message) || length(message) != 1L) {
    stop("message must be a character scalar.", call. = FALSE)
  }
  if (is.na(message) || !nzchar(message)) {
    stop("message must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.null(status_code)) {
    if (!is.numeric(status_code) || length(status_code) != 1L || is.na(status_code)) {
      stop("status_code must be NULL or a numeric scalar.", call. = FALSE)
    }
  }

  full_message <- paste0("[", connector, "] ")
  if (!is.null(status_code)) {
    full_message <- paste0(full_message, "HTTP ", as.integer(status_code), ": ")
  }
  full_message <- paste0(full_message, message)

  stop(full_message, call. = FALSE)
}
