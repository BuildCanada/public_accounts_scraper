require 'fileutils'
require 'zip'

module PbCli
  module Commands
    class Statscan
      # Mapping of dataset names to Statistics Canada Product IDs (PIDs)
      DATASETS = {
        'cpi_monthly' => '1810000401',
        'employment_rate' => '1410028701',
        'gdp_monthly' => '3610022201',
        'international_merchandise_trade' => '1210017101',
        'population_july1' => '1710000501',
        'population_quarterly' => '1710000901'
      }.freeze

      DEFAULT_DB_PATH = 'public_accounts.db'
      DEFAULT_STATSCAN_DIR = 'statscan'

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
        @statscan_dir = paths[:statscan_dir] || DEFAULT_STATSCAN_DIR
      end

      # Class method wrapper for backward compatibility
      def self.run(args, paths: {})
        new(paths).run_instance(args)
      end

      def run_instance(args)
        if args.empty?
          print_help
          return
        end

        subcommand = args[0]

        case subcommand
        when 'download'
          if args.length < 2
            # Download all datasets
            download_all
          else
            # Download specific dataset
            download(args[1])
          end
        when 'load'
          # Parse optional --limit and --index-only flags
          limit = nil
          index_only = false
          remaining_args = []

          i = 1
          while i < args.length
            if args[i] == '--limit' && i + 1 < args.length
              limit = args[i + 1].to_i
              i += 2
            elsif args[i] == '--index-only'
              index_only = true
              i += 1
            else
              remaining_args << args[i]
              i += 1
            end
          end

          if remaining_args.empty?
            # Load all downloaded datasets
            load_all(limit: limit, index_only: index_only)
          else
            # Load specific dataset
            load(remaining_args[0], limit: limit, index_only: index_only)
          end
        else
          puts "Unknown statscan subcommand: #{subcommand}"
          print_help
        end
      end

      def print_help
        puts "Usage: pb statscan <subcommand> [options] [dataset_name]"
        puts ""
        puts "Subcommands:"
        puts "  download  Download dataset from Statistics Canada"
        puts "  load      Load downloaded dataset into database"
        puts ""
        puts "Load Options:"
        puts "  --limit N      Load only the first N rows (useful for testing)"
        puts "  --index-only   Only create indexes (skip data loading)"
        puts ""
        puts "Examples:"
        puts "  pb statscan download cpi_monthly"
        puts "  pb statscan load cpi_monthly"
        puts "  pb statscan load cpi_monthly --limit 1000"
        puts "  pb statscan load --limit 100  # Load all datasets, 100 rows each"
        puts "  pb statscan load cpi_monthly --index-only  # Create indexes only"
        puts ""
        puts "Available datasets:"
        DATASETS.each do |name, pid|
          puts "  #{name} (PID: #{pid})"
        end
      end

      def download_all
        # Check if we're in a TTY environment for pretty output
        if $stdout.tty?
          download_all_with_ui
        else
          download_all_simple
        end
      end

      def download_all_with_ui
        ::CLI::UI::StdoutRouter.enable

        ::CLI::UI::Frame.open("Downloading all Statistics Canada datasets in parallel") do
          # Thread-safe arrays to track results
          results = []
          results_mutex = Mutex.new

          # Use SpinGroup for concurrent spinners
          ::CLI::UI::SpinGroup.new do |spin_group|
            DATASETS.each do |dataset_name, pid|
              spin_group.add("#{dataset_name} (PID: #{pid})") do
                success = download_dataset_silent(dataset_name, pid)

                results_mutex.synchronize do
                  results << { name: dataset_name, success: success }
                end

                success
              end
            end
          end

          # Calculate summary
          downloaded_count = results.count { |r| r[:success] }
          failed_count = results.count { |r| !r[:success] }

          puts ""
          puts ::CLI::UI.fmt("{{v}} Downloaded: #{downloaded_count}")
          puts ::CLI::UI.fmt("{{x}} Failed: #{failed_count}") if failed_count > 0
        end
      ensure
        ::CLI::UI::StdoutRouter.disable
      end

      def download_all_simple
        puts "Downloading all Statistics Canada datasets..."
        puts ""

        downloaded_count = 0
        failed_count = 0

        DATASETS.each do |dataset_name, pid|
          puts "Downloading #{dataset_name} (PID: #{pid})..."
          success = download_dataset(dataset_name, pid)

          if success
            downloaded_count += 1
          else
            failed_count += 1
          end
          puts ""
        end

        puts "Summary:"
        puts "  ✓ Downloaded: #{downloaded_count}"
        puts "  ✗ Failed: #{failed_count}" if failed_count > 0
      end

      def download(dataset_name)
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
        puts ""

        success = download_dataset(dataset_name, pid)

        if success
          puts "\nDownload complete!"
        end
      end

      def download_dataset(dataset_name, pid)
        # Create directory structure
        metadata_dir = File.join(@statscan_dir, 'metadata', dataset_name)
        data_dir = File.join(@statscan_dir, 'data', dataset_name)
        FileUtils.mkdir_p(metadata_dir)
        FileUtils.mkdir_p(data_dir)

        # Download metadata CSV
        metadata_url = "https://www150.statcan.gc.ca/t1/tbl1/en/dtl!downloadCubeMetaData-nonTraduit.action?pid=#{pid}&csvLocale=en"
        metadata_file = File.join(metadata_dir, "#{dataset_name}_metadata.csv")

        # Check if data needs updating
        if metadata_unchanged?(metadata_url, metadata_file)
          puts "  ✓ Data is up-to-date (metadata unchanged)"
          return true
        end

        begin
          download_file(metadata_url, metadata_file)
          puts "  ✓ Metadata saved"
        rescue => e
          puts "  ✗ Error downloading metadata: #{e.message}"
          return false
        end

        # Download data ZIP
        # Convert PID format: remove last 2 digits for data URL
        # Example: 1810000401 -> 18100004
        data_pid = pid[0..-3]
        data_url = "https://www150.statcan.gc.ca/n1/tbl/csv/#{data_pid}-eng.zip"
        data_file = File.join(data_dir, "#{dataset_name}_data.zip")

        begin
          download_file(data_url, data_file)
          puts "  ✓ Data saved"
          return true
        rescue => e
          puts "  ✗ Error downloading data: #{e.message}"
          return false
        end
      end

      def download_dataset_silent(dataset_name, pid)
        # Create directory structure
        metadata_dir = File.join(@statscan_dir, 'metadata', dataset_name)
        data_dir = File.join(@statscan_dir, 'data', dataset_name)
        FileUtils.mkdir_p(metadata_dir)
        FileUtils.mkdir_p(data_dir)

        # Download metadata CSV
        metadata_url = "https://www150.statcan.gc.ca/t1/tbl1/en/dtl!downloadCubeMetaData-nonTraduit.action?pid=#{pid}&csvLocale=en"
        metadata_file = File.join(metadata_dir, "#{dataset_name}_metadata.csv")

        # Check if data needs updating
        return true if metadata_unchanged?(metadata_url, metadata_file)

        begin
          download_file(metadata_url, metadata_file)
        rescue
          return false
        end

        # Download data ZIP
        # Convert PID format: remove last 2 digits for data URL
        # Example: 1810000401 -> 18100004
        data_pid = pid[0..-3]
        data_url = "https://www150.statcan.gc.ca/n1/tbl/csv/#{data_pid}-eng.zip"
        data_file = File.join(data_dir, "#{dataset_name}_data.zip")

        begin
          download_file(data_url, data_file)
          return true
        rescue
          return false
        end
      end

      def load_all(limit: nil, index_only: false)
        if index_only
          puts "Creating indexes for all Statistics Canada datasets..."
        elsif limit
          puts "Loading all downloaded Statistics Canada datasets (first #{limit} rows only)..."
        else
          puts "Loading all downloaded Statistics Canada datasets..."
        end
        puts ""

        loaded_count = 0
        skipped_count = 0
        failed_count = 0

        DATASETS.each do |dataset_name, pid|
          # Check if data file exists (only needed if not index_only)
          data_dir = File.join(@statscan_dir, 'data', dataset_name)
          data_file = File.join(data_dir, "#{dataset_name}_data.zip")

          if !index_only && !File.exist?(data_file)
            puts "⊘ Skipping #{dataset_name}: Not downloaded"
            skipped_count += 1
            next
          end

          if index_only
            puts "Creating indexes for #{dataset_name}..."
            success = create_indexes_for_table("statscan_#{dataset_name}")
          else
            puts "Loading #{dataset_name}..."
            success = load_dataset(dataset_name, data_file, data_dir, limit: limit, create_indexes: true)
          end

          if success
            loaded_count += 1
          else
            failed_count += 1
          end
          puts ""
        end

        puts "Summary:"
        if index_only
          puts "  ✓ Indexed: #{loaded_count}"
        else
          puts "  ✓ Loaded: #{loaded_count}"
        end
        puts "  ⊘ Skipped: #{skipped_count}" if skipped_count > 0
        puts "  ✗ Failed: #{failed_count}" if failed_count > 0
        puts ""
        puts "Database: #{@db_path}"
      end

      def load(dataset_name, limit: nil, index_only: false)
        unless DATASETS.key?(dataset_name)
          puts "Error: Unknown dataset '#{dataset_name}'"
          puts "\nAvailable datasets:"
          DATASETS.each do |name, pid|
            puts "  #{name} (PID: #{pid})"
          end
          return
        end

        table_name = "statscan_#{dataset_name}"

        if index_only
          puts "Creating indexes for Statistics Canada dataset: #{dataset_name}"
          success = create_indexes_for_table(table_name)

          if success
            puts "\nDatabase: #{@db_path}"
            puts "Table: #{table_name}"
          end
          return
        end

        if limit
          puts "Loading Statistics Canada dataset: #{dataset_name} (first #{limit} rows only)"
        else
          puts "Loading Statistics Canada dataset: #{dataset_name}"
        end

        # Check if data file exists
        data_dir = File.join(@statscan_dir, 'data', dataset_name)
        data_file = File.join(data_dir, "#{dataset_name}_data.zip")

        unless File.exist?(data_file)
          puts "Error: Dataset not downloaded. Run: pb statscan download #{dataset_name}"
          return
        end

        success = load_dataset(dataset_name, data_file, data_dir, limit: limit, create_indexes: true)

        if success
          puts "\nDatabase: #{@db_path}"
          puts "Table: #{table_name}"
        end
      end

      def load_dataset(dataset_name, data_file, data_dir, limit: nil, create_indexes: false)
        # Extract CSV from ZIP
        csv_file = extract_csv_from_zip(data_file, data_dir)

        unless csv_file
          puts "  ✗ Error: Could not find CSV file in ZIP archive"
          puts "     ZIP file: #{data_file}"
          return false
        end

        # Load into database using sqlite-utils
        table_name = "statscan_#{dataset_name}"

        # Ensure database directory exists
        FileUtils.mkdir_p(File.dirname(@db_path))

        # Build sqlite-utils command
        require 'open3'
        cmd = [
          'sqlite-utils', 'insert',
          @db_path,
          table_name,
          csv_file,
          '--csv',
          '--detect-types',
          '--replace'
        ]

        # Add --stop-after flag if limit is specified
        if limit
          cmd << "--stop-after=#{limit}"
        end

        stdout, stderr, status = Open3.capture3(*cmd)

        if status.success?
          # Get row count
          row_count_output, _, count_status = Open3.capture3(
            'sqlite-utils', 'query', @db_path,
            "SELECT COUNT(*) as count FROM #{table_name}",
            '--csv'
          )

          if count_status.success?
            row_count = row_count_output.lines[1]&.strip
            puts "  ✓ Loaded #{row_count || 'unknown'} rows into #{table_name}"
          else
            puts "  ✓ Loaded data into #{table_name}"
          end

          # Create indexes if requested
          if create_indexes
            create_indexes_for_table(table_name)
          end

          return true
        else
          puts "  ✗ Error loading data into database"
          puts "     Table: #{table_name}"
          puts "     CSV file: #{csv_file}"

          # Show the actual error from sqlite-utils
          if stderr && !stderr.empty?
            puts "     sqlite-utils error:"
            stderr.lines.each do |line|
              puts "       #{line.strip}"
            end
          end

          # Common issues and suggestions
          puts ""
          puts "     Common causes:"
          puts "       • CSV file may be malformed or have encoding issues"
          puts "       • sqlite-utils may not be installed (run: pip install sqlite-utils)"
          puts "       • Database file may be locked by another process"

          return false
        end
      end

      def create_indexes_for_table(table_name)
        require 'open3'

        # Check if table exists
        check_output, _, check_status = Open3.capture3(
          'sqlite-utils', 'tables', @db_path, '--json-cols'
        )

        unless check_status.success?
          puts "  ✗ Error checking tables in database"
          return false
        end

        require 'json'
        tables = JSON.parse(check_output).map { |t| t['table'] }

        unless tables.include?(table_name)
          puts "  ✗ Error: Table #{table_name} does not exist in database"
          return false
        end

        # Get columns from the table
        columns_output, _, columns_status = Open3.capture3(
          'sqlite-utils', 'schema', @db_path, table_name
        )

        unless columns_status.success?
          puts "  ✗ Error getting columns for table #{table_name}"
          return false
        end

        # Parse columns from schema (looking for CREATE TABLE statement)
        # Example: CREATE TABLE "statscan_cpi_monthly" (
        #   [REF_DATE] TEXT,
        #   [GEO] TEXT,
        #   [DGUID] TEXT,
        #   ...
        columns = []
        columns_output.lines.each do |line|
          # Match column definitions like: [COLUMN_NAME] TYPE,
          if line =~ /\[([^\]]+)\]\s+\w+/
            columns << $1
          end
        end

        # Filter columns to index
        # 1. Always index REF_DATE and GEO if they exist
        # 2. Index all columns that are NOT in CAPITAL_CASE
        # 3. Exclude row_id
        columns_to_index = []

        # Add REF_DATE and GEO if they exist
        columns_to_index << 'REF_DATE' if columns.include?('REF_DATE')
        columns_to_index << 'GEO' if columns.include?('GEO')

        # Add all non-CAPITAL_CASE columns (excluding row_id and columns already added)
        columns.each do |col|
          next if col == 'rowid' || col == 'row_id'
          next if columns_to_index.include?(col)
          # A column is CAPITAL_CASE if it's all uppercase and may contain underscores
          is_capital_case = col == col.upcase && col =~ /^[A-Z_]+$/
          columns_to_index << col unless is_capital_case
        end

        if columns_to_index.empty?
          puts "  ⊘ No columns to index"
          return true
        end

        # Create indexes
        indexed_count = 0
        columns_to_index.each do |column|
          index_name = "idx_#{table_name}_#{column.downcase.gsub(/[^a-z0-9_]/, '_')}"

          stdout, stderr, status = Open3.capture3(
            'sqlite-utils', 'create-index', @db_path,
            table_name, column,
            '--if-not-exists',
            '--analyze'
          )

          if status.success?
            indexed_count += 1
          else
            puts "  ! Warning: Could not create index on #{column}"
            if stderr && !stderr.empty?
              puts "     Error: #{stderr.strip}"
            end
          end
        end

        puts "  ✓ Created #{indexed_count} index(es) on #{columns_to_index.join(', ')}"
        true
      end

      def extract_csv_from_zip(zip_file, output_dir)
        # Find and extract the main CSV file from the ZIP
        Zip::File.open(zip_file) do |zip|
          # Look for the main data CSV (usually the largest file or has specific pattern)
          csv_entry = zip.entries.find do |entry|
            entry.name.end_with?('.csv') && !entry.name.include?('MetaData')
          end

          if csv_entry
            output_path = File.join(output_dir, csv_entry.name)
            csv_entry.extract(output_path) { true } # Override if exists
            return output_path
          end
        end

        nil
      end

      def download_file(url, output_path)
        # Use curl for downloading files (more robust than Net::HTTP)
        # -L: follow redirects
        # -s: silent mode (no progress bar)
        # -S: show errors even in silent mode
        # -o: output file
        system('curl', '-L', '-s', '-S', '-o', output_path, url, exception: true)
      end

      def metadata_unchanged?(metadata_url, metadata_file)
        # If metadata file doesn't exist locally, data needs downloading
        return false unless File.exist?(metadata_file)

        # Download metadata to temporary file
        require 'tempfile'
        temp_file = Tempfile.new(['statscan_metadata', '.csv'])

        begin
          download_file(metadata_url, temp_file.path)

          # Compare file contents
          existing_content = File.read(metadata_file)
          new_content = File.read(temp_file.path)

          existing_content == new_content
        rescue
          # If we can't download or compare, assume data needs updating
          false
        ensure
          temp_file.close
          temp_file.unlink
        end
      end

      # Class method wrappers for testing
      def self.metadata_unchanged?(metadata_url, metadata_file)
        new.metadata_unchanged?(metadata_url, metadata_file)
      end

      def self.download_file(url, output_path)
        new.download_file(url, output_path)
      end
    end
  end
end
