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

COMMIT_HASH=$1

# Log function
log_update() {
    local type=$1
    local status=$2
    local commit_hash=$3
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$type,$commit_hash,$status" >> "$LOG_FILE"
}

cd "$REACT_APP_PATH" || exit

echo "Installing dependencies as $REACT_APP_USER..."
npm install --force

echo "Building the React app..."
$NODE_ENV npm run build

if [ $? -eq 0 ]; then
    echo "Build successful. Deploying to Nginx..."

    # Ensure Nginx serve path exists
    if [ ! -d "$SERVE_PATH" ]; then
        echo "Creating Nginx serve directory..."
        sudo -u "$SERVE_USER" mkdir -p "$SERVE_PATH"
    fi

    # Timestamp for the backup folder
    TIMESTAMP=$(date '+%Y%m%d%H%M%S')
    BACKUP_PATH="${SERVE_PATH}_backup_$TIMESTAMP"

    # Rename the current Nginx serve path to the backup path
    if [ -d "$SERVE_PATH" ]; then
        echo "Backing up current build to $BACKUP_PATH..."
        sudo mv "$SERVE_PATH" "$BACKUP_PATH"
    fi

    # Remove old files and deploy new ones
    sudo mkdir -p "$SERVE_PATH"
    sudo cp -r "$REACT_APP_PATH/build/"* "$SERVE_PATH"

    # Set proper ownership for Nginx files
    sudo chown -R "$SERVE_USER":"$SERVE_USER" "$SERVE_PATH"

    # Set permissions for the build directory and files
    find "$SERVE_PATH" -type d -exec chmod $SERVE_DIR_PERM {} \;
    find "$SERVE_PATH" -type f -exec chmod $SERVE_FILE_PERM {} \;

    # Clean up build folder
    sudo -u "$REACT_APP_USER" rm -rf "$REACT_APP_PATH/build"

    echo "Deployment complete!"
    log_update "build" "success" "$COMMIT_HASH"

    # Retain only the last N backups
    echo "Retaining the last $RETAIN_OLD_BUILDS backups..."
    ls -dt "${SERVE_PATH}_backup_"* | tail -n +$((RETAIN_OLD_BUILDS + 1)) | xargs sudo rm -rf
else
    echo "Build failed!"
    log_update "build" "fail" "$COMMIT_HASH"
    exit 1
fi