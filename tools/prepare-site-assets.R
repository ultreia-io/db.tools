# Identify the resource archive with the package version being built.
resources_version <- read.dcf("DESCRIPTION", fields = "Version")[[1L]]
resources_archive <- paste0("db.tools-resources-", resources_version, ".zip")

# Replace generated downloads with the current packaged examples.
website_assets <- "pkgdown/assets"
unlink(website_assets, recursive = TRUE)
dir.create(website_assets, recursive = TRUE, showWarnings = FALSE)
if (!file.copy("inst/examples", website_assets, recursive = TRUE, overwrite = TRUE))
  stop("Could not prepare package resource downloads.", call. = FALSE)

# Keep the archive layout identical to the installed resources.
zip::zipr(resources_archive, "examples", root = website_assets)

# Publish the licence linked from the website.
if (!file.copy("LICENSE", file.path(website_assets, "LICENSE"), overwrite = TRUE))
  stop("Could not prepare the website licence.", call. = FALSE)
