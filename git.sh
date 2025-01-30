#!/bin/bash

# Determine the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Load the .env file from the script's directory
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo ".env file not found in $SCRIPT_DIR. Exiting."
    exit 1
fi

cd "$REACT_APP_PATH" || exit

echo "Installing dependencies as $REACT_APP_USER..."
npm install --force

echo "Building the React app..."
NODE_OPTIONS="--max_old_space_size=4096" npm run build

if [ $? -eq 0 ]; then
    echo "Build successful. Deploying to Nginx..."

    # Ensure Nginx serve path exists
    if [ ! -d "$NGINX_SERVE_PATH" ]; then
        echo "Creating Nginx serve directory..."
        sudo -u "$NGINX_USER" mkdir -p "$NGINX_SERVE_PATH"
    fi

    # Remove old files and deploy new ones
    sudo rm -rf "$NGINX_SERVE_PATH"/*
    sudo cp -r "$REACT_APP_PATH/build/"* "$NGINX_SERVE_PATH"

    # Set proper ownership for Nginx files
    sudo chown -R "$NGINX_USER":"$NGINX_USER" "$NGINX_SERVE_PATH"

    # Clean up build folder
    sudo -u "$REACT_APP_USER" rm -rf "$REACT_APP_PATH/build"

    echo "Deployment complete!"
else
    echo "Build failed!"
    exit 1
fi