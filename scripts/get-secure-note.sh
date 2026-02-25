#!/bin/sh
# Usage: get-secure-note.sh "FOLDER/ITEM_NAME"
# Returns the notes field of a Bitwarden secure note.

if [ -z "$1" ]; then
    echo "Usage: $0 FOLDER/ITEM_NAME"
    exit 1
fi

export BW_SESSION=$(cat "$SESSION_FILE")

FOLDER=$(dirname "$1")
ITEM_NAME=$(basename "$1")

FOLDER_ID=$(bw list folders | jq -r --arg NAME "$FOLDER" '.[] | select(.name==$NAME) | .id')
if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" = "null" ]; then
    echo "Folder '$FOLDER' not found."
    exit 1
fi

NOTES=$(bw list items --folderid "$FOLDER_ID" --search "$ITEM_NAME" \
    | jq -r --arg NAME "$ITEM_NAME" '.[] | select(.name==$NAME) | .notes')

if [ -z "$NOTES" ] || [ "$NOTES" = "null" ]; then
    echo "Item '$ITEM_NAME' not found or has no notes."
    exit 1
fi

echo "$NOTES"
