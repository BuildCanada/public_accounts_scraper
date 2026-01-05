require 'cli/ui'

module PbCli
  module Commands
    class Initialize
      DEFAULT_DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      DEFAULT_EXTRACTED_DIR = './extracted'
      DEFAULT_STATSCAN_DIR = './statscan'

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
        @paths = paths
      end

      def call(args)
        ::CLI::UI::Frame.open("Initializing database") do
          # Step 1: Extract data
          puts ::CLI::UI.fmt("{{*}} Step 1/4: Extracting data")
          extract_result = run_extract
          if extract_result != 0
            puts ::CLI::UI.fmt("{{x}} Extract failed")
            return 1
          end
          puts ""

          # Step 2: Create database and load extracted data
          # Use --skip-optimization to prevent switching to read mode after loading
          puts ::CLI::UI.fmt("{{*}} Step 2/4: Creating database and loading extracted data")
          create_db_result = run_create_db
          if create_db_result != 0
            puts ::CLI::UI.fmt("{{x}} Create database failed")
            return 1
          end
          puts ""

          # Step 3: Load Statistics Canada data
          puts ::CLI::UI.fmt("{{*}} Step 3/4: Loading Statistics Canada data")
          statscan_result = run_statscan_load
          # Note: statscan load doesn't return an exit code, so we assume success
          puts ""

          # Step 4: Optimize database for read workloads
          puts ::CLI::UI.fmt("{{*}} Step 4/4: Optimizing database for read workloads")
          optimize_for_reads
          puts ""

          puts ::CLI::UI.fmt("{{v}} Initialization complete!")
        end

        0
      end

      private

      def run_extract
        require_relative 'extract'
        Commands::Extract.new(@paths).call([])
      end

      def run_create_db
        require_relative 'create_db'
        # Use --keep-write-mode to stay in write-optimized mode for statscan loading
        Commands::CreateDb.new(@paths).call(['--keep-write-mode'])
      end

      def run_statscan_load
        require_relative 'statscan'
        Commands::Statscan.run(['load'], paths: @paths)
      end

      def optimize_for_reads
        require_relative 'create_db'
        Commands::CreateDb.new(@paths).set_read_optimized_settings
        puts ::CLI::UI.fmt("{{v}} Database optimization complete")
      end
    end
  end
end
