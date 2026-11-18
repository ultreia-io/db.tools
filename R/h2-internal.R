# Internal helpers ----------------------------------------------------------

#' Format H2 restoration settings as URL options
#' @param settings Named character vector of scalar H2 setting values.
#' @return A URL suffix containing validated uppercase names and their values.
#'   Empty settings produce empty text. Duplicate names, missing values, URL
#'   separators and provider-managed options raise an error.
#' @keywords internal
h2_backup_settings <- function(settings) {
  if (!is.character(settings) || anyNA(settings)) stop("settings must be a named character vector", call. = FALSE)
  if (!length(settings)) return("")
  keys <- toupper(names(settings))
  managed <- c("URL", "USER", "PASSWORD", "INIT", "IFEXISTS", "ACCESS_MODE_DATA",
    "DB_CLOSE_DELAY", "DB_CLOSE_ON_EXIT", "AUTO_SERVER")
  if (length(keys) != length(settings) || anyNA(keys) || any(!grepl("^[A-Z][A-Z0-9_]*$", keys)) ||
      anyDuplicated(keys) || any(keys %in% managed) || any(!nzchar(settings)) ||
      any(grepl("[;\\\\\r\n]", settings)))
    stop("Invalid or provider-managed H2 settings", call. = FALSE)
  paste0(";", paste(paste0(keys, "=", settings), collapse = ";"))
}

#' Restore an H2 script into a newly owned directory
#' @param backup_file Normalized path to a trusted SQL backup.
#' @param driver Caller-supplied H2 JDBC driver.
#' @param directory New destination directory with an existing parent.
#' @param database_url Local JDBC URL used for initial database creation.
#' @param connection_url URL used to reopen the completed database.
#' @param user,password Database administrator credentials supplied by the caller.
#' @return An open JDBC connection to the restored database. On failure, closes
#'   any restore connection and removes only the directory created by this call.
#' @details Directory creation reserves the destination before any SQL runs.
#'   Existing paths, including empty directories, are never used or removed.
#' @keywords internal
h2_restore_backup <- function(backup_file, driver, directory, database_url, connection_url, user, password) {
  if (!dir.create(directory, showWarnings = FALSE, mode = "0700"))
    stop("Cannot create H2 directory; it must be a new path with an existing parent: ", directory, call. = FALSE)
  connection <- NULL
  complete <- FALSE
  on.exit({
    if (!complete) {
      if (!is.null(connection)) {
        # SHUTDOWN also releases files if a partially executed script changed the close delay.
        try(RJDBC::dbSendUpdate(connection, "SHUTDOWN"), silent = TRUE)
        try(DBI::dbDisconnect(connection), silent = TRUE)
      }
      unlink(directory, recursive = TRUE)
    }
  }, add = TRUE)
  compressed <- identical(readBin(backup_file, "raw", n = 2L), as.raw(c(31L, 139L)))
  connection <- DBI::dbConnect(driver, database_url, user, password)
  statement <- paste0("RUNSCRIPT FROM ", DBI::dbQuoteString(connection, backup_file),
    if (compressed) " COMPRESSION GZIP" else "", " CHARSET 'UTF-8'")
  RJDBC::dbSendUpdate(connection, statement)
  RJDBC::dbSendUpdate(connection, "SET DB_CLOSE_DELAY 0")
  RJDBC::dbSendUpdate(connection, "SHUTDOWN")
  DBI::dbDisconnect(connection)
  connection <- NULL
  connection <- DBI::dbConnect(driver, connection_url, user, password)
  complete <- TRUE
  connection
}
