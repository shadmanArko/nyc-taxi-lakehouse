FROM apache/airflow:3.1.5-python3.13

# Our pipeline gets its own Python environment, built from uv.lock,
# so its libraries never clash with Airflow's own libraries.
RUN pip install --no-cache-dir uv==0.13.6
COPY --chown=airflow:root pyproject.toml uv.lock /tmp/build/
RUN cd /tmp/build \
 && UV_PROJECT_ENVIRONMENT=/home/airflow/pipeline-venv uv sync --frozen --no-install-project --no-dev
