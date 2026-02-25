#!/usr/bin/env bash
set -euo pipefail

# defaults -> can be overridden via env
WORKERS=${GUNICORN_WORKERS:-4}
THREADS=${GUNICORN_THREADS:-1}
TIMEOUT=${GUNICORN_TIMEOUT:-30}
MAX_REQS=${GUNICORN_MAX_REQUESTS:-1000}
MAX_REQS_JITTER=${GUNICORN_MAX_REQUESTS_JITTER:-50}

# Gunicorn command using app factory
exec gunicorn -w "$WORKERS" --threads "$THREADS" --timeout "$TIMEOUT" \
  --max-requests "$MAX_REQS" --max-requests-jitter "$MAX_REQS_JITTER" \
  --access-logfile - --error-logfile - --preload \
  -b 0.0.0.0:8000 "app:create_app()"
