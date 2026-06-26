#!/bin/bash
set -e

echo "=== BUILD START ==="

echo "Installing dependencies..."
python3.9 -m pip install -r requirements.txt

echo "Running database migrations..."
python3.9 manage.py migrate --noinput

echo "=== BUILD END ==="