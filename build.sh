#!/bin/bash
set -e

echo "=== BUILD START ==="

echo "Installing dependencies..."
uv pip install -r requirements.txt --system

echo "Running database migrations..."
python manage.py migrate --noinput

echo "=== BUILD END ==="