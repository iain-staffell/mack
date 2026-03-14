# connectors/world_bank.R
#
# World Bank connector implementation and helper functions.

#' Validate World Bank parameters
#'
#' @description Validates source-specific `params` for World Bank requests.
#' @param params Named list expected to include `country`, `indicator`, and `years`.
#' @return Invisibly returns `TRUE` when parameters are valid; otherwise errors.
validate_world_bank_params <- function(params) {
  years <- NULL
  indicators <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.character(params$country) || length(params$country) != 1L || is.na(params$country)) {
    stop("World Bank param `country` must be a non-NA character scalar.", call. = FALSE)
  }
  if (!grepl("^[A-Za-z]{3}$", params$country)) {
    stop("World Bank param `country` must be a 3-letter ISO3 code.", call. = FALSE)
  }

  indicators <- params$indicator
  if (!is.character(indicators) || length(indicators) < 1L || any(is.na(indicators)) || any(!nzchar(indicators))) {
    stop("World Bank param `indicator` must be a non-empty character vector.", call. = FALSE)
  }
  if (length(indicators) > 60L) {
    stop("World Bank supports at most 60 indicators per request.", call. = FALSE)
  }

  years <- params$years
  if (!is.numeric(years) || length(years) != 2L || any(is.na(years))) {
    stop("World Bank param `years` must be a numeric vector of length 2.", call. = FALSE)
  }
  years <- as.integer(years)
  if (years[1L] > years[2L]) {
    stop("World Bank param `years` start must be <= end.", call. = FALSE)
  }

  if (!is.null(params$per_page)) {
    if (!is.numeric(params$per_page) || length(params$per_page) != 1L || is.na(params$per_page)) {
      stop("World Bank param `per_page` must be NULL or a numeric scalar.", call. = FALSE)
    }
    if (as.integer(params$per_page) < 1L) {
      stop("World Bank param `per_page` must be >= 1.", call. = FALSE)
    }
  }

  return(invisible(TRUE))
}

#' Fetch raw World Bank response
#'
#' @description Executes one or more HTTP calls to the World Bank API,
#' including pagination when needed, and returns raw response content.
#' @param params Validated World Bank parameter list.
#' @return Raw connector response object ready for normalization.
fetch_world_bank <- function(params) {
  per_page <- 1000L
  current_page <- 1L
  total_pages <- 1L
  combined_rows <- list()
  request_page_one <- NULL
  page_metadata <- NULL
  request_config <- NULL
  response <- NULL
  parsed_page <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  validate_world_bank_params(params)

  if (!is.null(params$per_page)) {
    per_page <- as.integer(params$per_page)
  }

  repeat {
    request_config <- build_world_bank_request(params = params, page = current_page, per_page = per_page)
    if (current_page == 1L) {
      request_page_one <- request_config
    }

    response <- world_bank_http_get(url = request_config$url, query = request_config$query)
    parsed_page <- parse_world_bank_payload(response$body)

    if (is.null(page_metadata)) {
      page_metadata <- parsed_page$metadata
    }

    if (length(parsed_page$rows) > 0L) {
      combined_rows <- c(combined_rows, parsed_page$rows)
    }

    if (!is.null(parsed_page$metadata$pages)) {
      total_pages <- as.integer(parsed_page$metadata$pages)
    }

    if (current_page >= total_pages) {
      break
    }

    current_page <- current_page + 1L
  }

  return(list(
    request = request_page_one,
    rows = combined_rows,
    page_metadata = page_metadata,
    pages_fetched = current_page
  ))
}

#' Normalize World Bank result
#'
#' @description Converts raw World Bank API payload into the broker standard
#' output structure.
#' @param raw_result Raw response object returned by `fetch_world_bank()`.
#' @param params Validated World Bank parameter list used for the request.
#' @return Standard broker output object as a named list, excluding
#' `schema_version` (added by dispatcher).
normalize_world_bank_result <- function(raw_result, params) {
  parsed_payload <- NULL
  rows <- list()
  record <- NULL
  value <- NULL
  data_records <- list()
  units <- NULL
  query <- NULL
  dimensions <- NULL

  if (!is.list(raw_result)) {
    stop("raw_result must be a list.", call. = FALSE)
  }
  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  validate_world_bank_params(params)

  if (!is.list(raw_result$rows)) {
    stop("raw_result$rows must be a list of API row objects.", call. = FALSE)
  }

  parsed_payload <- list(
    metadata = raw_result$page_metadata,
    rows = raw_result$rows
  )
  units <- extract_world_bank_units(parsed_payload)
  rows <- raw_result$rows

  if (length(rows) > 0L) {
    data_records <- vector("list", length(rows))
    for (i in seq_along(rows)) {
      record <- rows[[i]]
      value <- record$value
      if (is.null(value)) {
        value <- NULL
      } else if (is.numeric(value)) {
        value <- as.numeric(value)
      }

      data_records[[i]] <- list(
        country = if (!is.null(record$countryiso3code)) record$countryiso3code else params$country,
        indicator = if (!is.null(record$indicator$id)) record$indicator$id else NA_character_,
        year = suppressWarnings(as.integer(record$date)),
        value = value
      )
    }
  }

  query <- list(
    url = raw_result$request$url,
    params = raw_result$request$query
  )

  dimensions <- list(
    temporal = list(
      start = as.character(as.integer(params$years[1L])),
      end = as.character(as.integer(params$years[2L])),
      resolution = "annual"
    ),
    spatial = list(
      type = "country",
      id = toupper(params$country)
    ),
    variable = "indicator",
    index = list(time = "year", geography = "country", variable = "indicator")
  )

  return(build_standard_output(
    connector = "world_bank",
    query = query,
    data = data_records,
    units = units,
    dimensions = dimensions,
    source_metadata = list(
      pages_fetched = raw_result$pages_fetched,
      page_metadata = raw_result$page_metadata
    )
  ))
}

#' Build World Bank API request configuration
#'
#' @description Constructs URL, query parameters, and paging values for a
#' single World Bank API call.
#' @param params Validated World Bank parameter list.
#' @param page Integer page number to request.
#' @param per_page Integer page size requested from API.
#' @return Named list containing request URL and query fields.
build_world_bank_request <- function(params, page = 1L, per_page = 1000L) {
  indicators <- NULL
  country <- NULL
  years <- NULL

  if (!is.list(params)) {
    stop("params must be a list.", call. = FALSE)
  }

  if (!is.numeric(page) || length(page) != 1L || is.na(page)) {
    stop("page must be a numeric scalar.", call. = FALSE)
  }

  if (!is.numeric(per_page) || length(per_page) != 1L || is.na(per_page)) {
    stop("per_page must be a numeric scalar.", call. = FALSE)
  }

  validate_world_bank_params(params)

  if (as.integer(page) < 1L) {
    stop("page must be >= 1.", call. = FALSE)
  }
  if (as.integer(per_page) < 1L) {
    stop("per_page must be >= 1.", call. = FALSE)
  }

  country <- toupper(params$country)
  indicators <- paste(params$indicator, collapse = ";")
  years <- as.integer(params$years)

  return(list(
    url = paste0("https://api.worldbank.org/v2/country/", country, "/indicator/", indicators),
    query = list(
      format = "json",
      date = paste0(years[1L], ":", years[2L]),
      page = as.integer(page),
      per_page = as.integer(per_page)
    )
  ))
}

#' Parse World Bank API payload
#'
#' @description Parses raw HTTP body into a normalized intermediate structure
#' for downstream output mapping.
#' @param raw_payload Raw decoded API payload from World Bank.
#' @return Named list containing parsed records and metadata.
parse_world_bank_payload <- function(raw_payload) {
  metadata <- NULL
  rows <- NULL
  pages_value <- NULL
  message_item <- NULL
  message_value <- NULL

  if (!is.list(raw_payload) || length(raw_payload) < 1L) {
    stop_with_connector_error("world_bank", "World Bank payload is empty or not list-like.")
  }

  # World Bank returns API errors as a one-element list containing message text.
  if (length(raw_payload) == 1L &&
      is.list(raw_payload[[1L]]) &&
      !is.null(raw_payload[[1L]]$message)) {
    message_item <- raw_payload[[1L]]$message[[1L]]
    message_value <- NULL
    if (is.list(message_item) && !is.null(message_item$value)) {
      message_value <- message_item$value
    }
    if (!is.character(message_value) || length(message_value) != 1L || is.na(message_value) || !nzchar(message_value)) {
      message_value <- "World Bank API returned an error."
    }
    stop_with_connector_error("world_bank", message_value)
  }

  if (length(raw_payload) < 2L) {
    stop_with_connector_error("world_bank", "World Bank payload missing metadata or data rows.")
  }

  metadata <- raw_payload[[1L]]
  rows <- raw_payload[[2L]]

  if (!is.list(metadata)) {
    stop("World Bank metadata must be a list.", call. = FALSE)
  }
  if (is.null(rows)) {
    rows <- list()
  }
  if (!is.list(rows)) {
    stop("World Bank rows must be a list.", call. = FALSE)
  }

  pages_value <- suppressWarnings(as.integer(metadata$pages))
  if (is.na(pages_value) || pages_value < 1L) {
    pages_value <- 1L
  }

  return(list(
    metadata = list(
      page = suppressWarnings(as.integer(metadata$page)),
      pages = pages_value,
      per_page = suppressWarnings(as.integer(metadata$per_page)),
      total = suppressWarnings(as.integer(metadata$total))
    ),
    rows = rows
  ))
}

#' Extract World Bank units metadata
#'
#' @description Pulls indicator unit metadata from parsed World Bank payload.
#' @param parsed_payload Parsed payload from `parse_world_bank_payload()`.
#' @return Unit metadata as character scalar, named list, or `NULL`.
extract_world_bank_units <- function(parsed_payload) {
  rows <- NULL
  units <- list()
  row <- NULL
  indicator_id <- NULL
  unit_value <- NULL

  if (!is.list(parsed_payload) || !is.list(parsed_payload$rows)) {
    stop("parsed_payload must contain a list `rows`.", call. = FALSE)
  }

  rows <- parsed_payload$rows
  if (length(rows) == 0L) {
    return(NULL)
  }

  for (i in seq_along(rows)) {
    row <- rows[[i]]
    indicator_id <- NULL
    unit_value <- NULL

    if (is.list(row$indicator) && !is.null(row$indicator$id) &&
        is.character(row$indicator$id) && length(row$indicator$id) == 1L &&
        !is.na(row$indicator$id) && nzchar(row$indicator$id)) {
      indicator_id <- row$indicator$id
    }

    if (!is.null(row$unit) && is.character(row$unit) && length(row$unit) == 1L &&
        !is.na(row$unit) && nzchar(row$unit)) {
      unit_value <- row$unit
    }

    if (!is.null(indicator_id) && !is.null(unit_value) && is.null(units[[indicator_id]])) {
      units[[indicator_id]] <- unit_value
    }
  }

  if (length(units) == 0L) {
    return(NULL)
  }
  if (length(units) == 1L) {
    return(units[[1L]])
  }

  return(units)
}

# Internal HTTP wrapper to enable deterministic unit testing of fetch logic.
world_bank_http_get <- function(url, query) {
  req <- NULL
  resp <- NULL
  body <- NULL
  status_code <- NULL

  req <- httr2::request(url)
  req <- do.call(httr2::req_url_query, c(list(req), query))

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      stop_with_connector_error("world_bank", conditionMessage(e))
    }
  )

  status_code <- httr2::resp_status(resp)
  if (status_code >= 400L) {
    stop_with_connector_error(
      connector = "world_bank",
      message = "API request failed.",
      status_code = status_code
    )
  }

  body <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) {
      stop_with_connector_error("world_bank", paste0("Failed to parse JSON response: ", conditionMessage(e)))
    }
  )

  return(list(
    status_code = status_code,
    body = body
  ))
}
