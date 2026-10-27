FROM python:3.12-slim-trixie
COPY --from=ghcr.io/astral-sh/uv:0.13.0 /uv /uvx /bin/

WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY transformation/dbt_project.yml \
     transformation/packages.yml \
     transformation/package-lock.yml \
     ./transformation/
RUN dbt deps --project-dir transformation

COPY . .

CMD ["dbt", "--version"]