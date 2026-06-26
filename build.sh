#!/bin/bash
set -e

echo "=== BUILD START ==="

echo "Installing dependencies..."
python3 -m pip install -r requirements.txt --break-system-packages

echo "Running database migrations..."
python3 manage.py migrate --noinput

echo "Collecting static files..."
python3 manage.py collectstatic --noinput

echo "=== BUILD END ==="