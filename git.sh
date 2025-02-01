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

# Ensure the SSH key is used for Git operations
export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"

# Log function
log_update() {
    local type=$1
    local status=$2
    local commit_hash=$3
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$type,$commit_hash,$status" >> "$LOG_FILE"
}

# Ensure the React app path exists
if [ ! -d "$REACT_APP_PATH" ]; then
    echo "Cloning repository as $REACT_APP_USER using SSH key..."
    sudo -u "$REACT_APP_USER" GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git clone -b "$GIT_BRANCH" "$GIT_REPO_SSH" "$REACT_APP_PATH"
    cd "$REACT_APP_PATH" || exit
    log_update "git" "success" "initial_clone"
    bash "$SCRIPT_DIR/check_env_and_build.sh"
    exit 0
else
    echo "Repository exists. Checking for updates..."
    cd "$REACT_APP_PATH" || exit

    sudo -u "$REACT_APP_USER" GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git fetch origin "$GIT_BRANCH"

    LOCAL_COMMIT=$(sudo -u "$REACT_APP_USER" GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git rev-parse HEAD)
    REMOTE_COMMIT=$(sudo -u "$REACT_APP_USER" GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git rev-parse origin/"$GIT_BRANCH")

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "New commit found! Pulling latest changes..."
        if sudo -u "$REACT_APP_USER" GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git pull origin "$GIT_BRANCH"; then
            log_update "git" "success" "$REMOTE_COMMIT"
            bash "$SCRIPT_DIR/build.sh" "$REMOTE_COMMIT"
        else
            log_update "git" "fail" "$REMOTE_COMMIT"
        fi
    else
        echo "No new updates."

        # Check if the last build failed and retry if necessary
        if [ -f "$LOG_FILE" ]; then
            LAST_BUILD_STATUS=$(tail -n 1 "$LOG_FILE" | grep ',build,' | awk -F, '{print $4}')
            LAST_BUILD_COMMIT=$(tail -n 1 "$LOG_FILE" | grep ',build,' | awk -F, '{print $3}')

            if [ "$LAST_BUILD_STATUS" == "fail" ] && [ "$LAST_BUILD_COMMIT" == "$LOCAL_COMMIT" ]; then
                echo "Last build failed. Retrying build..."
                bash "$SCRIPT_DIR/build.sh" "$LOCAL_COMMIT"
            fi
        else
            echo "Log file not found. Proceeding with environment checks and build."
            bash "$SCRIPT_DIR/check_env_and_build.sh"
        fi
    fi
fi

# Set permissions for the React app directory and files
find "$REACT_APP_PATH" -type d -exec chmod $REACT_APP_DIR_PERM {} \;
find "$REACT_APP_PATH" -type f -exec chmod $REACT_APP_FILE_PERM {} \;