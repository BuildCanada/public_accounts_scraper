# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Ruby CLI for downloading Canada Public Accounts data from government websites. The CLI handles archived data (2021 and earlier from epe.lac-bac.gc.ca), 2022 data from the Wayback Machine archive, and recent data (2023+ from canada.ca and tpsgc-pwgsc.gc.ca).

## Commands

### Scrape data for one or more years
```bash
./bin/pb scrape YEARS
```

The `YEARS` parameter supports multiple formats:
- **Single year**: `./bin/pb scrape 2025`
- **Year range**: `./bin/pb scrape 2021-2025`
- **Multiple years/ranges**: `./bin/pb scrape 2015,2017,2019-2025`

All downloaded data is saved to `./raw/YEAR/` directories.

### Legacy shell scripts

The original shell scripts are still available:
```bash
./download_public_accounts.sh YEAR [output_dir]
./download_multiple_years.sh START_YEAR END_YEAR
```

## Project Structure

```
bin/pb                              # CLI executable
lib/
  pb_cli.rb                         # CLI entry point
  pb_cli/commands/
    scrape.rb                       # Scrape command implementation
test/
  test_helper.rb                    # Test configuration
  commands/
    test_scrape.rb                  # Scrape command tests
Gemfile                             # Ruby dependencies
Rakefile                            # Test tasks
```

## Development

### Running tests
```bash
bundle exec rake test
```

### Adding new commands

1. Create a new file in `lib/pb_cli/commands/`
2. Add the command to the case statement in `lib/pb_cli.rb`
3. Add tests in `test/commands/`

### Commit message conventions

- Write clear, descriptive commit messages
- Do NOT include "Generated with Claude Code" or similar AI attribution footers
- Do NOT include "Co-Authored-By: Claude" signatures
- Focus on the technical changes and their purpose

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
