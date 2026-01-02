require 'test_helper'
require 'pb_cli/commands/create_db'
require 'json'

class TestCreateDb < Minitest::Test
  def setup
    @command = PbCli::Commands::CreateDb.new
    @extracted_dir = './extracted'
    @data_dir = File.join(@extracted_dir, 'data')
    @db_path = './public_accounts.db'

    # Create test data directory and sample JSON file
    FileUtils.mkdir_p(@data_dir)
    create_test_json_file
  end

  def teardown
    # Clean up test files
    FileUtils.rm_f(@db_path) if File.exist?(@db_path)
    FileUtils.rm_rf(@extracted_dir) if Dir.exist?(@extracted_dir)
  end

  def test_create_db_with_sqlite_utils_installed
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    result = @command.call([])
    assert_equal 0, result
  end

  def test_create_db_creates_database_file
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    @command.call([])
    assert File.exist?(@db_path), "Database file should be created"
  end

  def test_create_db_creates_table_from_json
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    @command.call([])

    # Verify table exists using sqlite3
    output = `sqlite3 #{@db_path} ".tables" 2>&1`
    assert output.include?('test_data'), "Table should be created from JSON filename"
  end

  def test_create_db_inserts_data
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    @command.call([])

    # Verify data was inserted
    output = `sqlite3 #{@db_path} "SELECT COUNT(*) FROM test_data" 2>&1`
    count = output.strip.to_i
    assert count > 0, "Data should be inserted into table"
  end

  def test_create_db_without_json_files
    # Remove test JSON file
    FileUtils.rm_rf(@data_dir)
    FileUtils.mkdir_p(@data_dir)

    result = @command.call([])
    assert_equal 1, result, "Should return error when no JSON files exist"
  end

  def test_create_db_deletes_previous_database
    skip "sqlite-utils not installed" unless sqlite_utils_installed?

    # Create initial database
    @command.call([])
    assert File.exist?(@db_path), "Database should be created"

    # Get the initial modification time
    initial_mtime = File.mtime(@db_path)

    # Wait a moment to ensure timestamp difference
    sleep 0.1

    # Run command again - should delete and recreate
    @command.call([])
    assert File.exist?(@db_path), "Database should still exist"

    # Verify database was recreated (modification time changed)
    new_mtime = File.mtime(@db_path)
    assert new_mtime > initial_mtime, "Database should be recreated with new modification time"
  end

  private

  def sqlite_utils_installed?
    system('which sqlite-utils > /dev/null 2>&1')
  end

  def create_test_json_file
    test_data = [
      { "id" => 1, "name" => "Test 1", "value" => 100 },
      { "id" => 2, "name" => "Test 2", "value" => 200 }
    ]

    File.write(
      File.join(@data_dir, 'test_data.json'),
      JSON.pretty_generate(test_data)
    )
  end
end
