#!/bin/sh
# Env vars are globally available

echo "================================Logging into Bitwarden================================"
set -e

renew_session() {
    # Login only needs to be done once per machine and ephemeral tokens are generated afterwards
    echo "No session found. Logging in..."
    echo "Log in to Bitwarden CLI:"
    bw login
    # Fail if the vault cannot be unlocked
    set -e
    echo "Unlocking vault enter password..."
    NEW_BW_SESSION=$(bw unlock --raw)
    echo $NEW_BW_SESSION > $SESSION_FILE
    echo "Session saved!"
}

# Check if session file exists
if [ -f "$SESSION_FILE" ]; then
    export BW_SESSION=$(cat "$SESSION_FILE")
    if bw status >/dev/null 2>&1; then
        echo "Using existing session."
    else
        renew_session
    fi
else
    renew_session
fi