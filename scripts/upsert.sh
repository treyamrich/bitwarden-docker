#!/bin/sh
# Usage: ./upsert.sh "FOLDER/ITEM_NAME" "USERNAME" "PASSWORD"
set -e

ITEM_PATH="$1"
USERNAME="$2"
PASSWORD="$3"

if [ -z "$ITEM_PATH" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 FOLDER/ITEM_NAME USERNAME PASSWORD"
    exit 1
fi

# Load BW_SESSION from session file
export BW_SESSION=$(cat "$SESSION_FILE")

# Split folder and item name
FOLDER=$(dirname "$ITEM_PATH")
ITEM_NAME=$(basename "$ITEM_PATH")

# --- Folder validation / create if missing ---
FOLDER_ID=$(bw list folders | jq -r --arg NAME "$FOLDER" '.[] | select(.name==$NAME) | .id')
if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" = "null" ]; then
    echo "Folder '$FOLDER' not found, creating..."
    
    FOLDER_ID=$(bw get template folder \
      | jq --arg name "$FOLDER" '.name = $name' \
      | bw encode \
      | bw create folder \
      | jq -r '.id')
    
    echo "Created folder '$FOLDER' with ID $FOLDER_ID"
fi

# --- Check if the item exists (folder + name = unique key) ---
ITEM_ID=$(bw list items --folderid "$FOLDER_ID" --search "$ITEM_NAME" \
    | jq -r --arg NAME "$ITEM_NAME" '.[] | select(.name==$NAME) | .id')

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
    echo "Creating Bitwarden item: $ITEM_PATH"

    bw get template item \
      | jq --arg name "$ITEM_NAME" \
           --arg username "$USERNAME" \
           --arg password "$PASSWORD" \
           --arg folder "$FOLDER_ID" \
           '.type = 1
            | .name = $name
            | .login.username = $username
            | .login.password = $password
            | .folderId = $folder' \
      | bw encode \
      | bw create item >/dev/null

else
    echo "Updating Bitwarden item: $ITEM_PATH"

    bw get template item \
        | jq --arg name "$ITEM_NAME" \
            --arg username "$USERNAME" \
            --arg password "$PASSWORD" \
            --arg folder "$FOLDER_ID" \
            '.type = 1
                | .name = $name
                | .login.username = $username
                | .login.password = $password
                | .folderId = $folder' \
        | bw encode \
        | bw edit item "$ITEM_ID" >/dev/null
fi

echo "Password stored in Bitwarden for $ITEM_PATH"
