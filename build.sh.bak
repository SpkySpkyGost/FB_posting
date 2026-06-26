#!/bin/bash
set -e

echo "=== BUILD START ==="

echo "Installing dependencies..."
uv pip install -r requirements.txt --system

echo "Running migrations..."
python3.13 manage.py migrate --noinput || true

echo "Collecting static files..."
python3.13 manage.py collectstatic --noinput --clear

echo "=== BUILD END ==="