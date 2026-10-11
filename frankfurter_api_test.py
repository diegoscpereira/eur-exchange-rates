import dlt
from dlt.sources.rest_api import rest_api_source

# 1. Describe the API
source = rest_api_source(
    {
        "client": {"base_url": "https://api.frankfurter.dev/v2"},
        "resources": [
            {
                "name": "frankfurter_api",
                "endpoint": {"path": "providers/ecb/rates?from=2026-10-05"},
            },
        ],
    }
)

# 2. Point a pipeline at the destination
pipeline = dlt.pipeline(
    pipeline_name="api", destination="duckdb", dataset_name="eur_exchange_rates"
)

# 3. Extract
pipeline.run(source)

# 4. Run
test_df = pipeline.dataset().frankfurter_api.df()
print(test_df.head(10))
print(test_df.shape)
print(test_df["_dlt_load_id"].nunique())
print(test_df["date"].nunique())

# https://api.frankfurter.dev/v2/providers/ecb/rates?from=2026-10-01
