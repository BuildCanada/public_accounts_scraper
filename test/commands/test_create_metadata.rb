require 'test_helper'
require 'pb_cli/commands/create_metadata'
require 'yaml'
require 'csv'
require 'fileutils'

class TestCreateMetadata < Minitest::Test
  def setup
    @test_dir = './test_metadata_temp'
    @original_dir = Dir.pwd

    # Create test directory structure
    FileUtils.mkdir_p(@test_dir)
    FileUtils.mkdir_p(File.join(@test_dir, 'extracted/metadata'))
    FileUtils.mkdir_p(File.join(@test_dir, 'statscan/metadata/test_dataset'))

    # Change to test directory
    Dir.chdir(@test_dir)

    # Create test base metadata
    base_metadata = {
      'title' => 'Test Database',
      'description' => 'Test database description',
      'license' => 'Test License',
      'license_url' => 'https://example.com/license',
      'source' => 'Test Source',
      'source_url' => 'https://example.com/source'
    }
    File.write('metadata.base.yaml', YAML.dump(base_metadata))

    # Create test extracted metadata
    extracted_metadata = {
      'databases' => {
        'public_accounts' => {
          'tables' => {
            'test_table' => {
              'title' => 'Test Table',
              'description_html' => 'Test table description',
              'source' => 'Test Source',
              'source_url' => 'https://example.com',
              'license' => 'Test License',
              'license_url' => 'https://example.com/license',
              'columns' => {
                'column1' => 'Column 1 description',
                'column2' => 'Column 2 description'
              }
            }
          }
        }
      }
    }
    File.write('extracted/metadata/test_table.yaml', YAML.dump(extracted_metadata))

    # Create test statscan metadata CSV
    create_test_statscan_csv
  end

  def teardown
    # Change back to original directory
    Dir.chdir(@original_dir)

    # Clean up test directory
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_creates_metadata_yaml_file
    PbCli::Commands::CreateMetadata.execute([])

    assert File.exist?('metadata.yaml'), "metadata.yaml should be created"
  end

  def test_includes_base_metadata_at_top_level
    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')

    assert_equal 'Test Database', metadata['title']
    assert_equal 'Test database description', metadata['description']
    assert_equal 'Test License', metadata['license']
    assert_equal 'https://example.com/license', metadata['license_url']
    assert_equal 'Test Source', metadata['source']
    assert_equal 'https://example.com/source', metadata['source_url']
  end

  def test_includes_extracted_table_metadata
    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')
    table = metadata['databases']['public_accounts']['tables']['test_table']

    assert_equal 'Test Table', table['title']
    assert_equal 'Test table description', table['description_html']
    assert table['columns'], "Columns should be present"
    assert_equal 'Column 1 description', table['columns']['column1']
  end

  def test_includes_statscan_table_metadata
    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')
    table = metadata['databases']['public_accounts']['tables']['statscan_test_dataset']

    assert_equal 'Test Dataset Title', table['title']
    assert_equal 'Statistics Canada', table['source']
    assert table['description_html'].include?('Monthly'), "Description should include frequency"
    assert table['columns'], "Columns should be present"
    assert table['columns']['REF_DATE'], "Standard statscan columns should be present"
  end

  def test_base_metadata_appears_before_databases
    PbCli::Commands::CreateMetadata.execute([])

    # Read the YAML file as text to check ordering
    yaml_content = File.read('metadata.yaml')

    # Find positions of key elements
    title_pos = yaml_content.index('title: Test Database')
    databases_pos = yaml_content.index('databases:')

    assert title_pos < databases_pos, "Base metadata should appear before databases in the file"
  end

  def test_handles_missing_base_metadata
    # Remove base metadata file
    FileUtils.rm('metadata.base.yaml')

    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')
    assert metadata['databases']['public_accounts']['tables'], "Should still create tables even without base metadata"
  end

  def test_handles_missing_extracted_metadata
    # Remove extracted metadata directory
    FileUtils.rm_rf('extracted')

    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')
    assert metadata['databases']['public_accounts'], "Should still create database structure"
  end

  def test_handles_missing_statscan_metadata
    # Remove statscan metadata directory
    FileUtils.rm_rf('statscan')

    PbCli::Commands::CreateMetadata.execute([])

    metadata = YAML.load_file('metadata.yaml')
    assert metadata['databases']['public_accounts'], "Should still create database structure"
  end

  private

  def create_test_statscan_csv
    csv_path = 'statscan/metadata/test_dataset/test_dataset_metadata.csv'

    CSV.open(csv_path, 'w') do |csv|
      # Header row
      csv << ['Cube Title', 'Product Id', 'CANSIM Id', 'URL', 'Cube Notes', 'Archive Status', 'Frequency', 'Start Reference Period', 'End Reference Period', 'Total number of dimensions']

      # Data row
      csv << ['Test Dataset Title', '12345678', '123-4567', 'https://example.com/dataset', '1;2', 'CURRENT', 'Monthly', '2020-01-01', '2025-01-01', '2']

      # Empty row
      csv << []

      # Dimension header
      csv << ['Dimension ID', 'Dimension name', 'Dimension Notes', 'Dimension Definitions']

      # Dimensions
      csv << ['1', 'Geography', '', '']
      csv << ['2', 'Indicators', '', '']

      # Empty row
      csv << []

      # Member header
      csv << ['Dimension ID', 'Member Name', 'Classification Code', 'Member ID', 'Parent Member ID', 'Terminated', 'Member Notes', 'Member Definitions']

      # Members (simplified)
      csv << ['1', 'Canada', '[11124]', '1', '', '', '', '']
      csv << ['2', 'Indicator 1', '', '1', '', '', '', '']

      # Symbol legend header
      csv << []
      csv << ['Symbol Legend']
      csv << ['Description', 'Symbol']
      csv << ['not available', '..']

      # Notes header
      csv << []
      csv << ['Note ID', 'Note']
      csv << ['1', 'This is a test note.']
      csv << ['2', 'This is another test note.']
    end
  end
end
