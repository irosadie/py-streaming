#!/bin/bash

# Name of the virtual environment
VENV_DIR="stream"

# Check if the virtual environment exists
if [ -d "$VENV_DIR" ]; then
    echo "Activating virtual environment '$VENV_DIR'..."
    source "$VENV_DIR/bin/activate"
else
    echo "Virtual environment '$VENV_DIR' not found."
    exit 1
fi

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set default port
PORT=${PORT:-5000}

# Check if the Flask application file exists
FLASK_APP_FILE="index.py"
if [ -f "$FLASK_APP_FILE" ]; then
    echo "Running Flask API..."
    
    # Run Gunicorn
    gunicorn -w 4 -b 0.0.0.0:$PORT index:app

else
    echo "Flask application file '$FLASK_APP_FILE' not found."
    exit 1
fi