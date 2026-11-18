# Contributing

Develop on `develop`. Use `feature/` branches only when requested, with pull requests targeting `develop`.

Keep the package independent of form models and application schemas. Callers supply drivers and credentials.

Tests and examples use synthetic data and temporary databases without private credentials or services.

Explain proposed regressions and obtain approval before adding tests or assertions.

Edit `README.md` directly. Regenerate `man/*.Rd` and `NAMESPACE` after changing roxygen documentation.

Run the checks in [DEVELOPMENT.md](DEVELOPMENT.md) before requesting review.

Contributions are licensed under LGPL-2.1.
