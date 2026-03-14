# connectors/renewables_ninja.R
#
# Renewables.ninja connector implementation and helper functions.

#' Validate Renewables.ninja parameters
#'
#' @description Validates source-specific `params` for Renewables.ninja site
#' or aggregated requests.
#' @param params Named list of connector parameters including technology,
#' sites, capacity, and date bounds.
#' @return Invisibly returns `TRUE` when parameters are valid; otherwise errors.
validate_renewables_ninja_params <- function(params) {
  sites <- NULL
  capacities <- NULL
  date_from <- NULL
  date_to <- NULL
  site <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.character(params$technology) || length(params$technology) != 1L ||
      is.na(params$technology) || !nzchar(params$technology)) {
    stop("Renewables.ninja param `technology` must be a non-empty character scalar.", call. = FALSE)
  }
  if (!(params$technology %in% c("wind", "solar"))) {
    stop("Renewables.ninja param `technology` must be either 'wind' or 'solar'.", call. = FALSE)
  }

  sites <- params$sites
  if (!is.list(sites) || length(sites) < 1L) {
    stop("Renewables.ninja param `sites` must be a non-empty list of lat/lon points.", call. = FALSE)
  }
  for (i in seq_along(sites)) {
    site <- sites[[i]]
    if (!is.list(site)) {
      stop("Each site must be a list with `lat` and `lon`.", call. = FALSE)
    }
    if (!is.numeric(site$lat) || length(site$lat) != 1L || is.na(site$lat)) {
      stop("Each site `lat` must be a numeric scalar.", call. = FALSE)
    }
    if (!is.numeric(site$lon) || length(site$lon) != 1L || is.na(site$lon)) {
      stop("Each site `lon` must be a numeric scalar.", call. = FALSE)
    }
    if (site$lat < -90 || site$lat > 90) {
      stop("Each site `lat` must be between -90 and 90.", call. = FALSE)
    }
    if (site$lon < -180 || site$lon > 180) {
      stop("Each site `lon` must be between -180 and 180.", call. = FALSE)
    }
  }

  capacities <- params$capacity
  if (!is.numeric(capacities) || length(capacities) < 1L || any(is.na(capacities))) {
    stop("Renewables.ninja param `capacity` must be numeric.", call. = FALSE)
  }
  if (!(length(capacities) %in% c(1L, length(sites)))) {
    stop("Renewables.ninja `capacity` must be length 1 or match number of sites.", call. = FALSE)
  }
  if (any(capacities < 0)) {
    stop("Renewables.ninja `capacity` values must be >= 0.", call. = FALSE)
  }

  if (!is.character(params$date_from) || length(params$date_from) != 1L ||
      is.na(params$date_from) || !nzchar(params$date_from)) {
    stop("Renewables.ninja param `date_from` must be a non-empty character scalar.", call. = FALSE)
  }
  if (!is.character(params$date_to) || length(params$date_to) != 1L ||
      is.na(params$date_to) || !nzchar(params$date_to)) {
    stop("Renewables.ninja param `date_to` must be a non-empty character scalar.", call. = FALSE)
  }
  date_from <- as.Date(params$date_from)
  date_to <- as.Date(params$date_to)
  if (is.na(date_from) || is.na(date_to)) {
    stop("Renewables.ninja params `date_from` and `date_to` must parse as dates.", call. = FALSE)
  }
  if (date_from > date_to) {
    stop("Renewables.ninja param `date_from` must be <= `date_to`.", call. = FALSE)
  }

  if (!is.null(params$sum_sites) &&
      (!is.logical(params$sum_sites) || length(params$sum_sites) != 1L || is.na(params$sum_sites))) {
    stop("Renewables.ninja param `sum_sites` must be NULL or a logical scalar.", call. = FALSE)
  }

  if (!is.null(params$interpolate) &&
      (!is.logical(params$interpolate) || length(params$interpolate) != 1L || is.na(params$interpolate))) {
    stop("Renewables.ninja param `interpolate` must be NULL or a logical scalar.", call. = FALSE)
  }

  if (!is.null(params$height) &&
      (!is.numeric(params$height) || length(params$height) != 1L || is.na(params$height) || params$height <= 0)) {
    stop("Renewables.ninja param `height` must be NULL or a positive numeric scalar.", call. = FALSE)
  }

  if (!is.null(params$turbine) &&
      (!is.character(params$turbine) || length(params$turbine) != 1L || is.na(params$turbine) || !nzchar(params$turbine))) {
    stop("Renewables.ninja param `turbine` must be NULL or a non-empty character scalar.", call. = FALSE)
  }

  if (!is.null(params$system_loss) &&
      (!is.numeric(params$system_loss) || length(params$system_loss) != 1L || is.na(params$system_loss))) {
    stop("Renewables.ninja param `system_loss` must be NULL or a numeric scalar.", call. = FALSE)
  }

  if (!is.null(params$tilt) &&
      (!is.numeric(params$tilt) || length(params$tilt) != 1L || is.na(params$tilt))) {
    stop("Renewables.ninja param `tilt` must be NULL or a numeric scalar.", call. = FALSE)
  }

  if (!is.null(params$azim) &&
      (!is.numeric(params$azim) || length(params$azim) != 1L || is.na(params$azim))) {
    stop("Renewables.ninja param `azim` must be NULL or a numeric scalar.", call. = FALSE)
  }

  if (!is.null(params$raw) &&
      (!is.logical(params$raw) || length(params$raw) != 1L || is.na(params$raw))) {
    stop("Renewables.ninja param `raw` must be NULL or a logical scalar.", call. = FALSE)
  }

  return(invisible(TRUE))
}

#' Fetch raw Renewables.ninja response
#'
#' @description Executes one API call per site using token authentication and
#' returns raw site-level response objects.
#' @param params Validated Renewables.ninja parameter list.
#' @param token Character API token from local secrets file.
#' @return Raw connector response object ready for normalization.
fetch_renewables_ninja <- function(params, token) {
  sites <- NULL
  capacities <- NULL
  normalized_params <- NULL
  site_result <- NULL
  site_results <- list()
  request_config <- NULL
  response <- NULL
  parsed <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
    stop("token must be a non-empty character scalar.", call. = FALSE)
  }

  normalized_params <- normalize_renewables_ninja_query_params(params)
  validate_renewables_ninja_params(normalized_params)

  sites <- normalized_params$sites
  capacities <- normalized_params$capacity
  if (length(capacities) == 1L) {
    capacities <- rep(capacities, length(sites))
  }

  site_results <- vector("list", length(sites))
  for (i in seq_along(sites)) {
    request_config <- build_renewables_ninja_site_request(
      params = normalized_params,
      site = sites[[i]],
      capacity = capacities[[i]]
    )

    response <- renewables_ninja_http_get(
      url = request_config$url,
      query = request_config$query,
      token = token
    )

    parsed <- parse_renewables_ninja_payload(response)
    site_result <- list(
      site_id = i,
      site = sites[[i]],
      capacity = capacities[[i]],
      request = request_config,
      parsed = parsed
    )
    site_results[[i]] <- site_result
  }

  return(list(
    query = list(
      params = normalized_params,
      token_supplied = TRUE
    ),
    sites = site_results
  ))
}

#' Normalize Renewables.ninja result
#'
#' @description Converts raw Renewables.ninja payload into the broker standard
#' output structure, with optional site aggregation.
#' @param raw_result Raw response object returned by `fetch_renewables_ninja()`.
#' @param params Validated Renewables.ninja parameter list used for request.
#' @return Standard broker output object as a named list, excluding
#' `schema_version` (added by dispatcher).
normalize_renewables_ninja_result <- function(raw_result, params) {
  sum_sites <- FALSE
  normalized_params <- NULL
  data <- list()
  data_records <- list()
  site_series <- list()
  request_log <- list()
  units <- NULL
  unit_values <- character(0)
  source_metadata <- list()
  site_entry <- NULL
  series <- NULL

  if (!is.list(raw_result)) {
    stop("raw_result must be a list.", call. = FALSE)
  }
  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  normalized_params <- normalize_renewables_ninja_query_params(params)
  validate_renewables_ninja_params(normalized_params)
  if (!is.list(raw_result$sites)) {
    stop("raw_result$sites must be a list of site responses.", call. = FALSE)
  }

  sum_sites <- isTRUE(normalized_params$sum_sites)

  for (i in seq_along(raw_result$sites)) {
    site_entry <- raw_result$sites[[i]]
    if (!is.list(site_entry$parsed) || !is.list(site_entry$parsed$series)) {
      stop("Each raw_result site entry must include parsed series data.", call. = FALSE)
    }

    series <- site_entry$parsed$series
    site_series[[i]] <- series

    if (!is.null(site_entry$parsed$units) &&
        is.character(site_entry$parsed$units) &&
        length(site_entry$parsed$units) == 1L &&
        !is.na(site_entry$parsed$units) &&
        nzchar(site_entry$parsed$units)) {
      unit_values <- c(unit_values, site_entry$parsed$units)
    }

    request_log[[i]] <- list(
      site_id = site_entry$site_id,
      url = site_entry$request$url,
      query = site_entry$request$query
    )

    source_metadata[[i]] <- list(
      site_id = site_entry$site_id,
      site = site_entry$site,
      metadata = site_entry$parsed$metadata
    )
  }

  if (sum_sites) {
    data_records <- sum_renewables_ninja_site_series(site_series)
    data <- renewables_ninja_records_to_columns(
      records = data_records,
      fields = c("timestamp", "value")
    )
  } else {
    data_records <- list()
    for (i in seq_along(raw_result$sites)) {
      site_entry <- raw_result$sites[[i]]
      series <- site_entry$parsed$series
      if (length(series) > 0L) {
        for (j in seq_along(series)) {
          data_records[[length(data_records) + 1L]] <- list(
            site_id = site_entry$site_id,
            lat = site_entry$site$lat,
            lon = site_entry$site$lon,
            timestamp = series[[j]]$timestamp,
            value = series[[j]]$value
          )
        }
      }
    }
    data <- renewables_ninja_records_to_columns(
      records = data_records,
      fields = c("site_id", "lat", "lon", "timestamp", "value")
    )
  }

  if (length(unit_values) == 0L) {
    units <- NULL
  } else {
    unit_values <- unique(unit_values)
    if (length(unit_values) == 1L) {
      units <- unit_values[[1L]]
    } else {
      units <- as.list(unit_values)
      names(units) <- paste0("unit_", seq_along(unit_values))
    }
  }

  return(build_standard_output(
    connector = "renewables_ninja",
    query = list(
      request = raw_result$query$params,
      api_requests = request_log
    ),
    data = data,
    units = units,
    dimensions = list(
      temporal = list(
        start = normalized_params$date_from,
        end = normalized_params$date_to,
        resolution = "hourly"
      ),
      spatial = list(
        type = "point_set",
        points = normalized_params$sites
      ),
      variable = "generation",
      geography = if (sum_sites) "point_set" else "site"
    ),
    source_metadata = list(
      sum_sites = sum_sites,
      sites = source_metadata
    )
  ))
}

#' Convert record list to column-oriented lists
#'
#' @description Converts a list of row-like records into a named list of
#' parallel list columns.
#' @param records List of records to reshape.
#' @param fields Character vector of field names to extract as columns.
#' @return Named list where each field is a list aligned by row index.
renewables_ninja_records_to_columns <- function(records, fields) {
  columns <- list()
  record <- NULL
  field <- NULL

  if (!is.list(records)) {
    stop("records must be a list.", call. = FALSE)
  }

  if (!is.character(fields) || length(fields) < 1L || any(is.na(fields)) || any(!nzchar(fields))) {
    stop("fields must be a non-empty character vector.", call. = FALSE)
  }

  columns <- vector("list", length(fields))
  names(columns) <- fields
  for (i in seq_along(fields)) {
    columns[[fields[[i]]]] <- vector("list", length(records))
  }

  for (i in seq_along(records)) {
    record <- records[[i]]
    if (!is.list(record)) {
      stop("Each record must be a list.", call. = FALSE)
    }
    for (j in seq_along(fields)) {
      field <- fields[[j]]
      columns[[field]][[i]] <- record[[field]]
    }
  }

  return(columns)
}

#' Read Renewables.ninja token
#'
#' @description Reads and returns the Renewables.ninja token from secrets YAML.
#' @param secrets_path Character path to local secrets YAML.
#' @return Character API token.
get_renewables_ninja_token <- function(secrets_path = "config/secrets.yaml") {
  secrets <- NULL
  token <- NULL

  if (!is.character(secrets_path) || length(secrets_path) != 1L || !nzchar(secrets_path)) {
    stop("secrets_path must be a non-empty character scalar.", call. = FALSE)
  }

  secrets <- read_secrets(path = secrets_path)
  token <- secrets$renewables_ninja$token

  if (!is.character(token) || length(token) != 1L || is.na(token) || !nzchar(token)) {
    stop("Missing renewables_ninja token in secrets file: ", secrets_path, call. = FALSE)
  }

  if (identical(token, "YOUR_TOKEN_HERE")) {
    stop("Replace placeholder renewables_ninja token in secrets file: ", secrets_path, call. = FALSE)
  }

  return(token)
}

#' Build site request configuration
#'
#' @description Builds endpoint and query list for a single site API call.
#' @param params Validated Renewables.ninja parameter list.
#' @param site Named list containing `lat` and `lon`.
#' @param capacity Numeric capacity value for the selected site.
#' @return Named list containing endpoint, query parameters, and headers.
build_renewables_ninja_site_request <- function(params, site, capacity) {
  query <- NULL
  passthrough <- NULL
  normalized_params <- NULL
  model_name <- NULL
  drop_keys <- c("technology", "sites", "capacity", "sum_sites")

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.list(site)) {
    stop("site must be a list.", call. = FALSE)
  }

  if (!is.numeric(capacity) || length(capacity) != 1L) {
    stop("capacity must be a numeric scalar.", call. = FALSE)
  }

  if (!is.numeric(site$lat) || length(site$lat) != 1L || is.na(site$lat)) {
    stop("site$lat must be a numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(site$lon) || length(site$lon) != 1L || is.na(site$lon)) {
    stop("site$lon must be a numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(capacity) || is.na(capacity)) {
    stop("capacity must be a non-NA numeric scalar.", call. = FALSE)
  }

  normalized_params <- normalize_renewables_ninja_query_params(params)
  validate_renewables_ninja_params(normalized_params)

  passthrough <- normalized_params[setdiff(names(normalized_params), drop_keys)]
  query <- c(
    passthrough,
    list(
      lat = as.numeric(site$lat),
      lon = as.numeric(site$lon),
      capacity = as.numeric(capacity)
    )
  )

  if (is.null(query$interpolate)) {
    query$interpolate <- TRUE
  }
  if (is.null(query$format)) {
    query$format <- "json"
  }

  model_name <- normalized_params$technology
  if (identical(model_name, "solar")) {
    model_name <- "pv"
  }

  return(list(
    url = paste0("https://www.renewables.ninja/api/data/", model_name),
    query = query,
    headers = list(
      Accept = "application/json"
    )
  ))
}

#' Parse Renewables.ninja payload
#'
#' @description Parses a site-level Renewables.ninja response in JSON or CSV
#' form into a common internal structure.
#' @param raw_payload Raw response content from one site request.
#' @return Named list containing normalized time series rows and metadata.
parse_renewables_ninja_payload <- function(raw_payload) {
  content_type <- NULL
  body <- NULL
  parsed <- NULL
  data_obj <- NULL
  metadata <- list()
  units <- NULL
  series <- list()
  timestamps <- NULL
  values <- NULL
  body_lines <- NULL
  metadata_line <- NULL
  metadata_json <- NULL
  data_lines <- NULL
  data_text <- NULL

  if (!is.list(raw_payload)) {
    stop("raw_payload must be a list.", call. = FALSE)
  }

  content_type <- tolower(if (!is.null(raw_payload$content_type)) raw_payload$content_type else "")
  body <- raw_payload$body
  if (is.null(body)) {
    stop("raw_payload$body must be provided.", call. = FALSE)
  }

  if (is.character(body) && length(body) == 1L &&
      (grepl("json", content_type, fixed = TRUE) || grepl("^\\s*\\{", body))) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      stop("Package 'jsonlite' is required to parse JSON payloads.", call. = FALSE)
    }
    parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
    data_obj <- parsed$data
    if (is.null(data_obj) && is.list(parsed) && !is.null(parsed$values)) {
      data_obj <- parsed$values
    }
    if (is.null(data_obj)) {
      stop("JSON payload missing expected `data` values.", call. = FALSE)
    }
    if (!is.null(parsed$metadata) && is.list(parsed$metadata)) {
      metadata <- parsed$metadata
      if (!is.null(parsed$metadata$units) && is.character(parsed$metadata$units)) {
        units <- parsed$metadata$units[[1L]]
      }
    }

    if (is.data.frame(data_obj)) {
      timestamps <- as.character(data_obj[[1L]])
      values <- as.numeric(data_obj[[2L]])
      for (i in seq_along(timestamps)) {
        series[[i]] <- list(timestamp = normalize_renewables_ninja_timestamp(timestamps[[i]]), value = values[[i]])
      }
    } else if (is.list(data_obj) && !is.null(names(data_obj))) {
      timestamps <- names(data_obj)
      values <- unlist(data_obj, use.names = FALSE)
      for (i in seq_along(timestamps)) {
        series[[i]] <- list(
          timestamp = normalize_renewables_ninja_timestamp(timestamps[[i]]),
          value = as.numeric(values[[i]])
        )
      }
    } else if (is.list(data_obj) && length(data_obj) > 0L &&
               is.list(data_obj[[1L]]) && !is.null(data_obj[[1L]]$timestamp)) {
      series <- lapply(data_obj, function(entry) {
        entry$timestamp <- normalize_renewables_ninja_timestamp(entry$timestamp)
        entry
      })
    } else {
      stop("Unsupported JSON data shape in Renewables.ninja payload.", call. = FALSE)
    }
  } else {
    if (!is.character(body) || length(body) != 1L) {
      stop("CSV payload must be a single character string.", call. = FALSE)
    }

    body_lines <- strsplit(body, "\n", fixed = TRUE)[[1L]]
    metadata_line <- body_lines[grepl("^#\\s*\\{", body_lines)]
    if (length(metadata_line) > 0L && requireNamespace("jsonlite", quietly = TRUE)) {
      metadata_json <- sub("^#\\s*", "", metadata_line[[1L]])
      metadata <- tryCatch(
        jsonlite::fromJSON(metadata_json, simplifyVector = FALSE),
        error = function(e) {
          list()
        }
      )
      if (is.list(metadata$units) &&
          !is.null(metadata$units$electricity) &&
          is.character(metadata$units$electricity) &&
          length(metadata$units$electricity) == 1L) {
        units <- metadata$units$electricity
      }
    }

    data_lines <- body_lines[!grepl("^\\s*#", body_lines)]
    data_lines <- data_lines[nzchar(trimws(data_lines))]
    data_text <- paste(data_lines, collapse = "\n")

    parsed <- utils::read.csv(text = data_text, stringsAsFactors = FALSE, check.names = FALSE)
    if (ncol(parsed) < 2L) {
      stop("CSV payload must contain at least timestamp and value columns.", call. = FALSE)
    }
    timestamps <- as.character(parsed[[1L]])
    values <- as.numeric(parsed[[2L]])
    for (i in seq_along(timestamps)) {
      series[[i]] <- list(timestamp = normalize_renewables_ninja_timestamp(timestamps[[i]]), value = values[[i]])
    }
  }

  return(list(
    series = series,
    metadata = metadata,
    units = units
  ))
}

#' Aggregate site series
#'
#' @description Sums hourly values across multiple site series when
#' `sum_sites = TRUE`.
#' @param site_series List of site-level time series records.
#' @return Aggregated time series list with one value per timestamp.
sum_renewables_ninja_site_series <- function(site_series) {
  sums <- list()
  timestamp <- NULL
  value <- NULL
  combined <- list()
  ordered_timestamps <- NULL

  if (!is.list(site_series)) {
    stop("site_series must be a list.", call. = FALSE)
  }

  if (length(site_series) == 0L) {
    return(list())
  }

  for (i in seq_along(site_series)) {
    if (!is.list(site_series[[i]])) {
      stop("Each site series must be a list of timestamp/value records.", call. = FALSE)
    }

    for (j in seq_along(site_series[[i]])) {
      timestamp <- site_series[[i]][[j]]$timestamp
      value <- site_series[[i]][[j]]$value

      if (!is.character(timestamp) || length(timestamp) != 1L || is.na(timestamp) || !nzchar(timestamp)) {
        stop("Each series record must include a non-empty character `timestamp`.", call. = FALSE)
      }

      if (is.null(value)) {
        value <- NA_real_
      } else {
        value <- suppressWarnings(as.numeric(value))
      }

      if (is.null(sums[[timestamp]])) {
        sums[[timestamp]] <- value
      } else {
        if (is.na(sums[[timestamp]]) || is.na(value)) {
          sums[[timestamp]] <- NA_real_
        } else {
          sums[[timestamp]] <- sums[[timestamp]] + value
        }
      }
    }
  }

  ordered_timestamps <- sort(names(sums))
  combined <- vector("list", length(ordered_timestamps))
  for (i in seq_along(ordered_timestamps)) {
    combined[[i]] <- list(
      timestamp = ordered_timestamps[[i]],
      value = sums[[ordered_timestamps[[i]]]]
    )
  }

  return(combined)
}

# Internal HTTP wrapper to enable deterministic unit testing of fetch logic.
renewables_ninja_http_get <- function(url, query, token) {
  req <- NULL
  resp <- NULL
  status_code <- NULL
  body <- NULL

  req <- httr2::request(url)
  req <- do.call(httr2::req_url_query, c(list(req), query))
  req <- httr2::req_headers(req, Authorization = paste("Token", token))
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      stop_with_connector_error("renewables_ninja", conditionMessage(e))
    }
  )

  status_code <- httr2::resp_status(resp)

  body <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(e) {
      stop_with_connector_error("renewables_ninja", paste0("Failed to read response body: ", conditionMessage(e)))
    }
  )

  if (status_code >= 400L) {
    stop_with_connector_error(
      connector = "renewables_ninja",
      message = paste0("API request failed. ", trimws(body)),
      status_code = status_code
    )
  }

  return(list(
    status_code = status_code,
    content_type = httr2::resp_header(resp, "content-type"),
    body = body
  ))
}

normalize_renewables_ninja_query_params <- function(params) {
  normalized <- params

  if (is.character(normalized$technology) &&
      length(normalized$technology) == 1L &&
      !is.na(normalized$technology)) {
    normalized$technology <- tolower(normalized$technology)
  }

  if (length(normalized$capacity) == 1L) {
    normalized$capacity <- rep(normalized$capacity, length(normalized$sites))
  }
  if (is.null(normalized$sum_sites)) {
    normalized$sum_sites <- FALSE
  }
  if (is.null(normalized$interpolate)) {
    normalized$interpolate <- TRUE
  }

  if (identical(normalized$technology, "wind")) {
    if (is.null(normalized$height)) {
      normalized$height <- 100
    }
    if (is.null(normalized$turbine)) {
      normalized$turbine <- "Vestas+V80+2000"
    }
  }

  if (identical(normalized$technology, "solar")) {
    if (is.null(normalized$system_loss)) {
      normalized$system_loss <- 0.1
    }
    if (is.null(normalized$tilt)) {
      normalized$tilt <- 35
    }
    if (is.null(normalized$azim)) {
      normalized$azim <- 180
    }
    if (is.null(normalized$raw)) {
      normalized$raw <- FALSE
    }
  }

  if (!is.null(normalized$turbine) && is.character(normalized$turbine)) {
    normalized$turbine <- gsub("\\+", " ", normalized$turbine)
  }

  return(normalized)
}

normalize_renewables_ninja_timestamp <- function(timestamp) {
  ts_char <- NULL
  ts_numeric <- NULL
  ts_posix <- NULL

  if (inherits(timestamp, "POSIXt")) {
    ts_posix <- as.POSIXct(timestamp, tz = "UTC")
    return(format(ts_posix, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  }

  ts_char <- as.character(timestamp)
  if (length(ts_char) != 1L || is.na(ts_char) || !nzchar(ts_char)) {
    stop("timestamp must be a non-empty scalar value.", call. = FALSE)
  }

  if (grepl("^[0-9]+$", ts_char)) {
    ts_numeric <- suppressWarnings(as.numeric(ts_char))
    if (nchar(ts_char) >= 13L) {
      ts_numeric <- ts_numeric / 1000
    }
    ts_posix <- as.POSIXct(ts_numeric, origin = "1970-01-01", tz = "UTC")
    return(format(ts_posix, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  }

  ts_posix <- suppressWarnings(as.POSIXct(ts_char, tz = "UTC"))
  if (!is.na(ts_posix)) {
    return(format(ts_posix, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  }

  return(ts_char)
}
