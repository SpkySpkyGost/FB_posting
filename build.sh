#!/bin/bash

echo "Installing dependencies with uv..."
uv pip install --system -r requirements.txt

echo "Build completed successfully!"