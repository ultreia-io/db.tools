# Survey database resources

`database.yaml` opens an in-memory SQLite database for the getting-started guide.

`postgresql.yaml` shows application-owned connection settings with a session environment reference for the password.

`queries/numbers.sql` selects values above one bound parameter from the synthetic `numbers` table.

The caller supplies its DBI driver, creates the example data and owns connection cleanup.

The H2 guide generates its own temporary SQL backup; no database file or private data is bundled.
