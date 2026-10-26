DBT = uv run dbt
DBT_FLAGS = --project-dir transformation --profiles-dir transformation

# Any dbt command from the repo root, e.g.:
#   make dbt-build
#   make dbt-build ARGS="--select trusted"
#   make dbt-docs ARGS="generate"
dbt-%:
	$(DBT) $* $(DBT_FLAGS) $(ARGS)
