# Eurostat Connector

Last reviewed: 2026-03-19

## Source Name

`eurostat`

## What This Connector Does

The Eurostat connector retrieves tabular data from Eurostat's Statistics API and converts the JSON-stat response into a row-based MACK result. It is designed as a generic dataset connector: you provide the Eurostat dataset code plus named dimension filters, and MACK fetches the matching observations.

The first implementation focuses on the Statistics API rather than the SDMX endpoints. It is well suited to requests where the user already knows the Eurostat dataset code they want to query.

## Upstream API

Official Eurostat documentation reviewed for this connector:

- https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-introduction
- https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-getting-started/api
- https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/

The example use case requested for this connector relies on these official dataset metadata pages:

- https://ec.europa.eu/eurostat/cache/metadata/en/nrg_pc_204_sims.htm
- https://ec.europa.eu/eurostat/cache/metadata/en/nrg_pc_202_sims.htm

## Endpoint Used by MACK

MACK builds requests against the Statistics API using this path shape:

`https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{dataset_code}`

The connector always sends:

- `lang={language_code}` with default `EN`

It then appends each named filter from `params$filters` as one or more repeated query parameters. For example:

`...?geo=DE&geo=FR&time=2024-S1&time=2024-S2&tax=I_TAX`

This follows the Statistics API filtering pattern documented by Eurostat and observed in live responses during connector implementation.

## Authentication

No authentication is required.

## Parameters Accepted by MACK

The connector currently validates these parameters:

- `dataset_code`: a single Eurostat dataset code such as `nrg_pc_204`
- `filters`: a named list of dimension filters; each filter value may be a scalar or vector
- `lang`: optional language code, default `EN`
- `aggregate_time`: optional aggregation mode; currently only `annual_mean` is supported

Additional notes:

- MACK treats `filters` generically. The filter names must match Eurostat's actual dimension ids for the selected dataset.
- Filter values are passed through as strings. MACK does not currently validate them against the live Eurostat code lists before the request is sent.
- The current implementation supports one dataset per request.

## Defaults Applied by MACK

The connector currently applies these defaults:

- `lang = "EN"`
- no time aggregation unless `aggregate_time` is explicitly supplied

If `aggregate_time = "annual_mean"`, MACK groups observations by their non-time dimensions and averages all matching observations whose `time` value starts with the same four-digit year. The normalized rows then use `year` instead of `time`, and a `period_count` field records how many periods contributed to each annual value.

## Output Returned by MACK

The connector returns a row-based `data` payload. Each row contains one field per returned Eurostat dimension, plus:

- `value`
- `status` when Eurostat supplies an observation status flag

If `aggregate_time = "annual_mean"`, the connector replaces `time` with:

- `year`
- `period_count`

The result also includes:

- `query`: the base URL, full request URL, and normalized request parameters
- `source_metadata`: dataset label, update timestamp, annotation metadata, and the returned dimension labels

## Units and Dimensions

When the dataset includes a `unit` dimension, MACK maps the returned unit codes to their Eurostat labels in the top-level `units` field.

The connector currently sets:

- temporal resolution from the dataset `freq` dimension where possible
- temporal resolution as `annual` after `aggregate_time = "annual_mean"`
- spatial ids from the returned `geo` dimension when present
- variable as `dataset_observation`

The row records preserve the original Eurostat dimension codes, while human-readable labels are stored in `source_metadata$dimensions`.

## Limits and Caveats

- The current connector uses the Statistics API only. It does not yet expose Eurostat's SDMX APIs or catalogue discovery API through a dedicated MACK interface.
- MACK expects the user to know the dataset code and relevant dimension ids in advance.
- MACK does not yet perform automatic metadata discovery or code validation before sending the request.
- `aggregate_time = "annual_mean"` is intentionally simple: it averages all matched observations sharing the same four-digit year prefix in `time`. This is suitable for semesterly datasets such as household gas and electricity prices, but other datasets may require a different aggregation strategy.
- The connector currently fetches the full filtered result in one call and does not implement pagination or batching.

## Example Requests

Electricity prices for household consumers:

```r
request <- list(
  source = "eurostat",
  params = list(
    dataset_code = "nrg_pc_204",
    filters = list(
      siec = "E7000",
      nrg_cons = "TOT_KWH",
      unit = "KWH",
      currency = "EUR",
      tax = "I_TAX",
      time = c("2024-S1", "2024-S2")
    ),
    aggregate_time = "annual_mean"
  )
)

result <- run_mack(request)
```

Gas prices for household consumers:

```r
request <- list(
  source = "eurostat",
  params = list(
    dataset_code = "nrg_pc_202",
    filters = list(
      siec = "G3000",
      nrg_cons = "TOT_GJ",
      unit = "KWH",
      currency = "EUR",
      tax = "I_TAX",
      time = c("2024-S1", "2024-S2")
    ),
    aggregate_time = "annual_mean"
  )
)
```

## Data Licence and Attribution

Eurostat publishes a copyright notice and free re-use policy for its content and datasets:

- https://ec.europa.eu/info/legal-notice_en
- https://ec.europa.eu/eurostat/web/main/help/copyright-notice

Users should still check dataset-specific metadata, explanatory notes, and any source institution caveats attached to the selected dataset.

## External Links

- Eurostat API introduction: https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-introduction
- Eurostat Statistics API getting started: https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/api-getting-started/api
- Eurostat API user guides landing page: https://ec.europa.eu/eurostat/web/user-guides/data-browser/api-data-access/
- Electricity prices metadata (`nrg_pc_204`): https://ec.europa.eu/eurostat/cache/metadata/en/nrg_pc_204_sims.htm
- Gas prices metadata (`nrg_pc_202`): https://ec.europa.eu/eurostat/cache/metadata/en/nrg_pc_202_sims.htm
