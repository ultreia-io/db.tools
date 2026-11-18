# Require a usable H2 driver before the maintainer checks start.
local({
  jar <- path.expand(Sys.getenv("H2_JAR"))
  if (!nzchar(jar) || !file.exists(jar) || dir.exists(jar) || file.access(jar, 4L) != 0L)
    stop("Set H2_JAR to the path of a readable H2 JDBC driver JAR.", call. = FALSE)
  jar <- normalizePath(jar, winslash = "/", mustWork = TRUE)

  # Check the file itself even if Java already has an H2 driver on its classpath.
  entries <- tryCatch(utils::unzip(jar, list = TRUE), error = function(error) NULL)
  if (!"org/h2/Driver.class" %in% entries$Name)
    stop("H2_JAR does not contain the H2 JDBC driver: ", jar, call. = FALSE)

  tryCatch(loadNamespace("RJDBC"), error = function(error)
    stop("RJDBC must be installed and loadable. ", conditionMessage(error), call. = FALSE))
  tryCatch(RJDBC::JDBC("org.h2.Driver", jar), error = function(error)
    stop("Cannot load the H2 JDBC driver from H2_JAR. ", conditionMessage(error), call. = FALSE))

  # Keep relative paths working when R CMD build or check changes directory.
  Sys.setenv(H2_JAR = jar)
})
