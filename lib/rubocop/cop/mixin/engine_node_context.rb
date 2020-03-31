# frozen_string_literal: true

module RuboCop
  module Cop
    # Helpers for determining the context of a node for engine violations.
    module EngineNodeContext
      # Sometimes modules/class are declared with the same name as an
      # engine or global model. For example, you might have both:
      #
      #   /engines/foo
      #   /app/graph/types/foo
      #
      # We ignore instead of yielding false positive for the module
      # declaration in the latter.
      def in_module_or_class_declaration?(node)
        depth = 0
        max_depth = 10
        while node.const_type? && node.parent && depth < max_depth
          node = node.parent
          depth += 1
        end
        node.module_type? || node.class_type?
      end
    end
  end
end
