# frozen_string_literal: true

require 'active_support/inflector'

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

      def_node_matcher :factory_bot_usage, <<~PATTERN
        (send _ {#{FACTORY_BOT_METHODS.map(&:inspect).join(' ')}} $sym)
      PATTERN

      def spec_file?
        processed_source&.path&.match?(/_spec\.rb$/) || false
      end

      # Recursively traverses a Parser::AST::Node, returning an array of
      # [factory_name, model_class_name] 2-tuples.
      def find_factories(node, model_class_name = nil)
        factories = []
        return factories unless node.is_a?(Parser::AST::Node)

        factory_node = extract_factory_node(node)
        if factory_node
          factory_name, aliases, model_class_name = parse_factory_node(factory_node, model_class_name)
          if factory_node?(node)
            ([factory_name] + aliases).each do |name|
              factories << [name, model_class_name]
            end
          end
        end

        factories + node.children.flat_map { |child| find_factories(child, model_class_name) }
      end

      private

      def extract_factory_node(node)
        return node.children[0] if factory_block?(node)
        return node if factory_node?(node)
      end

      def factory_block?(node)
        return false if node&.type != :block

        factory_node?(node.children[0])
      end

      def factory_node?(node)
        node&.type == :send && node.children[1] == :factory
      end

      def parse_factory_node(node, model_class_name_from_parent_factory = nil)
        factory_name_node, factory_config_node = node.children[2..3]

        factory_name = factory_name_node.children[0]
        aliases = extract_aliases(factory_config_node)
        explicit_model_class_name = extract_model_class_name(factory_config_node)
        model_class_name = explicit_model_class_name ||
                           model_class_name_from_parent_factory ||
                           ActiveSupport::Inflector.camelize(factory_name)

        [factory_name, aliases, model_class_name]
      end

      def extract_aliases(factory_config_hash_node)
        aliases_array = extract_hash_value(factory_config_hash_node, :aliases)
        return [] if aliases_array&.type != :array

        aliases_array.children.map(&:value)
      end

      def extract_model_class_name(factory_config_hash_node)
        model_class_name_node = extract_hash_value(factory_config_hash_node, :class)

        case model_class_name_node&.type
        when :const
          model_class_name_node.source.sub(/^::/, '')
        when :str
          model_class_name_node.value.sub(/^::/, '')
        end
      end

      def extract_hash_value(node, hash_key)
        return nil if node&.type != :hash

        pairs = node.children.select { |child| child.type == :pair }
        pairs.each do |pair|
          key, value = pair.children
          return value if key.value == hash_key
        end

        nil
      end
    end
  end
end
