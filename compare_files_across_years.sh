#!/bin/bash

# Script to compare files across different years of public_accounts data
# Shows files that appear in some years but not others
#
# Usage: ./compare_files_across_years.sh [--exclude YEAR1,YEAR2,...] [--list-unique]
#   --exclude, -e    Comma-separated list of years to exclude from analysis
#   --list-unique    List actual files unique to each year (not just count)

set -euo pipefail

# Parse command line arguments
EXCLUDED_YEARS=()
LIST_UNIQUE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--exclude)
            IFS=',' read -ra EXCLUDED_YEARS <<< "$2"
            shift 2
            ;;
        --list-unique)
            LIST_UNIQUE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--exclude YEAR1,YEAR2,...] [--list-unique]"
            echo "  --exclude, -e    Comma-separated list of years to exclude from analysis"
            echo "  --list-unique    List actual files unique to each year (not just count)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Analyzing public_accounts directories..."
echo

# Base directory containing all years
BASE_DIR="public_accounts"

if [ ! -d "$BASE_DIR" ]; then
    echo "Error: $BASE_DIR directory not found!"
    exit 1
fi

# Find all year subdirectories
YEARS=()
for dir in "$BASE_DIR"/*; do
    if [ -d "$dir" ]; then
        year=$(basename "$dir")
        # Only include if year is a 4-digit number
        if [[ "$year" =~ ^[0-9]{4}$ ]]; then
            YEARS+=("$year")
        fi
    fi
done

# Sort years
IFS=$'\n' YEARS=($(sort -n <<<"${YEARS[*]}"))
unset IFS

# Filter out excluded years
if [ ${#EXCLUDED_YEARS[@]} -gt 0 ]; then
    FILTERED_YEARS=()
    for year in "${YEARS[@]}"; do
        excluded=false
        for excluded_year in "${EXCLUDED_YEARS[@]}"; do
            if [ "$year" = "$excluded_year" ]; then
                excluded=true
                break
            fi
        done
        if [ "$excluded" = false ]; then
            FILTERED_YEARS+=("$year")
        fi
    done
    YEARS=("${FILTERED_YEARS[@]}")

    echo "Excluded years: ${EXCLUDED_YEARS[*]}"
fi

if [ ${#YEARS[@]} -eq 0 ]; then
    echo "No public_accounts directories found (after exclusions)!"
    exit 1
fi

echo "Analyzing years: ${YEARS[*]}"
echo

# Function to normalize file paths
# Removes domain-specific and year-specific prefixes to get comparable paths
normalize_path() {
    local file="$1"
    local year="$2"

    # Remove the base directory
    file="${file#public_accounts/${year}/}"

    # Try to extract the meaningful part after domain and year directories
    # Handle different URL structures (archived, wayback, recent)

    # For archived structure (epe.lac-bac.gc.ca)
    if [[ "$file" == epe.lac-bac.gc.ca/* ]]; then
        file=$(echo "$file" | sed -E "s|epe\.lac-bac\.gc\.ca/.*/recgen/cpc-pac/${year}/||")
    fi

    # For wayback structure
    if [[ "$file" == *wayback* ]]; then
        file=$(echo "$file" | sed -E "s|.*tpsgc-pwgsc\.gc\.ca/recgen/cpc-pac/${year}/||")
    fi

    # For canada.ca structure
    if [[ "$file" == *canada.ca/* ]]; then
        file=$(echo "$file" | sed -E "s|.*canada\.ca/.*/public-accounts/||")
    fi

    # For tpsgc-pwgsc.gc.ca structure
    if [[ "$file" == *tpsgc-pwgsc.gc.ca/* ]]; then
        file=$(echo "$file" | sed -E "s|.*tpsgc-pwgsc\.gc\.ca/recgen/cpc-pac/${year}/||")
    fi

    echo "$file"
}

# Build a catalog of all files by year
echo "Cataloging files by year..."
for year in "${YEARS[@]}"; do
    dir="$BASE_DIR/${year}"
    echo -n "  Processing ${year}..."

    # Find all HTML and PDF files, excluding /pdfs directory
    find "$dir" -type f \( -name "*.html" -o -name "*.pdf" \) 2>/dev/null | grep -v "/pdfs/" | while read -r file; do
        normalized=$(normalize_path "$file" "$year")
        # Only include files in numeric folders (vol1, vol2, s1, s2, etc.)
        if [[ "$normalized" =~ (vol[0-9]+|s[0-9]+|ds[0-9]+)/.*\.(html|pdf)$ ]]; then
            echo "$normalized" >> "$TEMP_DIR/files_${year}.txt"
        fi
    done 2>/dev/null || true

    if [ -f "$TEMP_DIR/files_${year}.txt" ]; then
        count=$(wc -l < "$TEMP_DIR/files_${year}.txt")
        echo " ${count} files"
    else
        echo " 0 files"
        touch "$TEMP_DIR/files_${year}.txt"
    fi
done

echo

# Get all unique files across all years
cat "$TEMP_DIR"/files_*.txt 2>/dev/null | sort -u > "$TEMP_DIR/all_files.txt"
total_unique=$(wc -l < "$TEMP_DIR/all_files.txt")

echo "Total unique files across all years: ${total_unique}"
echo

# Analyze which files appear in which years
echo "Analyzing file presence across years..."
echo

# Create output files
> "$TEMP_DIR/missing_in_some.txt"
> "$TEMP_DIR/file_matrix.txt"

while IFS= read -r file; do
    years_present=()
    years_missing=()

    for year in "${YEARS[@]}"; do
        if grep -Fxq "$file" "$TEMP_DIR/files_${year}.txt" 2>/dev/null; then
            years_present+=("$year")
        else
            years_missing+=("$year")
        fi
    done

    # If file is not present in all years, record it
    if [ ${#years_missing[@]} -gt 0 ]; then
        present_str=$(IFS=,; echo "${years_present[*]}")
        missing_str=$(IFS=,; echo "${years_missing[*]}")
        echo "${file}|${present_str}|${missing_str}" >> "$TEMP_DIR/missing_in_some.txt"
    fi
done < "$TEMP_DIR/all_files.txt"

# Display results
files_in_some=$(wc -l < "$TEMP_DIR/missing_in_some.txt")

if [ "$files_in_some" -eq 0 ]; then
    echo -e "${GREEN}All files appear consistently across all years!${NC}"
else
    echo -e "${YELLOW}Found ${files_in_some} files that appear in some years but not others${NC}"
    echo
    echo "Files missing in some years:"
    echo "=========================================="

    while IFS='|' read -r file present missing; do
        echo -e "${BLUE}File:${NC} $file"
        echo -e "  ${GREEN}Present in:${NC} $present"
        echo -e "  ${RED}Missing in:${NC} $missing"
        echo
    done < "$TEMP_DIR/missing_in_some.txt"
fi

# Summary statistics
echo
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Years analyzed: ${YEARS[*]}"
echo "Total unique files: ${total_unique}"
echo "Files present in all years: $((total_unique - files_in_some))"
echo "Files missing in some years: ${files_in_some}"

# Show files unique to specific years
echo
echo "Files unique to specific years:"
echo "=========================================="
for year in "${YEARS[@]}"; do
    unique_count=0
    unique_files=()

    while IFS='|' read -r file present missing; do
        if [ "$present" = "$year" ]; then
            ((unique_count++))
            unique_files+=("$file")
        fi
    done < "$TEMP_DIR/missing_in_some.txt"

    if [ $unique_count -gt 0 ]; then
        echo -e "${YELLOW}Year ${year}:${NC} ${unique_count} unique files"

        if [ "$LIST_UNIQUE" = true ]; then
            for file in "${unique_files[@]}"; do
                echo "  - $file"
            done
            echo
        fi
    fi
done

if [ "$LIST_UNIQUE" = false ] && [ -f "$TEMP_DIR/missing_in_some.txt" ]; then
    echo
    echo -e "${BLUE}Tip: Use --list-unique flag to see the actual filenames${NC}"
fi
