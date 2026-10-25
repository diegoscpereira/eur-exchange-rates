import dlt
from dlt.sources.rest_api import rest_api_source
from dlt.sources import DltSource
from dlt.common.pipeline import LoadInfo

## Connection parameters (READ function)
BASE_URL = "https://api.frankfurter.dev/v2"
RESOURCE_NAME_RATES = "ecb_rates"
PRIMARY_KEY_RATES = ["date", "quote"]
PATH_RATES = "providers/ecb/rates"
CURSOR_PATH_RATES = "date"
INITIAL_VALUE_RATES = "2026-01-01"
RESOURCE_NAME_CURRENCIES = "currencies"
PATH_CURRENCIES = "currencies"
SOURCE_NAME = "frankfurter"

## Pipeline parameters (LOAD function)
PIPELINE_NAME = "frankfurter"
DATASET_NAME = "raw"


def read_frankfurter_ecb_rates() -> DltSource:
    """
    Set the parameters to connect with Frankfurter API.
    Looks for daily EUR rates from the European Central Bank (ECB) endpoint:
        - Load strategy set to incremental so it GETs new records daily.
        - Write disposition set to MERGE so the load function is idempotent.
    It also fetches currencies lookup page, with the official name filtered to ECB-only currencies.
    """
    source = rest_api_source(
        {
            "client": {"base_url": BASE_URL},
            "resources": [
                {
                    "name": RESOURCE_NAME_RATES,
                    "write_disposition": "merge",
                    "primary_key": PRIMARY_KEY_RATES,
                    "endpoint": {
                        "path": PATH_RATES,
                        "method": "GET",
                        "paginator": "single_page",
                        "params": {
                            "from": {
                                "type": "incremental",
                                "cursor_path": CURSOR_PATH_RATES,
                                "initial_value": INITIAL_VALUE_RATES,
                            }
                        },
                    },
                },
                {
                    "name": RESOURCE_NAME_CURRENCIES,
                    "write_disposition": "replace",
                    "endpoint": {
                        "path": PATH_CURRENCIES,
                        "method": "GET",
                        "paginator": "single_page",
                        "params": {"providers": "ecb"},
                    },
                },
            ],
        },
        name=SOURCE_NAME,
    )
    return source


def load_frankfurter_ecb_rates(destination: str) -> LoadInfo:
    """
    Creates and runs the dlt pipeline.
    """
    pipeline = dlt.pipeline(
        pipeline_name=PIPELINE_NAME,
        destination=destination,
        dataset_name=DATASET_NAME,
    )

    load_info = pipeline.run(read_frankfurter_ecb_rates())
    return load_info


if __name__ == "__main__":
    load_data = load_frankfurter_ecb_rates("bigquery")
    print(load_data)
