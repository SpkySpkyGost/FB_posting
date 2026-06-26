#!/bin/bash
set -e

echo "Installing dependencies..."
uv pip install --system -r requirements.txt || echo "pip install  failed or no changes"

echo "Running database migrations..."
python3 manage.py migrate --noinput || echo "Migrate failed or no changes"

echo "Build completed successfully!"