# Renewables.ninja Connector

Last reviewed: 2026-03-14

## Source Name

`renewables_ninja`

## What This Connector Does

The Renewables.ninja connector retrieves simulated wind or solar generation profiles for one or more sites. It makes one upstream API request per site, parses the returned time series, and then either returns site-level data or sums the sites together depending on the `sum_sites` setting.

The current MAC implementation uses the site-level API rather than the country-level pre-aggregated endpoints.

## Upstream API

Official Renewables.ninja documentation:

- https://www.renewables.ninja/documentation
- https://www.renewables.ninja/documentation/api
- https://www.renewables.ninja/documentation/datasets
- https://www.renewables.ninja/about

## Endpoint Used by MAC

MAC currently uses the site-level endpoints:

- `https://www.renewables.ninja/api/data/wind` when `technology = "wind"`
- `https://www.renewables.ninja/api/data/pv` when `technology = "solar"`

Each site is requested separately. MAC records both the normalized request and the per-site API requests in the returned `query` field.

Although Renewables.ninja also documents country-level endpoints, the current MAC connector does not use them.

## Authentication

Renewables.ninja supports anonymous access and token-based access, but the current MAC implementation expects a token and reads it from `config/secrets.yaml`.

The request header used by MAC is:

`Authorization: Token <your_token_here>`

Expected secrets file structure:

```yaml
renewables_ninja:
  token: "YOUR_TOKEN_HERE"
```

## Parameters Accepted by MAC

The connector currently requires:

- `technology`: `"wind"` or `"solar"`
- `sites`: a non-empty list of `{lat, lon}` points
- `capacity`: either one numeric value for all sites or one value per site
- `date_from`
- `date_to`

The connector currently validates these optional parameters when present:

- `sum_sites`
- `interpolate`
- `height`
- `turbine`
- `system_loss`
- `tilt`
- `azim`
- `raw`

In addition, the connector will pass through other parameters that are supplied in `params` and are not used internally for MAC orchestration. In practice this means upstream parameters such as `dataset`, `format`, `header`, `local_time`, `mean`, or `tracking` can be included in the request, but MAC does not currently validate all of them locally.

## Defaults Applied by MAC

The connector applies several defaults before sending the upstream request:

- `sum_sites = FALSE`
- `interpolate = TRUE`
- `format = "json"` if not otherwise provided

For wind requests:

- `height = 100`
- `turbine = "Vestas V80 2000"`

For solar requests:

- `system_loss = 0.1`
- `tilt = 35`
- `azim = 180`
- `raw = FALSE`

## Output Returned by MAC

The connector returns a column-oriented `data` payload.

If `sum_sites = FALSE`, the output columns are:

- `site_id`
- `lat`
- `lon`
- `timestamp`
- `value`

If `sum_sites = TRUE`, the output columns are:

- `timestamp`
- `value`

The result also includes:

- `query`: normalized request parameters plus the site-level API requests MAC actually made
- `source_metadata`: one metadata block per site

The connector can parse either JSON or CSV responses from the upstream API, but MAC currently requests JSON by default.

## Units and Dimensions

Renewables.ninja documents site-level electricity output in kW for the standard point API output format. MAC extracts unit information from upstream metadata when present.

The connector currently sets:

- temporal start and end from `date_from` and `date_to`
- temporal resolution as `hourly`
- spatial type as `point_set`
- `geography` as `site` or `point_set` depending on whether the sites were summed

Timestamps are normalized into character strings such as `YYYY-MM-DD HH:MM:SS`.

## Rate Limits and Availability

According to the official Renewables.ninja documentation reviewed for this page:

- anonymous users are limited to 5 requests per day
- registered users are limited to 50 requests per hour
- the burst limit is currently 6 requests per minute
- the maximum amount of data available per request is 1 year
- anonymous users have access to a single year
- registered users have access to the full range of data currently available

The same documentation states that custom simulations currently run through the end of 2024.

Because MAC makes one upstream API request per site, a single MAC request with multiple sites will consume multiple upstream requests against those limits.

## Data Licence and Attribution

The Renewables.ninja site states that data available via the service are licensed under Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0).

For academic and professional use, the site requests citation of the papers describing the methods and, where possible, a link to `www.renewables.ninja`. For other use, it requests either citation of the papers or a link to the site, as appropriate.

Official reference pages:

- https://www.renewables.ninja/about
- https://www.renewables.ninja/documentation/science

## Known Caveats

- MAC currently requires a token even though the upstream API can also be accessed anonymously.
- MAC makes one upstream request per site, so large multi-site jobs will hit rate limits faster.
- The connector currently uses only the site-level API, not the country-level endpoints documented by Renewables.ninja.
- Additional upstream parameters may be passed through without local validation.
- If upstream parameters are used to request non-hourly aggregates, MAC still currently labels temporal resolution as `hourly` in `dimensions`.
- The upstream service limits each request to one year, so longer spans need to be split into multiple requests outside the current connector.

## Example Request

```r
request <- list(
  source = "renewables_ninja",
  params = list(
    technology = "wind",
    sites = list(
      list(lat = 52.1, lon = -1.5),
      list(lat = 53.2, lon = -2.0)
    ),
    capacity = c(100, 150),
    date_from = "2015-01-01",
    date_to = "2015-12-31",
    dataset = "merra2",
    sum_sites = TRUE
  )
)

result <- run_mac(request)
```

## External Links

- Renewables.ninja documentation: https://www.renewables.ninja/documentation
- API documentation: https://www.renewables.ninja/documentation/api
- Dataset format documentation: https://www.renewables.ninja/documentation/datasets
- Licence and attribution notes: https://www.renewables.ninja/about
- Science and citation references: https://www.renewables.ninja/documentation/science
