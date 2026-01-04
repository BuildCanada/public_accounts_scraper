require 'csv'

module PbCli
  class StatscanMetadataParser
    def initialize(csv_path)
      @csv_path = csv_path
      @rows = CSV.read(csv_path, headers: false, liberal_parsing: true)
    end

    # Parses statscan CSV metadata and returns Datasette-format metadata hash
    def parse
      # Extract cube metadata from row 2 (index 1)
      cube_title = @rows[1][0]
      cube_url = @rows[1][3]
      frequency = @rows[1][6]
      start_date = @rows[1][7]
      end_date = @rows[1][8]

      # Extract dimensions starting from row 5 (index 4)
      dimensions = []
      dimension_idx = 4
      while dimension_idx < @rows.length && !@rows[dimension_idx][0].to_s.empty?
        dimension_name = @rows[dimension_idx][1]
        break if dimension_name.to_s.empty?
        dimensions << dimension_name
        dimension_idx += 1
      end

      # Extract notes from the bottom section
      notes = extract_notes

      # Build description
      description_parts = []
      description_parts << cube_title
      description_parts << ""
      description_parts << "Frequency: #{frequency}"
      description_parts << "Coverage: #{start_date} to #{end_date}"
      description_parts << ""
      description_parts << "Dimensions: #{dimensions.join(', ')}"

      if notes.any?
        description_parts << ""
        description_parts << "Notes:"
        notes.each do |note_id, note_text|
          description_parts << "- #{note_text}"
        end
      end

      # Build column descriptions
      columns = build_column_descriptions(dimensions)

      {
        title: cube_title,
        description_html: description_parts.join("\n"),
        source: "Statistics Canada",
        source_url: cube_url,
        license: "Statistics Canada Open License",
        license_url: "https://www.statcan.gc.ca/en/reference/licence",
        columns: columns
      }
    end

    private

    def extract_notes
      notes = {}

      # Find the "Note ID" section
      note_section_idx = @rows.find_index { |row| row[0] == "Note ID" }
      return notes unless note_section_idx

      # Parse notes starting from the next row
      idx = note_section_idx + 1
      while idx < @rows.length
        note_id = @rows[idx][0]
        note_text = @rows[idx][1]
        break if note_id.to_s.empty?

        # Clean up HTML tags and extra whitespace from notes
        clean_text = note_text.to_s.gsub(/<[^>]+>/, '').strip
        notes[note_id] = clean_text unless clean_text.empty?

        idx += 1
      end

      notes
    end

    def build_column_descriptions(dimensions)
      columns = {}

      # Standard statscan columns
      columns["REF_DATE"] = "Reference date for the data point"
      columns["GEO"] = "Geographic location"
      columns["DGUID"] = "Unique identifier for the geographic location"

      # Dimension columns (dynamic based on the dataset)
      dimensions.each do |dim|
        columns[dim] = dim  # Use dimension name as description
      end

      # Standard measurement columns
      columns["UOM"] = "Unit of measure"
      columns["UOM_ID"] = "Unit of measure identifier"
      columns["SCALAR_FACTOR"] = "Scalar factor (e.g., thousands, millions)"
      columns["SCALAR_ID"] = "Scalar factor identifier"
      columns["VECTOR"] = "StatsCan vector identifier"
      columns["COORDINATE"] = "Coordinate value"
      columns["VALUE"] = "The measured value"
      columns["STATUS"] = "Status of the data point"
      columns["SYMBOL"] = "Symbol identifier for data quality or notes"
      columns["TERMINATED"] = "Whether this series has been terminated"
      columns["DECIMALS"] = "Number of decimal places"

      columns
    end
  end
end
