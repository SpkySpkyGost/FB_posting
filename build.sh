#!/bin/bash

echo "Starting build process..."

echo "Installing dependencies..."
pip install -r requirements.txt

#for Vercel
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "Build completed successfully!"