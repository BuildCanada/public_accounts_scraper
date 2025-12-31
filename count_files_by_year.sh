#!/bin/bash

# Script to count files in each year directory under public_accounts/

BASE_DIR="./public_accounts"

# Check if the base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory $BASE_DIR does not exist"
    exit 1
fi

echo "File counts by year in $BASE_DIR:"
echo "=================================="
printf "%-8s %10s\n" "Year" "Files"
echo "----------------------------------"

# Total files counter
total_files=0

# Loop through each year directory in sorted order
for year_dir in $(ls -1 "$BASE_DIR" | sort -n); do
    full_path="$BASE_DIR/$year_dir"

    # Only process if it's a directory
    if [ -d "$full_path" ]; then
        # Count all files recursively (excluding directories)
        file_count=$(find "$full_path" -type f | wc -l | tr -d ' ')

        printf "%-8s %10s\n" "$year_dir" "$file_count"

        # Add to total
        total_files=$((total_files + file_count))
    fi
done

echo "=================================="
printf "%-8s %10s\n" "TOTAL" "$total_files"
