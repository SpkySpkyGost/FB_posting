#!/bin/bash

echo "Installing dependencies with uv..."
uv pip install --system -r requirements.txt

echo "Running database migrations..."
python manage.py migrate --noinput

echo "Build completed successfully!"