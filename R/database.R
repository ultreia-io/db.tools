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
#' @seealso [Getting started](https://ultreia-io.github.io/db.tools/articles/database.html)
#' @export
#'
#' @examples
#' \dontrun{
#' # Keep the connection unopened until the provider is called.
#' connection_provider <- function() db_connect_from_yaml(driver, "database.yaml")
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
#' @seealso [Getting started](https://ultreia-io.github.io/db.tools/articles/database.html)
#' @export
#'
#' @examples
#' \dontrun{
#' connection_provider <- function() db_connect_from_yaml(driver, "database.yaml")
#' with_db_connection(connection_provider, function(connection) {
#'   db_query(connection, "SELECT 1")
#' })
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
#' @seealso [Getting started](https://ultreia-io.github.io/db.tools/articles/database.html)
#' @export
#'
#' @examples
#' \dontrun{
#' # Bind the lower limit on an open RJDBC connection.
#' db_query(connection, "SELECT amount FROM numbers WHERE amount > ?", list = list(2))
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

# Internal helpers ----------------------------------------------------------

#' An environment variable reference in connection YAML
#'
#' A character vector with classes `db.tools_yaml_environment_variable` and
#' `character`. Its value is an environment variable name, never a secret.
#' The YAML `!env` handler creates this internal marker. Connection configuration
#' resolves it immediately before calling DBI; it is not a connection object.
#' There are no S3 methods for this marker. Configure it through YAML rather
#' than constructing it directly.
#' @name db.tools_yaml_environment_variable-class
#' @seealso [db_connect_from_yaml()]
#' @keywords internal
NULL

#' Mark a YAML value for environment resolution
#' @param variable Environment variable name supplied by the YAML handler.
#' @return A character value carrying the internal environment-reference class.
#' @keywords internal
mark_yaml_environment_variable <- function(variable) {
  structure(
    variable,
    class = c("db.tools_yaml_environment_variable", "character")
  )
}

#' Resolve environment markers in nested connection configuration
#' @param value A parsed YAML value, list, or environment marker.
#' @return The value with markers replaced by their environment values.
#' @keywords internal
resolve_yaml_environment_variables <- function(value) {
  if (inherits(value, "db.tools_yaml_environment_variable")) {
    return(read_yaml_environment_variable(unclass(value)))
  }
  if (is.list(value)) {
    return(lapply(value, resolve_yaml_environment_variables))
  }
  value
}

#' Read a required configuration environment variable
#' @param variable One valid environment variable name.
#' @return Its character value; invalid or unset names raise an error.
#' @keywords internal
read_yaml_environment_variable <- function(variable) {
  if (
    !is.character(variable) || length(variable) != 1L ||
      is.na(variable) ||
      !grepl("^[A-Za-z_][A-Za-z0-9_]*$", variable)
  ) {
    stop("`!env` must name one valid environment variable.", call. = FALSE)
  }

  value <- Sys.getenv(variable, unset = NA_character_)
  if (is.na(value)) {
    stop(
      "Environment variable `", variable,
      "` referenced by YAML configuration is not set.",
      call. = FALSE
    )
  }
  value
}

#' Inspect connection validity without propagating driver errors
#' @param connection Candidate DBI connection.
#' @return TRUE only when DBI reports a valid connection.
#' @keywords internal
is_valid_db_connection <- function(connection) {
  tryCatch(
    isTRUE(DBI::dbIsValid(connection)),
    error = function(error) FALSE
  )
}

#' Close a connection owned by a scoped operation
#' @param connection Connection returned by the caller's provider.
#' @return Invisibly TRUE after disconnection or FALSE when already closed or
#'   disconnection fails. A failed disconnection emits a warning.
#' @keywords internal
disconnect_db_connection <- function(connection) {
  if (!is_valid_db_connection(connection)) {
    return(invisible(FALSE))
  }

  tryCatch(
    {
      DBI::dbDisconnect(connection)
      invisible(TRUE)
    },
    error = function(error) {
      warning(
        "Could not disconnect the DBI connection: ",
        conditionMessage(error),
        call. = FALSE
      )
      invisible(FALSE)
    }
  )
}

#' Check one required text argument
#' @param value Value supplied by the caller.
#' @param name Argument name used in diagnostics.
#' @return The unchanged character value, or an error for an invalid value.
#' @keywords internal
database_text <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value))
    stop(name, " must be a non-empty string", call. = FALSE)
  value
}
