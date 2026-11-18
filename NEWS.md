# db.tools 0.1.0

* Initialize db.tools as a standalone package, retaining the reusable database helpers developed in dbiutils.
* Open DBI connections from YAML with explicit session environment references.
* Execute bound queries as data.table objects and read SQL from UTF-8 files.
* Manage connections through caller-supplied providers and scoped cleanup.
* Restore H2 SQL backups into temporary or persistent directories, with reusable read-only connections.
* Provide synthetic examples, regression tests, generated manuals and versioned resource downloads.
* Align local checks, CI, documentation and release workflows with form.references.
