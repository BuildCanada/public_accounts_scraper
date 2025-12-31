# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains shell scripts for downloading Canada Public Accounts data from government websites. The scripts handle archived data (2021 and earlier from epe.lac-bac.gc.ca), 2022 data from the Wayback Machine archive, and recent data (2023+ from canada.ca and tpsgc-pwgsc.gc.ca).

## Commands

### Download data for a single year
```bash
./download_public_accounts.sh YEAR [output_dir]
```
- Downloads all HTML and PDF files for the specified year
- Defaults to `./public_accounts_YEAR` directory if output_dir not specified
- Example: `./download_public_accounts.sh 2020`
- Example: `./download_public_accounts.sh 2025 ./data`

### Download data for multiple years
```bash
./download_multiple_years.sh START_YEAR END_YEAR
```
- Downloads data for a range of years sequentially
- Example: `./download_multiple_years.sh 2018 2020`

## Architecture

### URL Structure Logic

The download script handles three different URL structures based on the year:

**Archived years (≤2021):**
- Source: `epe.lac-bac.gc.ca`
- Path pattern: `/100/201/301/public_accounts_can/html/YEAR/recgen/cpc-pac/YEAR/`
- Uses regex-based accept filtering for the archived structure

**Year 2022:**
- Source: Wayback Machine snapshot at `webarchiveweb.wayback.bac-lac.canada.ca`
- Specific snapshot: `web/20230216180145/https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/2022/index-eng.html`
- Uses glob-based accept filtering (*.html, *.pdf)
- Spans hosts to include both wayback domain and original tpsgc-pwgsc.gc.ca domain

**Recent years (≥2023):**
- Primary source: `www.canada.ca/en/public-services-procurement/services/payments-accounting/public-accounts/`
- Alternative source: `www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/YEAR/vol1/`
- Attempts both URLs to ensure complete coverage
- Uses glob-based accept filtering (*.html, *.pdf)

### Download Strategy

- Uses `wget` with recursive crawling (level=5)
- Includes page requisites (CSS, images, etc.) with `--page-requisites`
- Implements polite crawling with `--wait=0.5` and `--random-wait`
- Bypasses disclaimer pages using cookie file with `disclaimed=1` cookie
- Spans hosts to follow cross-domain links within specified domains
- Filters out disclaimer, feedback, and administrative pages via reject-regex
- Continues interrupted downloads with `--continue`

### Cookie Handling

A temporary `cookies.txt` file is created at the start of each download to bypass disclaimer pages on government sites. This is automatically cleaned up after the download completes.
