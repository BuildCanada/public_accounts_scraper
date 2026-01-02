require 'cli/ui'
require 'fileutils'

module PbCli
  module Commands
    class CreateDb
      DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      DATA_DIR = File.join(Dir.pwd, 'extracted', 'data')

      # Class methods for database optimization
      def self.set_write_optimized_settings(db_path = DB_PATH)
        # Optimize for bulk loading: prioritize write speed over safety
        execute_pragma(db_path, "journal_mode = OFF")      # Disable journaling during load
        execute_pragma(db_path, "synchronous = OFF")       # Don't wait for disk writes
        execute_pragma(db_path, "cache_size = -64000")     # 64MB cache
        execute_pragma(db_path, "temp_store = MEMORY")     # Keep temp data in memory
        execute_pragma(db_path, "locking_mode = EXCLUSIVE") # Exclusive access during load
      end

      def self.set_read_optimized_settings(db_path = DB_PATH)
        # Optimize for read-heavy workloads
        execute_pragma(db_path, "locking_mode = NORMAL")   # Allow concurrent access
        execute_pragma(db_path, "journal_mode = WAL")      # Write-Ahead Logging for concurrent reads
        execute_pragma(db_path, "synchronous = NORMAL")    # Balance safety and performance
        execute_pragma(db_path, "cache_size = -2000")      # 2MB cache
        execute_pragma(db_path, "temp_store = DEFAULT")    # Default temp storage

        # Analyze database for query optimization
        cmd = "sqlite-utils query #{db_path} 'PRAGMA optimize'"
        `#{cmd} 2>&1`
      end

      def self.execute_pragma(db_path, pragma)
        cmd = "sqlite-utils query #{db_path} 'PRAGMA #{pragma}'"
        output = `#{cmd} 2>&1`
        status = $?.exitstatus

        if status != 0
          puts ::CLI::UI.fmt("{{x}} Warning: Failed to set PRAGMA #{pragma}")
          puts output if ENV['DEBUG']
        end
      end

      def call(args)
        # Parse optional flags
        skip_optimization = args.include?('--skip-optimization')
        keep_write_mode = args.include?('--keep-write-mode')

        # Check if sqlite-utils is installed
        unless command_exists?('sqlite-utils')
          puts ::CLI::UI.fmt("{{x}} Error: sqlite-utils is not installed")
          puts ""
          puts "Install it with:"
          puts "  pip install sqlite-utils"
          puts ""
          puts "Or using Homebrew:"
          puts "  brew install sqlite-utils"
          return 1
        end

        # Find all JSON files
        json_files = Dir.glob(File.join(DATA_DIR, '*.json'))

        if json_files.empty?
          puts ::CLI::UI.fmt("{{x}} No JSON files found in #{DATA_DIR}")
          puts "Run 'pb extract' first to generate data files"
          return 1
        end

        # Delete existing database if it exists
        if File.exist?(DB_PATH)
          FileUtils.rm(DB_PATH)
          puts ::CLI::UI.fmt("{{i}} Deleted existing database: #{DB_PATH}")
        end

        # Create database
        create_database

        # Set write-optimized SQLite settings for bulk loading (unless skipped)
        unless skip_optimization
          puts ::CLI::UI.fmt("{{i}} Optimizing database for bulk loading...")
          self.class.set_write_optimized_settings(DB_PATH)
        end

        # Process each JSON file
        ::CLI::UI::Frame.open("Creating database: #{DB_PATH}") do
          json_files.each do |json_file|
            table_name = File.basename(json_file, '.json')
            insert_json_file(json_file, table_name)
          end

          # Show summary
          puts ""
          puts ::CLI::UI.fmt("{{v}} Database created successfully")
          puts ::CLI::UI.fmt("{{v}} Location: #{DB_PATH}")
          puts ::CLI::UI.fmt("{{v}} Tables: #{json_files.size}")
        end

        # Set read-optimized SQLite settings for queries (unless skipped or keeping write mode)
        unless skip_optimization || keep_write_mode
          puts ::CLI::UI.fmt("{{i}} Optimizing database for read workloads...")
          self.class.set_read_optimized_settings(DB_PATH)
          puts ::CLI::UI.fmt("{{v}} Database optimization complete")
        end

        0
      end

      private

      def command_exists?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def create_database
        cmd = "sqlite-utils create-database #{DB_PATH}"
        output = `#{cmd} 2>&1`
        status = $?.exitstatus

        if status != 0
          puts ::CLI::UI.fmt("{{x}} Failed to create database")
          puts output if ENV['DEBUG']
          exit 1
        end
      end

      def insert_json_file(json_file, table_name)
        ::CLI::UI::Frame.open("Table: #{table_name}") do
          # Build sqlite-utils command
          # Using --alter to auto-add columns, --detect-types to infer types
          # Using --replace to overwrite existing data
          cmd = [
            'sqlite-utils',
            'insert',
            DB_PATH,
            table_name,
            json_file,
            '--alter',
            '--detect-types',
            '--replace'
          ].join(' ')

          # Execute command
          output = `#{cmd} 2>&1`
          status = $?.exitstatus

          if status == 0
            # Count records in the JSON file
            record_count = count_json_records(json_file)
            puts ::CLI::UI.fmt("{{v}} Inserted #{record_count} records")
          else
            puts ::CLI::UI.fmt("{{x}} Failed to insert data")
            puts output if ENV['DEBUG']
          end
        end
      end

      def count_json_records(json_file)
        require 'json'
        data = JSON.parse(File.read(json_file))
        data.is_a?(Array) ? data.size : 1
      rescue => e
        "unknown"
      end
    end
  end
end
