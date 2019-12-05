# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require_relative 'lib/rubocop/flexport/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-flexport'
  spec.version = RuboCop::Flexport::VERSION
  spec.authors = ['Flexport Engineering']
  spec.email = ['dev@flexport.com']

  spec.summary = 'RuboCop cops used at Flexport.'
  spec.description = ''
  spec.homepage = 'https://github.com/flexport/rubocop-flexport'
  spec.license = 'MIT'

  spec.files = `git ls-files bin config lib LICENSE.txt README.md`
               .split($RS)
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 4.0'
  spec.add_runtime_dependency 'rubocop', '>= 0.70.0'
end
