import dlt
from dlt.sources.rest_api import rest_api_source

## Declare the variables
BASE_URL = "https://api.frankfurter.dev/v2/providers/ecb"
INITIAL_VALUE = "2026-10-05"


## Setup API connection
def load_frankfurter_ecb_rates() -> None:
    """
    Loads daily EUR rates from the European Central Bank (ECB), from the Frankfurter API.
    Load strategy set to incremental so it can only GET new records daily.
    """
    source = rest_api_source(
        {
            "client": {"base_url": BASE_URL},
            "resources": [
                {
                    "name": "frankfurter_ecb_rates",
                    "endpoint": {
                        "path": "rates",
                        "method": "GET",
                        "paginator": "single_page",
                        "params": {
                            "from": {
                                "type": "incremental",
                                "cursor_path": "date",
                                "initial_value": INITIAL_VALUE,
                            }
                        },
                    },
                },
            ],
        }
    )

    pipeline = dlt.pipeline(
        pipeline_name="frankfurter",
        destination="duckdb",
        dataset_name="eur_exchange_rates",
    )

    # load_info = pipeline.run(source)
    return pipeline


# 4. Run
# load_frankfurter_rates()
test_df = load_frankfurter_rates().dataset().frankfurter_ecb_rates.df()
print(test_df)
print(test_df["_dlt_load_id"].nunique())
print(test_df["_dlt_id"].nunique())
