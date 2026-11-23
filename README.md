# db.tools

[![Build](https://img.shields.io/github/actions/workflow/status/ultreia-io/db.tools/Build.yaml?branch=develop&label=Build&logo=githubactions&logoColor=white)](https://github.com/ultreia-io/db.tools/actions/workflows/Build.yaml?query=branch%3Adevelop)
[![Website](https://img.shields.io/badge/website-documentation-blue?logo=readthedocs&logoColor=white)](https://ultreia-io.github.io/db.tools/index.html)
[![License](https://img.shields.io/badge/license-LGPL--2.1-blue?logo=gnu&logoColor=white)](https://github.com/ultreia-io/db.tools/blob/main/LICENSE)

[![Latest release](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fultreia-io%2Fdb.tools%2Freleases%2Flatest&query=%24.tag_name&label=Latest%20release&color=blue&logo=github&logoColor=white)](https://github.com/ultreia-io/db.tools/releases/latest)
![CRAN release](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fcrandb.r-pkg.org%2Fdb.tools&query=%24.Version&label=CRAN%20release&color=brightgreen&logo=r&logoColor=white)

[![Coverage develop](https://img.shields.io/codecov/c/github/ultreia-io/db.tools/develop?label=coverage%20develop&logo=codecov)](https://app.codecov.io/gh/ultreia-io/db.tools/tree/develop)
[![Coverage main](https://img.shields.io/codecov/c/github/ultreia-io/db.tools/main?label=coverage%20main&logo=codecov)](https://app.codecov.io/gh/ultreia-io/db.tools/tree/main)

## About this project

`db.tools` provides reusable database operations for R applications built on DBI.

Callers supply their drivers, connection settings and SQL. Database schemas and form models remain in consumers.

See [Terminology][terminology] for the concepts used throughout the documentation.

## Features

**Connections and configuration**

- Open DBI connections from application-owned YAML.
- Resolve secrets from explicit session environment references.
- Scope a connection to a callback and close it after success or failure.

**Queries and SQL resources**

- Execute parameterized queries and return `data.table` results.
- Read SQL from explicit UTF-8 files.
- Keep parameter binding and database types under the selected driver's control.

**H2 backups**

- Restore plain or gzip-compressed SQL backups into new temporary or persistent directories.
- Supply fresh connections to the restored database without restoring it again.
- Protect existing files and clean up unsuccessful restores.
- Use the optional RJDBC backend with a caller-selected H2 jar.

## Related packages

- [db.atlas](https://github.com/ultreia-io/db.atlas) extracts schema metadata and generates documentation.
- `ros.db.atlas` applies the atlas engine to the ROS database.
- [form.tools](https://github.com/ultreia-io/form.tools) loads model-defined tables and operates on workbooks.

## Installation

### CRAN

Once `db.tools` is available on CRAN, install it with `install.packages()`.

```r
install.packages("db.tools")
```

### GitHub release

Install `pak` once, then use it to install the latest GitHub release.

```r
install.packages("pak")
pak::pak("ultreia-io/db.tools@*release")
```

### Development version

With `pak` installed, install from the `develop` branch.

```r
pak::pak("ultreia-io/db.tools@develop")
```

Install the DBI driver appropriate to your database separately.

For H2 backups, install RJDBC and supply a compatible H2 driver jar.

## Getting started

Use your DBI `driver` and a YAML file with its connection settings.

```r
library(db.tools)

connection_provider <- function() db_connect_from_yaml(driver, "database.yaml")
with_db_connection(connection_provider, function(connection) {
  db_query(connection, "SELECT 1")
})
```

`with_db_connection()` opens the connection through the provider and closes it when the query finishes.

For a runnable example that creates its own temporary H2 database, see the [getting-started guide][getting-started].

## Guides

- [Terminology][terminology]
- [Getting started][getting-started]
- [H2 SQL backups][h2]
- [Package resources][resources]
- [Function reference][reference]

[terminology]: https://ultreia-io.github.io/db.tools/articles/terminology.html
[getting-started]: https://ultreia-io.github.io/db.tools/articles/database.html
[h2]: https://ultreia-io.github.io/db.tools/articles/h2.html
[resources]: https://ultreia-io.github.io/db.tools/articles/resources.html
[reference]: https://ultreia-io.github.io/db.tools/reference/
