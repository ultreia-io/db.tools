# Supply the same caller-selected H2 driver used by SQL loading tests.
backup_h2_driver <- function() {
  skip_if_not_installed("RJDBC")
  jar <- Sys.getenv("H2_JAR")
  skip_if(!nzchar(jar) || !file.exists(jar), "Set H2_JAR to the H2 JDBC driver jar")
  RJDBC::JDBC("org.h2.Driver", jar, identifier.quote = '"')
}

# Generate a real H2 backup containing related survey data and difficult text values.
write_h2_backup <- function(driver, path, compressed = TRUE, lower_case = TRUE) {
  connection <- DBI::dbConnect(driver, paste0("jdbc:h2:mem:", basename(tempfile("backup-")),
    if (lower_case) ";DATABASE_TO_LOWER=TRUE" else ""), "sa", "")
  on.exit(DBI::dbDisconnect(connection))
  DBI::dbWriteTable(connection, "surveys", data.frame(id = c("S01", "S02")))
  DBI::dbWriteTable(connection, "observations", data.frame(survey = c("S01", "S02"), count = c(3L, 8L)))
  DBI::dbWriteTable(connection, "notes", data.frame(id = c("001", "002", "003"),
    text = c("Two lines;\nL'\u00e9t\u00e9", NA_character_, "")))
  invisible(db_query(connection, paste0("SCRIPT NOPASSWORDS NOSETTINGS TO ",
    DBI::dbQuoteString(connection, path), if (compressed) " COMPRESSION GZIP" else "")))
}

test_that("a gzip backup supplies a temporary read-only database", {
  driver <- backup_h2_driver()
  directory <- withr::local_tempdir()
  backup <- file.path(directory, "survey's backup.sql.gz")
  write_h2_backup(driver, backup)
  checksum <- tools::md5sum(backup)
  provider <- h2_backup_connection_provider(backup, driver, settings = c(DATABASE_TO_LOWER = "TRUE"))
  destination <- attr(provider, "directory")
  on.exit(unlink(destination, recursive = TRUE))
  expect_true(startsWith(destination, paste0(normalizePath(tempdir(), winslash = "/"), "/")))
  expect_false(dir.exists(destination))
  connection <- provider()
  tryCatch({
    tables <- list(
      surveys = db_query(connection, "SELECT id FROM surveys WHERE id = ?", list = list("S01")),
      observations = db_query(connection, "SELECT survey, count FROM observations WHERE survey = ?", list = list("S01")))
    expect_identical(tables$surveys$id, "S01")
    expect_identical(tables$observations$count, 3)
    notes <- db_query(connection, "SELECT id, text FROM notes ORDER BY id")
    expect_identical(notes$id, c("001", "002", "003"))
    expect_identical(notes$text, c("Two lines;\nL'\u00e9t\u00e9", NA_character_, ""))
    expect_error(RJDBC::dbSendUpdate(connection, "DELETE FROM surveys"), "read.only|not allowed")
  }, finally = DBI::dbDisconnect(connection))
  expect_true(file.exists(file.path(destination, "database.mv.db")))
  expect_identical(tools::md5sum(backup), checksum)
})

test_that("persistent providers reopen fresh connections without restoring again", {
  driver <- backup_h2_driver()
  directory <- withr::local_tempdir()
  backup <- file.path(directory, "survey.sql")
  write_h2_backup(driver, backup, compressed = FALSE)
  destination <- file.path(directory, "restored database")
  provider <- h2_backup_connection_provider(backup, driver, destination,
    read_only = FALSE, settings = c(DATABASE_TO_LOWER = "TRUE"))
  first <- provider()
  tryCatch(RJDBC::dbSendUpdate(first, "UPDATE observations SET count = 12 WHERE survey = 'S01'"),
    finally = DBI::dbDisconnect(first))
  unlink(backup)
  observed_connection <- NULL
  count <- with_db_connection(provider, function(connection) {
    observed_connection <<- connection
    db_query(connection, "SELECT count FROM observations WHERE survey = ?", list = list("S01"))$count
  })
  expect_identical(count, 12)
  expect_false(DBI::dbIsValid(observed_connection))
  expect_true(dir.exists(destination))
  expect_error(with_db_connection(provider, function(connection) {
    observed_connection <<- connection
    stop("consumer failure")
  }), "consumer failure")
  expect_false(DBI::dbIsValid(observed_connection))
  # A saved credential-free URL also opens the persistent database independently.
  reopened <- DBI::dbConnect(driver, attr(provider, "url"), "sa", "")
  expect_true(DBI::dbIsValid(reopened))
  DBI::dbDisconnect(reopened)
  unlink(destination, recursive = TRUE)
  expect_error(provider(), "not found|does not exist")
  expect_false(dir.exists(destination))
})

test_that("failed restores remove their files and can be retried", {
  driver <- backup_h2_driver()
  directory <- withr::local_tempdir()
  backup <- file.path(directory, "broken.sql.gz")
  output <- gzfile(backup, "wt")
  writeLines(c("CREATE TABLE partial (id INTEGER);", "THIS IS INVALID SQL;"), output)
  close(output)
  destination <- file.path(directory, "failed-restore")
  provider <- h2_backup_connection_provider(backup, driver, destination)
  expect_error(provider(), "Syntax error")
  expect_false(dir.exists(destination))
  unlink(backup)
  write_h2_backup(driver, backup, lower_case = FALSE)
  connection <- provider()
  tryCatch({
    expect_true(DBI::dbIsValid(connection))
    expect_identical(db_query(connection, 'SELECT id AS "id" FROM surveys ORDER BY id')$id,
      c("S01", "S02"))
  }, finally = DBI::dbDisconnect(connection))
})

test_that("providers protect pre-existing directories and files", {
  driver <- backup_h2_driver()
  directory <- withr::local_tempdir()
  backup <- file.path(directory, "survey.sql.gz")
  write_h2_backup(driver, backup)
  existing <- file.path(directory, "existing")
  dir.create(existing)
  provider <- h2_backup_connection_provider(backup, driver, existing)
  expect_error(provider(), "must be a new path")
  expect_true(dir.exists(existing))
  sentinel <- file.path(existing, "keep.txt")
  writeLines("Keep this file", sentinel)
  expect_error(provider(), "must be a new path")
  expect_identical(readLines(sentinel), "Keep this file")
  provider <- h2_backup_connection_provider(backup, driver, sentinel)
  expect_error(provider(), "must be a new path")
  expect_identical(readLines(sentinel), "Keep this file")
})
