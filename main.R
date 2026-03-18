# main.R
#
# Main entry-point for loading broker source files and running the broker.

# Internal guard to avoid repeated re-sourcing when main.R is sourced multiple times.
.broker_runtime_loaded <- FALSE
.broker_main_file <- tryCatch(
  normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = TRUE),
  error = function(e) {
    NULL
  }
)

# Validate whether a path looks like the MACK project root.
is_valid_root_path <- function(path) {
  if (is.null(path) || !is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    return(FALSE)
  }
  return(
    file.exists(file.path(path, "main.R")) &&
      file.exists(file.path(path, "R", "broker_fetch.R"))
  )
}

# Discover project root from current working directory and nearby folders.
discover_root_from_wd <- function() {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  candidates <- character(0)
  parent <- cwd
  previous <- ""
  subdirs <- character(0)

  candidates <- c(candidates, cwd)
  while (!identical(parent, previous)) {
    previous <- parent
    parent <- dirname(parent)
    if (!identical(parent, previous)) {
      candidates <- c(candidates, parent)
    }
  }

  candidates <- unique(candidates)
  for (i in seq_along(candidates)) {
    if (is_valid_root_path(candidates[[i]])) {
      return(candidates[[i]])
    }

    subdirs <- list.dirs(candidates[[i]], recursive = FALSE, full.names = TRUE)
    if (length(subdirs) > 0L) {
      for (j in seq_along(subdirs)) {
        if (is_valid_root_path(subdirs[[j]])) {
          return(subdirs[[j]])
        }
      }
    }
  }

  return(NULL)
}

# Resolve project root path from the location of this main.R file.
resolve_root_path <- function() {
  root_path <- NULL

  if (!is.null(.broker_main_file) &&
      is.character(.broker_main_file) &&
      length(.broker_main_file) == 1L &&
      !is.na(.broker_main_file) &&
      nzchar(.broker_main_file)) {
    root_path <- dirname(.broker_main_file)
    if (is_valid_root_path(root_path)) {
      return(root_path)
    }
  }

  root_path <- discover_root_from_wd()
  if (is_valid_root_path(root_path)) {
    return(root_path)
  }

  stop("Could not resolve project root containing main.R and R/broker_fetch.R.", call. = FALSE)
}

#' Load broker runtime source files
#'
#' @description Loads all required broker R files into the current environment.
#' @param force Logical; when `TRUE`, always re-source files.
#' @return Invisibly returns `TRUE` when runtime files are loaded.
load_broker_runtime <- function(force = FALSE) {
  root_path <- NULL
  required_files <- NULL
  candidate <- NULL

  if (!is.logical(force) || length(force) != 1L || is.na(force)) {
    stop("force must be a non-NA logical scalar.", call. = FALSE)
  }

  if (!force && isTRUE(.broker_runtime_loaded)) {
    return(invisible(TRUE))
  }

  root_path <- resolve_root_path()

  required_files <- c(
    file.path(root_path, "R", "utils.R"),
    file.path(root_path, "R", "validate_request.R"),
    file.path(root_path, "R", "export_result.R"),
    file.path(root_path, "R", "connectors", "world_bank.R"),
    file.path(root_path, "R", "connectors", "renewables_ninja.R"),
    file.path(root_path, "R", "broker_fetch.R")
  )

  for (i in seq_along(required_files)) {
    candidate <- required_files[[i]]
    if (!file.exists(candidate)) {
      stop("Required runtime file not found: ", candidate, call. = FALSE)
    }
    source(candidate)
  }

  .broker_runtime_loaded <<- TRUE
  return(invisible(TRUE))
}

# Load runtime dependencies immediately when main.R is sourced.
load_broker_runtime()

#' Run broker from request object or request file
#'
#' @description Executes the broker from either:
#' 1) an in-memory request list, or
#' 2) a character path to JSON/YAML request file.
#' If `request$output` includes both `format` and a non-empty `file`, this
#' function also exports the result to disk.
#' @param request Either a request list (`source`, `params`, optional `output`) or a
#' character path to request file.
#' @param secrets_path Character path to YAML secrets file. If `NULL`,
#' defaults to `config/secrets.yaml` relative to project root.
#' @return A standard broker output object as a named list.
run_mack <- function(request, secrets_path = NULL) {
  root_path <- NULL
  request_object <- NULL
  output <- NULL
  result <- NULL

  load_broker_runtime()

  if (is.null(secrets_path)) {
    root_path <- resolve_root_path()
    secrets_path <- file.path(root_path, "config", "secrets.yaml")
  }

  if (is.character(request) && length(request) == 1L && !is.na(request) && nzchar(request)) {
    request_object <- read_request_file(request)
  } else if (is.list(request)) {
    request_object <- request
  } else {
    stop("request must be either a request list or a request file path.", call. = FALSE)
  }

  result <- broker_fetch(request = request_object, secrets_path = secrets_path)

  output <- request_object$output
  if (!is.null(output) && is.list(output) &&
      !is.null(output$format) &&
      is.character(output$format) &&
      length(output$format) == 1L &&
      !is.na(output$format) &&
      nzchar(output$format) &&
      !is.null(output$file) &&
      is.character(output$file) &&
      length(output$file) == 1L &&
      !is.na(output$file) &&
      nzchar(output$file)) {
    export_result(result = result, format = output$format, file = output$file)
  }

  return(result)
}
