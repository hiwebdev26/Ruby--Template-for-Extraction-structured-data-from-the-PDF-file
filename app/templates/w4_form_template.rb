require 'active_support/core_ext/object/blank'

module Templates
  class W4FormTemplate
  
    INTEGER = /^\b\d+(\.0+)?\b$/.freeze
    TABLE_ENTRY = /[[:alnum:],.]+/.freeze
    LARGE_TABLE_ENTRY = /^(?:[[:alnum:],.\s-]+)/.freeze
    LINE_BEGINNING_DATA = /^\s*(\S.*?)(\s{2,}|\z)/.freeze
    LINE_BETWEEN_DATA = /^(\S+)\s+(\S+(?:\s+\S+)*)\s+(\S+)$/.freeze
    LINE_SECOND_DATA = /^(\S+)\s+((?:\S+(?:\s+\S+)*))\s+\S+.*$/.freeze
    LINE_ONLY_SECOND = /^\S+\s+(.+?)(?:\s{2,}|$)/.freeze
    LINE_NUMBER_INPUTED = /\$\s*(\d+(?:,\d+)?)/.freeze
    LAST_DATA = /.*  (.+)/.freeze
    LINE_NUMBER = /\$\s*(\d+(?:,\d+)*)/.freeze
  
    def self.name
      "W4 Form Template"
    end
  
    def self.description
      "Template for processing W4 Form, returns a hash of all the data"
    end
  
    def self.process_file(text, logs)
      lines = text.split("\n")

      # The code for the first page:

      result = {}
      if match = lines[7].match(LINE_BETWEEN_DATA)
        first_or_middle_name = match[2]
        last_name = match[3]
        special_security_number = match[4]
        personal_name = first_or_middle_name + " " + last_name
      end

      if match = lines[9].match(LINE_ONLY_SECOND)
        personal_address = match[1].strip
      end

      city_town_zip = lines[12].match(LINE_BEGINNING_DATA)[1]
      result[:Step1_Personal_Information] = {
        Personal_Name: personal_name,
        Special_Security_Number: special_security_number,
        Address: personal_address,
        City_Town_State_Zipcode: city_town_zip
      }

      step3_claim_dependent = {}

      # Find the line index
      line_index = lines.index { |line| line.include?('Multiply the number of qualifying children under age 17 by $2,000') }

      if line_index
        # Extract the amount
        if match = lines[line_index].match(LINE_NUMBER_INPUTED)
          multiply_qualify_children_amount = parse_float(match[1])
        end
      end

      line_index = lines.index { |line| line.include?('Multiply the number of other dependents by $500') }

      if line_index
        # Extract the amount
        if match = lines[line_index].match(LINE_NUMBER_INPUTED)
          multiply_other_dependents = parse_float(match[1])

          puts(line_index)
        end
      end

      total_amount =  lines[46].match(LINE_BEGINNING_DATA)[1]
      result[:Step3_Claim_Dependent_and_Other_Credits] = {
        Multiply_the_number_of_qualifying_children_under_age_17: multiply_qualify_children_amount,
        Multiply_the_number_of_other_dependents: multiply_other_dependents,
        Total_Amount: total_amount
      }

      # Step 4 code
      step4_other_adjustments =  {}

      line_index = lines.index { |line| line.include?('This may include interest, dividends, and retirement income') }

      if line_index
        # Extract the amount
        if match = lines[line_index].match(LINE_NUMBER_INPUTED)
          other_income = parse_float(match[1])
        end
      end

      line_index = lines.index { |line| line.include?('the result here') }

      if line_index
        # Extract the amount
        if match = lines[line_index].match(LINE_NUMBER_INPUTED)
          deductions = parse_float(match[1])
        end
      end

      line_index = lines.index { |line| line.include?('Extra withholding. Enter any additional tax you want withheld each pay period') }

      if line_index
        # Extract the amount
        if match = lines[line_index].match(LINE_NUMBER_INPUTED)
          extra_withholding = parse_float(match[1])
        end
      end
      
      result[:Step4_Other_Adjustments] = {
        Other_Income: other_income,
        Deductions: deductions,
        Extra_Withholding: extra_withholding
      }

      # Step 5: Employers only
      step5_employers_only = {}

      line_index = lines.index { |line| line.include?('Employer’s name and address') }
      if line_index
        employer_info = lines[line_index + 2].match(LINE_BEGINNING_DATA)[1]
        first_date_of_employment = lines[line_index + 4].match(LINE_BEGINNING_DATA)[1]
        if match= lines[line_index + 4].match(LAST_DATA)
          employer_identification_info = match[1]
        end
      end
      result[:Step5_Employers_Only] = {
        Employer_Information: employer_info,
        First_Date_Of_Employment: parse_date(first_date_of_employment),
        Employer_Identification_Information: employer_identification_info
      }

      # The code for Page 3
      # Multiple Jobs WorkSheet
      line_index = lines.index { |line| line.include?('that value on line 1. Then, skip to line 3') }
      if line_index
        amount_1 = lines[line_index + 1].match(LAST_DATA)
      end

      line_index = lines.index { |line| line.include?('and enter that value on line 2a .') }
      if line_index
        amount_2a = lines[line_index + 1].match(LAST_DATA)
      end

      line_index = lines.index { |line| line.include?('on line 2b') }
      if line_index
        amount_2b = lines[line_index + 1].match(LAST_DATA)
      end

      line_index = lines.index { |line| line.include?('Add the amounts from lines 2a and 2b and enter the result on line 2c ') }
      if line_index
        amount_2c = lines[line_index + 1].match(LAST_DATA)
      end

      line_index = lines.index { |line| line.include?('eekly, enter 52; if it pays every other week, enter 26; if it pays monthly, enter 12, etc.') }
      if line_index
        amount_3 = lines[line_index + 1].match(LAST_DATA)
      end

      line_index = lines.index { |line| line.include?('amount you want withheld) .') }
      if line_index
        amount_4 = lines[line_index + 1].match(LAST_DATA)
      end

      result[:Mutiple_Jobs_Worksheet] = {
        Two_jobs: amount_1,
        Three_Jobs: {
          A: amount_2a,
          B: amount_2b,
          C: amount_2c
        },
        Number_Of_Pay_Period: amount_3,
        Divide_Annual_Amount: amount_4
      }

      # Deduction Worksheet
      deduction_worksheet = {}
      line_index = lines.index { |line| line.include?('$10,000), and medical expenses in excess of 7.5% of your income .') }
      if line_index
        if match = lines[line_index].match(LAST_DATA)
          estimate_of_itemized_deductions = match[1]
        end
      end

      line_index = lines.index { |line| line.include?('$21,900 if you’re head of household') }
      if line_index
        if match = lines[line_index].match(LAST_DATA)
          second_amount = match[1]
        end
      end

      line_index = lines.index { |line| line.include?('than line 1, enter “-0-”') }
      if line_index
        if match = lines[line_index].match(LAST_DATA)
          third_amount = match[1]
        end
      end

      line_index = lines.index { |line| line.include?('adjustments (from Part II of Schedule 1 (Form 1040)). See Pub. 505 for more information') }
      if line_index
        if match = lines[line_index].match(LAST_DATA)
          fourth_amount = match[1]
        end
      end

      line_index = lines.index { |line| line.include?('Add lines 3 and 4. Enter the result here and in Step 4(b) of Form W-4') }
      if line_index
        if match = lines[line_index].match(LAST_DATA)
          fifth_amount = match[1]
        end
      end

      result[:Deductions_Worksheet] = {
        Estimate_Of_Your_2024_itemized_deductions: estimate_of_itemized_deductions,
        Second_amount: second_amount,
        Third_amount: third_amount,
        Fourth_amount: fourth_amount,
        Fifth_amount: fifth_amount
      }

      # The first table in Page 4.

      line_index = 160
      while not lines[line_index].include?('Married Filing Jointly or Qualifying Surviving Spouse')
        line_index += 1
      end
      line_index += 5
      married_filling_table = {}
  
      cols = ['$0 - 9,999', '$10,000 - 19,999', '$20,000 - 29,999', '$30,000 - 39,999', '$40,000 - 49,999', '$50,000 - 59,999', '$60,000 - 69,999', '$70,000 - 79,999', '$80,000 - 89,999', '$90,000 - 99,999', '$100,000 - 109,999', '$110,000 - 120,000']
      while not lines[line_index].include?('Single or Married Filing Separately')
        if lines[line_index].blank?
          line_index += 1
        else
          parse_table_row(married_filling_table, lines[line_index], cols)
          line_index += 1
        end
      end
  
      result[:Married_Filing_Jointly_or_Qualifying_Surviving_Spouse] = married_filling_table

      # The Second table
      while not lines[line_index].include?('Single or Married Filing Separately')
        line_index += 1
      end
      line_index += 5
      single_or_married_filling_table = {}
  
      cols = ['$0 - 9,999', '$10,000 - 19,999', '$20,000 - 29,999', '$30,000 - 39,999', '$40,000 - 49,999', '$50,000 - 59,999', '$60,000 - 69,999', '$70,000 - 79,999', '$80,000 - 89,999', '$90,000 - 99,999', '$100,000 - 109,999', '$110,000 - 120,000']
      while not lines[line_index].include?('Head of Household')
        if lines[line_index].blank?
          line_index += 1
        else
          parse_table_row(single_or_married_filling_table, lines[line_index], cols)
          line_index += 1
        end
      end
  
      result[:Single_OR_Marrid_Filing_Separately_Table] = single_or_married_filling_table

      # The Third table
      while not lines[line_index].include?('Head of Household')
        line_index += 1
      end
      line_index += 5
      head_of_household_table = {}

      cols = ['$0 - 9,999', '$10,000 - 19,999', '$20,000 - 29,999', '$30,000 - 39,999', '$40,000 - 49,999', '$50,000 - 59,999', '$60,000 - 69,999', '$70,000 - 79,999', '$80,000 - 89,999', '$90,000 - 99,999', '$100,000 - 109,999', '$110,000 - 120,000']

      # Process lines until we find the end condition
      while line_index < lines.length
        current_line = lines[line_index]
        
        # Check if we've reached the end of the relevant section
        if current_line.include?('$450,000 and over')
          parse_table_row(head_of_household_table, current_line, cols)
          break
        elsif current_line.blank?
          # Skip blank lines
          line_index += 1
          next
        else
          parse_table_row(head_of_household_table, current_line, cols)
        end
        
        line_index += 1
      end

      result[:Head_of_Household_Table] = head_of_household_table

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
        # Normalize multiple spaces to a single space throughout the line
        normalized_line = line.gsub(/\s*-\s*/, ' - ')
        puts(normalized_line)
        matches = normalized_line.strip.split(/ {2,}/)
        return if matches.empty?
      
        key = matches.shift
        obj = {}
        matches.each_with_index do |value, index|
          break if index >= cols.length
          obj[cols[index]] = value
        end
        parent[key] = obj unless obj.empty?
      end
  end
  end