# MOSAIC API Connector (MAC)

MAC is a lightweight connector written in R.  It fetches data from external APIs and exports simple, structured results to JSON or YAML.  It is intended to help standardise and streamline the process of gathering data inputs for energy systems models.

## What MAC does

1. Accepts and validates a structured request (what `source` to connect to, what `params` to pass to it, optionally what file to write `output` to).
2. Routes this to a connector which calls the API, parses the response and normalises output.
3. Returns the output as a list, and optionally writes it to JSON or YAML.

Currently, connectors are implemented for:
- [World Bank Indicators](docs/world_bank.md)
- [Renewables.ninja](docs/renewables_ninja.md)


## Quick start guide

You can make your first API calls with just two lines of code.  

Download this repo and then run:

```r
source("path/to/main.R")

uk_gdp <- run_mac('path/to/examples/example_world_bank_indicators.yaml')
```

This will load up MAC, read in an example call to the World Bank Indicators API and save the results with structured metadata to `uk_gdp`.  `uk_gdp$data` will contain a list giving the UK's GDP (in local currency) from 2010 through to 2024. 


### Running with list() objects

You can run a request from an in-memory list, returning the result object as a list.  This code yields the same result as above:

```r
request <- list(
  source = "world_bank",            # from the world bank indicators
  params = list(
    indicator = "NY.GDP.MKTP.KD",   # request GDP
    country = "GBR",                # for the United Kingdom
    years = c(2010, 2024)           # from 2010 to 2024
  )
)

result <- run_mac(request)
```

### Running with YAML input/output

The request used in the first example is defined by a simple YAML file structure:

`request.yaml`:
```yaml
request:
  source: world_bank
  params:
    country: GBR
    indicator: NY.GDP.MKTP.KD
    years:
      - 2010
      - 2024
  output:
    format: yaml
    file: outputs/gbr_gdp.yaml
```

By defining the output block, calling `run_mac()` with this input file will save your results as YAML to disk.


### Running with JSON input/output

The same is possible with JSON input and output:

`request.json`:
```json
{
  "request": {
    "source": "world_bank",
    "params": {
      "country": "GBR",
      "indicator": "NY.GDP.MKTP.KD",
      "years": [2010, 2024]
    },
    "output": {
      "format": "json",
      "file": "outputs/gbr_gdp.json"
    }
  }
}
```

Calling `run_mac()` with this input file will yield the same data as above, but save in a different format.


# Standard output object

All connectors return the same top-level structure:
- `schema_version` (set by dispatcher)
- `connector`
- `timestamp`
- `query`
- `data`
- `units`
- `dimensions`

Optional fields:
- `warnings`
- `source_metadata`

For example:

```json
{
  "schema_version": "0.1.0",
  "connector": "world_bank",
  "timestamp": "2026-03-14T08:45:02Z",
  "query": {
    "url": "https://api.worldbank.org/v2/country/GBR/indicator/NY.GDP.MKTP.KD",
    "params": {
      "format": "json",
      "date": "2018:2020",
      "page": 1,
      "per_page": 1000
    }
  },
  "data": [
    { "country": "GBR", "indicator": "NY.GDP.MKTP.KD", "year": 2020, "value": 2868821517197.41 },
    { "country": "GBR", "indicator": "NY.GDP.MKTP.KD", "year": 2019, "value": 3189276674514.83 },
    { "country": "GBR", "indicator": "NY.GDP.MKTP.KD", "year": 2018, "value": 3149706986726.54 }
  ],
  "units": null,
  "dimensions": {
    "temporal": { "start": "2018", "end": "2020", "resolution": "annual" },
    "spatial": { "type": "country", "id": "GBR" },
    "variable": "indicator",
    "index": { "time": "year", "geography": "country", "variable": "indicator" }
  }
}
```


## Available Connectors

Two connectors are currently available.  

A detailed guide has been written on how to [extend MAC by writing connectors to additional APIs](docs/_extending_mac.md).


### [World Bank Indicators](docs/world_bank.md)

The World Bank Indicators connector provides quick access to development and infrastructure metrics, for example, GDP (`NY.GDP.MKTP.KD`), GDP growth (`NY.GDP.MKTP.KD.ZG`), electric power consumption (`EG.USE.ELEC.KH`), access to electricity (`EG.ELC.ACCS.ZS`), access to clean fuels and technologies for cooking (`EG.CFT.ACCS.ZS`), electricity transmission and distribution losses (`EG.ELC.LOSS.ZS`), and the electricity generation mix from coal (`EG.ELC.COAL.ZS`), gas (`EG.ELC.NGAS.ZS`), nuclear (`EG.ELC.NUCL.ZS`), hydro (`EG.ELC.HYRO.ZS`), and non-hydro renewables (`EG.ELC.RNWX.ZS`). Indicators are typically annual country-aggregates, available from 1960 (with better availability from 1990 onwards). 

### [Renewables.ninja](docs/renewables_ninja.md)

The Renewables.ninja connector provides quick access to weather-driven wind and solar generation profiles which capture the real-world spatial and temporal variation in output. Several individual locations can be simulated within a single request, and aggregated together to form zonal or regional outputs.  The wind and solar site configuration (technology, hub height, orientation) can be specified, with standard defaults applied if none are given.  Simulations are available at hourly resolution from 1980 to 2024.

Renewables time series are returned in a column-oriented `data` structure.  Results can be requested for an individual site, or the sum across several sites.

### Authentication

Some APIs require authentication, for example, Renewables.ninja.  This is handled by storing your tokens inside:
- `config/secrets.yaml`

Template:
- `config/secrets_template.yaml`

Remember not to share or commit your secrets.yaml file to a repository.


## Dependencies

Runtime:
- `here`
- `httr2`
- `yaml`
- `jsonlite`

Testing:
- `testthat`


## Error behaviour

- Invalid request: clear error before API call.
- API failure: connector-specific error message with HTTP status when available.
- Missing data values: preserved as `NULL`/`NA` in normalized output where appropriate.


## License

BSD 3-Clause.

## Contact

[Iain Staffell](mailto:i.staffell@imperial.ac.uk), Imperial College London
