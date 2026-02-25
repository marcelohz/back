# back/Dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base

# Install minimal system deps required to build some wheels and health checks
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential gcc libpq-dev ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /app

# Copy dependency manifest first for caching
COPY requirements.txt /app/requirements.txt

# Install python deps as root
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy application code and set ownership
COPY --chown=appuser:appuser . /app

# Ensure upload folder exists and owned by appuser
RUN mkdir -p /app/documentos && chown -R appuser:appuser /app/documentos /app

# Provide entrypoint helper and switch to non-root user
USER appuser
COPY --chown=appuser:appuser docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV PYTHONUNBUFFERED=1
ENV FLASK_ENV=production
ENV GUNICORN_WORKERS=4
ENV GUNICORN_THREADS=1
ENV GUNICORN_TIMEOUT=30
ENV GUNICORN_MAX_REQUESTS=1000
ENV GUNICORN_MAX_REQUESTS_JITTER=50

EXPOSE 8000

CMD ["/app/entrypoint.sh"]
