# Public operations ---------------------------------------------------------

#' Create a connection provider from an H2 SQL backup
#'
#' Restore a trusted H2 SQL script once and supply a fresh connection on each
#' call. Use the provider with [with_db_connection()] and execute queries with
#' [db_query()] through the supplied connection.
#' @param backup_file Path to an existing H2 SQL backup, either plain SQL or gzip
#'   compressed SQL such as `.sql.gz`. Compression is detected from its header.
#' @param driver H2 JDBC driver created by `RJDBC::JDBC()` with a compatible H2
#'   jar supplied by the caller. No driver is downloaded or selected implicitly.
#' @param directory New directory for the restored database. Its parent must
#'   exist. NA selects a unique [base::tempfile()] path under the R session's
#'   temporary directory. Existing paths are never overwritten or reused.
#' @param user Database administrator name used to create and reopen the restored
#'   database. Defaults to `"sa"`; it is independent of application accounts.
#' @param password Database password, supplied by the caller, possibly from a
#'   session environment variable or keyring. Defaults to an empty password.
#' @param read_only Whether supplied connections open the restored database in
#'   read-only mode. Restoration itself requires a writable connection.
#' @param settings Named character vector of H2 URL settings, for example
#'   `c(DATABASE_TO_LOWER = "TRUE")` for a backup requiring lowercase identifiers.
#'   Lifecycle, authentication and initialization settings are managed internally.
#' @return A zero-argument function returning a new caller-owned JDBC connection.
#'   Its `directory` attribute gives the normalized destination; its `url`
#'   attribute gives the reopening URL without credentials.
#' @details The first invocation creates the directory and runs H2's `RUNSCRIPT`
#'   with UTF-8 decoding. H2 streams compressed scripts without an intermediate
#'   decompressed file. A failed restore closes its connections and removes the
#'   newly created directory; the backup remains unchanged.
#'
#'   Later calls to the same provider reopen the restored database with
#'   `IFEXISTS=TRUE`, without rerunning the script or rereading the backup.
#'   Removing that database makes later calls fail rather than create an empty one.
#'   A new provider never adopts a pre-existing directory. Reopen persistent
#'   databases across R sessions using the returned URL and [DBI::dbConnect()].
#'
#'   Closing a supplied connection does not delete the database. A temporary
#'   database remains available until normal R-session cleanup; an explicit
#'   directory persists. After all connections are closed, the caller can remove
#'   the directory obtained from `attr(provider, "directory")`.
#'
#'   The restore connection resets H2's close delay to zero before shutting down,
#'   so closing the last supplied connection releases the database files.
#'   The SQL script is trusted executable input, not a schema migration mechanism.
#'   Application defaults and legacy H2 conversion belong to the caller.
#' @seealso [db_query()], [with_db_connection()], [db_connect_from_yaml()]
#' @export
h2_backup_connection_provider <- function(backup_file, driver, directory = NA_character_,
                                          user = "sa", password = "", read_only = TRUE,
                                          settings = character()) {
  database_text(backup_file, "backup_file")
  if (!file.exists(backup_file) || dir.exists(backup_file) || file.access(backup_file, 4L) != 0L)
    stop("backup_file must be an existing readable SQL backup", call. = FALSE)
  backup_file <- normalizePath(backup_file, winslash = "/", mustWork = TRUE)
  if (!requireNamespace("RJDBC", quietly = TRUE)) stop("Install RJDBC to restore H2 backups", call. = FALSE)
  if (!inherits(driver, "JDBCDriver")) stop("driver must be an H2 JDBC driver", call. = FALSE)
  database_text(user, "user")
  if (!is.character(password) || length(password) != 1L || is.na(password))
    stop("password must be one character value", call. = FALSE)
  if (!is.logical(read_only) || length(read_only) != 1L || is.na(read_only))
    stop("read_only must be TRUE or FALSE", call. = FALSE)
  if ((is.character(directory) || is.logical(directory)) && length(directory) == 1L && is.na(directory))
    directory <- tempfile("db-tools-h2-")
  database_text(directory, "directory")
  directory <- path.expand(directory)
  directory <- file.path(normalizePath(dirname(directory), winslash = "/", mustWork = TRUE), basename(directory))
  if (grepl("[;\\\\]", directory)) stop("directory cannot contain H2 URL separators", call. = FALSE)
  options <- h2_backup_settings(settings)
  database_url <- paste0("jdbc:h2:file:", file.path(directory, "database"), options)
  connection_url <- paste0(database_url, ";IFEXISTS=TRUE", if (read_only) ";ACCESS_MODE_DATA=r" else "")
  restored <- FALSE
  # Restore lazily; subsequent calls return independent connections to the same database.
  provider <- function() {
    if (!restored) {
      connection <- h2_restore_backup(backup_file, driver, directory, database_url, connection_url, user, password)
      restored <<- TRUE
      return(connection)
    }
    DBI::dbConnect(driver, connection_url, user, password)
  }
  attr(provider, "directory") <- directory
  attr(provider, "url") <- connection_url
  provider
}
