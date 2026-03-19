# Agent Instructions for MACK

This file gives coding agents the repository-specific rules they should follow when working in MACK.

Humans usually do not need to read this file, but it is the right place to check how agent-driven work is expected to behave in this repository.

For contributor-facing guidance, see `docs/_extending_mack.md`.

This repository supports agent-assisted connector development.

If a user asks for a new connector, do not ask them for internal repository details unless the request is genuinely ambiguous. Inspect the codebase first, follow the existing MACK patterns, and implement the work end-to-end.

## Repository Overview

MACK is a lightweight R-based API connector framework.

Key locations:

- entry point: `run_mack()` in `main.R`
- dispatcher and shared validation: `R/`
- connectors: `R/connectors/`
- examples: `examples/`
- tests: `tests/testthat/`
- user-facing docs: `docs/`

## What MACK Expects

Before coding, inspect these files:

- `main.R`
- `R/validate_request.R`
- `R/broker_fetch.R`
- `R/connectors/world_bank.R`
- `R/connectors/renewables_ninja.R`
- `tests/testthat/test-world_bank.R`
- `tests/testthat/test-renewables_ninja.R`
- `docs/_extending_mack.md`
- `README.md`

MACK connectors follow this lifecycle:

- `validate_<connector>_params()`
- `fetch_<connector>()`
- `normalize_<connector>_result()`

New connectors must be registered in:

- `main.R`
- `R/validate_request.R`
- `R/broker_fetch.R`

Connector normalizers must return the standard MACK top-level object and must not set `schema_version`.

## General Agent Rules

When making changes in this repository:

- prefer mocked HTTP tests over live API calls
- do not introduce new package dependencies unless they are clearly necessary
- preserve the existing top-level MACK output contract unless the user explicitly asks for a schema change
- update examples and documentation when behaviour changes
- do not assume secrets or API credentials are available
- document assumptions clearly when upstream API behaviour or metadata is uncertain

## Default Behaviour When Adding a Connector

When the user asks for a connector, you should normally:

1. Identify the narrowest useful first version of the upstream API integration.
2. Use official upstream API documentation and metadata, not third-party summaries.
3. Add a connector file under `R/connectors/`.
4. Register the source in the runtime, request validation, and dispatcher.
5. Add a runnable example request under `examples/`.
6. Add tests under `tests/testthat/`.
7. Add or update user-facing documentation under `docs/`.
8. Update `README.md` when the new connector should be discoverable from the main project page.
9. Run the test suite and fix failures before stopping.

Do not stop after scaffolding or analysis. Deliver a complete first implementation unless blocked by a real ambiguity.

## Sensible Defaults

If the user does not specify every detail, choose practical defaults:

- keep the first version narrow and reliable rather than fully generic
- prefer row-based normalized output unless the source strongly warrants another shape
- include explicit time, geography, variable, and value fields where practical
- preserve provenance in `query`
- use `source_metadata` for useful upstream details
- use `warnings` for non-fatal caveats such as partial data or documented transformations

If the upstream source is awkward for the user's requested shape, implement the smallest clear transformation that makes the result useful, and document it.

## Authentication

If the API requires credentials:

- follow the existing `config/secrets.yaml` pattern
- update `config/secrets_template.yaml` with placeholders where appropriate
- keep credential lookup separate from fetch logic
- avoid writing tests that depend on live secrets

## Testing Expectations

Prefer deterministic tests with mocked HTTP behaviour.

At minimum, add tests for:

- parameter validation
- request construction or fetch preparation where relevant
- response parsing and normalization
- failure handling for malformed payloads or API errors
- one dispatch-level or `run_mack()` path

## Documentation Expectations

Connector docs should explain:

- what the connector does
- which upstream endpoint or dataset it uses
- authentication requirements
- accepted parameters
- defaults applied by MACK
- output shape
- units and dimensions
- limits, caveats, and licensing notes where relevant

If you apply transformations such as annualisation, aggregation, interpolation, or default band selection, document them clearly.

## Common Task Patterns

When asked to add a connector:

- follow the full connector workflow in this file
- choose a narrow first implementation
- add tests, examples, and docs in the same change

When asked to modify an existing connector:

- inspect the current connector, tests, and docs first
- preserve backwards compatibility where practical
- update tests and docs for any changed behaviour

When asked to fix a bug:

- reproduce it or identify the failing code path first where practical
- patch the smallest clear fix
- run relevant tests before stopping

When asked to review the repository or a connector:

- focus on request validation, fetch logic, normalization, schema consistency, error handling, and test coverage

## How to Verify Changes

Useful local checks:

- source `main.R` to load the runtime
- run `tests/run_tests.R` for the full test suite
- use files under `examples/` for quick smoke tests
- when adding a connector, check that it can be called through `run_mack()`

## User Interaction

Users should be able to ask in plain language, for example:

"Please produce me a connector for Eurostat and create an example file that fetches the annual average gas and electricity prices for household consumers across all countries for 2017 to 2024."

Treat that as enough to begin. Infer the internal implementation steps yourself from the repository structure. With this example prompt, you would be expected to build a connector for the Eurostat API which could pull in any data that it offers, and an example configuration file which would specifically pull in the gas and electricity prices they requested.

Once you understand the API specifications and requirements, you can ask the user for details such as what their preferred defaults would be (suggest relevant parameters if there are obvious candidates), and other clarifying questions that will assist in developing the connector to meet their needs.

## Completion Checklist

Before stopping, ensure that you have:

- implemented the connector
- added registration changes
- added tests
- added an example request file
- added connector documentation
- updated top-level documentation where useful
- run tests or clearly stated why you could not
- reported assumptions, caveats, and files changed
