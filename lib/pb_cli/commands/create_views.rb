require 'cli/ui'
require 'fileutils'

module PbCli
  module Commands
    class CreateViews
      DEFAULT_DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      DEFAULT_VIEWS_DIR = File.join(Dir.pwd, 'db', 'views')

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
        @views_dir = paths[:views_dir] || DEFAULT_VIEWS_DIR
      end

      def call(args)
        # Check if sqlite3 is available
        unless command_exists?('sqlite3')
          puts ::CLI::UI.fmt("{{x}} Error: sqlite3 is not installed")
          return 1
        end

        # Check if database exists
        unless File.exist?(@db_path)
          puts ::CLI::UI.fmt("{{x}} Error: Database not found at #{@db_path}")
          puts "Run 'pb create-db' first to create the database"
          return 1
        end

        # Check if views directory exists
        unless Dir.exist?(@views_dir)
          puts ::CLI::UI.fmt("{{x}} Error: Views directory not found at #{@views_dir}")
          return 1
        end

        # Find all SQL files
        sql_files = Dir.glob(File.join(@views_dir, '**', '*.sql'))

        if sql_files.empty?
          puts ::CLI::UI.fmt("{{i}} No SQL files found in #{@views_dir}")
          return 0
        end

        # Process each SQL file
        ::CLI::UI::Frame.open("Creating views in: #{@db_path}") do
          created_count = 0
          failed_count = 0

          sql_files.each do |sql_file|
            view_name = derive_view_name(sql_file)
            result = create_view(sql_file, view_name)

            if result
              created_count += 1
            else
              failed_count += 1
            end
          end

          # Show summary
          puts ""
          if failed_count == 0
            puts ::CLI::UI.fmt("{{v}} Created #{created_count} view(s) successfully")
          else
            puts ::CLI::UI.fmt("{{x}} Created #{created_count} view(s), #{failed_count} failed")
          end
        end

        0
      end

      private

      def command_exists?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def derive_view_name(sql_file)
        # Get relative path from views directory
        relative_path = sql_file.sub(@views_dir + '/', '')

        # Remove .sql extension
        relative_path = relative_path.sub(/\.sql$/, '')

        # Replace path separators with underscores
        view_name = relative_path.gsub('/', '_')

        view_name
      end

      def create_view(sql_file, view_name)
        # Read the raw SQL query
        query = File.read(sql_file).strip

        # Wrap in CREATE VIEW IF NOT EXISTS
        create_view_sql = "CREATE VIEW IF NOT EXISTS \"#{view_name}\" AS\n#{query}"

        # Remove trailing semicolon from query if present (we'll add our own)
        create_view_sql = create_view_sql.chomp(';')

        # Execute via sqlite3
        # Use a heredoc to pass the SQL safely
        cmd = "sqlite3 '#{@db_path}'"

        IO.popen(cmd, 'w') do |io|
          io.puts create_view_sql + ';'
        end

        status = $?.exitstatus

        if status == 0
          puts ::CLI::UI.fmt("{{v}} #{view_name}")
          true
        else
          puts ::CLI::UI.fmt("{{x}} #{view_name} - failed")
          puts "SQL file: #{sql_file}" if ENV['DEBUG']
          false
        end
      end
    end
  end
end
