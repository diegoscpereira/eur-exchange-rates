import argparse
from datetime import date, timedelta
import dlt
from dlt.sources.rest_api import rest_api_source
from dlt.sources import DltSource
from dlt.common.pipeline import LoadInfo

## Connection parameters (READ function)
BASE_URL = "https://api.frankfurter.dev/v2"
RESOURCE_NAME_RATES = "ecb_rates"
PRIMARY_KEY_RATES = ["date", "quote"]
PATH_RATES = "providers/ecb/rates"
RESOURCE_NAME_CURRENCIES = "currencies"
PATH_CURRENCIES = "currencies"
SOURCE_NAME = "frankfurter"

## Pipeline parameters (LOAD function)
PIPELINE_NAME = "frankfurter"
DATASET_NAME = "raw"


def read_frankfurter_ecb_rates(start_date: date, end_date: date) -> DltSource:
    """
    Set the parameters to connect with Frankfurter API.
    Daily EUR rates from the ECB for an explicit window
    [start_date, end_date], both inclusive.
    Write disposition set to MERGE so the load function is idempotent.
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
                            "from": start_date.isoformat(),
                            "to": end_date.isoformat()
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


def load_frankfurter_ecb_rates(destination: str, start_date: date, end_date: date) -> LoadInfo:
    """
    Creates and runs the dlt pipeline.
    """
    pipeline = dlt.pipeline(
        pipeline_name=PIPELINE_NAME,
        destination=destination,
        dataset_name=DATASET_NAME,
    )

    source = read_frankfurter_ecb_rates(start_date, end_date)
    return pipeline.run(source)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """
    CLI entry layer: decides WHICH dates to load.
    Defaults to yesterday; --end defaults to --start.
    """                                           
    yesterday = date.today() - timedelta(days=1)
    parser = argparse.ArgumentParser(
        description="Load ECB rates from Frankfurter."
    )
    parser.add_argument(
        "--start", type=date.fromisoformat, default=yesterday,
        help="First date to load, YYYY-MM-DD (default: yesterday)",
    )
    parser.add_argument(
        "--end", type=date.fromisoformat, default=None,
        help="Last date to load, inclusive (default: --start)",
    )
    args = parser.parse_args(argv)
    if args.end is None:
        args.end = args.start
    if args.start > args.end:
        parser.error("--start must be on or before --end")
    return args


if __name__ == "__main__":
    args = parse_args()
    load_data = load_frankfurter_ecb_rates("bigquery", args.start, args.end)
    print(load_data)
