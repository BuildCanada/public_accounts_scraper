# Add Statistics Canada Dataset

This command helps add a new Statistics Canada dataset to the `pb statscan download` command.

## Instructions

Follow these steps to add a new Statistics Canada dataset:

### Step 1: Gather Dataset Information

Ask the user for the following information:
1. **Dataset Name**: A short, descriptive name (lowercase, underscores for spaces)
   - Example: `cpi_monthly`, `gdp_quarterly`, `employment_rate`
2. **Product ID (PID)**: The 10-digit Statistics Canada Product ID
   - Example: `1810000401`
   - Can be found in the dataset URL: `https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=XXXXXXXXXX`

If the user doesn't have the PID, offer to search for it using the dataset description.

### Step 2: Validate the PID

Before proceeding, validate that the PID works by checking both URLs:

1. **Metadata URL**:
   ```
   https://www150.statcan.gc.ca/t1/tbl1/en/dtl!downloadCubeMetaData-nonTraduit.action?pid={PID}&csvLocale=en
   ```

2. **Data URL** (PID with last 2 digits removed):
   ```
   https://www150.statcan.gc.ca/n1/tbl/csv/{SHORT_PID}-eng.zip
   ```

Use `curl -I` to verify both URLs return HTTP 200 status codes.

### Step 3: Add Dataset to DATASETS Hash

Edit `lib/pb_cli/commands/statscan.rb`:

1. Read the current file
2. Locate the `DATASETS` constant
3. Add the new dataset to the hash in alphabetical order
4. Preserve the `.freeze` at the end

Example:
```ruby
DATASETS = {
  'cpi_monthly' => '1810000401',
  'new_dataset_name' => 'NEW_PID_HERE'
}.freeze
```

### Step 4: Add Test Case

Edit `test/commands/test_statscan.rb`:

Add a new test method for the dataset:
```ruby
def test_DATASET_NAME_exists
  assert Statscan::DATASETS.key?('dataset_name')
  assert_equal 'PID_HERE', Statscan::DATASETS['dataset_name']
end
```

### Step 5: Run Tests

Execute the test suite to verify everything works:
```bash
bundle exec rake test
```

Ensure all tests pass, especially the new test case.

### Step 6: Test Download

Test the actual download to verify the dataset works:
```bash
./bin/pb statscan download dataset_name
```

Verify:
1. Both metadata CSV and data ZIP are downloaded
2. Files are saved to correct directories
3. No errors occur

Check the downloaded files:
```bash
# Verify metadata
head -10 statscan/metadata/dataset_name/dataset_name_metadata.csv

# Verify data ZIP
file statscan/data/dataset_name/dataset_name_data.zip
```

### Step 7: Clean Up Test Data

After verification, clean up the test download:
```bash
rm -rf statscan/metadata/dataset_name statscan/data/dataset_name
```

If statscan directories are now empty:
```bash
rmdir statscan/metadata statscan/data statscan
```

### Step 8: Show Summary

Display a summary of what was added:
```
✓ Added Statistics Canada dataset: {dataset_name}
  - PID: {pid}
  - Command: ./bin/pb statscan download {dataset_name}
  - Metadata URL: {metadata_url}
  - Data URL: {data_url}

Files modified:
  - lib/pb_cli/commands/statscan.rb
  - test/commands/test_statscan.rb

Next steps:
  1. Run tests: bundle exec rake test
  2. Test download: ./bin/pb statscan download {dataset_name}
  3. Commit changes: git add lib/pb_cli/commands/statscan.rb test/commands/test_statscan.rb && git commit
```

## PID Format Reference

Statistics Canada uses different PID formats for different URLs:

- **Full PID**: 10 digits (e.g., `1810000401`) - used for metadata URL
- **Short PID**: 8 digits (e.g., `18100004`) - used for data URL
  - Conversion: Remove last 2 characters from full PID

## Common Datasets

Here are some commonly used Statistics Canada datasets:

| Name | PID | Description |
|------|-----|-------------|
| `cpi_monthly` | 1810000401 | Consumer Price Index, monthly |
| `gdp_monthly` | 3610022201 | GDP by industry, monthly |
| `employment_rate` | 1410028701 | Labour force characteristics |
| `population_quarterly` | 1710000501 | Population estimates, quarterly |

## Troubleshooting

### Invalid PID Error
- Verify the PID is exactly 10 digits
- Check the PID on Statistics Canada website
- Try the metadata URL in a browser

### 404 Not Found Error
- Dataset may be archived or removed
- Check if the dataset exists at: `https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid={PID}`
- Verify the short PID calculation is correct

### Download Fails
- Check internet connection
- Verify curl is installed and working
- Try downloading URLs manually with curl

## Resources

- Statistics Canada Data Tables: https://www150.statcan.gc.ca/t1/tbl1/en/tv.action
- Open Data Portal: https://open.canada.ca/en
- License: https://open.canada.ca/en/open-government-licence-canada
