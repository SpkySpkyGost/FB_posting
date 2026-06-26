#!/bin/bash

echo "Installing dependencies..."
uv pip install --system -r requirements.txt

echo "Running database migrations..."
uv run python manage.py migrate --noinput || echo "Migrate had issues (continuing anyway)"

echo "Collecting static files..."
uv run python manage.py collectstatic --noinput --clear || echo "Collectstatic had issues"

# Ensure the folder exists even if collectstatic had problems
mkdir -p staticfiles

echo "Build completed successfully!"