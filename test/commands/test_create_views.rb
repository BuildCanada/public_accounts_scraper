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
end
