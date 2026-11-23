# Maintainer guide

Work on `develop`. `main` contains releases.

## Code organization

| File                 | Responsibility                                      |
|----------------------|-----------------------------------------------------|
| `database.R`         | Connection, query and SQL file operations.          |
| `h2.R`               | H2 backup restoration and connection providers.     |
| `db.tools-package.R` | Package documentation.                              |

Internal helpers follow the public functions in each file.

The package owns database operations; consumers own form models, application schemas and export rules.

## Local verification

Install the development dependencies, LaTeX, Java and RJDBC. Run this from the package root.

```sh
export H2_JAR=/path/to/h2.jar
Rscript tools/check.R
```

The script generates documentation, runs tests and `R CMD check --as-cran`, and builds the website.

Local and GitHub checks stop early if RJDBC or the H2 driver cannot load.

Plain `R CMD check`, as run by CRAN, skips H2 tests and examples when the optional driver setup is absent.

Check results and source archives are written to `build/`.

GitHub Actions checks Linux with R release and R-devel, plus macOS and Windows with R release.

## Examples and website

Packaged resources live in `inst/examples/survey/`. Update the corresponding guide when changing them.

```r
# Prepare individual downloads and the archive named with the package version.
source("tools/prepare-site-assets.R")
# Build the website using the generated manuals and articles.
pkgdown::build_site()
```

Website dependencies are declared in `Config/Needs/website`.

Edit `README.md` directly. Roxygen generates `NAMESPACE` and `man/`.

## GitHub release

1. Prepare the stable version, NEWS and CRAN check evidence on `develop`.
2. Run the complete local checks and resolve their findings.
3. Commit with `[db.tools] Release <version>`, then push when authorized.
4. Run **Start Release** on `develop`.
5. Review the release PR and wait for all checks before merging it.

**Publish Release** checks the merged commit, publishes its archive and checksum, and submits that archive to CRAN.

The website uses the same released commit. Confirm CRAN's email after submission.

For an interrupted CRAN submission, inspect its release markers and job log before retrying.

The manual **Publish Release** action accepts an existing tag and retries submission without rebuilding the archive.

## License

LGPL-2.1. See [LICENSE](LICENSE).
