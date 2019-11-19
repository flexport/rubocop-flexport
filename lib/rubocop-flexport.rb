# frozen_string_literal: true

require 'rubocop'

require_relative 'rubocop/flexport'
require_relative 'rubocop/flexport/version'
require_relative 'rubocop/flexport/inject'

RuboCop::Flexport::Inject.defaults!

require_relative 'rubocop/cop/flexport_cops'
