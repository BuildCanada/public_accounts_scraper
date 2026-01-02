require 'fileutils'

module PbCli
  module Commands
    class Statscan
      # Mapping of dataset names to Statistics Canada Product IDs (PIDs)
      DATASETS = {
        'cpi_monthly' => '1810000401'
      }.freeze

      def self.run(args)
        if args.length < 2
          puts "Usage: pb statscan download <dataset_name>"
          puts "\nAvailable datasets:"
          DATASETS.each do |name, pid|
            puts "  #{name} (PID: #{pid})"
          end
          return
        end

        subcommand = args[0]
        dataset_name = args[1]

        case subcommand
        when 'download'
          download(dataset_name)
        else
          puts "Unknown statscan subcommand: #{subcommand}"
          puts "Available subcommands: download"
        end
      end

      def self.download(dataset_name)
        unless DATASETS.key?(dataset_name)
          puts "Error: Unknown dataset '#{dataset_name}'"
          puts "\nAvailable datasets:"
          DATASETS.each do |name, pid|
            puts "  #{name} (PID: #{pid})"
          end
          return
        end

        pid = DATASETS[dataset_name]
        puts "Downloading Statistics Canada dataset: #{dataset_name} (PID: #{pid})"

        # Create directory structure
        metadata_dir = File.join('statscan', 'metadata', dataset_name)
        data_dir = File.join('statscan', 'data', dataset_name)
        FileUtils.mkdir_p(metadata_dir)
        FileUtils.mkdir_p(data_dir)

        # Download metadata CSV
        metadata_url = "https://www150.statcan.gc.ca/t1/tbl1/en/dtl!downloadCubeMetaData-nonTraduit.action?pid=#{pid}&csvLocale=en"
        metadata_file = File.join(metadata_dir, "#{dataset_name}_metadata.csv")

        puts "Downloading metadata from #{metadata_url}"
        download_file(metadata_url, metadata_file)
        puts "✓ Metadata saved to #{metadata_file}"

        # Download data ZIP
        # Convert PID format: remove last 2 digits for data URL
        # Example: 1810000401 -> 18100004
        data_pid = pid[0..-3]
        data_url = "https://www150.statcan.gc.ca/n1/tbl/csv/#{data_pid}-eng.zip"
        data_file = File.join(data_dir, "#{dataset_name}_data.zip")

        puts "Downloading data from #{data_url}"
        download_file(data_url, data_file)
        puts "✓ Data saved to #{data_file}"

        puts "\nDownload complete!"
        puts "  Metadata: #{metadata_file}"
        puts "  Data: #{data_file}"
      end

      def self.download_file(url, output_path)
        # Use curl for downloading files (more robust than Net::HTTP)
        # -L: follow redirects
        # -s: silent mode (no progress bar)
        # -S: show errors even in silent mode
        # -o: output file
        system('curl', '-L', '-s', '-S', '-o', output_path, url, exception: true)
      end
    end
  end
end
