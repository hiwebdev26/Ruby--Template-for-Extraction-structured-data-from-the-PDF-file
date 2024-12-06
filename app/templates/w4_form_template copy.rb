require 'active_support/core_ext/object/blank'

module Templates
  class W4FormTemplate
  
    INTEGER = /^\b\d+(\.0+)?\b$/.freeze
    TABLE_ENTRY = /[[:alnum:],.]+/.freeze
    LARGE_TABLE_ENTRY = /^(?:[[:alnum:],.\s-]+)/.freeze
    LINE_BEGINNING_DATA = /^\s*(\S.*?)(\s{2,}|\z)/.freeze
    LINE_BETWEEN_DATA = /^(\S+)\s+(\S+(?:\s+\S+)*)\s+(\S+)$/.freeze
    LINE_SECOND_DATA = /^(\S+)\s+((?:\S+(?:\s+\S+)*))\s+\S+.*$/.freeze
    FIRST_COL_LAST_DATA = /\S+\s+(\S+(\.|\/)\S+)/.freeze
    LAST_DATA = /.*  (.+)/.freeze
    SECOND_COL_FIRST_DATA = /.{76}(.+?)(\s{2}|\z)/.freeze
  
    def self.name
      "W4 Form Template"
    end
  
    def self.description
      "Template for processing W4 Form, returns a hash of all the data"
    end
  
    def self.process_file(text, logs)
      lines = text.split("\n")
      # puts(lines)
      result = {}
      if match = lines[7].match(LINE_BETWEEN_DATA)
        first_or_middle_name = match[2]
        last_name = match[3]
        special_security_number = match[4]
        personal_name = first_or_middle_name + " " + last_name
      end

      if match = lines[9].match(LINE_SECOND_DATA)
        personal_address = match[2]
      end

      city_town_zip = lines[12].match(LINE_BEGINNING_DATA)[1]
      result[:Personal_Information] = {
        Personal_Name: personal_name,
        Special_Security_Number: special_security_number,
        Address: personal_address,
        City_Town_State_Zipcode: city_town_zip
      }

      # married_filling_table = {
      #   Married_Filing_Jointly_or_Qualifying_Surviving_Spouse: {
      #     Higher_Paying_Job_Annual_Taxable_Wage_&_Salary: {}
      #   }
      # }
  
      fuel_transaction_summary = {}
      cols = ['$0 - 9,999', '$10,000 - 19,999', '$20,000 - 29,999', '$30,000 - 39,999', '$40,000 - 49,999', '$50,000 - 59,999', '$60,000 - 69,999', '$70,000 - 79,999', '$80,000 - 89,999', '$90,000 - 99,999', '$100,000 - 109,999', '$110,000 - 120,000']
      # rows = ['$0 - 9,999', '$10,000 - 19,999', '$20,000 - 29,999', '$30,000 - 39,999', '$40,000 - 49,999', '$50,000 - 59,999', '$60,000 - 69,999', '$70,000 - 79,999', '$80,000 - 89,999', '$100,000 - 109,999', '$150,000 - 239,999', '$240,000 - 259,999', '$260,000 - 279,999', '$280,000 - 299,999', '$300,000 - 319,999', '$320,000 - 364,999', '$365,000 - 524,999', '$525,000 and over']
      while not lines[line_index].include?('Single or Married Filing Separately')
        if lines[line_index].blank?
          line_index += 1
        else
          parse_table_row(fuel_transaction_summary, lines[line_index], cols)
          line_index += 1
        end
      end
  
      # result[:fuel_transaction_summary] = fuel_transaction_summary
  
      # while not lines[line_index].include?('DATE ')
      #   line_index += 1
      # end
  
      # statement_details = []
  
      # columns = [
      #   "date", "category", "use", "description", "card", "unit", "prompt_data", "check_number", 
      #   "location_number", "location_name", "state", "quantity", "gross_ppg", "sales_tax", "fed_tax", "gross_amount", "discrete_amount", "fees", "total_amount"
      # ]
  
      # column_positions = [0, 17, 33, 36, 77, 89, 99, 108, 121, 132, 167, 170, 182, 193, 204, 214, 226, 237, 248]
  
      # line_index += 1
      # while lines[line_index].blank?
      #   line_index += 1
      # end
      # leftovers = {}
      # line_index = parse_terminal_row(statement_details, lines, line_index, columns, column_positions, leftovers)
      # while not lines[line_index].include?('Ending Balance')
      #   if lines[line_index].blank?
      #     line_index += 1
      #   else
      #     line_index = parse_big_table_row(statement_details, lines, line_index, columns, column_positions, leftovers)
      #   end
      # end
      # line_index = parse_terminal_row(statement_details, lines, line_index, columns, column_positions, leftovers)
  
      # result[:statement_details] = statement_details
  
      return [result, nil]
    end
  
    private
  
      def self.parse_date(text)
        if text.blank?
          return nil
        end
        if text.length < 10
          Date.strptime(text, '%m/%d/%y')
        else
          Date.strptime(text, '%m/%d/%Y')
        end
      end
  
      def self.parse_float(text)
        text = text.gsub(',', '')
        if text.match?(INTEGER)
          text.to_i
        else
          text.to_f
        end
      end
  
      def self.parse_table_row(parent, line, cols)
        obj = {}
        key = ''
        matches = line.scan(LARGE_TABLE_ENTRY)
        index = 0
        matches.each do |m|
          if index == 0
            key = m
          else
            obj[cols[index-1]] = parse_float(m)
          end
          index += 1
        end
        parent[key] = obj
      end
  
      def self.parse_big_table_row(parent, lines, line_index, cols, col_positions, leftovers)
        row_data = {}
        cols.each do |col|
          row_data[col] = leftovers[col]
        end
        begin
          reached_end = false
          line = lines[line_index]
          cols.each_with_index do |col, idx|
            if reached_end
              break
            end
            start_pos = col_positions[idx]
            end_pos = (idx + 1 < cols.length) ? col_positions[idx+1] : line.length
            length = end_pos - start_pos
            linepart = line.slice(start_pos, length)
            begin
              value = linepart.strip
            rescue
              reached_end = true
              break
            end
            key = col
            if key == 'card' and lines[line_index][col_positions[0]] == ' '
              leftovers[key] = value
            elsif row_data[key].nil?
              row_data[key] = value
            elsif not value.nil?
              row_data[key] += value
            end
          end
          if not row_data["check_number"].blank? and not row_data["check_number"].include?(' ') and not row_data["location_number"].blank? and not row_data["location_number"].include?(' ')
            row_data["location_number"] = ' ' + row_data["location_number"]
          end
          combined = (row_data["check_number"] || '') + (row_data["location_number"] || '')
          combined = combined.split(/\s+/)
          row_data["check_number"] = combined[0]
          row_data["location_number"] = combined[1]
  
          line_index += 1
          while lines[line_index].blank? and line_index < lines.length - 1
            line_index += 1
          end
        end while line_index < lines.length-1 && lines[line_index][col_positions[0]] == ' '
        
        cols.each_with_index do |col, idx|
          value = row_data[col]
          if idx == 0 and not value.nil?
            value = parse_date(value)
          elsif idx > 10 and not value.nil?
            value = parse_float(value)
          end
          if value.blank?
            value = nil
          end
          row_data[col] = value
        end
  
        parent << row_data
        return line_index
      end
  
      def self.parse_terminal_row(parent, lines, line_index, cols, col_positions, leftovers)
        line_index = parse_big_table_row(parent, lines, line_index, cols, col_positions, leftovers)
        data = parent.last
        data["category"] += (data["use"] || '') + (data["description"] || '')
        data["use"] = nil
        data["description"] = nil
        return line_index
      end
  
      
  end
  end