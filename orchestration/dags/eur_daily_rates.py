import os
from datetime import datetime, timedelta, timezone

from airflow.providers.docker.operators.docker import DockerOperator
from airflow.sdk import DAG
from airflow.timetables.trigger import CronTriggerTimetable
from docker.types import Mount


PIPELINE_IMAGE = os.environ["PIPELINE_IMAGE"]
GCP_PROJECT_ID = os.environ["GCP_PROJECT_ID"]
DBT_SERVICE_ACCOUNT = os.environ["DBT_SERVICE_ACCOUNT"]
ADC_PATH_DLT = os.environ["ADC_PATH_DLT"]   
ADC_PATH_DBT = os.environ["ADC_PATH"]       

ADC_TARGET = "/root/.config/gcloud/application_default_credentials.json"
LOAD_DATE = "{{ macros.ds_add(ds, -1) }}"   


def adc_mount(host_path: str) -> Mount:
    return Mount(
        source=host_path, target=ADC_TARGET,
        type="bind", read_only=True,
    )


docker_defaults = {
    "image": PIPELINE_IMAGE,
    "docker_url": "unix://var/run/docker.sock",
    "auto_remove": "success",
    "mount_tmp_dir": False,
}

default_args = {
    "retries": 3,
    "retry_delay": timedelta(minutes=2),
}

with DAG(
    dag_id="eur_daily_rates",
    schedule=CronTriggerTimetable("0 6 * * *", timezone="UTC"),
    start_date=datetime(2026, 10, 1, tzinfo=timezone.utc),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["eur-exchange-rates"],
):
    ingest = DockerOperator(
        task_id="ingest",
        command=[
            "python", "ingestion/frankfurter.py",
            "--start", LOAD_DATE,
        ],
        environment={"GOOGLE_CLOUD_PROJECT": GCP_PROJECT_ID},
        mounts=[adc_mount(ADC_PATH_DLT)],
        **docker_defaults,
    )

    transform = DockerOperator(
        task_id="transform",
        command=[
            "dbt", "build",
            "--project-dir", "transformation",
            "--profiles-dir", "transformation",
        ],
        environment={
            "GCP_PROJECT_ID": GCP_PROJECT_ID,
            "DBT_SERVICE_ACCOUNT": DBT_SERVICE_ACCOUNT,
            "DBT_TARGET": "prod",
        },
        mounts=[adc_mount(ADC_PATH_DBT)],
        **docker_defaults,
    )

    ingest >> transform