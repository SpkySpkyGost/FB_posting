#!/bin/bash
set -e

echo "Installing dependencies..."
uv pip install --system -r requirements.txt

echo "Running database migrations..."
uv run python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear || true

echo "Build completed successfully!"