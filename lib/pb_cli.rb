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
      puts ""
      puts "Examples:"
      puts "  pb scrape 2025              # Scrape single year"
      puts "  pb scrape 2021-2025         # Scrape year range"
      puts "  pb scrape 2015,2017,2019-2025  # Scrape multiple years/ranges"
      puts "  pb extract                  # Run all extractors"
      puts "  pb extract major_transfers_by_provinces_and_territories  # Run specific extractor"
    end
  end
end
