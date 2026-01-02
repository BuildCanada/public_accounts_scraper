require 'test_helper'
require 'pb_cli/commands/initialize'
require 'fileutils'

class TestInitialize < Minitest::Test
  def setup
    @command = PbCli::Commands::Initialize.new
    @db_path = File.join(Dir.pwd, 'public_accounts.db')
    @extracted_dir = './extracted'
    @statscan_dir = './statscan'
  end

  def teardown
    # Clean up test files
    FileUtils.rm(@db_path) if File.exist?(@db_path)
    FileUtils.rm("#{@db_path}-shm") if File.exist?("#{@db_path}-shm")
    FileUtils.rm("#{@db_path}-wal") if File.exist?("#{@db_path}-wal")
    FileUtils.rm_rf(@extracted_dir) if Dir.exist?(@extracted_dir)
  end

  def test_initialize_returns_success_code
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?('./raw')

    result = @command.call([])
    assert_equal 0, result
  end

  def test_initialize_creates_database
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?('./raw')

    @command.call([])
    assert File.exist?(@db_path), "Database should be created"
  end

  def test_initialize_sets_wal_mode
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?('./raw')

    @command.call([])

    # Check if WAL mode is enabled
    output = `sqlite-utils query #{@db_path} 'PRAGMA journal_mode' --csv 2>&1`
    assert_match(/wal/i, output, "Database should be in WAL mode after initialization")
  end
end
