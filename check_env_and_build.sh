#!/bin/bash

# Determine the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FILE="$SCRIPT_DIR/updates.csv"

# Load the .env file from the script's directory
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo ".env file not found in $SCRIPT_DIR. Exiting."
    exit 1
fi

# Check if .env file exists inside the React app
if [ -f "$REACT_APP_PATH/.env" ]; then
    echo ".env file found in the React app path."
else
    echo ".env file not found in the React app path. Exiting."
    exit 1
fi

# Check if the serve path is empty
if [ -z "$(ls -A "$SERVE_PATH")" ]; then
    echo "Serve path is empty. Proceeding with build."
    bash "$SCRIPT_DIR/build.sh" "initial_build"
else
    echo "Serve path is not empty. Exiting."
    exit 0
fi