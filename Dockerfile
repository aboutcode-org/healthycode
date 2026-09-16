FROM python:3.13-slim

LABEL org.opencontainers.image.source="https://github.com/aboutcode-org/healthycode"
LABEL org.opencontainers.image.description="Client to generate GrimoireLab metrics for Project Health using the software analytics platform GrimoireLab"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/healthycode

RUN pip install --no-cache-dir poetry
RUN poetry config virtualenvs.in-project true

COPY pyproject.toml poetry.lock* ./
RUN poetry install --no-interaction --no-ansi --no-root

COPY . .

RUN poetry build -f wheel \
    && .venv/bin/pip install dist/*.whl