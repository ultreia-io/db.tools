# Maintainer guide

Work on `develop`. `main` contains releases.

## Code organization

| File                  | Responsibility                                        |
|-----------------------|-------------------------------------------------------|
| `database.R`          | Public connection, query and SQL-file operations.      |
| `database-internal.R` | Configuration markers, validation and cleanup helpers. |
| `h2.R`                | Public H2 backup connection provider.                  |
| `h2-internal.R`       | H2 settings, restoration and failed-restore cleanup.    |
| `db.tools-package.R`  | Package-level documentation.                           |

Each area has one public API file and one internal helper file.

The package owns database operations; consumers own form models, application schemas and export rules.

## Local verification

Install development dependencies, LaTeX, Java and RJDBC, then run from the package root:

```sh
# Select a compatible H2 driver supplied by your environment.
export H2_JAR=/path/to/h2-2.5.252.jar
# Generate documentation, run tests and CRAN checks, then build the website.
Rscript tools/check.R
```

The workflow includes examples, vignettes, the PDF manual and CRAN incoming checks.

Without RJDBC or `H2_JAR`, H2 tests and executable H2 vignette chunks are skipped.

Set both for comprehensive verification. No test opens a user backup.

Archives and check output stay in `build/`.

Local and CI checks share the CRAN mirror settings in `tools/check.Renviron`.

The Build workflow checks Linux release/devel, macOS and Windows.

CI configures Java 21 and verifies the H2 2.5.252 driver checksum before running the existing H2 tests.

Coverage runs once after successful Linux release checks and uploads to Codecov using `CODECOV_TOKEN`.

The organization provides this secret. Fork pull requests can upload coverage without making upload errors fail checks.

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

## Repository settings

Both `main` and `develop` are protected against force pushes and deletion.

GitHub Pages uses Actions and accepts deployments only from protected branches.

Run the Website workflow from `develop` or `main`; its `ref` input selects the commit or tag to document.
