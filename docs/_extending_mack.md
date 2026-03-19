# Extending MACK

It is possible to extend MACK by adding connectors to new APIs.  This page offers two routes to doing this, using coding agents such as Codex / Claude Code, or manually.


## Using Coding Agents

If you work with with a coding tool such as Codex or Claude Code, you can usually ask for a new connector in plain language and let the agent handle the repository-specific details. In this repository, those agent instructions live in `AGENTS.md`, which they will likely read anyway.

In practice, the workflow can be as simple as:

1. Clone the repository and open it locally.
2. Start your coding agent in the repository root.
3. Ask for the connector you want, for example:
   "Please produce me a connector for Eurostat and create an example file that fetches the annual average gas and electricity prices for household consumers across all countries for 2017 to 2024."

The `AGENTS.md` file gives complete guidance on how the tool should do this.  This includes searching for the API documentation (so that you don't need to research the details), writing the connector, writing unit tests (to ensure the connector works), and writing example documentation to go with it. 

If you create a useful new connector, please open a pull request so we can review it and help grow MACK together.


## Manually adding connectors

### 1. Purpose of This Guide

This guide documents the current logic of the MOSAIC API Connector (MACK) and sets out the working standard for adding new API connectors to the codebase.

The intended audience is the MOSAIC project team and any contributor extending MACK with additional external data sources. In practical terms, the guide is meant to support future connector development and help MACK to streamline and standardise the production of Starter Data Kits.


### 2. Current MACK Runtime Logic

The core operations of MACK are centred on a single entry point, `run_mack()`, defined in `main.R`. This loads shared runtime files (on first use), processes the request object from the user (which API to call, what parameters to request, etc.), resolves authentication keys (if needed), and then passes the main work to `broker_fetch()`.

Before any API-specific work is attempted, MACK validates the top-level request structure through `validate_request()`. At minimum, a valid request must contain a `source` value and a `params` list. If an `output` block is provided, it is also checked for supported formats and a valid file specification. This ensures that connector code receives a request in a consistent top-level shape.

The dispatch step is handled by `broker_fetch()`. This function inspects `request$source`, routes the request to the selected connector, and calls the connector-specific stages in sequence:

1. `validate_<connector>_params()`
2. `fetch_<connector>()`
3. `normalize_<connector>_result()`

After the connector returns its normalized result, the dispatcher validates that the shared MACK result structure has been respected and then stamps the `schema_version`. If the original request includes a valid output specification, `run_mack()` also writes the result to disk after dispatch completes. 

To summarise:
- The core of MACK is responsible for validating that a request has a valid structure, defining the schema structure, and exporting results; so these do not need to be handled within a connector.
- Each individual connector is responsible for validating that the `params` of the request object match the needs of the API, connecting to the API and receiving the result (with any necessary authentication), and normalizing the result into the MACK schema (including the possibility of simple data transformations such as unit conversion or aggregation).


### 3. Existing Connector Architecture

Each connector is responsible for source-specific parameter handling, request execution, response parsing, and output normalization. The common public pattern is:

- `validate_<connector>_params()`
- `fetch_<connector>()`
- `normalize_<connector>_result()`

This pattern gives each connector a recognisable shape while still allowing source-specific helper functions where needed. For example, helper functions may be used for request construction, payload parsing, token retrieval, timestamp normalization, unit extraction, or aggregation logic.

The MACK dispatcher retains two responsibilities that are intentionally not delegated to connectors. First, it owns source routing. New sources are explicitly registered in the dispatcher, rather than discovered dynamically. Second, it owns `schema_version`, which means connector normalizers must not set that field themselves.

Two connectors are implemented at the time of launch to illustrate how this architecture can accommodate quite different APIs.

The World Bank connector is relatively simple and largely request-response oriented. It validates country, indicator, and year inputs; constructs paginated API requests; combines rows across pages; and normalizes the result into a row-based list of annual country-indicator records. It also captures request details and page metadata for traceability.

The Renewables.ninja connector demonstrates a more involved case. It retrieves an API token needed for authentication, normalizes user parameters by applying defaults where needed, performs one API call per site, parses either JSON or CSV payloads, and can return either site-level data or a summed series across sites.

Taken together, these two examples show the intended architectural boundary in MACK: connectors should share the same lifecycle and top-level output object, but they do not need to force all APIs into an identical internal data layout.


### 4. Current Working Standard for New API Connectors

New connectors should fit into the established validator-fetch-normalizer flow, return the shared top-level MACK output object, and integrate with the existing dispatcher and validation logic. Beyond that, the codebase intentionally leaves room for source-specific design choices.

That flexibility is important because the APIs that could be useful to integrate are likely to be diverse. Some sources may return annual scalar indicators. Others may return hourly time series, multiple spatial points, scenario bundles, tabular metadata, or nested structures that do not map neatly onto a single canonical format.

In this project, MACK is best understood as an intermediate acquisition step in the workflow. Its role is to make it easy to pull structured data from external sources into a consistent top-level container. More complex reshaping, aggregation, reconciliation, or model-specific formatting can and should remain downstream where appropriate.

For that reason, the project standard should be read as follows:

- connectors should be easy to understand and test
- connector inputs should be validated before network calls are made (where practical)
- request details should be traceable in the output (to maintain data provenance and transparency)
- the top-level MACK result object should remain consistent
- the internal structure of `data`, `units`, and parts of `dimensions` may vary when the source demands it

Clear separation of concerns is encouraged, but not an absolute rule. For simple APIs, a lightweight implementation may be sufficient. For more complex APIs, additional helper functions may be appropriate. The standard should support both cases.


### 5. Recommended Onboarding Checklist for a New API Connector

The following checklist summarises the practical repository changes needed to add a new connector.

1. Choose a stable source name and define the expected request parameters.
   The source name becomes the value used in `request$source`, so it should be concise, predictable, and suitable for explicit registration in the dispatcher.

2. Implement the connector within a new file under `R/connectors/`.
   At minimum, add `validate_<connector>_params()`, `fetch_<connector>()`, and `normalize_<connector>_result()`. Add helper functions where they improve clarity or testability.

3. Register the new source in the runtime, request validation, and dispatch flow.
   In the current codebase this means editing three places:
   - `main.R`: add the new connector file to `load_broker_runtime()` so it is sourced with the other runtime files.
   - `R/validate_request.R`: update `validate_request_source()` so the new source name is included in `supported_sources`.
   - `R/broker_fetch.R`: update `broker_fetch()` so the new source name dispatches to `validate_<connector>_params()`, `fetch_<connector>()`, and `normalize_<connector>_result()`. If the connector needs authentication, this is also where any connector-specific secrets helper is called before `fetch_<connector>()`.

4. Add secrets handling only if the API requires authentication.
   If the source needs credentials, follow the existing pattern of reading them from `config/secrets.yaml` through a connector-specific helper, with an appropriate placeholder in `config/secrets_template.yaml`.

5. Add an example invocation.
   Provide a small example under `examples/` so that future users can see the intended connector usage and expected request shape.

6. Add tests.
   At minimum, tests should cover parameter validation, core request construction or fetch behaviour, normalization, and a successful end-to-end dispatch path.

7. Document the connector's source and any specific assumptions.
   Create a corresponding documentation file under `docs/connectors/`, following the examples already there. If the connector applies defaults, uses a particular data layout, or preserves source-specific structure for good reason, that choice should be made explicit in this user-facing documentation.


### 6. Parameter Validation and Query Construction Rules

Parameter validation should happen before any network call is made. The main purpose is to fail early on invalid input, produce clearer error messages, and avoid unnecessary external requests.

Validation should be proportionate to the connector. Required parameters should always be checked. Important optional parameters should be checked when present, especially if they affect query correctness, date ranges, identifiers, spatial coordinates, or authentication. Rather than try to predict every possible upstream API error, the aim is to catch the obvious and high-value cases locally.

The World Bank connector validates ISO3 country codes, indicator vectors, year ranges, and paging settings. The Renewables.ninja connector validates technology choice, site coordinates, capacities, and date bounds, and also checks several optional source-specific parameters when provided.

Where helpful, connectors may normalize user parameters before request execution. The Renewables.ninja code already does this by applying defaults such as `sum_sites`, `interpolate`, wind turbine settings, and solar system-loss settings before making requests.

A dedicated request-builder helper is encouraged whenever it makes the final API call easier to understand or test. The World Bank connector uses `build_world_bank_request()` to make URL and query assembly explicit. This gives both developers and tests a stable point at which to inspect the final request shape. For a very simple connector, request construction may remain inside the fetch function if that keeps the implementation clearer.

Any defaults, aliases, parameter transformations, or normalization rules should be documented. Contributors should be able to see not only what inputs the connector accepts, but also what changes MACK may apply before sending the final request.

### 7. Standard Request and Output Expectations

At request level, MACK expects three common top-level fields:

- `source`: the connector name to route to
- `params`: a list of connector-specific parameters
- `output`: an optional export block

The `params` block is connector-specific. This is where diversity between APIs belongs. Top-level standardisation in MACK is primarily about dispatch and result handling, not about forcing all APIs to expose the same parameter vocabulary.

At result level, connectors are expected to return the shared MACK top-level object. The required fields are:

- `connector` identifies the source that produced the result.
- `timestamp` records when MACK generated the result object.
- `query` captures enough information to reconstruct what was requested from the API.
- `data` contains the main payload returned by the connector.
- `units` records unit information where it exists and is useful.
- `dimensions` summarises the temporal, spatial, and variable structure of the result.

The optional fields are:

- `warnings` is available for non-fatal caveats.
- `source_metadata` stores extra upstream details that are useful for traceability but not essential to the main payload.

MACK standardises the top-level container, not every internal data shape.

This distinction is visible in the World Bank and Renewables.ninja connectors. World Bank returns a list of records. Renewables.ninja returns a column-oriented structure. Both are wrapped inside the same top-level MACK object.

For future connectors, the following conventions should be treated as guidance:

- Single values or point observations should usually be returned in a compact structure that makes the variable, value, and any time or location identifiers explicit.
- Time series should include an explicit time field such as `year`, `date`, or `timestamp`, and should use a stable representation where practical.
- Spatial collections should include location identifiers, coordinates, or both where that information is important to interpreting the result.
- Aggregated or multi-site results should indicate clearly whether they represent individual components or a combined series.
- If flattening a source-specific structure would remove useful meaning, it is acceptable to preserve more of the source shape and explain it through `dimensions`, `query`, or `source_metadata`.

This flexible approach is deliberate. MACK should produce data that is easy to inspect and reuse, but it should not try to anticipate every downstream transformation a modeller might want. Users may later reshape the data for a specific model, database, or reporting pipeline. MACK should make the acquisition of data easier, not try to build entire bespoke data processing pipelines.

### 8. Authentication, Secrets, and External Dependency Handling

Some APIs require authentication and some do not.

For authenticated connectors, the current project pattern is to store credentials in `config/secrets.yaml`, following the conventions in the placeholder file `config/secrets_template.yaml`. The Renewables.ninja connector follows this pattern by reading its token through a connector-specific helper and explicitly rejecting missing or placeholder values.

Credential retrieval should be isolated from request execution so that authentication logic is easy to test, easy to reason about, and easy to update if the credential format changes.

Connectors should also make their external dependencies explicit. That includes required R packages, credentials, known API format assumptions, and any notable limitations imposed by the upstream source. A contributor should be able to tell, from the connector code and tests, what the connector depends on and what conditions must be met for it to work correctly.

Where possible, tests should avoid depending on live credentials or live network calls. The current code already supports this approach by using HTTP wrapper functions that can be mocked in tests.

### 9. Error Handling and Result Normalization

MACK's current error-handling model is straightforward and should continue to guide new connectors.

Invalid input should fail before transport. If a request is malformed or internally inconsistent, the error should be raised locally during validation rather than after an API call has already been attempted.

Transport and upstream failures should be raised as connector-specific runtime errors. The utility helper `stop_with_connector_error()` already provides a standard pattern for this by prefixing errors with the connector name and optionally including an HTTP status code. This makes it easier to distinguish connector failures from general runtime problems.

Where available, connectors should preserve the most useful error detail from the upstream source. That may include HTTP status, API-provided error messages, or parsing failures that explain why a response could not be interpreted. Error messages do not need to be elaborate, but they should make it reasonably clear whether the problem arose from authentication, request content, transport, or unexpected response shape.

Normalization should prioritise clarity and traceability over aggressive harmonisation. The connector's job is to transform the raw API response into a stable MOSAIC result object that is easy to inspect and work with. That does not mean every source must be flattened into the same internal structure. It does mean that field names, timestamps, units, and metadata should be clear enough for users to understand what they have received.

The optional `warnings` field is available for cases where the connector completes successfully but there are caveats worth preserving, such as partial data, substituted defaults, or non-critical omissions. Likewise, `source_metadata` should be used where upstream metadata is useful to retain for interpretation, provenance, or debugging.

In short, connectors should normalise enough to make the data usable and consistent at top level, but not so aggressively that important source-specific meaning is lost.

### 10. Testing and Acceptance Criteria

The repository provides a testing strategy for the existing connectors, and new connectors should follow the same pattern.

Current tests cover top-level request validation, utility functions, export logic, dispatcher behaviour, and connector-specific logic such as parameter validation, request building, payload parsing, fetch wrappers, and normalization. This is a strong base because it tests both the common MACK contract and the specific behaviour of each connector.

For a new connector, the minimum expected test set should include:

1. Validation tests for required and optional parameters.
2. Tests for request construction or fetch preparation, where that logic exists separately.
3. Tests for response parsing and normalization.
4. Tests for API error handling and malformed payload handling.
5. At least one dispatch-level or `run_mack()`-level test showing that the connector can be invoked through the standard MACK path.

The current codebase also uses dedicated HTTP wrapper functions to support deterministic testing without relying on live services. That pattern should continue. Unit tests should focus on connector logic and contract compliance, not on whether an external service happens to be reachable during test execution.

A new connector should be treated as ready for inclusion when the following conditions are met:

- the connector is registered and callable through the standard MACK flow
- its parameters are validated to a reasonable level before network calls
- it returns the expected MACK top-level structure
- any authentication requirements are implemented clearly if needed
- its output is traceable through `query`, `dimensions`, and optional metadata
- source-specific payload choices are documented
- automated tests cover the main success and failure cases

This acceptance threshold is intentionally practical. It aims to ensure maintainability and consistency without preventing MACK from supporting a wide range of data sources and response formats.
