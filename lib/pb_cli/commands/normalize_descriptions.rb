require 'cli/ui'
require 'open3'
require 'json'

module PbCli
  module Commands
    class NormalizeDescriptions
      DEFAULT_DB_PATH = File.join(Dir.pwd, 'public_accounts.db')
      SOURCE_TABLE = 'transfer_payments_by_ministry'
      ITEMS_TABLE = 'transfer_payment_items'
      NORMALIZED_VIEW = 'transfer_payments_by_ministry_normalized'

      def initialize(paths = {})
        @db_path = paths[:db_path] || DEFAULT_DB_PATH
      end

      def call(args)
        # Check if this is just an update to add inflation-adjusted view
        if args.include?('--update-inflation-view')
          return update_inflation_adjusted_view
        end

        ::CLI::UI::Frame.open("Normalizing transfer payment descriptions") do
          # Step 1: Check prerequisites
          unless check_prerequisites
            return 1
          end

          # Step 2: Load all records
          puts ::CLI::UI.fmt("{{*}} Step 1/4: Loading transfer payment records")
          records = load_records
          unless records && records.size > 0
            puts ::CLI::UI.fmt("{{x}} No transfer payment records found")
            return 1
          end
          puts ::CLI::UI.fmt("{{v}} Loaded #{records.size} records")
          puts ""

          # Step 3: Build item chains
          puts ::CLI::UI.fmt("{{*}} Step 2/4: Building item chains across years")
          items = build_item_chains(records)
          puts ::CLI::UI.fmt("{{v}} Identified #{items.size} unique transfer items")
          puts ""

          # Step 4: Create reference table
          puts ::CLI::UI.fmt("{{*}} Step 3/4: Creating reference table")
          create_items_table(items)
          puts ::CLI::UI.fmt("{{v}} Created #{ITEMS_TABLE} table")
          puts ""

          # Step 5: Create normalized view
          puts ::CLI::UI.fmt("{{*}} Step 4/4: Creating normalized view")
          create_normalized_view
          puts ::CLI::UI.fmt("{{v}} Created #{NORMALIZED_VIEW} view")
          puts ""

          # Summary statistics
          print_summary(items)

          puts ::CLI::UI.fmt("{{v}} Description normalization complete!")
        end

        0
      end

      # Called after inflation adjustment to add the inflation-adjusted normalized view
      def update_inflation_adjusted_view
        unless File.exist?(@db_path)
          return 1
        end

        inflation_table = "#{SOURCE_TABLE}_inflation_adjusted"
        table_exists = execute_sql(
          "SELECT COUNT(*) FROM sqlite_master WHERE type='view' AND name='#{inflation_table}'"
        )

        if table_exists&.strip == '1'
          execute_sql("DROP VIEW IF EXISTS #{NORMALIZED_VIEW}_inflation_adjusted")

          inflation_view_sql = <<~SQL
            CREATE VIEW #{NORMALIZED_VIEW}_inflation_adjusted AS
            SELECT
              t.*,
              m.transfer_item_id,
              i.description_normalized
            FROM #{inflation_table} t
            LEFT JOIN transfer_payment_item_mapping m
              ON t.year = m.year
              AND t.ministry_code = m.ministry_code
              AND t.description = m.description
              AND (t.position = m.position OR (t.position IS NULL AND m.position IS NULL))
            LEFT JOIN #{ITEMS_TABLE} i ON m.transfer_item_id = i.transfer_item_id
          SQL
          execute_sql(inflation_view_sql)
          puts ::CLI::UI.fmt("{{v}} Created #{NORMALIZED_VIEW}_inflation_adjusted view")
        end

        0
      end

      private

      def check_prerequisites
        unless File.exist?(@db_path)
          puts ::CLI::UI.fmt("{{x}} Database not found: #{@db_path}")
          puts "Run 'pb initialize' to create the database"
          return false
        end

        unless command_exists?('sqlite3')
          puts ::CLI::UI.fmt("{{x}} sqlite3 is not installed")
          return false
        end

        # Check source table exists
        result = execute_sql("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='#{SOURCE_TABLE}'")
        if result.strip != '1'
          puts ::CLI::UI.fmt("{{x}} Source table #{SOURCE_TABLE} not found")
          puts "Run extraction first: pb extract transfer_payments_by_ministry"
          return false
        end

        true
      end

      def load_records
        sql = <<~SQL
          SELECT
            rowid,
            year,
            ministry_code,
            ministry_name_normalized,
            category,
            description,
            position,
            is_total_or_subtotal,
            used_in_current_year,
            used_in_previous_year
          FROM #{SOURCE_TABLE}
          WHERE is_total_or_subtotal = 0
          ORDER BY year, ministry_code, category, description
        SQL

        result = execute_sql(sql, format: :json)
        return nil if result.nil? || result.empty?

        JSON.parse(result)
      end

      def build_item_chains(records)
        # Group records by year
        by_year = records.group_by { |r| r['year'] }
        years = by_year.keys.sort

        # Track items: rowid -> transfer_item_id
        rowid_to_item = {}
        # Track item metadata
        items = {}
        next_item_id = 1

        years.each do |year|
          year_records = by_year[year] || []

          if year == years.first
            # First year: each record is a new item
            year_records.each do |record|
              item_id = next_item_id
              next_item_id += 1

              rowid_to_item[record['rowid']] = item_id
              items[item_id] = {
                id: item_id,
                descriptions: [record['description']],
                categories: [record['category']],
                ministry_codes: [record['ministry_code']],
                ministry_names: [record['ministry_name_normalized']],
                first_year: year,
                last_year: year,
                years: [year]
              }
            end
          else
            # Subsequent years: try to match to previous year
            prev_year = years[years.index(year) - 1]
            prev_records = by_year[prev_year] || []

            # Build lookup for previous year: key -> record
            prev_lookup = build_lookup(prev_records, rowid_to_item)

            year_records.each do |record|
              matched_item_id = find_matching_item(record, prev_lookup, rowid_to_item)

              if matched_item_id
                # Extend existing item
                rowid_to_item[record['rowid']] = matched_item_id
                item = items[matched_item_id]
                item[:descriptions] << record['description'] unless item[:descriptions].include?(record['description'])
                item[:categories] << record['category'] unless item[:categories].include?(record['category'])
                item[:ministry_codes] << record['ministry_code'] unless item[:ministry_codes].include?(record['ministry_code'])
                item[:ministry_names] << record['ministry_name_normalized'] unless item[:ministry_names].include?(record['ministry_name_normalized'])
                item[:last_year] = year
                item[:years] << year
              else
                # New item
                item_id = next_item_id
                next_item_id += 1

                rowid_to_item[record['rowid']] = item_id
                items[item_id] = {
                  id: item_id,
                  descriptions: [record['description']],
                  categories: [record['category']],
                  ministry_codes: [record['ministry_code']],
                  ministry_names: [record['ministry_name_normalized']],
                  first_year: year,
                  last_year: year,
                  years: [year]
                }
              end
            end
          end
        end

        # Build record -> item mapping for the mapping table
        @record_to_item = {}
        records.each do |record|
          item_id = rowid_to_item[record['rowid']]
          @record_to_item[record] = item_id if item_id
        end

        items.values
      end

      def build_lookup(records, rowid_to_item)
        # Build lookup by (ministry_name_normalized, category, used_in_current_year)
        lookup = {}
        records.each do |record|
          # Skip zero values to avoid false matches
          used = record['used_in_current_year']
          next if used.nil? || used == 0

          key = [
            record['ministry_name_normalized'],
            record['category'],
            used.to_f.round(2)
          ]
          lookup[key] = {
            record: record,
            item_id: rowid_to_item[record['rowid']]
          }
        end
        lookup
      end

      def find_matching_item(record, prev_lookup, rowid_to_item)
        # Try to match using used_in_previous_year
        used_prev = record['used_in_previous_year']
        return nil if used_prev.nil? || used_prev == 0

        # Look for matching record in previous year
        key = [
          record['ministry_name_normalized'],
          record['category'],
          used_prev.to_f.round(2)
        ]

        match = prev_lookup[key]
        return match[:item_id] if match

        # Try matching across ministries (for reorgs) - same category and amount
        # This is more permissive - match by category and amount only
        prev_lookup.each do |k, v|
          if k[1] == record['category'] && k[2] == used_prev.to_f.round(2)
            return v[:item_id]
          end
        end

        nil
      end

      def create_items_table(items)
        # Drop existing table
        execute_sql("DROP TABLE IF EXISTS #{ITEMS_TABLE}")

        # Create table
        create_sql = <<~SQL
          CREATE TABLE #{ITEMS_TABLE} (
            transfer_item_id INTEGER PRIMARY KEY,
            description_normalized TEXT NOT NULL,
            category TEXT,
            first_year INTEGER NOT NULL,
            last_year INTEGER NOT NULL,
            year_count INTEGER NOT NULL,
            ministry_codes TEXT,
            ministry_names TEXT,
            description_variations TEXT
          )
        SQL
        execute_sql(create_sql)

        # Insert data
        items.each do |item|
          # Use most recent description as normalized
          description_normalized = item[:descriptions].last
          category = item[:categories].last

          insert_sql = <<~SQL
            INSERT INTO #{ITEMS_TABLE} (
              transfer_item_id,
              description_normalized,
              category,
              first_year,
              last_year,
              year_count,
              ministry_codes,
              ministry_names,
              description_variations
            ) VALUES (
              #{item[:id]},
              '#{escape_sql(description_normalized)}',
              #{item[:categories].compact.empty? ? 'NULL' : "'#{escape_sql(category)}'"},
              #{item[:first_year]},
              #{item[:last_year]},
              #{item[:years].size},
              '#{escape_sql(item[:ministry_codes].uniq.to_json)}',
              '#{escape_sql(item[:ministry_names].compact.uniq.to_json)}',
              '#{escape_sql(item[:descriptions].uniq.to_json)}'
            )
          SQL
          execute_sql(insert_sql)
        end

        # Create mapping table using natural key columns (works with views too)
        execute_sql("DROP TABLE IF EXISTS transfer_payment_item_mapping")
        execute_sql(<<~SQL)
          CREATE TABLE transfer_payment_item_mapping (
            year INTEGER NOT NULL,
            ministry_code TEXT NOT NULL,
            description TEXT NOT NULL,
            position INTEGER,
            transfer_item_id INTEGER NOT NULL,
            PRIMARY KEY (year, ministry_code, description, position),
            FOREIGN KEY (transfer_item_id) REFERENCES #{ITEMS_TABLE}(transfer_item_id)
          )
        SQL

        # Build mapping from records
        @record_to_item.each do |record, item_id|
          insert_sql = <<~SQL
            INSERT OR IGNORE INTO transfer_payment_item_mapping VALUES (
              #{record['year']},
              '#{escape_sql(record['ministry_code'])}',
              '#{escape_sql(record['description'])}',
              #{record['position'] || 'NULL'},
              #{item_id}
            )
          SQL
          execute_sql(insert_sql)
        end
      end

      def create_normalized_view
        # Drop existing view
        execute_sql("DROP VIEW IF EXISTS #{NORMALIZED_VIEW}")

        # Create view joining source table with items using natural key
        view_sql = <<~SQL
          CREATE VIEW #{NORMALIZED_VIEW} AS
          SELECT
            t.*,
            m.transfer_item_id,
            i.description_normalized
          FROM #{SOURCE_TABLE} t
          LEFT JOIN transfer_payment_item_mapping m
            ON t.year = m.year
            AND t.ministry_code = m.ministry_code
            AND t.description = m.description
            AND (t.position = m.position OR (t.position IS NULL AND m.position IS NULL))
          LEFT JOIN #{ITEMS_TABLE} i ON m.transfer_item_id = i.transfer_item_id
        SQL
        execute_sql(view_sql)
      end

      def print_summary(items)
        multi_year = items.count { |i| i[:years].size > 1 }
        multi_desc = items.count { |i| i[:descriptions].uniq.size > 1 }
        multi_ministry = items.count { |i| i[:ministry_codes].uniq.size > 1 }

        avg_years = items.map { |i| i[:years].size }.sum.to_f / items.size

        puts ::CLI::UI.fmt("{{i}} Summary:")
        puts ::CLI::UI.fmt("  - Total unique items: #{items.size}")
        puts ::CLI::UI.fmt("  - Items spanning multiple years: #{multi_year}")
        puts ::CLI::UI.fmt("  - Items with description variations: #{multi_desc}")
        puts ::CLI::UI.fmt("  - Items that moved between ministries: #{multi_ministry}")
        puts ::CLI::UI.fmt("  - Average years per item: #{'%.1f' % avg_years}")
        puts ""
      end

      def escape_sql(str)
        return '' if str.nil?
        str.to_s.gsub("'", "''")
      end

      def execute_sql(sql, format: nil)
        cmd = if format == :json
                "sqlite3 -json '#{@db_path}'"
              else
                "sqlite3 '#{@db_path}'"
              end

        stdout, stderr, status = Open3.capture3(cmd, stdin_data: sql)

        unless status.success?
          puts ::CLI::UI.fmt("{{x}} SQL error: #{stderr}") unless stderr.empty?
          return nil
        end

        stdout
      end

      def command_exists?(command)
        system("which #{command} > /dev/null 2>&1")
      end
    end
  end
end
