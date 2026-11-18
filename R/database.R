# Public operations ---------------------------------------------------------

#' Connect to a database using YAML configuration
#'
#' Reads connection arguments from a YAML file and passes them to
#' [DBI::dbConnect()]. The YAML document must contain a top-level mapping whose
#' keys are connection argument names supported by the selected DBI driver.
#'
#' Values tagged with `!env` are read from environment variables. For example,
#' `password: !env APPLICATION_DB_PASSWORD` keeps the password out of the YAML
#' file. An error is raised if the referenced variable is not set.
#'
#' For local development, the optional `keyring` package can retrieve a secret
#' from the operating system credential store. Copy that value into the
#' referenced environment variable for the duration of the R session, then
#' unset the variable when the database work is complete. CI and production
#' should inject the same variable from their secret manager.
#'
#' `db.tools` does not select or import a database driver. The consuming
#' application supplies the driver and remains responsible for installing it.
#'
#' @param drv A [DBI::DBIDriver-class] object created by the consuming
#'   application.
#' @param config_file A path to a UTF-8 YAML file containing named connection
#'   arguments.
#'
#' @return A [DBI::DBIConnection-class] object returned by [DBI::dbConnect()].
#' @export
#'
#' @examples
#' if (requireNamespace("RSQLite", quietly = TRUE)) {
#'   config_file <- tempfile(fileext = ".yaml")
#'   writeLines("dbname: ':memory:'", config_file, useBytes = TRUE)
#'
#'   connection <- db_connect_from_yaml(RSQLite::SQLite(), config_file)
#'   DBI::dbDisconnect(connection)
#' }
db_connect_from_yaml <- function(drv, config_file) {
  if (!inherits(drv, "DBIDriver")) {
    stop("`drv` must be a DBI driver.", call. = FALSE)
  }
  if (
    !is.character(config_file) || length(config_file) != 1L ||
      is.na(config_file) || !nzchar(config_file)
  ) {
    stop("`config_file` must be one non-empty path.", call. = FALSE)
  }
  if (!file.exists(config_file) || dir.exists(config_file)) {
    stop("YAML configuration file not found: ", config_file, call. = FALSE)
  }

  config <- yaml::read_yaml(
    config_file,
    fileEncoding = "UTF-8",
    handlers = list(env = mark_yaml_environment_variable)
  )
  if (
    !is.list(config) || is.null(names(config)) || !length(config) ||
      any(is.na(names(config))) || any(!nzchar(names(config)))
  ) {
    stop(
      "YAML configuration must contain a non-empty top-level mapping.",
      call. = FALSE
    )
  }
  if ("drv" %in% names(config)) {
    stop("YAML configuration must not contain a `drv` entry.", call. = FALSE)
  }

  config <- lapply(config, resolve_yaml_environment_variables)
  do.call(DBI::dbConnect, c(list(drv = drv), config))
}

#' Use and automatically close a DBI connection
#'
#' Obtains a connection from `connection_provider`, passes it to `code`, and
#' closes it when `code` finishes. The connection is also closed when `code`
#' raises an error. A connection that has already been closed by `code` is not
#' closed a second time.
#'
#' `with_db_connection()` owns the connection returned by the provider. Do not
#' use it when the provider returns a shared connection whose lifecycle is
#' managed elsewhere.
#'
#' @param connection_provider A zero-argument function returning a valid
#'   [DBI::DBIConnection-class].
#' @param code A function taking the connection as its only argument.
#'
#' @return The value returned by `code`.
#' @export
#'
#' @examples
#' if (requireNamespace("RSQLite", quietly = TRUE)) {
#'   connection_provider <- function() {
#'     DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'   }
#'
#'   with_db_connection(connection_provider, function(connection) {
#'     DBI::dbGetQuery(connection, "SELECT 1 AS value")
#'   })
#' }
with_db_connection <- function(connection_provider, code) {
  if (!is.function(connection_provider)) {
    stop("`connection_provider` must be a function.", call. = FALSE)
  }
  if (!is.function(code)) {
    stop("`code` must be a function.", call. = FALSE)
  }

  connection <- connection_provider()
  if (!is_valid_db_connection(connection)) {
    stop(
      "`connection_provider` did not return a valid DBI connection.",
      call. = FALSE
    )
  }

  on.exit(disconnect_db_connection(connection), add = TRUE)
  code(connection)
}

#' Execute a query and return a data table
#'
#' Executes a SQL query through a [DBI::DBIConnection-class] and converts the result
#' to a [data.table::data.table]. The function is independent of the concrete
#' DBI backend used by the connection.
#'
#' @param connection A valid [DBI::DBIConnection-class].
#' @param sql A character scalar containing the SQL statement to execute.
#' @param params An optional list of values to bind to parameter placeholders.
#'   The placeholder syntax is defined by the DBI backend.
#' @param ... Additional arguments passed to [DBI::dbGetQuery()].
#'
#' @return A [data.table::data.table] containing the query result.
#' @export
#'
#' @examples
#' if (requireNamespace("RSQLite", quietly = TRUE)) {
#'   connection <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'
#'   DBI::dbWriteTable(connection, "numbers", data.frame(value = 1:3))
#'   db_query(connection, "SELECT * FROM numbers WHERE value > ?", list(1))
#'   DBI::dbDisconnect(connection)
#' }
db_query <- function(connection, sql, params = NULL, ...) {
  invalid_sql <- !is.character(sql) ||
    length(sql) != 1L ||
    is.na(sql) ||
    !nzchar(sql)

  if (invalid_sql) {
    stop("`sql` must be a single, non-empty character value.", call. = FALSE)
  }

  result <- DBI::dbGetQuery(
    conn = connection,
    statement = sql,
    params = params,
    ...
  )

  data.table::as.data.table(result)
}

#' Read a SQL statement from a file
#'
#' Reads an explicitly located text file using UTF-8 by default and joins its
#' lines with newline characters. No assumption is made about the current
#' working directory or the location of a project-level `sql` directory.
#'
#' @param path A character scalar containing the path to a SQL file.
#' @param encoding The text encoding passed to [base::readLines()].
#'
#' @return A character scalar containing the SQL statement.
#' @export
#'
#' @examples
#' sql_file <- tempfile(fileext = ".sql")
#' writeLines(c("SELECT *", "FROM example;"), sql_file)
#' read_sql_file(sql_file)
read_sql_file <- function(path, encoding = "UTF-8") {
  invalid_path <- !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !nzchar(path)

  if (invalid_path) {
    stop("`path` must be a single, non-empty character value.", call. = FALSE)
  }

  invalid_encoding <- !is.character(encoding) ||
    length(encoding) != 1L ||
    is.na(encoding) ||
    !nzchar(encoding)

  if (invalid_encoding) {
    stop("`encoding` must be a single, non-empty character value.", call. = FALSE)
  }

  expanded_path <- path.expand(path)
  if (!file.exists(expanded_path) || dir.exists(expanded_path)) {
    stop("SQL file not found: ", path, call. = FALSE)
  }

  paste(
    readLines(expanded_path, warn = FALSE, encoding = encoding),
    collapse = "\n"
  )
}
