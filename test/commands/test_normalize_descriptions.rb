require 'test_helper'
require 'pb_cli/commands/normalize_descriptions'
require 'json'

class TestNormalizeDescriptions < Minitest::Test
  include TestPaths

  def setup
    @test_paths = setup_test_paths('normalize_descriptions')
    @db_path = @test_paths[:db_path]

    skip "sqlite3 not installed" unless sqlite3_installed?
  end

  def teardown
    cleanup_test_paths(@test_paths)
  end

  def test_prerequisites_check_without_database
    command = PbCli::Commands::NormalizeDescriptions.new(db_path: '/nonexistent/path.db')
    result = command.call([])
    assert_equal 1, result, "Should fail when database doesn't exist"
  end

  def test_prerequisites_check_without_source_table
    # Create empty database
    `sqlite3 '#{@db_path}' "SELECT 1"`

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    result = command.call([])
    assert_equal 1, result, "Should fail when source table doesn't exist"
  end

  def test_creates_items_table
    create_test_database_with_transfers

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    result = command.call([])

    assert_equal 0, result, "Command should succeed"

    # Check items table exists
    output = `sqlite3 '#{@db_path}' "SELECT COUNT(*) FROM transfer_payment_items"`
    assert output.strip.to_i > 0, "Items table should have records"
  end

  def test_creates_normalized_view
    create_test_database_with_transfers

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # Check view exists
    output = `sqlite3 '#{@db_path}' "SELECT COUNT(*) FROM transfer_payments_by_ministry_normalized"`
    assert output.strip.to_i > 0, "Normalized view should have records"
  end

  def test_links_items_across_years
    create_test_database_with_transfers

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # Check that items spanning multiple years are linked
    output = `sqlite3 '#{@db_path}' "SELECT COUNT(*) FROM transfer_payment_items WHERE year_count > 1"`
    multi_year_count = output.strip.to_i
    assert multi_year_count > 0, "Should have items spanning multiple years"
  end

  def test_uses_most_recent_description
    create_test_database_with_description_change

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # The normalized description should be the most recent one
    output = `sqlite3 '#{@db_path}' "SELECT description_normalized FROM transfer_payment_items WHERE transfer_item_id = 1"`
    assert_equal "Grant to Indigenous organizations", output.strip
  end

  def test_tracks_description_variations
    create_test_database_with_description_change

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # Check that variations are tracked
    output = `sqlite3 '#{@db_path}' "SELECT description_variations FROM transfer_payment_items WHERE transfer_item_id = 1"`
    variations = JSON.parse(output.strip)
    assert_equal 2, variations.length, "Should track both description variants"
    assert_includes variations, "Grant to Aboriginal organizations"
    assert_includes variations, "Grant to Indigenous organizations"
  end

  def test_handles_ministry_reorganization
    create_test_database_with_ministry_change

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # Item should be linked across ministry change
    output = `sqlite3 '#{@db_path}' "SELECT year_count FROM transfer_payment_items WHERE transfer_item_id = 1"`
    assert_equal 2, output.strip.to_i, "Should link items across ministry reorganization"

    # Check ministry_codes includes both
    output = `sqlite3 '#{@db_path}' "SELECT ministry_codes FROM transfer_payment_items WHERE transfer_item_id = 1"`
    codes = JSON.parse(output.strip)
    assert_equal 2, codes.length, "Should track both ministry codes"
  end

  def test_excludes_totals
    create_test_database_with_totals

    command = PbCli::Commands::NormalizeDescriptions.new(db_path: @db_path)
    command.call([])

    # Totals should be excluded from items table
    output = `sqlite3 '#{@db_path}' "SELECT COUNT(*) FROM transfer_payment_items WHERE description_normalized LIKE '%Total%'"`
    assert_equal 0, output.strip.to_i, "Totals should be excluded"
  end

  private

  def sqlite3_installed?
    system('which sqlite3 > /dev/null 2>&1')
  end

  def create_test_database_with_transfers
    # Create source table
    `sqlite3 '#{@db_path}' "
      CREATE TABLE transfer_payments_by_ministry (
        year INTEGER,
        ministry_code TEXT,
        ministry_name_normalized TEXT,
        category TEXT,
        description TEXT,
        position INTEGER,
        is_total_or_subtotal INTEGER,
        used_in_current_year REAL,
        used_in_previous_year REAL
      )
    "`

    # Insert test data - same item across 3 years
    `sqlite3 '#{@db_path}' "
      INSERT INTO transfer_payments_by_ministry VALUES
        (2020, 'test-ministry', 'Test Ministry', 'Grants', 'Test Grant Item', 1, 0, 1000.0, 900.0),
        (2021, 'test-ministry', 'Test Ministry', 'Grants', 'Test Grant Item', 1, 0, 1100.0, 1000.0),
        (2022, 'test-ministry', 'Test Ministry', 'Grants', 'Test Grant Item', 1, 0, 1200.0, 1100.0)
    "`
  end

  def create_test_database_with_description_change
    `sqlite3 '#{@db_path}' "
      CREATE TABLE transfer_payments_by_ministry (
        year INTEGER,
        ministry_code TEXT,
        ministry_name_normalized TEXT,
        category TEXT,
        description TEXT,
        position INTEGER,
        is_total_or_subtotal INTEGER,
        used_in_current_year REAL,
        used_in_previous_year REAL
      )
    "`

    # Insert data with description change (Aboriginal -> Indigenous)
    `sqlite3 '#{@db_path}' "
      INSERT INTO transfer_payments_by_ministry VALUES
        (2016, 'inac', 'Indigenous Affairs', 'Grants', 'Grant to Aboriginal organizations', 1, 0, 5000.0, 4500.0),
        (2017, 'inac', 'Indigenous Affairs', 'Grants', 'Grant to Indigenous organizations', 1, 0, 5500.0, 5000.0)
    "`
  end

  def create_test_database_with_ministry_change
    `sqlite3 '#{@db_path}' "
      CREATE TABLE transfer_payments_by_ministry (
        year INTEGER,
        ministry_code TEXT,
        ministry_name_normalized TEXT,
        category TEXT,
        description TEXT,
        position INTEGER,
        is_total_or_subtotal INTEGER,
        used_in_current_year REAL,
        used_in_previous_year REAL
      )
    "`

    # Insert data with ministry reorganization (same normalized ministry name)
    `sqlite3 '#{@db_path}' "
      INSERT INTO transfer_payments_by_ministry VALUES
        (2018, 'aanc-inac', 'Crown-Indigenous Relations', 'Grants', 'Test Grant', 1, 0, 2000.0, 1800.0),
        (2019, 'rcaanc-cirnac', 'Crown-Indigenous Relations', 'Grants', 'Test Grant', 1, 0, 2200.0, 2000.0)
    "`
  end

  def create_test_database_with_totals
    `sqlite3 '#{@db_path}' "
      CREATE TABLE transfer_payments_by_ministry (
        year INTEGER,
        ministry_code TEXT,
        ministry_name_normalized TEXT,
        category TEXT,
        description TEXT,
        position INTEGER,
        is_total_or_subtotal INTEGER,
        used_in_current_year REAL,
        used_in_previous_year REAL
      )
    "`

    # Insert data with totals
    `sqlite3 '#{@db_path}' "
      INSERT INTO transfer_payments_by_ministry VALUES
        (2020, 'test', 'Test', 'Grants', 'Regular Grant', 1, 0, 1000.0, 900.0),
        (2020, 'test', 'Test', 'Grants', 'Total - Grants', 2, 1, 5000.0, 4500.0)
    "`
  end
end
