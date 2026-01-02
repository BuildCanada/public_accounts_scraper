require_relative '../test_helper'
require 'pb_cli/commands/statscan'
require 'fileutils'

module PbCli
  module Commands
    class TestStatscan < Minitest::Test
      def setup
        @test_dir = 'test_statscan_output'
        FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
      end

      def teardown
        FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
        FileUtils.rm_rf('statscan') if Dir.exist?('statscan')
      end

      def test_datasets_mapping_exists
        assert Statscan::DATASETS.is_a?(Hash)
        assert Statscan::DATASETS.frozen?
      end

      def test_cpi_monthly_dataset_exists
        assert Statscan::DATASETS.key?('cpi_monthly')
        assert_equal '1810000401', Statscan::DATASETS['cpi_monthly']
      end

      def test_run_without_args_shows_usage
        output = capture_io do
          Statscan.run([])
        end

        assert_match(/Usage: pb statscan download/, output[0])
        assert_match(/Available datasets:/, output[0])
      end

      def test_run_with_unknown_subcommand
        output = capture_io do
          Statscan.run(['unknown'])
        end

        assert_match(/Usage: pb statscan download/, output[0])
      end

      def test_download_unknown_dataset_shows_error
        output = capture_io do
          Statscan.run(['download', 'nonexistent_dataset'])
        end

        assert_match(/Error: Unknown dataset/, output[0])
        assert_match(/Available datasets:/, output[0])
      end
    end
  end
end
