test_that("db_query returns a data table", {
  driver <- h2_test_driver()
  directory <- withr::local_tempdir()
  connection <- DBI::dbConnect(driver, h2_test_url(directory), "sa", "")
  withr::defer(DBI::dbDisconnect(connection))

  DBI::dbWriteTable(connection, "numbers", data.frame(amount = 1:3))
  result <- db_query(
    connection,
    "SELECT amount FROM numbers WHERE amount > ? ORDER BY amount",
    params = list(1)
  )

  expect_s3_class(result, "data.table")
  expect_equal(result$amount, 2:3)
})

test_that("db_query preserves columns for an empty result", {
  driver <- h2_test_driver()
  directory <- withr::local_tempdir()
  connection <- DBI::dbConnect(driver, h2_test_url(directory), "sa", "")
  withr::defer(DBI::dbDisconnect(connection))

  DBI::dbWriteTable(connection, "numbers", data.frame(amount = 1:3))
  result <- db_query(
    connection,
    "SELECT amount FROM numbers WHERE amount > ?",
    list = list(99)
  )

  expect_s3_class(result, "data.table")
  expect_identical(names(result), "amount")
  expect_equal(nrow(result), 0L)
})

test_that("db_query validates SQL input", {
  expect_error(db_query(NULL, character()), "`sql`")
  expect_error(db_query(NULL, ""), "`sql`")
  expect_error(db_query(NULL, NA_character_), "`sql`")
  expect_error(db_query(NULL, c("SELECT 1", "SELECT 2")), "`sql`")
})
