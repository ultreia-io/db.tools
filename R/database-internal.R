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
