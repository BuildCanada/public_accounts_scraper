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

      def test_employment_rate_dataset_exists
        assert Statscan::DATASETS.key?('employment_rate')
        assert_equal '1410028701', Statscan::DATASETS['employment_rate']
      end

      def test_gdp_monthly_dataset_exists
        assert Statscan::DATASETS.key?('gdp_monthly')
        assert_equal '3610022201', Statscan::DATASETS['gdp_monthly']
      end

      def test_population_july1_dataset_exists
        assert Statscan::DATASETS.key?('population_july1')
        assert_equal '1710000501', Statscan::DATASETS['population_july1']
      end

      def test_population_quarterly_dataset_exists
        assert Statscan::DATASETS.key?('population_quarterly')
        assert_equal '1710000901', Statscan::DATASETS['population_quarterly']
      end

      def test_run_without_args_shows_usage
        output = capture_io do
          Statscan.run([])
        end

        assert_match(/Usage: pb statscan/, output[0])
        assert_match(/Subcommands:/, output[0])
        assert_match(/download/, output[0])
        assert_match(/load/, output[0])
      end

      def test_run_with_unknown_subcommand
        output = capture_io do
          Statscan.run(['unknown'])
        end

        assert_match(/Unknown statscan subcommand/, output[0])
        assert_match(/Usage: pb statscan/, output[0])
      end

      def test_download_without_dataset_downloads_all
        output = capture_io do
          Statscan.run(['download'])
        end

        assert_match(/Downloading all Statistics Canada datasets/, output[0])
        assert_match(/Summary:/, output[0])
      end

      def test_download_unknown_dataset_shows_error
        output = capture_io do
          Statscan.run(['download', 'nonexistent_dataset'])
        end

        assert_match(/Error: Unknown dataset/, output[0])
        assert_match(/Available datasets:/, output[0])
      end

      def test_load_without_dataset_loads_all
        output = capture_io do
          Statscan.run(['load'])
        end

        assert_match(/Loading all downloaded Statistics Canada datasets/, output[0])
        assert_match(/Summary:/, output[0])
      end

      def test_load_unknown_dataset_shows_error
        output = capture_io do
          Statscan.run(['load', 'nonexistent_dataset'])
        end

        assert_match(/Error: Unknown dataset/, output[0])
        assert_match(/Available datasets:/, output[0])
      end

      def test_load_without_download_shows_error
        output = capture_io do
          Statscan.run(['load', 'cpi_monthly'])
        end

        assert_match(/Error: Dataset not downloaded/, output[0])
        assert_match(/pb statscan download/, output[0])
      end

      def test_metadata_unchanged_returns_false_when_file_missing
        # When metadata file doesn't exist, should return false (needs downloading)
        refute Statscan.metadata_unchanged?('http://example.com/metadata.csv', 'nonexistent.csv')
      end

      def test_metadata_unchanged_with_mock_download
        # Create a temporary metadata file
        require 'tempfile'
        metadata_file = Tempfile.new(['test_metadata', '.csv'])
        metadata_content = "Column1,Column2\nValue1,Value2\n"
        File.write(metadata_file.path, metadata_content)

        # Mock download_file to write the same content
        Statscan.define_singleton_method(:download_file) do |url, output_path|
          File.write(output_path, metadata_content)
        end

        # Should return true when content is identical
        assert Statscan.metadata_unchanged?('http://example.com/metadata.csv', metadata_file.path)

        # Mock download_file to write different content
        different_content = "Column1,Column2\nDifferentValue1,DifferentValue2\n"
        Statscan.define_singleton_method(:download_file) do |url, output_path|
          File.write(output_path, different_content)
        end

        # Should return false when content is different
        refute Statscan.metadata_unchanged?('http://example.com/metadata.csv', metadata_file.path)

        metadata_file.close
        metadata_file.unlink
      end

      def test_load_with_limit_flag_single_dataset
        output = capture_io do
          Statscan.run(['load', 'cpi_monthly', '--limit', '100'])
        end

        assert_match(/Loading Statistics Canada dataset: cpi_monthly \(first 100 rows only\)/, output[0])
      end

      def test_load_with_limit_flag_all_datasets
        output = capture_io do
          Statscan.run(['load', '--limit', '50'])
        end

        assert_match(/Loading all downloaded Statistics Canada datasets \(first 50 rows only\)/, output[0])
      end

      def test_help_shows_limit_option
        output = capture_io do
          Statscan.run([])
        end

        assert_match(/--limit N/, output[0])
        assert_match(/Load only the first N rows/, output[0])
      end

      def test_help_shows_index_only_option
        output = capture_io do
          Statscan.run([])
        end

        assert_match(/--index-only/, output[0])
        assert_match(/Only create indexes/, output[0])
      end

      def test_load_with_index_only_flag
        output = capture_io do
          Statscan.run(['load', 'cpi_monthly', '--index-only'])
        end

        assert_match(/Creating indexes for Statistics Canada dataset: cpi_monthly/, output[0])
      end

      def test_load_all_with_index_only_flag
        output = capture_io do
          Statscan.run(['load', '--index-only'])
        end

        assert_match(/Creating indexes for all Statistics Canada datasets/, output[0])
        assert_match(/Summary:/, output[0])
      end
    end
  end
end
