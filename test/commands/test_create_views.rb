require 'test_helper'
require 'pb_cli/commands/create_views'
require 'pb_cli/commands/create_db'
require 'json'

class TestCreateViews < Minitest::Test
  include TestPaths

  def setup
    @test_paths = setup_test_paths('create_views')
    @base_dir = @test_paths[:base_dir]
    @data_dir = @test_paths[:data_dir]
    @db_path = @test_paths[:db_path]
    @views_dir = File.join(@base_dir, 'db', 'views')

    # Create views directory structure
    FileUtils.mkdir_p(@views_dir)
    FileUtils.mkdir_p(@data_dir)

    # Create test database with sample data
    create_test_database
  end

  def teardown
    cleanup_test_paths(@test_paths)
  end

  def test_create_views_basic
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Create a simple SQL view file
    create_sql_file('test_view.sql', 'SELECT * FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    result = command.call([])

    assert_equal 0, result
  end

  def test_create_views_creates_view_in_database
    skip "sqlite3 not installed" unless sqlite3_installed?

    create_sql_file('test_view.sql', 'SELECT * FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Verify view exists
    output = `sqlite3 '#{@db_path}' ".tables" 2>&1`
    assert output.include?('test_view'), "View should be created"
  end

  def test_create_views_with_nested_directory
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Create nested directory structure
    nested_dir = File.join(@views_dir, 'vol1')
    FileUtils.mkdir_p(nested_dir)
    File.write(File.join(nested_dir, 'nested_view.sql'), 'SELECT id, name FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Verify view name includes parent folder
    output = `sqlite3 '#{@db_path}' ".tables" 2>&1`
    assert output.include?('vol1_nested_view'), "View name should include parent folder: #{output}"
  end

  def test_create_views_with_deeply_nested_directory
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Create deeply nested directory structure
    deep_dir = File.join(@views_dir, 'section', 'subsection')
    FileUtils.mkdir_p(deep_dir)
    File.write(File.join(deep_dir, 'deep_view.sql'), 'SELECT id FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Verify view name includes all parent folders
    output = `sqlite3 '#{@db_path}' ".tables" 2>&1`
    assert output.include?('section_subsection_deep_view'), "View name should include all parent folders: #{output}"
  end

  def test_create_views_without_database
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Remove the database
    FileUtils.rm(@db_path)

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    result = command.call([])

    assert_equal 1, result, "Should return error when database doesn't exist"
  end

  def test_create_views_without_views_directory
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Remove views directory
    FileUtils.rm_rf(@views_dir)

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    result = command.call([])

    assert_equal 1, result, "Should return error when views directory doesn't exist"
  end

  def test_create_views_with_no_sql_files
    skip "sqlite3 not installed" unless sqlite3_installed?

    # views_dir exists but is empty
    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    result = command.call([])

    assert_equal 0, result, "Should succeed with no SQL files"
  end

  def test_create_views_view_is_queryable
    skip "sqlite3 not installed" unless sqlite3_installed?

    create_sql_file('sum_view.sql', 'SELECT SUM(value) as total FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Query the view
    output = `sqlite3 '#{@db_path}' "SELECT total FROM sum_view" 2>&1`
    assert_equal "300\n", output, "View should return correct sum"
  end

  def test_create_views_idempotent
    skip "sqlite3 not installed" unless sqlite3_installed?

    create_sql_file('test_view.sql', 'SELECT * FROM test_data')

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)

    # Run twice
    result1 = command.call([])
    result2 = command.call([])

    assert_equal 0, result1
    assert_equal 0, result2, "Should succeed when run multiple times (IF NOT EXISTS)"
  end

  def test_childrens_benefits_view_includes_tax_system_data
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Create database with transfer data including tax system rows
    create_transfer_test_database

    # Create the childrens_benefits view SQL file (matching real view)
    sql = <<~SQL
      SELECT
        year,
        MAX(CASE WHEN province_territory = 'Ontario' THEN childrens_benefits END) AS "Ontario",
        COALESCE(
          MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN childrens_benefits END),
          MAX(CASE WHEN province_territory = 'Add: transfers made through the tax system' THEN childrens_benefits END)
        ) AS "Tax System"
      FROM major_transfers_by_provinces_and_territories_inflation_adjusted
      WHERE is_total_or_subtotal = 0
         OR province_territory IN ('Transfers made through the tax system', 'Add: transfers made through the tax system')
      GROUP BY year
      ORDER BY year
    SQL
    create_sql_file('childrens_benefits.sql', sql)

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Verify view returns tax system data
    output = `sqlite3 -separator '|' '#{@db_path}' "SELECT year, \\\"Tax System\\\" FROM childrens_benefits WHERE \\\"Tax System\\\" IS NOT NULL" 2>&1`
    assert output.include?('2016|22949.43'), "View should include 2016 tax system data: #{output}"
    assert output.include?('2012|17075.75'), "View should include 2012 'Add: transfers made through the tax system' data: #{output}"
  end

  def test_early_learning_view_includes_accrual_adjustments_data
    skip "sqlite3 not installed" unless sqlite3_installed?

    # Create database with transfer data including accrual adjustment rows
    create_transfer_test_database

    # Create the canadawide_early_learning_and_child_care view SQL file (matching real view)
    sql = <<~SQL
      SELECT
        year,
        MAX(CASE WHEN province_territory = 'Ontario' THEN canadawide_early_learning_and_child_care END) AS "Ontario",
        COALESCE(
          MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN canadawide_early_learning_and_child_care END),
          MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN canadawide_early_learning_and_child_care END)
        ) AS "Accrual Adjustments"
      FROM major_transfers_by_provinces_and_territories_inflation_adjusted
      WHERE is_total_or_subtotal = 0
         OR province_territory IN ('Accrual and other adjustments', 'Accrual and other  adjustments')
      GROUP BY year
      ORDER BY year
    SQL
    create_sql_file('canadawide_early_learning_and_child_care.sql', sql)

    command = PbCli::Commands::CreateViews.new(db_path: @db_path, views_dir: @views_dir)
    command.call([])

    # Verify view returns accrual adjustments data
    output = `sqlite3 -separator '|' '#{@db_path}' "SELECT year, \\\"Accrual Adjustments\\\" FROM canadawide_early_learning_and_child_care WHERE \\\"Accrual Adjustments\\\" IS NOT NULL" 2>&1`
    assert output.include?('2022|3320.04'), "View should include 2022 accrual adjustments data: #{output}"
    assert output.include?('2023|4741.73'), "View should include 2023 accrual adjustments data: #{output}"
  end

  private

  def sqlite3_installed?
    system('which sqlite3 > /dev/null 2>&1')
  end

  def sqlite_utils_installed?
    system('which sqlite-utils > /dev/null 2>&1')
  end

  def create_test_database
    return unless sqlite_utils_installed?

    # Create test data JSON file
    test_data = [
      { "id" => 1, "name" => "Test 1", "value" => 100 },
      { "id" => 2, "name" => "Test 2", "value" => 200 }
    ]

    FileUtils.mkdir_p(@data_dir)
    File.write(File.join(@data_dir, 'test_data.json'), JSON.pretty_generate(test_data))

    # Create database using CreateDb command
    create_db = PbCli::Commands::CreateDb.new(@test_paths)
    create_db.call(['--skip-optimization'])
  end

  def create_sql_file(filename, query)
    File.write(File.join(@views_dir, filename), query)
  end

  def create_transfer_test_database
    # Create table structure matching real data
    `sqlite3 '#{@db_path}' "
      CREATE TABLE major_transfers_by_provinces_and_territories_inflation_adjusted (
        year INTEGER,
        province_territory TEXT,
        is_total_or_subtotal INTEGER,
        childrens_benefits REAL,
        canadawide_early_learning_and_child_care REAL
      )
    "`

    # Insert test data simulating real patterns:
    # - Provinces have is_total_or_subtotal = 0 but NULL for these columns
    # - Tax system rows have is_total_or_subtotal = 1 and contain childrens_benefits data
    # - Accrual adjustment rows have is_total_or_subtotal = 1 and contain early learning data
    `sqlite3 '#{@db_path}' "
      INSERT INTO major_transfers_by_provinces_and_territories_inflation_adjusted VALUES
        -- 2012: Ontario province row (no data for these columns)
        (2012, 'Ontario', 0, NULL, NULL),
        -- 2012: Old format for tax system (is_total_or_subtotal = 1)
        (2012, 'Add: transfers made through the tax system', 1, 17075.75, NULL),
        -- 2016: Ontario province row (no data for these columns)
        (2016, 'Ontario', 0, NULL, NULL),
        -- 2016: New format for tax system (is_total_or_subtotal = 1)
        (2016, 'Transfers made through the tax system', 1, 22949.43, NULL),
        -- 2022: Ontario province row (no data for these columns)
        (2022, 'Ontario', 0, NULL, NULL),
        -- 2022: Tax system row
        (2022, 'Transfers made through the tax system', 1, 29535.72, NULL),
        -- 2022: Accrual adjustments row (is_total_or_subtotal = 1)
        (2022, 'Accrual and other adjustments', 1, NULL, 3320.04),
        -- 2023: Ontario province row (no data for these columns)
        (2023, 'Ontario', 0, NULL, NULL),
        -- 2023: Tax system row
        (2023, 'Transfers made through the tax system', 1, 25935.33, NULL),
        -- 2023: Accrual adjustments row (is_total_or_subtotal = 1)
        (2023, 'Accrual and other adjustments', 1, NULL, 4741.73)
    "`
  end
end
