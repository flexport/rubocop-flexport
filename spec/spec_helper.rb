# frozen_string_literal: true

require 'rubocop-flexport'
require 'rubocop/rspec/support'

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense

  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.raise_on_warning = true
  config.fail_if_no_examples = true
  config.before(:each) do
    allow(File).to receive(:read).with(a_string_matching('/obsoletion.yml')).and_call_original
  end

  config.order = :random
  Kernel.srand config.seed
end
