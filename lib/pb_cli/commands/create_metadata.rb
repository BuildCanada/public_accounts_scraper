require 'yaml'
require_relative '../statscan_metadata_parser'

module PbCli
  module Commands
    class CreateMetadata
      DEFAULT_EXTRACTED_DIR = "extracted/metadata"
      DEFAULT_STATSCAN_DIR = "statscan/metadata"
      DEFAULT_OUTPUT_PATH = "metadata.yaml"
      DEFAULT_BASE_PATH = "metadata.base.yaml"

      def initialize(paths = {})
        @extracted_dir = paths[:extracted_dir] || DEFAULT_EXTRACTED_DIR
        @statscan_dir = paths[:statscan_dir] || DEFAULT_STATSCAN_DIR
        @output_path = paths[:output_path] || DEFAULT_OUTPUT_PATH
        @base_path = paths[:base_path] || DEFAULT_BASE_PATH
      end

      # Class method wrapper for backward compatibility
      def self.execute(args = [], paths: {})
        new(paths).call(args)
      end

      def call(_args = [])
        puts "Creating consolidated metadata.yaml..."

        # Initialize the metadata structure
        metadata = {}

        # Read base metadata if it exists and merge it at the top level first
        base_metadata_path = @base_path
        if File.exist?(base_metadata_path)
          puts "Reading base metadata from #{base_metadata_path}..."
          base_metadata = YAML.load_file(base_metadata_path)

          # Merge base metadata at the top level (title, description, license, etc.)
          if base_metadata
            base_metadata.each do |key, value|
              metadata[key] = value
            end
          end
        end

        # Initialize databases structure after base metadata
        metadata["databases"] = {
          "public_accounts" => {
            "tables" => {}
          }
        }

        # Read extracted metadata YAML files
        if Dir.exist?(@extracted_dir)
          puts "Reading extracted metadata from #{@extracted_dir}..."
          Dir.glob("#{@extracted_dir}/*.yaml").each do |yaml_file|
            yaml_metadata = YAML.load_file(yaml_file)
            next unless yaml_metadata && yaml_metadata["databases"] && yaml_metadata["databases"]["public_accounts"]

            tables = yaml_metadata["databases"]["public_accounts"]["tables"]
            metadata["databases"]["public_accounts"]["tables"].merge!(tables) if tables
          end
        end

        # Read statscan metadata CSV files
        if Dir.exist?(@statscan_dir)
          puts "Reading Statistics Canada metadata from #{@statscan_dir}..."
          Dir.glob("#{@statscan_dir}/*/*.csv").each do |csv_file|
            dataset_name = File.basename(File.dirname(csv_file))
            table_name = "statscan_#{dataset_name}"

            puts "  Processing #{dataset_name}..."

            begin
              parser = StatscanMetadataParser.new(csv_file)
              table_metadata = parser.parse

              # Convert symbol keys to string keys for YAML output
              table_metadata_str = table_metadata.transform_keys(&:to_s)
              table_metadata_str["columns"] = table_metadata_str["columns"].transform_keys(&:to_s) if table_metadata_str["columns"]

              metadata["databases"]["public_accounts"]["tables"][table_name] = table_metadata_str
            rescue => e
              puts "  Warning: Failed to parse #{csv_file}: #{e.message}"
            end
          end
        end

        # Write consolidated metadata.yaml
        File.write(@output_path, YAML.dump(metadata))
        puts "Consolidated metadata written to #{@output_path}"

        # Print summary
        table_count = metadata["databases"]["public_accounts"]["tables"].size
        puts "\nSummary:"
        puts "  Total tables: #{table_count}"
      end
    end
  end
end
