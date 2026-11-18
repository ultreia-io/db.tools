# Security policy

Report vulnerabilities privately through [GitHub advisories][advisories].

If private reporting is unavailable, contact the maintainer at `dev@tchemit.fr`.

Do not include credentials, connection dumps or private database contents in public issues or logs.

Use YAML `!env` references for secrets provided by the current session or your secret manager.

Connection configuration is trusted input passed to the caller-selected DBI driver.

SQL queries and H2 backups are executable input. Use trusted files and database accounts with suitable permissions.

H2 restoration reserves a new directory and never adopts or overwrites an existing destination.

Restored databases may contain private data. Close all connections before removing their files.

[advisories]: https://github.com/ultreia-io/db.tools/security/advisories/new
