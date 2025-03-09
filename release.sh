#!/usr/bin/env bash

# Abort on error
set -eo pipefail

# 𝗔𝗦𝗦𝗘𝗚𝗡𝗔 𝗜𝗟 𝗡𝗢𝗠𝗘 𝗗𝗘𝗟 𝗗𝗘𝗩𝗜𝗖𝗘 𝗤𝗨𝗜
DEVICE="pipa"

# Path configuration
DEVICE_DIR="out/target/product/$DEVICE"
if [[ ! -d "$DEVICE_DIR" ]]; then
    echo "Error: Device directory not found: $DEVICE_DIR"
    exit 1
fi

# Function to get user confirmation
get_confirmation() {
    while true; do
        printf "Execute this command? (Y/N): "
        read -r response
        case "$response" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please enter Y or N" ;;
        esac
    done
}

# Extract ROM ZIP file
ZIP_FILES=("$DEVICE_DIR"/*.zip)
if [[ ${#ZIP_FILES[@]} -eq 0 ]]; then
    echo "Error: No ROM ZIP found in $DEVICE_DIR"
    exit 1
elif [[ ${#ZIP_FILES[@]} -gt 1 ]]; then
    echo "Error: Multiple ZIP files found. Keep only one ROM ZIP."
    exit 1
fi

ZIP_PATH="${ZIP_FILES[0]}"
ZIPNAME=$(basename "$ZIP_PATH")

# Extract tag from ZIP filename (remove everything after last '-')
TAG=$(basename "$ZIP_PATH" .zip | sed 's/-[^-]*$//')
TITLE="$ZIPNAME"

# Validate IMG files
IMG_FILES=(
    "$DEVICE_DIR/boot.img"
    "$DEVICE_DIR/dtbo.img"
    "$DEVICE_DIR/vendor_boot.img"
)

# Show extracted info
echo "Device: $DEVICE"
echo "Tag: $TAG"
echo "ROM ZIP: $ZIPNAME"
printf '\n'

# Get release notes
echo "Enter up to 5 release notes (press Enter after each, type 'done' when finished):"
echo "Do not start with '-', bullets will be added automatically"
NOTES=""
count=0

while [[ $count -lt 5 ]]; do
    printf "Note %d: " "$count"
    read -r LINE
    [[ "$LINE" = "done" ]] && break

    if [[ -n "$NOTES" ]]; then
        NOTES="${NOTES}
- ${LINE}"
    else
        NOTES="- ${LINE}"
    fi
    ((count++))
done

# Release options
echo
echo "Release options:"
echo "1. All files (IMGs + ROM ZIP)"
echo "2. Only IMG files"
echo "3. Only ROM ZIP"
printf "Choose option (1-3): "
read -r choice

# File selection logic
case $choice in
    1)
        for f in "${IMG_FILES[@]}" "$ZIP_PATH"; do
            if [[ ! -f "$f" ]]; then
                echo "Error: Missing required file $(basename "$f")"
                exit 1
            fi
        done
        FILES=("${IMG_FILES[@]}" "$ZIP_PATH")
        ;;
    2)
        for f in "${IMG_FILES[@]}"; do
            if [[ ! -f "$f" ]]; then
                echo "Error: Missing required file $(basename "$f")"
                exit 1
            fi
        done
        FILES=("${IMG_FILES[@]}")
        ;;
    3)
        FILES=("$ZIP_PATH")
        ;;
    *)
        echo "Error: Invalid option"
        exit 1
        ;;
esac

# Build command with full paths
CMD=(gh release create "$TAG" "${FILES[@]}" --title "$TITLE" --notes "$NOTES")

# Preview
printf '\n'
echo "⚠️  ATTENZIONE: La release sarà creata in QUESTO repository ⚠️"
echo "Repository corrente: $(git config --get remote.origin.url)"
echo "================================"
printf "%s " "${CMD[@]}"
printf '\n'
echo "================================"
printf '\n'

# Confirmation
if get_confirmation; then
    "${CMD[@]}" || {
        echo "Error: Failed to create release"
        exit 1
    }
    echo "Release created successfully!"
else
    echo "Operation cancelled."
fi

read -r -p "Press enter to exit"
