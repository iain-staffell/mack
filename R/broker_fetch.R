# broker_fetch.R
#
# Main dispatcher for connector selection and execution.

#' Fetch data through the broker
#'
#' @description Validates the top-level request, routes to the selected
#' connector, and returns the standard output object.
#' @param request A named list with top-level entries: `source`, `params`,
#' and optional `output`.
#' @param secrets_path Character path to YAML secrets file for authenticated
#' connectors.
#' @param schema_version Character schema version to stamp on output.
#' @return A standard broker output object as a named list. `schema_version`
#' is set by the dispatcher.
broker_fetch <- function(request, secrets_path = "config/secrets.yaml", schema_version = "0.1.0") {
  validate_request(request)

  source <- request$source
  params <- request$params
  result <- NULL

  if (identical(source, "world_bank")) {
    validate_world_bank_params(params)
    raw_result <- fetch_world_bank(params)
    result <- normalize_world_bank_result(raw_result, params)
  } else if (identical(source, "renewables_ninja")) {
    validate_renewables_ninja_params(params)
    token <- get_renewables_ninja_token(secrets_path = secrets_path)
    raw_result <- fetch_renewables_ninja(params, token = token)
    result <- normalize_renewables_ninja_result(raw_result, params)
  } else if (identical(source, "eurostat")) {
    validate_eurostat_params(params)
    raw_result <- fetch_eurostat(params)
    result <- normalize_eurostat_result(raw_result, params)
  } else {
    stop("Unsupported source in request$source: ", source, call. = FALSE)
  }

  result <- validate_normalized_result(result = result, source = source)
  result$schema_version <- schema_version

  return(result)
}

#' Validate normalized connector output
#'
#' @description Checks that connector normalizers return the required standard
#' output fields, except `schema_version`, which is dispatcher-owned.
#' @param result Normalized connector output candidate.
#' @param source Character connector name expected in `result$connector`.
#' @return Validated normalized result list.
validate_normalized_result <- function(result, source) {
  required_fields <- c("connector", "timestamp", "query", "data", "units", "dimensions")
  missing_fields <- character(0)

  if (!is.list(result) || is.data.frame(result)) {
    stop("Connector normalizer must return a named list.", call. = FALSE)
  }

  if (is.null(names(result))) {
    stop("Connector normalizer output must be a named list.", call. = FALSE)
  }

  missing_fields <- setdiff(required_fields, names(result))
  if (length(missing_fields) > 0L) {
    stop(
      "Connector normalizer output is missing required fields: ",
      paste(missing_fields, collapse = ", "),
      call. = FALSE
    )
  }

  if ("schema_version" %in% names(result)) {
    stop("Connector normalizer must not set schema_version; dispatcher owns it.", call. = FALSE)
  }

  if (!is.character(result$connector) || length(result$connector) != 1L) {
    stop("Connector normalizer output field `connector` must be a character scalar.", call. = FALSE)
  }

  if (!identical(result$connector, source)) {
    stop("Connector normalizer output field `connector` does not match request source.", call. = FALSE)
  }

  if (!is.character(result$timestamp) || length(result$timestamp) != 1L || !nzchar(result$timestamp)) {
    stop("Connector normalizer output field `timestamp` must be a non-empty character scalar.", call. = FALSE)
  }

  if (!is.list(result$query)) {
    stop("Connector normalizer output field `query` must be a list.", call. = FALSE)
  }

  if (!is.list(result$dimensions)) {
    stop("Connector normalizer output field `dimensions` must be a list.", call. = FALSE)
  }

  return(result)
}
