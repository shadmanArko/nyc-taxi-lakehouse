"""Daily pipeline: download -> load Bronze -> dbt build (Silver, Gold, tests)."""

from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

PROJECT = "/opt/project"
PYTHON = "/home/airflow/pipeline-venv/bin/python"
DBT = "/home/airflow/pipeline-venv/bin/dbt"


def alert_on_failure(context):
    """Called by Airflow when a task fails. Replace the print with email/Slack later."""
    task = context["task_instance"]
    print(f"ALERT: task '{task.task_id}' failed in DAG '{task.dag_id}' (run {context['run_id']})")


default_args = {
    "retries": 2,                          # try again twice before giving up
    "retry_delay": timedelta(minutes=1),   # wait a minute between tries
    "on_failure_callback": alert_on_failure,
}

with DAG(
    dag_id="green_taxi_daily",
    schedule="0 6 * * *",                  # every day at 06:00
    start_date=datetime(2025, 1, 1),
    catchup=False,                         # don't run for every past day
    max_active_runs=1,                     # never overlap: DuckDB allows one writer at a time
    default_args=default_args,
    tags=["nyc-taxi"],
) as dag:

    download = BashOperator(
        task_id="download",
        bash_command=f"cd {PROJECT} && PYTHONPATH=src {PYTHON} -m nyc_taxi_lakehouse.download",
    )

    load_bronze = BashOperator(
        task_id="load_bronze",
        bash_command=f"cd {PROJECT} && PYTHONPATH=src {PYTHON} -m nyc_taxi_lakehouse.load_bronze",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {PROJECT}/dbt && {DBT} build --profiles-dir .",
    )

    download >> load_bronze >> dbt_build
