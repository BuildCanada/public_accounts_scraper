require_relative 'base'

module PbCli
  module Extractors
    class MajorTransfersByProvincesAndTerritories < Base
      def extractor_name
        'major_transfers_by_provinces_and_territories'
      end

      def extract
        all_records = []

        # Find all charges-expenses files (2013 onwards, skip 2012)
        html_files = find_html_files('**/vol1/s3/charges-expenses-eng.html')

        html_files.each do |filepath|
          source_year = year_from_path(filepath)

          # Skip 2012 as it has different structure
          next if source_year && source_year < 2013

          records = extract_from_file(filepath, source_year)
          all_records.concat(records) if records
        end

        # Sort by source_year, then fiscal year, then province
        all_records.sort_by! { |r| [r[:source_year], r[:year], r[:province_territory]] }

        # Export JSON
        json_path = export_json(all_records, "#{extractor_name}.json")

        # Export metadata
        metadata = generate_metadata(all_records)
        yaml_path = export_metadata(metadata, "#{extractor_name}.yaml")

        { json_path: json_path, yaml_path: yaml_path, record_count: all_records.size }
      end

      private

      def extract_from_file(filepath, source_year)
        return nil unless File.exist?(filepath)

        doc = Nokogiri::HTML(File.read(filepath))

        # Find table 3.7
        table = doc.at_css('table#t3\.7')
        return nil unless table

        records = []
        current_province = nil

        # Get column headers
        headers = extract_headers(table)

        # Process each row in tbody
        table.css('tbody tr').each do |row|
          # Check if this row has a province/territory name (rowspan cell)
          province_cell = row.at_css('th[rowspan]')
          if province_cell
            current_province = province_cell.text.strip
          end

          # Skip if we don't have a province
          next unless current_province

          # Extract fiscal year
          year_cell = row.at_css('th:not([rowspan])')
          next unless year_cell

          fiscal_year = year_cell.text.strip.to_i
          next if fiscal_year == 0

          # Extract all numeric data cells
          data_cells = row.css('td.num')

          # Build record
          record = {
            source_year: source_year,
            year: fiscal_year,
            province_territory: current_province
          }

          # Add all column values
          data_cells.each_with_index do |cell, index|
            next if index >= headers.size

            column_name = headers[index]
            value = parse_numeric(cell.text)
            record[column_name.to_sym] = value
          end

          records << record
        end

        records
      end

      def extract_headers(table)
        headers = []

        # Find header row
        header_row = table.at_css('thead tr')
        return headers unless header_row

        # Get all th elements except the first two (Province and Fiscal year)
        header_cells = header_row.css('th')

        # Skip first two columns (Province/Territory and Fiscal year)
        header_cells.drop(2).each do |th|
          # Get text content, removing footnote links
          header_text = th.text.strip

          # Remove footnote references (e.g., "Link to footnote 6", "Link to table note 8")
          header_text = header_text.gsub(/Link to (footnote|table note|Footnote) \d+/, '')
                                   .gsub(/Links to (footnote|table note|Footnote) \d+ in .*/, '')
                                   .gsub(/\d+$/, '')  # Remove trailing numbers
                                   .strip

          normalized = normalize_column_name(header_text)
          headers << normalized unless normalized.empty?
        end

        headers
      end

      def generate_metadata(records)
        # Get all unique column names from records
        all_columns = records.flat_map(&:keys).uniq

        # Build columns metadata
        columns_metadata = {
          'source_year' => 'Year of the Public Accounts document',
          'year' => 'Fiscal year of the data',
          'province_territory' => 'Province or territory name'
        }

        # Add descriptions for transfer columns
        transfer_columns = all_columns - [:source_year, :year, :province_territory]
        transfer_columns.each do |col|
          readable_name = col.to_s.split('_').map(&:capitalize).join(' ')
          columns_metadata[col.to_s] = "#{readable_name} (millions of dollars)"
        end

        {
          'databases' => {
            'federal_transfers' => {
              'tables' => {
                extractor_name => {
                  'title' => 'Major Transfer Payments by Province and Territory',
                  'description_html' => "Major transfer payments to provinces and territories from the\nPublic Accounts of Canada (Table 3.7). Data extracted from\nVolume 1, Section 3 (charges-expenses-eng.html) for fiscal years 2013 onwards.\nValues are in millions of dollars.",
                  'source' => 'Public Accounts of Canada',
                  'source_url' => 'https://www.tpsgc-pwgsc.gc.ca/recgen/cpc-pac/index-eng.html',
                  'license' => 'Open Government License - Canada',
                  'license_url' => 'https://open.canada.ca/en/open-government-licence-canada',
                  'columns' => columns_metadata
                }
              }
            }
          }
        }
      end
    end
  end
end
