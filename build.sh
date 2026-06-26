#!/bin/bash

echo "Starting build process..."

echo "Installing dependencies with uv..."
uv pip install -r requirements.txt

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "Build completed successfully!"