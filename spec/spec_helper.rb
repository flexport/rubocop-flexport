require "pry"
require "rubocop"
require "rubocop/rspec/support"

Dir[File.join(__dir__, "..", "lib", "rubocop", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include(RuboCop::RSpec::ExpectOffense)
  config.include(CopHelper)
end
