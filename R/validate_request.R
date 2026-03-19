# validate_request.R
#
# Top-level request validation for source, params, and output settings.

#' Validate full broker request
#'
#' @description Checks that request has required top-level fields and valid
#' types before any API call is attempted.
#' @param request A named list expected to include `source` and `params`.
#' `output` is optional.
#' @return Invisibly returns `TRUE` when request is valid; otherwise errors.
validate_request <- function(request) {
  if (!is.list(request)) {
    stop("request must be a list.", call. = FALSE)
  }

  validate_request_source(request$source)
  validate_request_params(request$params)
  if (!is.null(request$output)) {
    validate_request_output(request$output)
  }

  return(invisible(TRUE))
}

#' Validate request source
#'
#' @description Ensures `source` is a single supported connector name.
#' @param source Character source name from `request$source`.
#' @return Invisibly returns `TRUE` when source is valid; otherwise errors.
validate_request_source <- function(source) {
  supported_sources <- c("world_bank", "renewables_ninja", "eurostat")

  if (!is.character(source) || length(source) != 1L || !nzchar(source)) {
    stop("request$source must be a non-empty character scalar.", call. = FALSE)
  }

  if (!(source %in% supported_sources)) {
    stop("request$source is not supported: ", source, call. = FALSE)
  }

  return(invisible(TRUE))
}

#' Validate request params
#'
#' @description Ensures `params` is present and list-like for connector-specific
#' validation downstream.
#' @param params List of source-specific request parameters.
#' @return Invisibly returns `TRUE` when params are valid at top level; otherwise errors.
validate_request_params <- function(params) {
  if (is.null(params) || !is.list(params)) {
    stop("request$params must be a list.", call. = FALSE)
  }

  return(invisible(TRUE))
}

#' Validate request output
#'
#' @description Ensures output configuration exists and uses a supported format.
#' @param output List containing output settings, including `format` and
#' optional `file`. If `file` is missing, `NULL`, or `""`, no file is written.
#' @return Invisibly returns `TRUE` when output config is valid; otherwise errors.
validate_request_output <- function(output) {
  supported_formats <- c("json", "yaml")

  if (is.null(output) || !is.list(output)) {
    stop("request$output must be a list.", call. = FALSE)
  }

  if (!is.character(output$format) || length(output$format) != 1L || is.na(output$format)) {
    stop("request$output$format must be a character scalar.", call. = FALSE)
  }

  if (!(output$format %in% supported_formats)) {
    stop("request$output$format must be one of: json, yaml.", call. = FALSE)
  }

  if (!is.null(output$file) &&
      (!is.character(output$file) || length(output$file) != 1L || is.na(output$file))) {
    stop("request$output$file must be NULL or a non-NA character scalar.", call. = FALSE)
  }

  return(invisible(TRUE))
}
