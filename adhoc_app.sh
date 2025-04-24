#!/bin/bash

# Ensure a .app directory is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_app>"
    exit 1
fi

APP_PATH="$1"

# Verify the provided path is a .app bundle
if [[ ! -d "$APP_PATH" || "${APP_PATH##*.}" != "app" ]]; then
    echo "Error: The specified path is not a valid .app directory."
    exit 1
fi

# Function to check if a file is a Mach-O binary
is_mach_o() {
    file "$1" | grep -q "Mach-O"
}

echo "Ad-hoc signing binaries in: $APP_PATH"

# Temp directory for extracted entitlements
TEMP_DIR=$(mktemp -d)

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Iterate through all files within the .app directory
find "$APP_PATH" -type f | while read -r FILE; do
    if is_mach_o "$FILE"; then
        echo "Processing: $FILE"

        # Extract entitlements from the existing binary
        ENTITLEMENTS_FILE="$TEMP_DIR/entitlements.plist"
        ldid -e "$FILE" > "$ENTITLEMENTS_FILE" 2>/dev/null

        # Check if entitlements were successfully extracted
        if [ -s "$ENTITLEMENTS_FILE" ]; then
            echo "Entitlements extracted for: $FILE"
        else
            echo "No entitlements found for: $FILE"
            rm -f "$ENTITLEMENTS_FILE"
        fi

        # Ad-hoc sign the binary
        if [ -f "$ENTITLEMENTS_FILE" ]; then
            codesign --force --sign - --entitlements "$ENTITLEMENTS_FILE" "$FILE" 2>/dev/null
        else
            codesign --force --sign - "$FILE" 2>/dev/null
        fi

        # Check result
        if [ $? -eq 0 ]; then
            echo "Signed: $FILE"
        else
            echo "Failed to sign: $FILE"
        fi
    fi
done

echo "Ad-hoc signing complete."
