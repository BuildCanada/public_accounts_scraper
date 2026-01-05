require 'test_helper'
require 'pb_cli/commands/initialize'
require 'fileutils'

class TestInitialize < Minitest::Test
  include TestPaths

  def setup
    @test_paths = setup_test_paths('initialize')
    @command = PbCli::Commands::Initialize.new(@test_paths)
    @db_path = @test_paths[:db_path]
  end

  def teardown
    cleanup_test_paths(@test_paths)
  end

  def test_initialize_returns_success_code
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?(@test_paths[:raw_dir])

    result = @command.call([])
    assert_equal 0, result
  end

  def test_initialize_creates_database
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?(@test_paths[:raw_dir])

    @command.call([])
    assert File.exist?(@db_path), "Database should be created"
  end

  def test_initialize_sets_wal_mode
    # Skip this test if no raw data is available
    skip "No raw data available for extraction" unless Dir.exist?(@test_paths[:raw_dir])

    @command.call([])

    # Check if WAL mode is enabled
    output = `sqlite-utils query #{@db_path} 'PRAGMA journal_mode' --csv 2>&1`
    assert_match(/wal/i, output, "Database should be in WAL mode after initialization")
  end
end
