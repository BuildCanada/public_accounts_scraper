#!/bin/bash

# Script to download multiple years of Canada Public Accounts data
# Usage: ./download_multiple_years.sh START_YEAR END_YEAR
# Example: ./download_multiple_years.sh 2018 2020

START_YEAR=$1
END_YEAR=$2

if [ -z "$START_YEAR" ] || [ -z "$END_YEAR" ]; then
    echo "Usage: $0 START_YEAR END_YEAR"
    echo "Example: $0 2018 2020"
    exit 1
fi

echo "Downloading Public Accounts data from $START_YEAR to $END_YEAR..."
echo ""

for year in $(seq $START_YEAR $END_YEAR); do
    echo "========================================"
    echo "Starting download for year $year"
    echo "========================================"
    ./download_public_accounts.sh "$year"
    echo ""
    echo "Completed year $year"
    echo ""
    sleep 2
done

echo "All downloads complete!"
echo ""
echo "Overall summary:"
for year in $(seq $START_YEAR $END_YEAR); do
    dir="public_accounts_$year"
    if [ -d "$dir" ]; then
        html_count=$(find "$dir" -name "*.html" 2>/dev/null | wc -l)
        pdf_count=$(find "$dir" -name "*.pdf" 2>/dev/null | wc -l)
        echo "Year $year: $html_count HTML files, $pdf_count PDF files"
    fi
done
