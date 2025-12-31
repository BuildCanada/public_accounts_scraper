#!/bin/bash

# Script to download Canada Public Accounts data
# Usage: ./download_public_accounts.sh YEAR [output_dir]
# Example: ./download_public_accounts.sh 2020
# Example: ./download_public_accounts.sh 2025 ./data

YEAR=$1
OUTPUT_DIR=${2:-"./raw/$YEAR"}

if [ -z "$YEAR" ]; then
    echo "Usage: $0 YEAR [output_dir]"
    echo "Example: $0 2020"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Downloading Public Accounts data for year $YEAR to $OUTPUT_DIR..."

# Create cookie file to bypass disclaimer page
cat > cookies.txt <<EOF
# HTTP cookie file for wget
# This cookie bypasses the disclaimer page on epe.lac-bac.gc.ca
epe.lac-bac.gc.ca	FALSE	/	FALSE	0	disclaimed	1
www.tpsgc-pwgsc.gc.ca	FALSE	/	FALSE	0	disclaimed	1
tpsgc-pwgsc.gc.ca	FALSE	/	FALSE	0	disclaimed	1
EOF

# Determine URL structure based on year
# Years 2021 and earlier are archived at epe.lac-bac.gc.ca
# Year 2015 has a different path structure with extra www.tpsgc-pwgsc.gc.ca directory
# Year 2022 is in the Wayback Machine archive
# Recent years (2023+) are on canada.ca or tpsgc-pwgsc.gc.ca
if [ "$YEAR" -eq 2015 ]; then
    # 2015 has a different archived data structure with extra directory level
    BASE_URL="https://epe.lac-bac.gc.ca/100/201/301/public_accounts_can/html/2015/www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/2015/index-eng.html"
    DOMAIN="epe.lac-bac.gc.ca"
    ACCEPT_REGEX="(www\.tpsgc-pwgsc\.gc\.ca/recgen/cpc-pac/2015/.*\.(html|pdf)|public_accounts_can/html/2015/.*\.(html|pdf))"

    wget --recursive \
         --no-parent \
         --level=5 \
         --adjust-extension \
         --page-requisites \
         --wait=0.5 \
         --random-wait \
         --accept-regex="$ACCEPT_REGEX" \
         --reject-regex='(disclaimer|avis)' \
         -e robots=off \
         --load-cookies cookies.txt \
         --keep-session-cookies \
         --continue \
         --span-hosts \
         --domains="$DOMAIN" \
         --no-check-certificate \
         "$BASE_URL"
elif [ "$YEAR" -le 2021 ]; then
    # Archived data structure
    BASE_URL="https://epe.lac-bac.gc.ca/100/201/301/public_accounts_can/html/$YEAR/recgen/cpc-pac/$YEAR/index-eng.html"
    DOMAIN="epe.lac-bac.gc.ca"
    ACCEPT_REGEX="(recgen/cpc-pac/$YEAR/.*\.(html|pdf)|public_accounts_can/html/$YEAR/.*\.(html|pdf))"

    wget --recursive \
         --no-parent \
         --level=5 \
         --adjust-extension \
         --page-requisites \
         --wait=0.5 \
         --random-wait \
         --accept-regex="$ACCEPT_REGEX" \
         --reject-regex='(disclaimer|avis)' \
         -e robots=off \
         --load-cookies cookies.txt \
         --keep-session-cookies \
         --continue \
         --span-hosts \
         --domains="$DOMAIN" \
         --no-check-certificate \
         "$BASE_URL"
elif [ "$YEAR" -eq 2022 ]; then
    # 2022 is available through Wayback Machine snapshot
    echo "Downloading from Wayback Machine archive..."
    BASE_URL="https://webarchiveweb.wayback.bac-lac.canada.ca/web/20230216180145/https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/2022/index-eng.html"

    # Note: Wayback Machine links contain different timestamps for different snapshots
    # We need to accept any snapshot that contains 2022 data
    # Only match HTML and PDF files within the public accounts path
    wget --recursive \
         --level=5 \
         --adjust-extension \
         --wait=0.5 \
         --random-wait \
         --accept-regex='(recgen/cpc-pac/2022/.*\.(html|pdf))' \
         --reject-regex='(disclaimer|avis|feedback|retroaction)' \
         -e robots=off \
         --load-cookies cookies.txt \
         --keep-session-cookies \
         --continue \
         --span-hosts \
         --domains="webarchiveweb.wayback.bac-lac.canada.ca" \
         --no-check-certificate \
         "$BASE_URL"
else
    # Recent data - try both URL structures
    echo "Downloading from canada.ca..."
    BASE_URL_1="https://www.canada.ca/en/public-services-procurement/services/payments-accounting/public-accounts/$YEAR.html"

    # Only accept files within the public-accounts or recgen/cpc-pac paths
    wget --recursive \
         --no-parent \
         --level=5 \
         --adjust-extension \
         --page-requisites \
         --wait=0.5 \
         --random-wait \
         --accept-regex='(public-accounts/.*\.(html|pdf)|recgen/cpc-pac/'"$YEAR"'/.*\.(html|pdf))' \
         --reject-regex='(disclaimer|avis|feedback|retroaction)' \
         -e robots=off \
         --load-cookies cookies.txt \
         --keep-session-cookies \
         --continue \
         --span-hosts \
         --domains="www.canada.ca,www.tpsgc-pwgsc.gc.ca,tpsgc-pwgsc.gc.ca" \
         --no-check-certificate \
         "$BASE_URL_1"

    echo "Downloading from tpsgc-pwgsc.gc.ca..."
    BASE_URL_2="https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/$YEAR/vol1/intro-eng.html"

    # Only accept files within the recgen/cpc-pac path for this year
    wget --recursive \
         --no-parent \
         --level=5 \
         --adjust-extension \
         --page-requisites \
         --wait=0.5 \
         --random-wait \
         --accept-regex='(recgen/cpc-pac/'"$YEAR"'/.*\.(html|pdf)|public-accounts/.*\.(html|pdf))' \
         --reject-regex='(disclaimer|avis|feedback|retroaction)' \
         -e robots=off \
         --load-cookies cookies.txt \
         --keep-session-cookies \
         --continue \
         --span-hosts \
         --domains="www.canada.ca,www.tpsgc-pwgsc.gc.ca,tpsgc-pwgsc.gc.ca" \
         --no-check-certificate \
         "$BASE_URL_2"
fi

echo "Download complete! Data saved to $OUTPUT_DIR"
echo "Cleaning up cookies..."
rm -f cookies.txt

# Print summary
echo ""
echo "Summary:"
echo "--------"
echo "HTML files: $(find . -name "*.html" | wc -l)"
echo "PDF files: $(find . -name "*.pdf" | wc -l)"
