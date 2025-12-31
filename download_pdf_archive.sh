#!/bin/bash

# Script to download all PDFs from the Canada Public Accounts PDF archive index
# Source: https://epe.lac-bac.gc.ca/100/201/301/public_accounts_can/pdf/index.html

set -e

# Default output directory
OUTPUT_DIR="${1:-./raw_pdfs}"

echo "Downloading PDFs from Canada Public Accounts archive..."
echo "Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create temporary cookies file to bypass disclaimer
COOKIE_FILE=$(mktemp)
echo "epe.lac-bac.gc.ca	FALSE	/	FALSE	0	disclaimed	1" > "$COOKIE_FILE"

# Cleanup function
cleanup() {
    rm -f "$COOKIE_FILE"
}
trap cleanup EXIT

# Download the index page and all PDFs it links to
wget \
    --directory-prefix="$OUTPUT_DIR" \
    --load-cookies="$COOKIE_FILE" \
    --recursive \
    --level=2 \
    --no-parent \
    --accept="*.pdf" \
    --no-clobber \
    --wait=0.5 \
    --random-wait \
    --user-agent="Mozilla/5.0 (compatible; wget)" \
    --continue \
    "https://epe.lac-bac.gc.ca/100/201/301/public_accounts_can/pdf/index.html"

echo "Download complete! PDFs saved to: $OUTPUT_DIR"
