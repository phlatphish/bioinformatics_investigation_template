# paths.R -- read config/paths.tsv so scripts never hard-code absolute paths.
#
#   source(file.path(repo_root, "scripts/lib/paths.R"))
#   out <- path_for("results", "m01_qc", run_id)
#
# The table is found from Sys.getenv("INVESTIGATION_PATHS"), or by walking up
# from the working directory to the first config/paths.tsv. Base R only.

paths_file <- function() {
  env <- Sys.getenv("INVESTIGATION_PATHS")
  if (nzchar(env)) return(env)
  d <- normalizePath(getwd())
  repeat {
    f <- file.path(d, "config", "paths.tsv")
    if (file.exists(f)) return(f)
    up <- dirname(d)
    if (up == d) stop("config/paths.tsv not found; set INVESTIGATION_PATHS")
    d <- up
  }
}

path_for <- function(key, ...) {
  tab <- utils::read.delim(paths_file(), comment.char = "#", colClasses = "character")
  hit <- tab$path[tab$key == key]
  if (length(hit) != 1) stop("Unknown path key '", key, "' in ", paths_file())
  file.path(hit, ...)
}
