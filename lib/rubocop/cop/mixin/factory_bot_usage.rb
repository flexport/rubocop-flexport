# frozen_string_literal: true

module RuboCop
  module Cop
    # Helpers for detecting FactoryBot usage.
    module FactoryBotUsage
      extend NodePattern::Macros

      FACTORY_BOT_METHODS = %i[
        attributes_for
        attributes_for_list
        build
        build_list
        build_pair
        build_stubbed
        build_stubbed_list
        create
        create_list
        create_pair
      ].freeze

      def_node_matcher :factory_bot, <<~PATTERN
        (send _ {#{FACTORY_BOT_METHODS.map(&:inspect).join(' ')}} $sym)
      PATTERN

      def spec_file?
        processed_source&.path&.match?(/_spec\.rb$/) || false
      end

      # Recursively traverses a Parser::AST::Node, returning an array of all
      # the factory names found within.
      def find_factories(node)
        factories = []
        return factories unless node.is_a?(Parser::AST::Node)

        if node.type == :send && node.children[1] == :factory
          factory_name_node = node.children[2]
          factory_name = factory_name_node.children[0]
          factories << factory_name
        end

        factories + node.children.flat_map { |child| find_factories(child) }
      end
    end
  end
end