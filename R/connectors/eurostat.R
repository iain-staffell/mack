# eurostat.R
#
# Eurostat Statistics API connector implementation and helper functions.

#' Validate Eurostat parameters
#'
#' @description Validates source-specific `params` for Eurostat Statistics API
#' requests.
#' @param params Named list expected to include `dataset_code` and `filters`.
#' @return Invisibly returns `TRUE` when parameters are valid; otherwise errors.
validate_eurostat_params <- function(params) {
  filters <- NULL
  filter_name <- NULL
  filter_values <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.character(params$dataset_code) || length(params$dataset_code) != 1L ||
      is.na(params$dataset_code) || !nzchar(params$dataset_code)) {
    stop("Eurostat param `dataset_code` must be a non-empty character scalar.", call. = FALSE)
  }
  if (!grepl("^[A-Za-z0-9_]+$", params$dataset_code)) {
    stop("Eurostat param `dataset_code` must contain only letters, numbers, and underscores.", call. = FALSE)
  }

  filters <- params$filters
  if (is.null(filters) || !is.list(filters)) {
    stop("Eurostat param `filters` must be a named list.", call. = FALSE)
  }
  if (length(filters) > 0L) {
    if (is.null(names(filters)) || any(is.na(names(filters))) || any(!nzchar(names(filters)))) {
      stop("Eurostat param `filters` must use non-empty names for each dimension.", call. = FALSE)
    }
    for (i in seq_along(filters)) {
      filter_name <- names(filters)[[i]]
      filter_values <- filters[[i]]
      if (is.null(filter_values)) {
        stop("Eurostat filter `", filter_name, "` must not be NULL.", call. = FALSE)
      }
      if (is.factor(filter_values)) {
        filter_values <- as.character(filter_values)
      }
      if (!is.atomic(filter_values) || is.list(filter_values) || length(filter_values) < 1L) {
        stop("Eurostat filter `", filter_name, "` must be a non-empty atomic vector.", call. = FALSE)
      }
      if (any(is.na(filter_values))) {
        stop("Eurostat filter `", filter_name, "` must not contain NA values.", call. = FALSE)
      }
      filter_values <- as.character(filter_values)
      if (any(!nzchar(filter_values))) {
        stop("Eurostat filter `", filter_name, "` must not contain empty strings.", call. = FALSE)
      }
    }
  }

  if (!is.null(params$lang) &&
      (!is.character(params$lang) || length(params$lang) != 1L || is.na(params$lang) || !nzchar(params$lang))) {
    stop("Eurostat param `lang` must be NULL or a non-empty character scalar.", call. = FALSE)
  }

  if (!is.null(params$aggregate_time) &&
      (!is.character(params$aggregate_time) || length(params$aggregate_time) != 1L || is.na(params$aggregate_time))) {
    stop("Eurostat param `aggregate_time` must be NULL or a character scalar.", call. = FALSE)
  }
  if (!is.null(params$aggregate_time) &&
      !(params$aggregate_time %in% c("annual_mean"))) {
    stop("Eurostat param `aggregate_time` must be one of: annual_mean.", call. = FALSE)
  }

  return(invisible(TRUE))
}

#' Normalize Eurostat query params
#'
#' @description Applies light defaults to Eurostat connector params.
#' @param params Raw connector params.
#' @return Normalized params list.
normalize_eurostat_query_params <- function(params) {
  normalized <- params

  if (is.null(normalized$lang)) {
    normalized$lang <- "EN"
  } else if (is.character(normalized$lang) && length(normalized$lang) == 1L &&
             !is.na(normalized$lang)) {
    normalized$lang <- toupper(normalized$lang)
  }

  if (is.null(normalized$aggregate_time)) {
    normalized$aggregate_time <- NULL
  }

  return(normalized)
}

#' Build Eurostat request configuration
#'
#' @description Constructs API endpoint and full query URL for a Eurostat
#' Statistics API request.
#' @param params Validated Eurostat parameter list.
#' @return Named list containing endpoint, normalized query, and full URL.
build_eurostat_request <- function(params) {
  normalized_params <- NULL
  base_url <- NULL
  query_pairs <- character(0)
  filters <- NULL
  filter_name <- NULL
  filter_values <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  normalized_params <- normalize_eurostat_query_params(params)
  validate_eurostat_params(normalized_params)

  base_url <- paste0(
    "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/",
    normalized_params$dataset_code
  )

  query_pairs <- c(
    query_pairs,
    paste0("lang=", utils::URLencode(normalized_params$lang, reserved = TRUE))
  )

  filters <- normalized_params$filters
  if (length(filters) > 0L) {
    for (i in seq_along(filters)) {
      filter_name <- names(filters)[[i]]
      filter_values <- as.character(filters[[i]])
      query_pairs <- c(
        query_pairs,
        vapply(
          filter_values,
          function(value) {
            paste0(
              utils::URLencode(filter_name, reserved = TRUE),
              "=",
              utils::URLencode(value, reserved = TRUE)
            )
          },
          character(1)
        )
      )
    }
  }

  return(list(
    url = base_url,
    full_url = paste0(base_url, "?", paste(query_pairs, collapse = "&")),
    query = list(
      lang = normalized_params$lang,
      filters = normalized_params$filters
    )
  ))
}

#' Fetch raw Eurostat response
#'
#' @description Executes a Eurostat Statistics API request and returns parsed
#' raw content together with request metadata.
#' @param params Validated Eurostat parameter list.
#' @return Raw connector response object ready for normalization.
fetch_eurostat <- function(params) {
  normalized_params <- NULL
  request_config <- NULL
  response <- NULL
  parsed <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  normalized_params <- normalize_eurostat_query_params(params)
  validate_eurostat_params(normalized_params)
  request_config <- build_eurostat_request(normalized_params)

  response <- eurostat_http_get(request_config$full_url)
  parsed <- parse_eurostat_payload(response$body)

  return(list(
    request = request_config,
    parsed = parsed
  ))
}

#' Normalize Eurostat result
#'
#' @description Converts a Eurostat JSON-stat payload into the broker standard
#' output structure.
#' @param raw_result Raw response object returned by `fetch_eurostat()`.
#' @param params Validated Eurostat parameter list used for the request.
#' @return Standard broker output object as a named list, excluding
#' `schema_version` (added by dispatcher).
normalize_eurostat_result <- function(raw_result, params) {
  normalized_params <- NULL
  parsed <- NULL
  data_rows <- NULL
  aggregation <- NULL
  warnings <- NULL
  dimensions <- NULL

  if (!is.list(raw_result)) {
    stop("raw_result must be a list.", call. = FALSE)
  }
  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  normalized_params <- normalize_eurostat_query_params(params)
  validate_eurostat_params(normalized_params)

  if (!is.list(raw_result$parsed)) {
    stop("raw_result$parsed must be a parsed Eurostat payload list.", call. = FALSE)
  }

  parsed <- raw_result$parsed
  data_rows <- parsed$rows
  warnings <- NULL

  if (!is.null(normalized_params$aggregate_time) &&
      identical(normalized_params$aggregate_time, "annual_mean")) {
    aggregation <- aggregate_eurostat_rows_by_year(data_rows)
    data_rows <- aggregation$rows
    warnings <- aggregation$warnings
  }

  dimensions <- build_eurostat_dimensions(
    dimension_metadata = parsed$dimension_metadata,
    data_rows = data_rows,
    aggregate_time = normalized_params$aggregate_time
  )

  return(build_standard_output(
    connector = "eurostat",
    query = list(
      url = raw_result$request$url,
      full_url = raw_result$request$full_url,
      params = raw_result$request$query
    ),
    data = data_rows,
    units = extract_eurostat_units(parsed$dimension_metadata),
    dimensions = dimensions,
    warnings = warnings,
    source_metadata = list(
      dataset_code = normalized_params$dataset_code,
      dataset_label = parsed$label,
      updated = parsed$updated,
      source = parsed$source,
      dimensions = summarize_eurostat_dimensions(parsed$dimension_metadata),
      annotations = parsed$annotations
    )
  ))
}

#' Parse Eurostat JSON-stat payload
#'
#' @description Parses a Eurostat Statistics API JSON-stat dataset into an
#' internal row-based structure for normalization.
#' @param raw_payload Raw decoded JSON-stat payload from Eurostat.
#' @return Named list containing parsed rows and metadata.
parse_eurostat_payload <- function(raw_payload) {
  ids <- NULL
  sizes <- NULL
  dimension_metadata <- list()
  rows <- list()
  values <- NULL
  status <- NULL

  if (!is.list(raw_payload)) {
    stop_with_connector_error("eurostat", "Eurostat payload is not list-like.")
  }

  ids <- raw_payload$id
  sizes <- raw_payload$size
  values <- raw_payload$value

  if (is.list(ids)) {
    ids <- unlist(ids, use.names = FALSE)
  }
  if (is.list(sizes)) {
    sizes <- unlist(sizes, use.names = FALSE)
  }

  if (!is.character(ids) || length(ids) < 1L || any(is.na(ids)) || any(!nzchar(ids))) {
    stop_with_connector_error("eurostat", "Eurostat payload is missing valid dimension ids.")
  }
  if (!is.numeric(sizes) || length(sizes) != length(ids) || any(is.na(sizes))) {
    stop_with_connector_error("eurostat", "Eurostat payload is missing valid dimension sizes.")
  }
  if (is.null(values)) {
    stop_with_connector_error("eurostat", "Eurostat payload is missing observation values.")
  }
  if (is.null(raw_payload$dimension) || !is.list(raw_payload$dimension)) {
    stop_with_connector_error("eurostat", "Eurostat payload is missing dimension metadata.")
  }

  for (i in seq_along(ids)) {
    dimension_metadata[[ids[[i]]]] <- parse_eurostat_dimension(
      dimension_id = ids[[i]],
      dimension_payload = raw_payload$dimension[[ids[[i]]]]
    )
  }

  status <- raw_payload$status
  rows <- eurostat_values_to_rows(
    values = values,
    status = status,
    ids = ids,
    sizes = as.integer(sizes),
    dimension_metadata = dimension_metadata
  )

  return(list(
    label = raw_payload$label,
    updated = raw_payload$updated,
    source = raw_payload$source,
    annotations = raw_payload$extension$annotation,
    ids = ids,
    sizes = as.integer(sizes),
    rows = rows,
    dimension_metadata = dimension_metadata
  ))
}

#' Parse one Eurostat dimension description
#'
#' @description Extracts dimension code order and labels from a JSON-stat
#' dimension payload.
#' @param dimension_id Character dimension identifier.
#' @param dimension_payload Raw dimension payload.
#' @return Parsed dimension metadata list.
parse_eurostat_dimension <- function(dimension_id, dimension_payload) {
  index_values <- NULL
  ordered_positions <- NULL
  codes <- NULL
  labels <- list()
  label_values <- NULL

  if (!is.character(dimension_id) || length(dimension_id) != 1L || is.na(dimension_id) || !nzchar(dimension_id)) {
    stop("dimension_id must be a non-empty character scalar.", call. = FALSE)
  }
  if (!is.list(dimension_payload) || !is.list(dimension_payload$category)) {
    stop("dimension_payload must contain a `category` list.", call. = FALSE)
  }
  if (is.null(dimension_payload$category$index)) {
    stop("dimension_payload$category$index must be provided.", call. = FALSE)
  }

  index_values <- unlist(dimension_payload$category$index, use.names = TRUE)
  if (length(index_values) < 1L || is.null(names(index_values))) {
    stop("dimension_payload$category$index must be a named mapping.", call. = FALSE)
  }

  ordered_positions <- order(as.integer(index_values))
  codes <- names(index_values)[ordered_positions]

  if (!is.null(dimension_payload$category$label)) {
    label_values <- unlist(dimension_payload$category$label, use.names = TRUE)
    for (i in seq_along(codes)) {
      labels[[codes[[i]]]] <- unname(label_values[[codes[[i]]]])
    }
  }

  return(list(
    id = dimension_id,
    label = dimension_payload$label,
    codes = codes,
    labels = labels
  ))
}

#' Convert sparse Eurostat values into row records
#'
#' @description Decodes the JSON-stat sparse observation map into one list
#' record per observation.
#' @param values Sparse observation values object.
#' @param status Sparse observation status object.
#' @param ids Character vector of dimension ids.
#' @param sizes Integer vector of dimension sizes.
#' @param dimension_metadata Parsed dimension metadata keyed by dimension id.
#' @return List of row-like observation records.
eurostat_values_to_rows <- function(values, status, ids, sizes, dimension_metadata) {
  indices <- NULL
  value_entries <- NULL
  rows <- list()
  obs_index <- NULL
  coordinates <- NULL
  record <- NULL
  dim_id <- NULL
  dim_meta <- NULL
  status_entries <- NULL
  status_value <- NULL

  if (is.null(names(values))) {
    value_entries <- unname(unlist(values, use.names = FALSE))
    indices <- seq_along(value_entries) - 1L
  } else {
    indices <- suppressWarnings(as.integer(names(values)))
    value_entries <- unlist(values, use.names = FALSE)
  }

  if (length(indices) != length(value_entries) || any(is.na(indices))) {
    stop("values must use integer-compatible sparse keys.", call. = FALSE)
  }

  if (!is.null(status)) {
    status_entries <- unlist(status, use.names = TRUE)
  } else {
    status_entries <- NULL
  }

  rows <- vector("list", length(indices))
  for (i in seq_along(indices)) {
    obs_index <- indices[[i]]
    coordinates <- decode_eurostat_index(obs_index, sizes)
    record <- list()

    for (j in seq_along(ids)) {
      dim_id <- ids[[j]]
      dim_meta <- dimension_metadata[[dim_id]]
      record[[dim_id]] <- dim_meta$codes[[coordinates[[j]] + 1L]]
    }

    record$value <- as.numeric(value_entries[[i]])
    if (!is.null(status_entries) && as.character(obs_index) %in% names(status_entries)) {
      status_value <- unname(status_entries[[as.character(obs_index)]])
      if (!is.null(status_value) && !is.na(status_value)) {
        record$status <- as.character(status_value)
      }
    }

    rows[[i]] <- record
  }

  return(rows)
}

#' Decode one JSON-stat linear observation index
#'
#' @description Converts a flattened observation index into zero-based
#' coordinates for each dimension in JSON-stat order.
#' @param index Integer-like observation index.
#' @param sizes Integer vector of dimension sizes.
#' @return Integer vector of zero-based coordinates.
decode_eurostat_index <- function(index, sizes) {
  remainder <- NULL
  coordinates <- NULL
  stride <- NULL

  if (!is.numeric(index) || length(index) != 1L || is.na(index)) {
    stop("index must be a numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(sizes) || length(sizes) < 1L || any(is.na(sizes))) {
    stop("sizes must be a numeric vector.", call. = FALSE)
  }

  remainder <- as.integer(index)
  coordinates <- integer(length(sizes))

  for (i in seq_along(sizes)) {
    if (i == length(sizes)) {
      coordinates[[i]] <- remainder
    } else {
      stride <- prod(sizes[(i + 1L):length(sizes)])
      coordinates[[i]] <- remainder %/% stride
      remainder <- remainder %% stride
    }
  }

  return(coordinates)
}

#' Aggregate Eurostat observations to annual means
#'
#' @description Groups observations sharing the same non-time dimensions and
#' averages values by four-digit year.
#' @param rows Row-based Eurostat observation records.
#' @return Named list containing aggregated rows and warning messages.
aggregate_eurostat_rows_by_year <- function(rows) {
  aggregated <- list()
  key_map <- list()
  record <- NULL
  base_record <- NULL
  year <- NULL
  field_names <- NULL
  group_key <- NULL
  row_key <- NULL
  values <- NULL
  periods <- NULL
  warnings <- character(0)

  if (!is.list(rows)) {
    stop("rows must be a list.", call. = FALSE)
  }

  if (length(rows) == 0L) {
    return(list(rows = list(), warnings = NULL))
  }

  for (i in seq_along(rows)) {
    record <- rows[[i]]
    if (!is.list(record)) {
      stop("Each row must be a list.", call. = FALSE)
    }
    if (is.null(record$time) || !is.character(record$time) || length(record$time) != 1L ||
        is.na(record$time) || !nzchar(record$time)) {
      stop("Eurostat annual_mean aggregation requires each row to include a non-empty `time` field.", call. = FALSE)
    }

    year <- extract_eurostat_year(record$time)
    if (is.null(year)) {
      stop("Eurostat annual_mean aggregation requires `time` values that begin with a four-digit year.", call. = FALSE)
    }

    field_names <- setdiff(names(record), c("time", "value", "status"))
    group_key <- paste(
      vapply(
        field_names,
        function(field) paste0(field, "=", as.character(record[[field]])),
        character(1)
      ),
      collapse = "|"
    )
    row_key <- paste0(group_key, "::year=", year)

    if (is.null(key_map[[row_key]])) {
      base_record <- record[field_names]
      base_record$year <- year
      key_map[[row_key]] <- base_record
      aggregated[[row_key]] <- list(values = numeric(0), periods = character(0))
    }

    aggregated[[row_key]]$values <- c(aggregated[[row_key]]$values, as.numeric(record$value))
    aggregated[[row_key]]$periods <- c(aggregated[[row_key]]$periods, record$time)
  }

  rows_out <- vector("list", length(aggregated))
  keys <- names(aggregated)
  for (i in seq_along(keys)) {
    values <- aggregated[[keys[[i]]]]$values
    periods <- aggregated[[keys[[i]]]]$periods
    base_record <- key_map[[keys[[i]]]]
    base_record$value <- if (all(is.na(values))) {
      NA_real_
    } else {
      mean(values, na.rm = TRUE)
    }
    base_record$period_count <- length(periods)
    rows_out[[i]] <- base_record
  }

  warnings <- c(
    warnings,
    "aggregate_time = annual_mean averages all matched observations sharing the same four-digit year prefix; period_count records how many time periods contributed to each annual value."
  )

  return(list(
    rows = rows_out,
    warnings = warnings
  ))
}

#' Extract year prefix from a Eurostat time code
#'
#' @description Returns the leading four-digit year when present.
#' @param time_value Character time code.
#' @return Character year or `NULL`.
extract_eurostat_year <- function(time_value) {
  if (!is.character(time_value) || length(time_value) != 1L || is.na(time_value) || !nzchar(time_value)) {
    stop("time_value must be a non-empty character scalar.", call. = FALSE)
  }

  if (!grepl("^[0-9]{4}", time_value)) {
    return(NULL)
  }

  return(substr(time_value, 1L, 4L))
}

#' Extract Eurostat units metadata
#'
#' @description Pulls unit codes and labels from parsed Eurostat dimensions.
#' @param dimension_metadata Parsed dimension metadata keyed by dimension id.
#' @return Unit metadata as a character scalar or named list.
extract_eurostat_units <- function(dimension_metadata) {
  unit_meta <- NULL
  units <- list()
  unit_code <- NULL

  if (!is.list(dimension_metadata)) {
    stop("dimension_metadata must be a list.", call. = FALSE)
  }

  unit_meta <- dimension_metadata$unit
  if (is.null(unit_meta) || !is.character(unit_meta$codes) || length(unit_meta$codes) < 1L) {
    return(NULL)
  }

  for (i in seq_along(unit_meta$codes)) {
    unit_code <- unit_meta$codes[[i]]
    units[[unit_code]] <- if (!is.null(unit_meta$labels[[unit_code]])) {
      unit_meta$labels[[unit_code]]
    } else {
      unit_code
    }
  }

  if (length(units) == 1L) {
    return(units[[1L]])
  }

  return(units)
}

#' Build Eurostat dimensions summary
#'
#' @description Builds the standard `dimensions` block for Eurostat results.
#' @param dimension_metadata Parsed dimension metadata keyed by dimension id.
#' @param data_rows Normalized data rows.
#' @param aggregate_time Optional time aggregation mode.
#' @return Dimensions list for the MACK output object.
build_eurostat_dimensions <- function(dimension_metadata, data_rows, aggregate_time = NULL) {
  geo_values <- character(0)
  time_values <- character(0)
  temporal_index <- NULL

  if (!is.list(dimension_metadata)) {
    stop("dimension_metadata must be a list.", call. = FALSE)
  }
  if (!is.list(data_rows)) {
    stop("data_rows must be a list.", call. = FALSE)
  }

  if (length(data_rows) > 0L) {
    if (!is.null(aggregate_time) && identical(aggregate_time, "annual_mean")) {
      year_candidates <- vapply(
        data_rows,
        function(record) if (!is.null(record$year)) as.character(record$year) else NA_character_,
        character(1)
      )
      time_values <- year_candidates[!is.na(year_candidates) & nzchar(year_candidates)]
      temporal_index <- "year"
    } else {
      time_candidates <- vapply(
        data_rows,
        function(record) if (!is.null(record$time)) as.character(record$time) else NA_character_,
        character(1)
      )
      time_values <- time_candidates[!is.na(time_candidates) & nzchar(time_candidates)]
      temporal_index <- "time"
    }

    geo_candidates <- vapply(
      data_rows,
      function(record) if (!is.null(record$geo)) as.character(record$geo) else NA_character_,
      character(1)
    )
    geo_values <- unique(geo_candidates[!is.na(geo_candidates) & nzchar(geo_candidates)])
  }

  return(list(
    temporal = list(
      start = if (length(time_values) > 0L) min(time_values) else NULL,
      end = if (length(time_values) > 0L) max(time_values) else NULL,
      resolution = infer_eurostat_resolution(dimension_metadata = dimension_metadata, aggregate_time = aggregate_time)
    ),
    spatial = list(
      type = if (length(geo_values) > 1L) "geo_set" else if (length(geo_values) == 1L) "geo" else NULL,
      ids = if (length(geo_values) > 0L) as.list(geo_values) else NULL
    ),
    variable = "dataset_observation",
    index = list(
      time = temporal_index,
      geography = if (length(geo_values) > 0L) "geo" else NULL,
      value = "value"
    )
  ))
}

#' Infer temporal resolution for Eurostat output
#'
#' @description Uses either the aggregation mode or the `freq` dimension to
#' label temporal resolution.
#' @param dimension_metadata Parsed dimension metadata keyed by dimension id.
#' @param aggregate_time Optional time aggregation mode.
#' @return Character scalar resolution label.
infer_eurostat_resolution <- function(dimension_metadata, aggregate_time = NULL) {
  freq_code <- NULL

  if (!is.null(aggregate_time) && identical(aggregate_time, "annual_mean")) {
    return("annual")
  }

  if (!is.null(dimension_metadata$freq) &&
      is.character(dimension_metadata$freq$codes) &&
      length(dimension_metadata$freq$codes) == 1L) {
    freq_code <- dimension_metadata$freq$codes[[1L]]
    if (identical(freq_code, "S")) {
      return("semesterly")
    }
    if (identical(freq_code, "A")) {
      return("annual")
    }
    if (identical(freq_code, "Q")) {
      return("quarterly")
    }
    if (identical(freq_code, "M")) {
      return("monthly")
    }
    return(freq_code)
  }

  return("unknown")
}

#' Summarize parsed Eurostat dimensions
#'
#' @description Converts internal dimension metadata into a compact
#' user-facing summary for `source_metadata`.
#' @param dimension_metadata Parsed dimension metadata keyed by dimension id.
#' @return Named list of dimension summaries.
summarize_eurostat_dimensions <- function(dimension_metadata) {
  summary <- list()
  dim_id <- NULL
  dim_meta <- NULL
  values <- list()
  value_code <- NULL

  if (!is.list(dimension_metadata)) {
    stop("dimension_metadata must be a list.", call. = FALSE)
  }

  for (i in seq_along(dimension_metadata)) {
    dim_id <- names(dimension_metadata)[[i]]
    dim_meta <- dimension_metadata[[i]]
    values <- list()

    if (is.character(dim_meta$codes) && length(dim_meta$codes) > 0L) {
      for (j in seq_along(dim_meta$codes)) {
        value_code <- dim_meta$codes[[j]]
        values[[value_code]] <- if (!is.null(dim_meta$labels[[value_code]])) {
          dim_meta$labels[[value_code]]
        } else {
          value_code
        }
      }
    }

    summary[[dim_id]] <- list(
      label = dim_meta$label,
      values = values
    )
  }

  return(summary)
}

# Internal HTTP wrapper to enable deterministic unit testing of fetch logic.
eurostat_http_get <- function(url) {
  req <- NULL
  resp <- NULL
  status_code <- NULL
  body <- NULL

  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("url must be a non-empty character scalar.", call. = FALSE)
  }

  req <- httr2::request(url)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      stop_with_connector_error("eurostat", conditionMessage(e))
    }
  )

  status_code <- httr2::resp_status(resp)
  body <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) {
      stop_with_connector_error("eurostat", paste0("Failed to parse JSON response: ", conditionMessage(e)))
    }
  )

  if (status_code >= 400L) {
    message_text <- eurostat_extract_error_message(body)
    if (is.null(message_text)) {
      message_text <- "API request failed."
    }
    stop_with_connector_error(
      connector = "eurostat",
      message = message_text,
      status_code = status_code
    )
  }

  return(list(
    status_code = status_code,
    body = body
  ))
}

#' Extract Eurostat API error message
#'
#' @description Pulls a human-readable error string from a decoded error body
#' when Eurostat returns JSON details for HTTP failures.
#' @param body Decoded response body.
#' @return Character error message or `NULL`.
eurostat_extract_error_message <- function(body) {
  if (!is.list(body)) {
    return(NULL)
  }

  if (!is.null(body$error$message) &&
      is.character(body$error$message) &&
      length(body$error$message) == 1L &&
      !is.na(body$error$message) &&
      nzchar(body$error$message)) {
    return(body$error$message)
  }

  if (!is.null(body$error$label) &&
      is.character(body$error$label) &&
      length(body$error$label) == 1L &&
      !is.na(body$error$label) &&
      nzchar(body$error$label)) {
    return(body$error$label)
  }

  if (!is.null(body$message) &&
      is.character(body$message) &&
      length(body$message) == 1L &&
      !is.na(body$message) &&
      nzchar(body$message)) {
    return(body$message)
  }

  return(NULL)
}
