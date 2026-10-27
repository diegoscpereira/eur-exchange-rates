.PHONY: lint fix ingest

PYTHON = uv run python
DBT = uv run dbt
DBT_FLAGS = --project-dir transformation --profiles-dir transformation
SQLFLUFF = uv run --env-file .env sqlfluff

# Load raw FX rates into BigQuery (dlt)
ingest:
	$(PYTHON) ingestion/<file>.py

# Any dbt command from the repo root, e.g.:
#   make dbt-build
#   make dbt-build ARGS="--select trusted"
#   make dbt-docs ARGS="generate"
dbt-%:
	$(DBT) $* $(DBT_FLAGS) $(ARGS)

lint:
	$(SQLFLUFF) lint transformation/models

fix:
	$(SQLFLUFF) fix transformation/models