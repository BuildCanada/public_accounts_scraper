require 'cli/ui'
require 'fileutils'

module PbCli
  module CLI
    def self.start(args)
      if args.empty? || args[0] == 'help'
        print_help
        exit 0
      end

      command = args[0]
      command_args = args[1..-1]

      case command
      when 'scrape'
        require_relative 'pb_cli/commands/scrape'
        Commands::Scrape.new.call(command_args)
      when 'extract'
        require_relative 'pb_cli/commands/extract'
        Commands::Extract.new.call(command_args)
      when 'create-db'
        require_relative 'pb_cli/commands/create_db'
        Commands::CreateDb.new.call(command_args)
      when 'statscan'
        require_relative 'pb_cli/commands/statscan'
        Commands::Statscan.run(command_args)
      when 'initialize'
        require_relative 'pb_cli/commands/initialize'
        Commands::Initialize.new.call(command_args)
      when 'create-inflation-adjusted-tables'
        require_relative 'pb_cli/commands/create_inflation_adjusted_tables'
        Commands::CreateInflationAdjustedTables.new.call(command_args)
      when 'create-metadata'
        require_relative 'pb_cli/commands/create_metadata'
        Commands::CreateMetadata.execute(command_args)
      when 'validate'
        require_relative 'pb_cli/commands/validate'
        Commands::Validate.new.call(command_args)
      when 'create-views'
        require_relative 'pb_cli/commands/create_views'
        Commands::CreateViews.new.call(command_args)
      when 'normalize-descriptions'
        require_relative 'pb_cli/commands/normalize_descriptions'
        Commands::NormalizeDescriptions.new.call(command_args)
      else
        puts "Unknown command: #{command}"
        puts ""
        print_help
        exit 1
      end
    end

    def self.print_help
      puts "pb - Public Accounts CLI"
      puts ""
      puts "Usage:"
      puts "  pb scrape YEARS"
      puts "  pb extract [EXTRACTOR_NAME]"
      puts "  pb create-db"
      puts "  pb statscan download <dataset_name>"
      puts "  pb initialize"
      puts "  pb create-inflation-adjusted-tables"
      puts "  pb normalize-descriptions"
      puts "  pb create-metadata"
      puts "  pb validate [TABLE_NAME]"
      puts "  pb create-views"
      puts ""
      puts "Examples:"
      puts "  pb scrape 2025              # Scrape single year"
      puts "  pb scrape 2021-2025         # Scrape year range"
      puts "  pb scrape 2015,2017,2019-2025  # Scrape multiple years/ranges"
      puts "  pb extract                  # Run all extractors"
      puts "  pb extract major_transfers_by_provinces_and_territories  # Run specific extractor"
      puts "  pb create-db                # Create SQLite database from extracted JSON"
      puts "  pb statscan download cpi_monthly  # Download Statistics Canada CPI data"
      puts "  pb initialize               # Run extract, create-db, and statscan load"
      puts "  pb create-inflation-adjusted-tables  # Create CPI-adjusted views"
      puts "  pb normalize-descriptions   # Normalize transfer payment descriptions across years"
      puts "  pb create-metadata          # Create consolidated metadata.yaml"
      puts "  pb validate                 # Validate all tables in database"
      puts "  pb validate major_transfers_by_provinces_and_territories  # Validate specific table"
      puts "  pb create-views             # Create views from db/views SQL files"
    end
  end
end
