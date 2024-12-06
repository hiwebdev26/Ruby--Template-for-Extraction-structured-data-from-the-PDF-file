require 'spec_helper'
require 'pathname'
require 'active_support/all'

module Rails
  def self.root
    Pathname.new(File.expand_path('../../', __FILE__))
  end
end

# Add any additional requires or configurations here

RSpec.configure do |config|
  # Add any RSpec configurations here
end