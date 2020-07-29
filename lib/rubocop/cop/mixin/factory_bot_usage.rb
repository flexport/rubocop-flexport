# frozen_string_literal: true

require 'active_support/inflector'

module RuboCop
  module Cop
    # Helpers for detecting FactoryBot usage.
    # rubocop:disable Metrics/ModuleLength
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

      # Parses factory definition files, returning a hash mapping factory names
      # to model class names for each file.
      def find_factories
        # We'll add factories here as we parse the factory files.
        @factories = {}

        # We'll add factories that specify a parent here, so we can resolve the
        # reference to the parent after we have finished parsing all the files.
        @parents = {}

        # Parse the factory files, then resolve any parent references.
        traverse_factory_files
        resolve_parents

        @factories
      end

      def traverse_factory_files
        factory_files.each do |path|
          @factories[path] = {}
          @parents[path] = {}

          source_code = File.read(path)
          source = RuboCop::ProcessedSource.new(source_code, RUBY_VERSION.to_f)
          traverse_node(source.ast, path)
        end
      end

      def resolve_parents
        all_factories = @factories.values.reduce(:merge)
        all_parents = @parents.values.reduce(:merge)
        @parents.each do |path, parents|
          parents.each do |factory, parent|
            parent = all_parents[parent] while all_parents[parent]
            model_class_name = all_factories[parent]
            next unless model_class_name

            @factories[path][factory] = model_class_name
          end
        end
      end

      def factory_files
        @factory_files ||= Dir['spec/factories/**/*.rb'] + Dir["#{engines_path}*/spec/factories/**/*.rb"]
      end

      def engines_path
        raise NotImplementedError
      end

      private

      def traverse_node(node, path, parent = nil, model_class_name = nil)
        return unless node.is_a?(Parser::AST::Node)

        factory_node = extract_factory_node(node)
        if factory_node
          factory_name, aliases, parent, model_class_name = parse_factory_node(
            factory_node,
            model_class_name,
            parent
          )
          if factory_node?(node)
            ([factory_name] + aliases).each do |name|
              if parent
                @parents[path][name] = parent
              else
                @factories[path][name] = model_class_name
              end
            end
            return
          end
        end

        node.children.each { |child| traverse_node(child, path, parent, model_class_name) }
      end

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

      def parse_factory_node(
        node,
        model_class_name_from_surrounding_block = nil,
        parent_from_surrounding_block = nil
      )
        factory_name_node, factory_config_node = node.children[2..3]

        factory_name = factory_name_node.children[0]
        aliases = extract_aliases(factory_config_node)
        explicit_model_class_name = extract_model_class_name(factory_config_node)
        parent = explicit_model_class_name ? nil : extract_parent(factory_config_node) || parent_from_surrounding_block
        model_class_name = explicit_model_class_name ||
                           model_class_name_from_surrounding_block ||
                           ActiveSupport::Inflector.camelize(factory_name)

        [factory_name, aliases, parent, model_class_name]
      end

      def extract_aliases(factory_config_hash_node)
        aliases_array = extract_hash_value(factory_config_hash_node, :aliases)
        return [] if aliases_array&.type != :array

        aliases_array.children.map(&:value)
      end

      def extract_parent(factory_config_hash_node)
        parent_node = extract_hash_value(factory_config_hash_node, :parent)
        parent_node&.value
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
    # rubocop:enable Metrics/ModuleLength
  end
end
