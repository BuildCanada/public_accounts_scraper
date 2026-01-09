require 'test_helper'
require 'pb_cli/commands/create_inflation_adjusted_tables'

class TestCreateInflationAdjustedTables < Minitest::Test
  def setup
    @command = PbCli::Commands::CreateInflationAdjustedTables.new
    @db_path = './test_inflation.db'

    # Skip tests if sqlite-utils is not installed
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    # Create test database with sample data
    create_test_database
  end

  def teardown
    # Clean up test files
    FileUtils.rm_f(@db_path) if File.exist?(@db_path)
  end

  def test_fiscal_year_calculation
    cpi_data = [
      { ref_date: '2016-04', value: 128.0 },
      { ref_date: '2016-12', value: 129.0 },
      { ref_date: '2017-03', value: 130.0 },
      { ref_date: '2017-04', value: 131.0 }
    ]

    fiscal_year_data = @command.send(:calculate_fiscal_year_averages, cpi_data)

    # April 2016 - March 2017 should be FY 2017
    assert fiscal_year_data.key?(2017), "FY 2017 should exist"
    assert_equal 3, fiscal_year_data[2017][:months_count], "FY 2017 should have 3 months"

    # April 2017 should be FY 2018
    assert fiscal_year_data.key?(2018), "FY 2018 should exist"
    assert_equal 1, fiscal_year_data[2018][:months_count], "FY 2018 should have 1 month"
  end

  def test_calendar_year_calculation
    cpi_data = [
      { ref_date: '2016-01', value: 127.0 },
      { ref_date: '2016-06', value: 128.0 },
      { ref_date: '2016-12', value: 129.0 },
      { ref_date: '2017-01', value: 130.0 },
      { ref_date: '2017-06', value: 131.0 }
    ]

    calendar_year_data = @command.send(:calculate_calendar_year_averages, cpi_data)

    # 2016 should have 3 months (Jan, Jun, Dec)
    assert calendar_year_data.key?(2016), "Calendar year 2016 should exist"
    assert_equal 3, calendar_year_data[2016][:months_count], "2016 should have 3 months"
    expected_avg_2016 = (127.0 + 128.0 + 129.0) / 3.0
    assert_in_delta expected_avg_2016, calendar_year_data[2016][:avg_cpi], 0.01

    # 2017 should have 2 months (Jan, Jun)
    assert calendar_year_data.key?(2017), "Calendar year 2017 should exist"
    assert_equal 2, calendar_year_data[2017][:months_count], "2017 should have 2 months"
    expected_avg_2017 = (130.0 + 131.0) / 2.0
    assert_in_delta expected_avg_2017, calendar_year_data[2017][:avg_cpi], 0.01
  end

  def test_detect_latest_complete_year
    fiscal_year_data = {
      2020 => { avg_cpi: 135.0, months_count: 12 },
      2021 => { avg_cpi: 140.0, months_count: 12 },
      2022 => { avg_cpi: 145.0, months_count: 11 },  # Exactly 11 months
      2023 => { avg_cpi: 150.0, months_count: 10 },  # Incomplete
      2024 => { avg_cpi: 155.0, months_count: 6 }    # Incomplete
    }

    latest_year = @command.send(:detect_latest_complete_year, fiscal_year_data)

    # Should be 2022 (11 months is acceptable)
    assert_equal 2022, latest_year, "Latest complete year should be 2022"
  end

  def test_index_calculation
    fiscal_year_data = {
      2017 => { avg_cpi: 129.0, months_count: 12 },
      2023 => { avg_cpi: 156.7, months_count: 12 }
    }

    index_years = [2017, 2023]
    records = @command.send(:calculate_index_columns, fiscal_year_data, index_years)

    # Find FY 2017 record
    fy2017_record = records.find { |r| r['fiscal_year'] == 2017 }

    # index_2023 for FY 2017 = 156.7 / 129.0 = 1.2147...
    expected_index = (156.7 / 129.0).round(4)
    assert_equal expected_index, fy2017_record['index_2023'], "Index calculation should be correct"

    # index_2017 for FY 2017 should be 1.0
    assert_equal 1.0, fy2017_record['index_2017'], "Self-index should be 1.0"
  end

  def test_get_monetary_columns
    # Need to stub the command to use test database
    stub_db_path(@db_path) do
      monetary_columns = @command.send(:get_monetary_columns, 'test_transfers')

      # Should include FLOAT columns
      assert monetary_columns.include?('transfer_amount'), "Should include transfer_amount"

      # Should NOT include non-monetary columns
      refute monetary_columns.include?('year'), "Should not include year"
      refute monetary_columns.include?('position'), "Should not include position"
      refute monetary_columns.include?('is_total_or_subtotal'), "Should not include is_total_or_subtotal"
    end
  end

  def test_create_cpi_reference_table
    stub_db_path(@db_path) do
      # Create CPI data
      fiscal_year_data = {
        2020 => { avg_cpi: 135.0, months_count: 12 },
        2021 => { avg_cpi: 140.0, months_count: 12 }
      }

      @command.send(:create_cpi_reference_table, fiscal_year_data, 2021)

      # Verify table was created
      tables_output, _, _ = Open3.capture3(
        'sqlite-utils', 'tables', @db_path
      )

      assert tables_output.include?('cpi_inflation_indexes'), "CPI table should be created"

      # Verify data
      query_output, stderr, status = Open3.capture3(
        'sqlite-utils', 'query', @db_path,
        "SELECT count(*) as count FROM cpi_inflation_indexes", '--csv'
      )

      assert status.success?, "Query should succeed: #{stderr}"

      # Parse CSV output
      lines = query_output.lines
      count = lines[1].strip.to_i if lines.size > 1

      assert_equal 2, count, "Should have 2 records in CPI table"
    end
  end

  def test_create_calendar_cpi_reference_table
    stub_db_path(@db_path) do
      # Create calendar year CPI data
      calendar_year_data = {
        2020 => { avg_cpi: 136.0, months_count: 12 },
        2021 => { avg_cpi: 141.0, months_count: 12 }
      }

      @command.send(:create_calendar_cpi_reference_table, calendar_year_data, 2021)

      # Verify table was created
      tables_output, _, _ = Open3.capture3(
        'sqlite-utils', 'tables', @db_path
      )

      assert tables_output.include?('calendar_cpi_inflation_indexes'), "Calendar CPI table should be created"

      # Verify data and structure
      query_output, stderr, status = Open3.capture3(
        'sqlite-utils', 'query', @db_path,
        "SELECT calendar_year, avg_cpi, months_count FROM calendar_cpi_inflation_indexes ORDER BY calendar_year", '--csv'
      )

      assert status.success?, "Query should succeed: #{stderr}"

      # Parse CSV output - should have header + 2 data rows
      lines = query_output.lines
      assert_equal 3, lines.size, "Should have header + 2 records"

      # First data row should be 2020
      first_row = lines[1].strip.split(',')
      assert_equal '2020', first_row[0], "First row should be calendar year 2020"

      # Second data row should be 2021
      second_row = lines[2].strip.split(',')
      assert_equal '2021', second_row[0], "Second row should be calendar year 2021"
    end
  end

  def test_command_with_missing_database
    # Temporarily rename test database
    FileUtils.mv(@db_path, "#{@db_path}.bak") if File.exist?(@db_path)

    stub_db_path("nonexistent.db") do
      result = @command.call([])
      assert_equal 1, result, "Should return error code when database doesn't exist"
    end
  ensure
    FileUtils.mv("#{@db_path}.bak", @db_path) if File.exist?("#{@db_path}.bak")
  end

  def test_inflation_adjusted_view_is_queryable
    # This test ensures views created by the command can actually be queried
    # It would have caught the source_year column issue where the view referenced
    # a column that didn't exist in the base table
    stub_db_path(@db_path) do
      # Create the inflation views
      @command.call([])

      # Verify the view exists and can be queried
      query_output, stderr, status = Open3.capture3(
        'sqlite-utils', 'query', @db_path,
        "SELECT * FROM test_transfers_inflation_adjusted LIMIT 1", '--csv'
      )

      assert status.success?, "View query should succeed: #{stderr}"
      assert query_output.lines.size >= 1, "View should return at least a header row"
    end
  end

  def test_inflation_adjusted_view_with_source_year_column
    # This test verifies that tables with source_year column have correctly
    # functioning inflation-adjusted views (the view filters by source_year
    # but does not include it in the output)
    stub_db_path(@db_path) do
      # Create a table with source_year to mimic budgetary_details_by_allotment
      table_with_source_year = [
        {
          'source_year' => 2020,
          'year' => 2020,
          'ministry_code' => 'test-ministry',
          'description' => 'Test item',
          'allotments' => 1000.0,
          'expenditures' => 900.0
        },
        {
          'source_year' => 2021,
          'year' => 2020,  # Same year, different source - will be filtered
          'ministry_code' => 'test-ministry',
          'description' => 'Test item updated',
          'allotments' => 1050.0,
          'expenditures' => 950.0
        },
        {
          'source_year' => 2021,
          'year' => 2021,
          'ministry_code' => 'test-ministry',
          'description' => 'Test item year 2',
          'allotments' => 1100.0,
          'expenditures' => 1000.0
        }
      ]

      temp_file = Tempfile.new(['table_with_source', '.json'])
      begin
        temp_file.write(JSON.pretty_generate(table_with_source_year))
        temp_file.close

        system("sqlite-utils insert #{@db_path} table_with_source_year #{temp_file.path} --alter 2>&1 > /dev/null")
      ensure
        temp_file.unlink
      end

      # Create the inflation views
      @command.call([])

      # Verify the view exists and can be queried
      query_output, stderr, status = Open3.capture3(
        'sqlite-utils', 'query', @db_path,
        "SELECT year, ministry_code, description, allotments FROM table_with_source_year_inflation_adjusted ORDER BY year", '--csv'
      )

      assert status.success?, "View with source_year should be queryable: #{stderr}"

      # Verify the view filters to use most recent source_year per fiscal year
      lines = query_output.lines
      assert lines.size == 3, "Should have header + 2 data rows (year 2020 from source 2021, year 2021 from source 2021)"

      # Year 2020 should come from source_year 2021 (most recent) with updated values
      if lines.size >= 2
        row_2020 = lines[1].strip
        assert row_2020.include?('Test item updated'), "Year 2020 should use source_year 2021 data: #{row_2020}"
      end
    end
  end

  def test_all_non_statscan_tables_have_queryable_views
    # Integration test: after running the command, verify ALL created views are queryable
    stub_db_path(@db_path) do
      # Run the command
      @command.call([])

      # Get all inflation-adjusted views
      views_output, _, _ = Open3.capture3(
        'sqlite-utils', 'query', @db_path,
        "SELECT name FROM sqlite_master WHERE type='view' AND name LIKE '%_inflation_adjusted'", '--csv'
      )

      view_names = views_output.lines[1..-1].map(&:strip).reject(&:empty?)

      assert view_names.size > 0, "At least one inflation-adjusted view should be created"

      # Verify each view is queryable
      view_names.each do |view_name|
        query_output, stderr, status = Open3.capture3(
          'sqlite-utils', 'query', @db_path,
          "SELECT * FROM #{view_name} LIMIT 1", '--csv'
        )

        assert status.success?, "View #{view_name} should be queryable: #{stderr}"
      end
    end
  end

  private

  def sqlite_utils_installed?
    system('which sqlite-utils > /dev/null 2>&1')
  end

  def create_test_database
    # Create database
    system("sqlite-utils create-database #{@db_path} 2>&1 > /dev/null")

    # Create test CPI table with sample data
    cpi_data = []
    # Create 12 months for FY 2020 (April 2019 - March 2020)
    (4..12).each do |month|
      cpi_data << {
        'REF_DATE' => "2019-#{month.to_s.rjust(2, '0')}",
        'GEO' => 'Canada',
        'UOM' => '2002=100',
        'Products and product groups' => 'All-items',
        'VALUE' => 135.0 + month * 0.1
      }
    end
    (1..3).each do |month|
      cpi_data << {
        'REF_DATE' => "2020-#{month.to_s.rjust(2, '0')}",
        'GEO' => 'Canada',
        'UOM' => '2002=100',
        'Products and product groups' => 'All-items',
        'VALUE' => 135.0 + (12 + month) * 0.1
      }
    end

    # Create 12 months for FY 2021 (April 2020 - March 2021)
    (4..12).each do |month|
      cpi_data << {
        'REF_DATE' => "2020-#{month.to_s.rjust(2, '0')}",
        'GEO' => 'Canada',
        'UOM' => '2002=100',
        'Products and product groups' => 'All-items',
        'VALUE' => 140.0 + month * 0.1
      }
    end
    (1..3).each do |month|
      cpi_data << {
        'REF_DATE' => "2021-#{month.to_s.rjust(2, '0')}",
        'GEO' => 'Canada',
        'UOM' => '2002=100',
        'Products and product groups' => 'All-items',
        'VALUE' => 140.0 + (12 + month) * 0.1
      }
    end

    # Write to temporary JSON file and insert
    require 'tempfile'
    temp_file = Tempfile.new(['cpi_data', '.json'])
    begin
      temp_file.write(JSON.pretty_generate(cpi_data))
      temp_file.close

      system("sqlite-utils insert #{@db_path} statscan_cpi_monthly #{temp_file.path} --alter 2>&1 > /dev/null")
    ensure
      temp_file.unlink
    end

    # Create test transfers table
    # Must include source_year as inflation-adjusted views filter on it
    transfers_data = [
      {
        'source_year' => 2020,
        'year' => 2020,
        'province_territory' => 'Ontario',
        'position' => 1,
        'is_total_or_subtotal' => 0,
        'transfer_amount' => 1000.0
      },
      {
        'source_year' => 2021,
        'year' => 2021,
        'province_territory' => 'Ontario',
        'position' => 2,
        'is_total_or_subtotal' => 0,
        'transfer_amount' => 1100.0
      }
    ]

    temp_file2 = Tempfile.new(['transfers_data', '.json'])
    begin
      temp_file2.write(JSON.pretty_generate(transfers_data))
      temp_file2.close

      system("sqlite-utils insert #{@db_path} test_transfers #{temp_file2.path} --alter 2>&1 > /dev/null")
    ensure
      temp_file2.unlink
    end
  end

  def stub_db_path(db_path)
    # No longer needed with dependency injection - just instantiate with the path
    @command = PbCli::Commands::CreateInflationAdjustedTables.new(db_path: db_path)
    yield
  end
end
