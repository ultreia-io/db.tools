# Survey database resources

## Run the H2 example

With RJDBC installed, set `H2_JAR` to the path of a compatible H2 JAR and follow the getting-started guide.

1. The example builds the JDBC URL from a temporary path and sets `SURVEY_H2_URL` for `database.yaml`.
2. H2 creates the database when the example connects. The example loads and queries sample data.
3. The example closes the connection and removes the temporary files.

## Bundled files

- `database.yaml` reads the temporary H2 URL and supplies the connection settings.
- `queries/numbers.sql` selects rows from the sample `numbers` table using a bound lower limit.
- `postgresql.yaml` shows how to read a PostgreSQL password from a session environment variable.
- `backups/numbers.sql` contains sample data for the H2 restore guide.
