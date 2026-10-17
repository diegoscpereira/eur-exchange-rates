import dlt
from dlt.sources.rest_api import rest_api_source
from dlt.sources import DltSource
from dlt.common.pipeline import LoadInfo

## Connection parameters (READ function)
BASE_URL = "https://api.frankfurter.dev/v2/providers/ecb"
RESOURCE_NAME = "frankfurter_ecb_rates"
PRIMARY_KEY = ["date", "quote"]
PATH = "rates"
CURSOR_PATH = "date"
INITIAL_VALUE = "2026-01-01"

## Pipeline parameters (LOAD function)
PIPELINE_NAME = "frankfurter"
DATASET_NAME = "eur_exchange_rates"


def read_frankfurter_ecb_rates() -> DltSource:
    """
    Set the parameters to connect with Frankfurter API.
    Looks for daily EUR rates from the European Central Bank (ECB) endpoint.
    Load strategy set to incremental so it GETs new records daily.
    Write disposition set to MERGE so the load function is idempotent.
    """
    source = rest_api_source(
        {
            "client": {"base_url": BASE_URL},
            "resources": [
                {
                    "name": RESOURCE_NAME,
                    "write_disposition": "merge",
                    "primary_key": PRIMARY_KEY,
                    "endpoint": {
                        "path": PATH,
                        "method": "GET",
                        "paginator": "single_page",
                        "params": {
                            "from": {
                                "type": "incremental",
                                "cursor_path": CURSOR_PATH,
                                "initial_value": INITIAL_VALUE,
                            }
                        },
                    },
                },
            ],
        }
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
    load_data = load_frankfurter_ecb_rates("duckdb")
    print(load_data)

    pipeline = dlt.attach(pipeline_name=PIPELINE_NAME)
    test_df = pipeline.dataset()[RESOURCE_NAME].df()
    print(test_df)
    print(test_df["date"].nunique())
    print(test_df["_dlt_load_id"].nunique())
    print(test_df["_dlt_id"].nunique())
