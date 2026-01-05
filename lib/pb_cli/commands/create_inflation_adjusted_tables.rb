require 'cli/ui'
require 'open3'
require 'json'
require 'tempfile'

module PbCli
  module Commands
    class CreateInflationAdjustedTables
      DEFAULT_DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      CPI_TABLE_NAME = 'cpi_inflation_indexes'
      MIN_INDEX_YEAR = 2017

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
      end

      def call(args)
        ::CLI::UI::Frame.open("Creating inflation-adjusted tables") do
          # Step 1: Check prerequisites
          unless check_prerequisites
            return 1
          end

          # Step 2: Extract and process CPI data
          puts ::CLI::UI.fmt("{{*}} Step 1/4: Extracting CPI data")
          cpi_data = extract_cpi_data
          unless cpi_data && cpi_data.size > 0
            puts ::CLI::UI.fmt("{{x}} No CPI data available")
            return 1
          end
          puts ::CLI::UI.fmt("{{v}} Found #{cpi_data.size} CPI records")
          puts ""

          # Step 3: Calculate fiscal year averages
          puts ::CLI::UI.fmt("{{*}} Step 2/4: Calculating fiscal year averages")
          fiscal_year_data = calculate_fiscal_year_averages(cpi_data)
          puts ::CLI::UI.fmt("{{v}} Calculated averages for #{fiscal_year_data.size} fiscal years")
          puts ""

          # Step 4: Detect latest complete year
          puts ::CLI::UI.fmt("{{*}} Step 3/4: Creating CPI reference table")
          latest_year = detect_latest_complete_year(fiscal_year_data)
          unless latest_year
            return 1
          end
          puts ::CLI::UI.fmt("{{v}} Latest complete fiscal year: #{latest_year}")

          # Create CPI reference table
          create_cpi_reference_table(fiscal_year_data, latest_year)
          puts ""

          # Step 5: Create inflation-adjusted views
          puts ::CLI::UI.fmt("{{*}} Step 4/4: Creating inflation-adjusted views")
          tables = get_non_statscan_tables

          if tables.empty?
            puts ::CLI::UI.fmt("{{i}} No non-statscan tables found")
          else
            tables.each do |table_name|
              create_inflation_adjusted_view(table_name, latest_year)
            end
          end
          puts ""

          puts ::CLI::UI.fmt("{{v}} Inflation adjustment complete!")
          puts ::CLI::UI.fmt("{{v}} Database: #{@db_path}")
          puts ::CLI::UI.fmt("{{v}} Reference table: #{CPI_TABLE_NAME}")
          puts ::CLI::UI.fmt("{{v}} Views created: #{tables.size}")
        end

        0
      end

      private

      def check_prerequisites
        # Check database exists
        unless File.exist?(@db_path)
          puts ::CLI::UI.fmt("{{x}} Database not found: #{@db_path}")
          puts "Run 'pb initialize' to create the database"
          return false
        end

        # Check sqlite-utils is installed
        unless command_exists?('sqlite-utils')
          puts ::CLI::UI.fmt("{{x}} sqlite-utils is not installed")
          puts ""
          puts "Install it with:"
          puts "  pip install sqlite-utils"
          puts "  or"
          puts "  brew install sqlite-utils"
          return false
        end

        # Check statscan_cpi_monthly table exists
        sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='statscan_cpi_monthly'"
        output, _, status = Open3.capture3(
          'sqlite-utils', 'query', @db_path, sql, '--csv'
        )

        unless status.success? && output.lines.size > 1
          puts ::CLI::UI.fmt("{{x}} Table 'statscan_cpi_monthly' not found")
          puts "Run 'pb statscan download cpi_monthly' to download CPI data"
          puts "Then run 'pb statscan load cpi_monthly' to load it"
          return false
        end

        true
      end

      def command_exists?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def extract_cpi_data
        sql = <<~SQL
          SELECT REF_DATE, VALUE
          FROM statscan_cpi_monthly
          WHERE GEO='Canada'
            AND UOM='2002=100'
            AND "Products and product groups"='All-items'
          ORDER BY REF_DATE
        SQL

        output, stderr, status = Open3.capture3(
          'sqlite-utils', 'query', @db_path, sql, '--csv'
        )

        unless status.success?
          puts ::CLI::UI.fmt("{{x}} Error querying CPI data")
          puts stderr if ENV['DEBUG']
          return nil
        end

        # Parse CSV output
        lines = output.lines
        return [] if lines.size <= 1 # Only header or empty

        cpi_data = []
        lines[1..-1].each do |line|
          next if line.strip.empty?
          ref_date, value = line.strip.split(',')
          cpi_data << { ref_date: ref_date, value: value.to_f }
        end

        cpi_data
      end

      def calculate_fiscal_year_averages(cpi_data)
        # Group by fiscal year
        # FY 2017 = 2016-04 through 2017-03
        fiscal_years = {}

        cpi_data.each do |record|
          # Parse YYYY-MM format
          year, month = record[:ref_date].split('-').map(&:to_i)

          # Determine fiscal year
          fiscal_year = if month >= 4
            year + 1  # April 2016 belongs to FY 2017
          else
            year      # March 2017 belongs to FY 2017
          end

          fiscal_years[fiscal_year] ||= { values: [], months: [] }
          fiscal_years[fiscal_year][:values] << record[:value]
          fiscal_years[fiscal_year][:months] << "#{year}-#{month.to_s.rjust(2, '0')}"
        end

        # Calculate averages
        fiscal_years.transform_values do |data|
          {
            avg_cpi: data[:values].sum / data[:values].size.to_f,
            months_count: data[:values].size,
            months: data[:months].sort
          }
        end
      end

      def detect_latest_complete_year(fiscal_year_data)
        # Find latest fiscal year with at least 11 months of data
        complete_years = fiscal_year_data.select { |year, data| data[:months_count] >= 11 }

        if complete_years.empty?
          puts ::CLI::UI.fmt("{{x}} No fiscal year has at least 11 months of CPI data")
          return nil
        end

        complete_years.keys.max
      end

      def create_cpi_reference_table(fiscal_year_data, latest_year)
        ::CLI::UI::Frame.open("Creating CPI reference table") do
          # Drop existing table if it exists
          drop_sql = "DROP TABLE IF EXISTS #{CPI_TABLE_NAME}"
          execute_query(drop_sql)

          # Calculate index columns (from MIN_INDEX_YEAR to latest_year)
          index_years = (MIN_INDEX_YEAR..latest_year).to_a
          records = calculate_index_columns(fiscal_year_data, index_years)

          # Insert data using sqlite-utils
          insert_cpi_reference_data(records)

          puts ::CLI::UI.fmt("{{v}} Created table: #{CPI_TABLE_NAME}")
          puts ::CLI::UI.fmt("{{v}} Fiscal years: #{records.size}")
          puts ::CLI::UI.fmt("{{v}} Index columns: #{index_years.size} (#{MIN_INDEX_YEAR}-#{latest_year})")
        end
      end

      def calculate_index_columns(fiscal_year_data, index_years)
        records = []

        fiscal_year_data.each do |fiscal_year, data|
          record = {
            'fiscal_year' => fiscal_year,
            'avg_cpi' => data[:avg_cpi].round(2),
            'months_count' => data[:months_count]
          }

          # Calculate index for each target year
          # index_YYYY = target_year_avg_cpi / this_year_avg_cpi
          index_years.each do |target_year|
            next unless fiscal_year_data[target_year]

            target_avg_cpi = fiscal_year_data[target_year][:avg_cpi]
            index_value = target_avg_cpi / data[:avg_cpi]

            record["index_#{target_year}"] = index_value.round(4)
          end

          records << record
        end

        records.sort_by { |r| r['fiscal_year'] }
      end

      def insert_cpi_reference_data(records)
        # Write records to temporary JSON file
        temp_file = Tempfile.new(['cpi_indexes', '.json'])
        begin
          temp_file.write(JSON.pretty_generate(records))
          temp_file.close

          # Use sqlite-utils to insert
          cmd = [
            'sqlite-utils', 'insert',
            @db_path,
            CPI_TABLE_NAME,
            temp_file.path,
            '--alter',
            '--pk=fiscal_year',
            '--replace'
          ]

          stdout, stderr, status = Open3.capture3(*cmd)

          unless status.success?
            puts ::CLI::UI.fmt("{{x}} Failed to insert CPI reference data")
            puts stderr if ENV['DEBUG']
            exit 1
          end
        ensure
          temp_file.unlink
        end
      end

      def get_non_statscan_tables
        sql = <<~SQL
          SELECT name
          FROM sqlite_master
          WHERE type='table'
            AND name NOT LIKE 'statscan_%'
            AND name NOT LIKE 'sqlite_%'
            AND name != '#{CPI_TABLE_NAME}'
          ORDER BY name
        SQL

        output, stderr, status = Open3.capture3(
          'sqlite-utils', 'query', @db_path, sql, '--csv'
        )

        unless status.success?
          puts ::CLI::UI.fmt("{{x}} Error getting table list")
          return []
        end

        # Parse table names from CSV output
        lines = output.lines[1..-1] # Skip header
        return [] if lines.nil?

        lines.map { |line| line.strip }.reject(&:empty?)
      end

      def create_inflation_adjusted_view(table_name, latest_year)
        ::CLI::UI::Frame.open("Creating view for: #{table_name}") do
          monetary_columns = get_monetary_columns(table_name)

          if monetary_columns.empty?
            puts ::CLI::UI.fmt("{{i}} No monetary columns found")
            return
          end

          view_sql = generate_view_sql(table_name, monetary_columns, latest_year)

          # Drop existing view if it exists
          drop_view_sql = "DROP VIEW IF EXISTS #{table_name}_inflation_adjusted"
          execute_query(drop_view_sql)

          # Create view
          execute_query(view_sql)

          puts ::CLI::UI.fmt("{{v}} Created view: #{table_name}_inflation_adjusted")
          puts ::CLI::UI.fmt("{{v}} Adjusted columns: #{monetary_columns.size}")
          puts ::CLI::UI.fmt("{{v}} Target year: #{latest_year}")
        end
      end

      def get_monetary_columns(table_name)
        # Get table schema using PRAGMA
        pragma_sql = "PRAGMA table_info(#{table_name})"
        pragma_output, _, pragma_status = Open3.capture3(
          'sqlite-utils', 'query', @db_path, pragma_sql, '--csv'
        )

        return [] unless pragma_status.success?

        # Parse CSV: cid,name,type,notnull,dflt_value,pk
        non_monetary = ['year', 'source_year', 'position', 'is_total_or_subtotal']
        monetary_columns = []

        pragma_output.lines[1..-1].each do |line|
          next if line.strip.empty?
          parts = line.strip.split(',')
          col_name = parts[1]
          col_type = parts[2]

          if col_type == 'FLOAT' && !non_monetary.include?(col_name)
            monetary_columns << col_name
          end
        end

        monetary_columns
      end

      def generate_view_sql(table_name, monetary_columns, latest_year)
        index_column = "index_#{latest_year}"

        # Get all columns from the base table
        schema_output, _, _ = Open3.capture3(
          'sqlite-utils', 'query', @db_path,
          "PRAGMA table_info(#{table_name})", '--csv'
        )

        all_columns = []
        schema_output.lines[1..-1].each do |line|
          next if line.strip.empty?
          col_name = line.split(',')[1]
          all_columns << col_name
        end

        # Build SELECT for each column, excluding source_year
        select_parts = all_columns.reject { |col| col == 'source_year' }.map do |col|
          if monetary_columns.include?(col)
            # Multiply monetary columns by inflation index
            # Handle NULL values gracefully
            "CASE WHEN base.#{col} IS NOT NULL THEN base.#{col} * cpi.#{index_column} ELSE NULL END AS #{col}"
          else
            # Pass through non-monetary columns
            "base.#{col}"
          end
        end

        # Generate VIEW SQL with filter for most recent source_year per fiscal year
        # For each fiscal year, only include data from the most recent source_year
        # that contains that year (e.g., if FY 2023 appears in both 2023 and 2024
        # Public Accounts, only use the 2024 version with updated numbers)
        # Exception: FY 2018 uses source_year 2018 (not 2019) due to data quality
        <<~SQL
          CREATE VIEW #{table_name}_inflation_adjusted AS
          SELECT
            #{select_parts.join(",\n    ")}
          FROM #{table_name} AS base
          LEFT JOIN #{CPI_TABLE_NAME} AS cpi
            ON base.year = cpi.fiscal_year
          WHERE (base.year, base.source_year) IN (
            SELECT
              year,
              CASE
                WHEN year = 2018 THEN 2018
                ELSE MAX(source_year)
              END as source_year
            FROM #{table_name}
            GROUP BY year
          )
        SQL
      end

      def execute_query(sql)
        stdout, stderr, status = Open3.capture3(
          'sqlite-utils', 'query', @db_path, sql
        )

        unless status.success?
          puts ::CLI::UI.fmt("{{x}} SQL execution failed")
          puts stderr if ENV['DEBUG']
          exit 1
        end

        stdout
      end
    end
  end
end
