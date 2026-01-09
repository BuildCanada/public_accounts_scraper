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

### Extract data to structured formats
```bash
./bin/pb extract [EXTRACTOR_NAME]
```

The `extract` command processes downloaded HTML files and exports structured data:
- **Run all extractors**: `./bin/pb extract`
- **Run specific extractor**: `./bin/pb extract major_transfers_by_provinces_and_territories`

Extracted data is saved to:
- `./extracted/data/` - JSON files with structured data
- `./extracted/metadata/` - YAML metadata files conforming to Datasette specification

### Download Statistics Canada data
```bash
./bin/pb statscan download <dataset_name>
```

Downloads datasets from Statistics Canada. Use the `.claude/commands/add-statscan-dataset.md` command to add new datasets.

### Create SQLite database
```bash
./bin/pb create-db [OPTIONS]
```

Creates a SQLite database from extracted JSON data files. The command:
- Creates `public_accounts.db` in the current directory
- Automatically imports all JSON files from `./extracted/data/`
- Uses table names based on JSON filenames
- Detects column types automatically
- Deletes any existing database before creating a new one
- Optimizes database settings during loading for maximum performance

**Database Optimization:**
By default, the command automatically:
1. Sets write-optimized SQLite parameters before loading data (journal_mode=OFF, synchronous=OFF, 64MB cache)
2. Loads all JSON data into the database
3. Sets read-optimized SQLite parameters after loading (journal_mode=WAL, synchronous=NORMAL, 2MB cache)
4. Runs PRAGMA optimize to analyze the database for query optimization

**Options:**
- `--skip-optimization`: Skip both write and read optimizations (not recommended)
- `--keep-write-mode`: Keep write-optimized settings after loading (useful when more data will be loaded)

**Prerequisites**: Requires `sqlite-utils` to be installed (`pip install sqlite-utils` or `brew install sqlite-utils`)

### Initialize database
```bash
./bin/pb initialize [OPTIONS]
```

Runs the complete workflow to create and populate the database:
1. Deletes any existing `public_accounts.db` database
2. Initializes Statistics Canada data cache (creates `public_accounts.statscan_base.db` if not present)
3. Copies statscan cache as the base database
4. Extracts data from downloaded HTML files (`pb extract`)
5. Loads extracted JSON data into database
6. Creates inflation-adjusted tables (`pb create-inflation-adjusted-tables`)
7. Creates views and optimizes database for read-heavy workloads

**Options:**
- `--force`: Delete the statscan cache and rebuild it from scratch

**Statistics Canada Cache**: The statscan data is cached separately in `public_accounts.statscan_base.db` because it takes a long time to load. On subsequent runs, the cached database is copied as the base, significantly speeding up initialization. Use `--force` to rebuild the cache.

**Prerequisites**: Requires data to be downloaded first using `pb scrape` and `pb statscan download`

### Create inflation-adjusted tables
```bash
./bin/pb create-inflation-adjusted-tables
```

Creates CPI-adjusted views for monetary data using Statistics Canada CPI data. The command:
- Creates a `cpi_inflation_indexes` reference table with fiscal year averages
- Calculates inflation indexes for converting historical dollars to recent dollars
- Creates `_inflation_adjusted` views for each non-statscan table
- Automatically detects the latest fiscal year with complete CPI data (≥11 months)
- Adjusts all monetary columns (FLOAT type) while preserving metadata columns

The `cpi_inflation_indexes` table contains:
- One row per fiscal year with `avg_cpi` and `months_count` columns
- Index columns for each year (e.g., `index_2025`, `index_2024`, ..., `index_2017`)
- Each index shows the multiplier to convert that row's fiscal year dollars to the target year

For example, if fiscal year 2017 has `index_2023 = 1.215`, multiply 2017 dollar amounts by 1.215 to get 2023 dollars.

**Prerequisites**: Requires CPI data to be loaded (`pb statscan download cpi_monthly` and `pb statscan load cpi_monthly`)

**Fiscal Year Convention**: FY 2017 = April 2016 through March 2017

**Example Usage:**
```bash
# Query inflation-adjusted data
sqlite3 public_accounts.db "
  SELECT year, province_territory, old_age_security_benefits
  FROM major_transfers_by_provinces_and_territories_inflation_adjusted
  WHERE province_territory = 'Ontario'
  ORDER BY year;
"

# Join with CPI reference table for custom analysis
sqlite3 public_accounts.db "
  SELECT fiscal_year, avg_cpi, months_count, index_2025
  FROM cpi_inflation_indexes
  WHERE fiscal_year >= 2017
  ORDER BY fiscal_year;
"
```

### Legacy shell scripts

The original shell scripts are still available:
```bash
./download_public_accounts.sh YEAR [output_dir]
./download_multiple_years.sh START_YEAR END_YEAR
```

## Project Structure

```
.claude/commands/
  add-statscan-dataset.md           # Command for adding new Statistics Canada datasets
bin/pb                              # CLI executable
lib/
  pb_cli.rb                         # CLI entry point
  pb_cli/commands/
    scrape.rb                       # Scrape command implementation
    extract.rb                      # Extract command implementation
    create_db.rb                    # Database creation command
    initialize.rb                   # Initialize database workflow command
    statscan.rb                     # Statistics Canada download command
  pb_cli/extractors/
    base.rb                         # Base extractor class
    major_transfers_by_provinces_and_territories.rb  # Major transfers extractor
test/
  test_helper.rb                    # Test configuration
  commands/
    test_scrape.rb                  # Scrape command tests
    test_extract.rb                 # Extract command tests
    test_create_db.rb               # Database creation command tests
    test_statscan.rb                # Statistics Canada command tests
extracted/
  data/                             # Extracted JSON data files
  metadata/                         # Datasette YAML metadata files
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

### Adding new extractors

1. Create a new extractor class in `lib/pb_cli/extractors/` that inherits from `Base`
2. Implement the `extract` and `extractor_name` methods
3. Register the extractor in `lib/pb_cli/commands/extract.rb` EXTRACTORS hash
4. Add tests in `test/commands/test_extract.rb`

### Datasette Metadata Format

All extractors must generate YAML metadata conforming to the Datasette specification. The metadata structure should follow this format:

```yaml
databases:
  public_accounts:              # Database name (use 'public_accounts' for all transfer-related data)
    tables:
      [extractor_name]:            # Table name (should match extractor_name method)
        title: Human Readable Title
        description_html: |
          Multi-line description of the data.
          Include source information and units.
        source: Public Accounts of Canada
        source_url: https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/index-eng.html
        license: Open Government License - Canada
        license_url: https://open.canada.ca/en/open-government-licence-canada
        columns:
          column_name: Column description (units if applicable)
          another_column: Another column description
```

**Key conventions:**
- Database name: Use `public_accounts` for all transfer-related extractions
- Table name: Should match the extractor's `extractor_name` method
- Column descriptions: Include units (e.g., "millions of dollars") where applicable
- Use `description_html` (not `description`) to preserve formatting

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

### Fiscal Year Format and Parsing

**Important:** Canada's fiscal year runs from April 1 to March 31. The fiscal year naming convention is:
- **Fiscal Year 2017** = the period from April 1, 2016 to March 31, 2017
- **Fiscal Year 2020** = the period from April 1, 2019 to March 31, 2020

Public Accounts documents use different formats for fiscal years depending on the publication year:

**Format changes by year:**
- **2017 and earlier**: Uses hyphenated format "2016-2017" or "2016‑2017" (with en-dash or non-breaking hyphen)
- **2018 onwards**: Uses single year format "2017"

**Parsing convention:**
When extracting fiscal year data, always use the **ending year** of the fiscal period:
- "2016-2017" → Fiscal Year **2017**
- "2019-2020" → Fiscal Year **2020**
- "2017" → Fiscal Year **2017**

Extractors must normalize different dash characters (hyphen, en-dash, non-breaking hyphen) and consistently extract the ending year to ensure fiscal year values are correct across all data sources.
