# World Bank Connector

Last reviewed: 2026-03-14

## Source Name

`world_bank`

## What This Connector Does

The World Bank connector retrieves indicator time series from the World Bank Indicators API v2 for a single country and one or more indicators. It validates the request, fetches all pages of results, and normalizes the response into MACK's shared top-level output object.

The current implementation is aimed at country-indicator time series. It is well suited to requests such as GDP, electricity consumption, electricity access, and other development indicators already exposed through the World Bank API.

## Upstream API

Official World Bank developer documentation:

- https://datahelpdesk.worldbank.org/knowledgebase/articles/889386-developer-information-overview
- https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation
- https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures
- https://datahelpdesk.worldbank.org/knowledgebase/articles/898599-indicator-api-queries

## Endpoint Used by MACK

MACK builds requests against the Indicators API v2 using the following path shape:

`https://api.worldbank.org/v2/country/{country}/indicator/{indicator1;indicator2;...}`

The current connector sends these query parameters:

- `format=json`
- `date={start}:{end}`
- `page={page_number}`
- `per_page={page_size}`

If more than one page is returned, the connector continues requesting pages until all rows have been collected.

## Authentication

No authentication is required. The World Bank documentation states that API keys and other authentication methods are no longer necessary for the Indicators API.

## Parameters Accepted by MACK

The connector currently validates these parameters:

- `country`: a single three-letter code, documented in MACK as an ISO3 country code
- `indicator`: a non-empty character vector of one or more indicator codes
- `years`: a numeric vector of length two giving start year and end year
- `per_page`: optional positive integer

Additional notes:

- MACK supports multiple indicators in one request.
- MACK follows the upstream API convention of joining multiple indicators with `;`.
- The World Bank documentation states that a maximum of 60 indicators can be used in one request; the MACK validator enforces the same limit.
- If `per_page` is not supplied, MACK currently requests 1000 rows per page.

## Output Returned by MACK

The connector returns a row-based `data` payload. Each row contains:

- `country`
- `indicator`
- `year`
- `value`

The surrounding MACK output also includes:

- `query`: the final URL and query parameters used
- `source_metadata`: page count and page metadata from the upstream API

Missing values are preserved as `NULL` or `NA` where appropriate.

## Units and Dimensions

The connector extracts unit metadata from the upstream response when available.

- If a single indicator is returned and it has a unit, `units` is usually a scalar.
- If multiple indicators are returned with units, `units` is returned as a named list keyed by indicator code.

The connector currently sets:

- temporal resolution: `annual`
- spatial type: `country`
- spatial identifier: the requested country code
- variable: `indicator`

## Rate Limits and Other Limits

No explicit request rate limit was found in the official World Bank documentation reviewed for this page.

The official documentation does specify some other constraints relevant to this connector:

- default `per_page` is 50 if not overridden
- up to 60 indicators can be requested together
- the API supports paged responses for larger result sets

## Data Licence and Attribution

World Bank datasets are governed by the World Bank Terms of Use for Datasets:

- https://www.worldbank.org/en/about/legal/terms-of-use-for-datasets
- https://datacatalog.worldbank.org/public-licenses

For most World Bank Data Catalog datasets, the documented public licence is Creative Commons Attribution 4.0 International (CC BY 4.0). However, the World Bank also notes that some datasets or indicators are provided by third parties and may carry different reuse conditions. Where applicable, those conditions should be checked in the upstream metadata.

## Known Caveats

- MACK currently documents `country` as a single three-letter country code and does not expose a multi-country request interface.
- The connector is focused on the main indicator data endpoint. It does not currently expose the wider set of World Bank metadata and source-selection endpoints through a dedicated MACK interface.
- MACK captures unit information, but it does not currently pull through the fuller indicator metadata that the World Bank API can also provide.
- The connector preserves the order returned by the API rather than applying its own sorting step.

## Example Request

```r
request <- list(
  source = "world_bank",
  params = list(
    country = "GBR",
    indicator = c("NY.GDP.MKTP.KD", "EG.USE.ELEC.KH"),
    years = c(2010, 2024)
  )
)

result <- run_mack(request)
```

## External Links

- World Bank Developer Overview: https://datahelpdesk.worldbank.org/knowledgebase/articles/889386-developer-information-overview
- World Bank Indicators API documentation: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation
- API basic call structures: https://datahelpdesk.worldbank.org/knowledgebase/articles/898581-api-basic-call-structures
- Indicator API queries: https://datahelpdesk.worldbank.org/knowledgebase/articles/898599-indicator-api-queries
- Dataset licence terms: https://www.worldbank.org/en/about/legal/terms-of-use-for-datasets
