#!/bin/sh

export BW_SESSION=$(cat "$SESSION_FILE")
FOLDER=$(dirname "$1")
ITEM_NAME=$(basename "$1")

FOLDER_ARG=""
if [ "$FOLDER" != "." ]; then
    FOLDER_ID=$(bw list folders | jq -r --arg NAME "$FOLDER" '.[] | select(.name==$NAME) | .id')
    if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" = "null" ]; then
        echo "Folder '$FOLDER' not found."
        exit 1
    fi
    FOLDER_ARG="--folderid $FOLDER_ID"
fi

RESULT=$(bw list items --search "$ITEM_NAME" $FOLDER_ARG | jq -r --arg NAME "$ITEM_NAME" '.[] | select(.name==$NAME)' | jq -s '.[0]?')

if [ -z "$RESULT" ] || [ "$RESULT" = "null" ]; then
    echo "Item '$ITEM_NAME' not found."
    exit 1
fi

echo "$RESULT" | jq -r '.login.password'