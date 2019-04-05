# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "rubocop/flexport/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-flexport"
  spec.summary = "Flexport RuboCop configuration and custom cops."
  spec.description = <<-DESCRIPTION
    A plugin for RuboCop. It includes portions of the Rubocop configuration used at Flexport
    and a few new rules written for internal use cases that may be usefully generally.
    The goal is generally to upstream any custom cops from this repo into the main repo.
  DESCRIPTION
  spec.authors = ["Flexport Engineering"]
  spec.email = ["rubocop@flexport.com"]
  spec.homepage = "https://github.com/flexport/rubocop-flexport"
  spec.license = "MIT"
  spec.version = RuboCop::Flexport::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.3"

  spec.require_paths = ["lib"]
  spec.files = Dir[
    "{config,lib,spec}/**/*",
    "*.md",
    "*.gemspec",
    "Gemfile",
  ]

  spec.add_dependency("rubocop", "~> 0.67.1")
  spec.add_dependency("rubocop-rspec", "~> 1.32.0")
  spec.add_development_dependency("rspec", "~> 3.8.0")
end
