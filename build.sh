#!/bin/bash
set -e

echo "=== BUILD START ==="

echo "Installing dependencies..."
python3 -m pip install -r requirements.txt

echo "Running database migrations..."
python3 manage.py migrate --noinput

echo "=== BUILD END ==="