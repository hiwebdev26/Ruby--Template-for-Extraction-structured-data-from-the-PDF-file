require 'active_support/core_ext/object/blank'

module Templates
  class EfsStatementTemplate
  
    INTEGER = /^\b\d+(\.0+)?\b$/.freeze
    TABLE_ENTRY = /[[:alnum:],.]+/.freeze
    LINE_BEGINNING_DATA = /^\s*(\S.*?)(\s{2,}|\z)/.freeze
    FIRST_COL_LAST_DATA = /\S+\s+(\S+(\.|\/)\S+)/.freeze
    LAST_DATA = /.*  (.+)/.freeze
    SECOND_COL_FIRST_DATA = /.{76}(.+?)(\s{2}|\z)/.freeze
  
    def self.name
      "EFS Statement template"
    end
  
    def self.description
      "Template for processing EFS statements, returns a hash of all the data"
    end
  
    def self.process_file(text, logs)
      lines = text.split("\n")
      result = {}
      comp_address = lines[0].match(LINE_BEGINNING_DATA)[1]
      comp_address += ', '
      comp_address += lines[1].match(LINE_BEGINNING_DATA)[1]
      comp_address += ', '
      comp_address += lines[2].match(LINE_BEGINNING_DATA)[1]
      result[:fleetone_address] = comp_address
  
      own_address = lines[5].match(LINE_BEGINNING_DATA)[1]
      own_address += ', '
      own_address += lines[6].match(LINE_BEGINNING_DATA)[1]
      own_address += ', '
      own_address += lines[7].match(LINE_BEGINNING_DATA)[1]
      result[:own_address] = own_address
  
      result[:statement_date] = parse_date(lines[5].match(LAST_DATA)[1])
      period = lines[6].match(LAST_DATA)[1].split(" - ")
      result[:statement_period] = {
        start: parse_date(period[0]),
        end: parse_date(period[1])
      }
  
      result[:customer_number] = lines[7].match(LAST_DATA)[1]
      result[:statement_number] = lines[9].match(LAST_DATA)[1]
  
      m = lines[10].match(LAST_DATA)
      result[:voice_number] = m[1] != 'Voice Number' ? m[1] : nil
  
      m = lines[11].match(LAST_DATA)
      result[:fax] = m[1] != 'Fax' ? m[1] : nil
  
      result[:email] = lines[12].match(LAST_DATA)[1]
  
      account_summary = {}
      account_summary[:overall_credit_limit] = parse_float(lines[17].match(FIRST_COL_LAST_DATA)[1])
      account_summary[:credit_deposit] = parse_float(lines[18].match(FIRST_COL_LAST_DATA)[1])
      result[:account_summary] = account_summary
  
      payment_summary = {}
      payment_summary[:payment] = parse_float(lines[17].match(LAST_DATA)[1])
      payment_summary[:total] = parse_float(lines[19].match(LAST_DATA)[1])
      result[:payment_summary] = payment_summary
  
      balance_summary = {}
      balance_summary[:beginning_balance] = parse_float(lines[23].match(FIRST_COL_LAST_DATA)[1])
      balance_summary[:payment_total] = parse_float(lines[24].match(FIRST_COL_LAST_DATA)[1])
      balance_summary[:balance_after_payments] = parse_float(lines[25].match(FIRST_COL_LAST_DATA)[1])
      balance_summary[:statement_total] = parse_float(lines[26].match(LINE_BEGINNING_DATA)[1])
      balance_summary[:ending_account_balance] = parse_float(lines[28].match(FIRST_COL_LAST_DATA)[1])
      balance_summary[:past_due_balance] = parse_float(lines[29].match(FIRST_COL_LAST_DATA)[1])
      result[:balance_summary] = balance_summary
  
      statement_activity = {}
      line_index = 23
      item = lines[line_index].match(SECOND_COL_FIRST_DATA)[1]
      while item != 'Statement Total'
        value = parse_float(lines[line_index].match(LAST_DATA)[1])
        statement_activity[item.underscore.gsub(' ', '_')] = value
        line_index += 1
        while lines[line_index].blank?
          line_index += 1
        end
        m = lines[line_index].match(SECOND_COL_FIRST_DATA)
        if m.nil?
          break
        end
        item = m[1]
      end
      m = lines[line_index].match(LAST_DATA)
      if m[1] == 'Statement Total'
        line_index += 1
        m = lines[line_index].match(LAST_DATA)
      end
      statement_activity[:statement_total] = parse_float(m[1])
      result[:statement_activity] = statement_activity
  
      result[:ending_account_balance] = parse_float(lines[34].match(FIRST_COL_LAST_DATA)[1])
      result[:statement_due_date] = parse_date(lines[35].match(FIRST_COL_LAST_DATA)[1])
  
      line_index = 36
      while not lines[line_index].include?('Fuel Transaction Summary')
        line_index += 1
      end
      line_index += 3
  
      fuel_transaction_summary = {}
      cols = ['count', 'total_volume', 'gross_ppu', 'sub_total', 'discount_amount', 'net_ppu', 'total_amount']
      while not lines[line_index].include?('Statement Detail Legend')
        if lines[line_index].blank?
          line_index += 1
        else
          parse_table_row(fuel_transaction_summary, lines[line_index], cols)
          line_index += 1
        end
      end
  
      result[:fuel_transaction_summary] = fuel_transaction_summary
  
      while not lines[line_index].include?('DATE ')
        line_index += 1
      end
  
      statement_details = []
  
      columns = [
        "date", "category", "use", "description", "card", "unit", "prompt_data", "check_number", 
        "location_number", "location_name", "state", "quantity", "gross_ppg", "sales_tax", "fed_tax", "gross_amount", "discrete_amount", "fees", "total_amount"
      ]
  
      column_positions = [0, 17, 33, 36, 77, 89, 99, 108, 121, 132, 167, 170, 182, 193, 204, 214, 226, 237, 248]
  
      line_index += 1
      while lines[line_index].blank?
        line_index += 1
      end
      leftovers = {}
      line_index = parse_terminal_row(statement_details, lines, line_index, columns, column_positions, leftovers)
      while not lines[line_index].include?('Ending Balance')
        if lines[line_index].blank?
          line_index += 1
        else
          line_index = parse_big_table_row(statement_details, lines, line_index, columns, column_positions, leftovers)
        end
      end
      line_index = parse_terminal_row(statement_details, lines, line_index, columns, column_positions, leftovers)
  
      result[:statement_details] = statement_details
  
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
        matches = line.scan(TABLE_ENTRY)
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