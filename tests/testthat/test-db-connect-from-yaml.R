test_that("db_connect_from_yaml creates a DBI connection", {
  driver <- h2_test_driver()
  directory <- withr::local_tempdir()
  config_file <- file.path(directory, "database.yaml")
  yaml::write_yaml(list(url = h2_test_url(directory), user = "sa", password = ""), config_file)

  connection <- db_connect_from_yaml(driver, config_file)
  withr::defer(DBI::dbDisconnect(connection))

  expect_true(DBI::dbIsValid(connection))
  expect_equal(DBI::dbGetQuery(connection, "SELECT 1 AS amount")$amount, 1L)
})

test_that("db_connect_from_yaml validates its inputs", {
  directory <- withr::local_tempdir()
  config_file <- file.path(directory, "database.yaml")
  yaml::write_yaml(list(url = h2_test_url(directory)), config_file)

  expect_error(db_connect_from_yaml(NULL, config_file), "`drv`")
  driver <- h2_test_driver()
  expect_error(
    db_connect_from_yaml(driver, character()),
    "`config_file`"
  )
  expect_error(
    db_connect_from_yaml(driver, file.path(directory, "missing.yaml")),
    "not found"
  )
  expect_error(
    db_connect_from_yaml(driver, directory),
    "not found"
  )
})

test_that("db_connect_from_yaml requires a connection mapping", {
  driver <- h2_test_driver()
  config_file <- file.path(withr::local_tempdir(), "database.yaml")

  writeLines("- one\n- two", config_file, useBytes = TRUE)
  expect_error(
    db_connect_from_yaml(driver, config_file),
    "top-level mapping"
  )

  writeLines("drv: forbidden", config_file, useBytes = TRUE)
  expect_error(
    db_connect_from_yaml(driver, config_file),
    "must not contain a `drv`"
  )
})

test_that("YAML configuration resolves explicit environment references", {
  driver <- h2_test_driver()
  directory <- withr::local_tempdir()
  withr::local_envvar(c(SURVEY_H2_URL = h2_test_url(directory)))
  config_file <- system.file("examples", "survey", "database.yaml", package = "db.tools")

  connection <- db_connect_from_yaml(driver, config_file)
  withr::defer(DBI::dbDisconnect(connection))
  expect_true(DBI::dbIsValid(connection))
})

test_that("YAML environment references must be valid and available", {
  driver <- h2_test_driver()
  variable <- "DB_TOOLS_TEST_MISSING_VALUE"
  withr::local_envvar(c(DB_TOOLS_TEST_MISSING_VALUE = NA_character_))

  config_file <- file.path(withr::local_tempdir(), "database.yaml")
  writeLines(paste("url: !env", variable), config_file, useBytes = TRUE)
  expect_error(
    db_connect_from_yaml(driver, config_file),
    paste0("Environment variable `", variable, "`.*not set")
  )

  writeLines("url: !env invalid-name", config_file, useBytes = TRUE)
  expect_error(
    db_connect_from_yaml(driver, config_file),
    "must name one valid environment variable"
  )
})
