require 'rails_helper'
require 'yaml'
require 'pdf-reader'
# require_relative '../../app/templates/efs_statement_template'
require_relative '../../app/templates/w4_form_template.rb'

RSpec.describe Templates::W4FormTemplate do
  def test_for_file(file_name, expected_name)
    test_file = File.expand_path("../../fixtures/files/#{file_name}", __FILE__)
    puts "Test file path: #{test_file}"
    puts "Test file exists: #{File.exist?(test_file)}"

    raise "Test file does not exist: #{test_file}" unless File.exist?(test_file)

    text = ''
    PDF::Reader.open(test_file) do |reader|
      text = reader.pages.map(&:text).join("\n")
    end
    puts "PDF text extracted successfully: #{!text.empty?}"

    logs = []
    result, error = described_class.process_file(text, logs)
    puts "Process file result: #{result.inspect}"
    puts "Process file error: #{error.inspect}"

    # Write the result to a YAML file
    output_filename = File.expand_path("../../fixtures/expected_results/efs_statement/#{expected_name}", __FILE__)
    File.open(output_filename, 'w') do |file|
      YAML.dump(result, file)
      puts "Written output to #{output_filename}"
    end

    expected_file = File.expand_path("../../fixtures/expected_results/efs_statement/#{expected_name}", __FILE__)
    puts "Expected file path: #{expected_file}"
    puts "Expected file exists: #{File.exist?(expected_file)}"

    expected_hash = YAML.safe_load_file(expected_file, permitted_classes: [Date, Symbol])
    puts "Expected hash: #{expected_hash.inspect}"

    expect(result).to eq(expected_hash)
    expect(error).to be_nil
  end

  # describe 'efs_statement_sample-16/10/24.process_file' do
  #   it 'should return the expected output' do
  #     test_for_file('EFS_Statement_2024-10-16.pdf', 'efs_2024-10-16.yml')
  #   end
  # end

  # describe 'efs_statement_sample-28/10/24.process_file' do
  #   it 'should return the expected output' do
  #     test_for_file('EFS_Statement_2024-10-28.pdf', 'efs_2024-10-28.yml')
  #   end
  # end

  describe 'w4_form_template.process_file' do
    it 'should return the expected output' do
      test_for_file('w4_form.pdf', 'w4_form.yml')
    end
  end
end