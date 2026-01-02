Public Accounts Extractor
=========================

This is a tool to make it easy to download and ETL public accounts data.

## Methodology
The approach that it takes is to gradually upgrade the datasets that it grabs. 

For public accounts:
- download the HTML public accounts verbatim (the format is the same from) `pb scrape <years>`
- normalize the data for each year into the same structure `pb extract`

For statscan datasets:



## Usage

`./bin/pb <command>