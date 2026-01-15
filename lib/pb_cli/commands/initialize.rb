require 'cli/ui'
require 'fileutils'

module PbCli
  module Commands
    class Initialize
      DEFAULT_DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      DEFAULT_STATSCAN_CACHE_PATH = File.join(Dir.pwd, 'public_accounts.statscan_base.db')
      DEFAULT_EXTRACTED_DIR = './extracted'
      DEFAULT_STATSCAN_DIR = './statscan'

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
        @statscan_cache_path = paths[:statscan_cache_path] || DEFAULT_STATSCAN_CACHE_PATH
        @paths = paths
      end

      def call(args)
        force = args.include?('--force')

        ::CLI::UI::Frame.open("Initializing database") do
          # Step 1: Delete existing database (and cache if --force)
          puts ::CLI::UI.fmt("{{*}} Step 1/11: Cleaning up existing database")
          delete_existing_database
          delete_statscan_cache if force
          puts ""

          # Step 2: Initialize statscan cache (or use existing)
          puts ::CLI::UI.fmt("{{*}} Step 2/11: Initializing Statistics Canada data cache")
          statscan_result = initialize_statscan_cache
          if statscan_result != 0
            puts ::CLI::UI.fmt("{{x}} Statistics Canada cache initialization failed")
            return 1
          end
          puts ""

          # Step 3: Copy statscan cache as base database
          puts ::CLI::UI.fmt("{{*}} Step 3/11: Copying statscan cache as base database")
          copy_statscan_cache
          puts ""

          # Step 4: Extract data from HTML
          puts ::CLI::UI.fmt("{{*}} Step 4/11: Extracting data from HTML")
          extract_result = run_extract
          if extract_result != 0
            puts ::CLI::UI.fmt("{{x}} Extract failed")
            return 1
          end
          puts ""

          # Step 5: Load extracted data into database
          puts ::CLI::UI.fmt("{{*}} Step 5/11: Loading extracted data")
          load_result = load_extracted_data
          if load_result != 0
            puts ::CLI::UI.fmt("{{x}} Load extracted data failed")
            return 1
          end
          puts ""

          # Step 6: Download open data tables
          puts ::CLI::UI.fmt("{{*}} Step 6/11: Downloading open data tables")
          download_result = run_download_tables
          # Don't fail if download fails (network issues, etc.)
          if download_result != 0
            puts ::CLI::UI.fmt("{{!}} Open data download had issues - continuing")
          end
          puts ""

          # Step 7: Import open data tables
          puts ::CLI::UI.fmt("{{*}} Step 7/11: Importing open data tables")
          import_result = run_import_tables
          # Don't fail if import fails (may not have downloaded data)
          if import_result != 0
            puts ::CLI::UI.fmt("{{!}} Open data import had issues - continuing")
          end
          puts ""

          # Step 8: Normalize transfer payment descriptions
          puts ::CLI::UI.fmt("{{*}} Step 8/11: Normalizing transfer payment descriptions")
          normalize_result = run_normalize_descriptions
          if normalize_result != 0
            puts ::CLI::UI.fmt("{{x}} Normalize descriptions failed")
            return 1
          end
          puts ""

          # Step 9: Create inflation-adjusted tables
          puts ::CLI::UI.fmt("{{*}} Step 9/11: Creating inflation-adjusted tables")
          inflation_result = run_create_inflation_adjusted_tables
          if inflation_result != 0
            puts ::CLI::UI.fmt("{{x}} Create inflation-adjusted tables failed")
            return 1
          end

          # Update normalized view with inflation-adjusted version
          run_normalize_descriptions_update
          puts ""

          # Step 10: Create views
          puts ::CLI::UI.fmt("{{*}} Step 10/11: Creating views")
          run_create_views
          puts ""

          # Step 11: Create consolidated metadata and optimize
          puts ::CLI::UI.fmt("{{*}} Step 11/11: Creating consolidated metadata and optimizing database")
          run_create_metadata
          optimize_for_reads
          puts ""

          puts ::CLI::UI.fmt("{{v}} Initialization complete!")
        end

        0
      end

      private

      def delete_existing_database
        if File.exist?(@db_path)
          FileUtils.rm(@db_path)
          puts ::CLI::UI.fmt("{{v}} Deleted existing database: #{@db_path}")
        else
          puts ::CLI::UI.fmt("{{i}} No existing database to delete")
        end

        # Also clean up WAL files if they exist
        wal_file = "#{@db_path}-wal"
        shm_file = "#{@db_path}-shm"
        FileUtils.rm(wal_file) if File.exist?(wal_file)
        FileUtils.rm(shm_file) if File.exist?(shm_file)
      end

      def delete_statscan_cache
        if File.exist?(@statscan_cache_path)
          FileUtils.rm(@statscan_cache_path)
          puts ::CLI::UI.fmt("{{v}} Deleted statscan cache: #{@statscan_cache_path}")
        end
      end

      def initialize_statscan_cache
        if File.exist?(@statscan_cache_path)
          puts ::CLI::UI.fmt("{{v}} Using existing statscan cache: #{@statscan_cache_path}")
          return 0
        end

        puts ::CLI::UI.fmt("{{i}} Creating new statscan cache (this may take a while)...")

        # Create a fresh database for statscan data
        require_relative 'create_db'

        # Create the database file
        cmd = "sqlite-utils create-database #{@statscan_cache_path}"
        output = `#{cmd} 2>&1`
        status = $?.exitstatus

        if status != 0
          puts ::CLI::UI.fmt("{{x}} Failed to create statscan cache database")
          puts output if ENV['DEBUG']
          return 1
        end

        # Set write-optimized settings
        cache_paths = @paths.merge(db_path: @statscan_cache_path)
        Commands::CreateDb.new(cache_paths).set_write_optimized_settings

        # Load statscan data
        require_relative 'statscan'
        Commands::Statscan.run(['load'], paths: cache_paths)

        # Set read-optimized settings
        Commands::CreateDb.new(cache_paths).set_read_optimized_settings

        puts ::CLI::UI.fmt("{{v}} Statscan cache created: #{@statscan_cache_path}")
        0
      end

      def copy_statscan_cache
        FileUtils.cp(@statscan_cache_path, @db_path)
        puts ::CLI::UI.fmt("{{v}} Copied statscan cache to: #{@db_path}")

        # Set write-optimized settings for loading more data
        require_relative 'create_db'
        Commands::CreateDb.new(@paths).set_write_optimized_settings
      end

      def run_extract
        require_relative 'extract'
        Commands::Extract.new(@paths).call([])
      end

      def run_download_tables
        require_relative 'download_tables'
        Commands::DownloadTables.new(@paths).call([])
      end

      def run_import_tables
        require_relative 'import_tables'
        Commands::ImportTables.new(@paths).call([])
      end

      def load_extracted_data
        require_relative 'create_db'
        # Use a custom load that doesn't delete the database
        Commands::CreateDb.new(@paths).load_json_files_only
      end

      def run_create_inflation_adjusted_tables
        require_relative 'create_inflation_adjusted_tables'
        Commands::CreateInflationAdjustedTables.new(@paths).call([])
      end

      def run_normalize_descriptions
        require_relative 'normalize_descriptions'
        Commands::NormalizeDescriptions.new(@paths).call([])
      end

      def run_normalize_descriptions_update
        require_relative 'normalize_descriptions'
        Commands::NormalizeDescriptions.new(@paths).call(['--update-inflation-view'])
      end

      def run_create_views
        require_relative 'create_views'
        Commands::CreateViews.new(@paths).call([])
      end

      def run_create_metadata
        require_relative 'create_metadata'
        Commands::CreateMetadata.new(@paths).call([])
      end

      def optimize_for_reads
        require_relative 'create_db'
        Commands::CreateDb.new(@paths).set_read_optimized_settings
        puts ::CLI::UI.fmt("{{v}} Database optimization complete")
      end
    end
  end
end
