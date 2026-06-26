#!/bin/bash

echo "Installing dependencies..."
uv pip install --system -r requirements.txt

echo "Running database migrations..."
python3 manage.py migrate --noinput || echo "Migrate had issues (continuing anyway)"

echo "Collecting static files..."
python3 manage.py collectstatic --noinput --clear || echo "Collectstatic had issues"

# Make sure the folder exists
mkdir -p staticfiles

echo "Build completed successfully!"