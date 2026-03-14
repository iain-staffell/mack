project_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(project_root, "main.R"))

with_temp_bindings <- function(bindings, code) {
  names_to_bind <- names(bindings)
  had_binding <- logical(length(names_to_bind))
  old_bindings <- vector("list", length(names_to_bind))
  names(had_binding) <- names_to_bind
  names(old_bindings) <- names_to_bind

  for (nm in names_to_bind) {
    had_binding[[nm]] <- exists(nm, envir = globalenv(), inherits = FALSE)
    if (had_binding[[nm]]) {
      old_bindings[[nm]] <- get(nm, envir = globalenv(), inherits = FALSE)
    }
    assign(nm, bindings[[nm]], envir = globalenv())
  }

  on.exit({
    for (nm in names_to_bind) {
      if (had_binding[[nm]]) {
        assign(nm, old_bindings[[nm]], envir = globalenv())
      } else if (exists(nm, envir = globalenv(), inherits = FALSE)) {
        rm(list = nm, envir = globalenv())
      }
    }
  }, add = TRUE)

  force(code)
}
