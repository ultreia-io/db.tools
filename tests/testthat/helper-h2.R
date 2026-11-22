h2_test_driver <- function() {
  skip_if_not_installed("RJDBC")
  jar <- Sys.getenv("H2_JAR")
  skip_if(!nzchar(jar) || !file.exists(jar), "Set H2_JAR to the H2 JDBC driver jar")
  RJDBC::JDBC("org.h2.Driver", jar, identifier.quote = '"')
}

h2_test_url <- function(directory, lower_case = TRUE) {
  paste0("jdbc:h2:file:", file.path(directory, basename(tempfile("h2-"))),
    if (lower_case) ";DATABASE_TO_LOWER=TRUE" else "")
}
