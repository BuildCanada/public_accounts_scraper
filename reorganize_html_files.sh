#!/bin/bash

# Script to reorganize HTML files from wget download structure
# to a cleaner /public_accounts/YEAR/... structure
#
# Usage: ./reorganize_html_files.sh [base_output_dir]
#
# Source structure examples:
#   ./public_accounts_2025/www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/2025/vol1/s8/adts-sdra-eng.html
#   ./public_accounts_2022/webarchiveweb.wayback.bac-lac.canada.ca/web/20230216180145/https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/2022/index-eng.html
#   ./public_accounts_2020/epe.lac-bac.gc.ca/100/201/301/public_accounts_can/html/2020/recgen/cpc-pac/2020/index-eng.html
#
# Target structure:
#   ./public_accounts/2025/vol1/s8/adts-sdra-eng.html
#   ./public_accounts/2022/index-eng.html
#   ./public_accounts/2020/index-eng.html

set -e  # Exit on error

# Default output directory
OUTPUT_BASE="${1:-./public_accounts}"

# Counter for files processed
TOTAL_FILES=0
COPIED_FILES=0

echo "Reorganizing HTML files..."
echo "Output directory: $OUTPUT_BASE"
echo ""

# Process each public_accounts_YEAR directory
for source_dir in ./public_accounts_*/; do
    if [ ! -d "$source_dir" ]; then
        continue
    fi

    # Extract year from directory name
    year=$(basename "$source_dir" | sed 's/public_accounts_//')

    echo "Processing year: $year"

    # Find all HTML files in this directory
    while IFS= read -r -d '' html_file; do
        ((TOTAL_FILES++))

        # Extract the relative path after the year
        # Handle different URL structures:

        # For recent years (www.tpsgc-pwgsc.gc.ca or www.canada.ca)
        if [[ "$html_file" =~ /recgen/cpc-pac/$year/(.+)$ ]]; then
            relative_path="${BASH_REMATCH[1]}"

        # For wayback machine (2022)
        elif [[ "$html_file" =~ /cpc-pac/$year/(.+)$ ]]; then
            relative_path="${BASH_REMATCH[1]}"

        # For archived years (epe.lac-bac.gc.ca)
        elif [[ "$html_file" =~ /public_accounts_can/html/$year/recgen/cpc-pac/$year/(.+)$ ]]; then
            relative_path="${BASH_REMATCH[1]}"

        # Fallback: try to find any path after the year
        elif [[ "$html_file" =~ /$year/(.+)$ ]]; then
            relative_path="${BASH_REMATCH[1]}"

        else
            echo "  Warning: Could not extract path for: $html_file"
            continue
        fi

        # Create target path
        target_file="$OUTPUT_BASE/$year/$relative_path"
        target_dir=$(dirname "$target_file")

        # Create target directory if it doesn't exist
        mkdir -p "$target_dir"

        # Copy the file
        cp "$html_file" "$target_file"
        ((COPIED_FILES++))

        # Show progress for every 50 files
        if [ $((COPIED_FILES % 50)) -eq 0 ]; then
            echo "  Copied $COPIED_FILES files..."
        fi

    done < <(find "$source_dir" -name "*.html" -type f -print0)

    echo "  Completed year $year"
    echo ""
done

echo "========================================="
echo "Reorganization complete!"
echo "Total HTML files found: $TOTAL_FILES"
echo "Files copied: $COPIED_FILES"
echo "Output directory: $OUTPUT_BASE"
echo "========================================="
