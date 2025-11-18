# frozen_string_literal: true

require 'digest/sha1'

# rubocop:disable Metrics/ClassLength
module RuboCop
  module Cop
    module Flexport
      # This cop prevents code outside of a Rails Engine from directly
      # accessing the engine without going through an API. The goal is
      # to improve modularity and enforce separation of concerns.
      #
      # # Defining an engine's API
      #
      # The cop looks inside an engine's `api/` directory to determine its
      # API. API surface can be defined in two ways:
      #
      # - Add source files to `api/`. Code defined in these modules
      #   will be accessible outside your engine. For example, adding
      #   `api/foo_service.rb` will allow code outside your engine to
      #   invoke eg `MyEngine::Api::FooService.bar(baz)`.
      # - Create an `_allowlist.rb` or `_whitelist.rb` file in `api/`. Modules listed in
      #   this file are accessible to code outside the engine. The file
      #   must have this name and a particular format (see below).
      #
      # Both of these approaches can be used concurrently in the same engine.
      # Due to Rails Engine directory conventions, the API directory should
      # generally be located at eg `engines/my_engine/app/api/my_engine/api/`.
      #
      # # Usage
      #
      # This cop can be useful when splitting apart a legacy codebase.
      # In particular, you might move some code into an engine without
      # enabling the cop, and then enable the cop to see where the engine
      # boundary is crossed. For each violation, you can either:
      #
      # - Expose new API surface from your engine
      # - Move the violating file into the engine
      # - Add the violating file to `_legacy_dependents.rb` (see below)
      #
      # The cop detects cross-engine associations as well as cross-engine
      # module access.
      #
      # The cop will complain if you use FactoryBot factories defined in other
      # engines in your engine's specs. You can disable this check by adding
      # the engine name to `FactoryBotOutboundAccessAllowedEngines` in
      # .rubocop.yml.
      #
      # # Isolation guarantee
      #
      # This cop can be easily circumvented with metaprogramming, so it cannot
      # strongly guarantee the isolation of engines. But it can serve as
      # a useful guardrail during development, especially during incremental
      # migrations.
      #
      # Consider using plain-old Ruby objects instead of ActiveRecords as the
      # exchange value between engines. If one engine gets a reference to an
      # ActiveRecord object for a model in another engine, it will be able
      # to perform arbitrary reads and writes via associations and `.save`.
      #
      # # Example `api/_legacy_dependents.rb` file
      #
      # This file contains a burn-down list of source code files that still
      # do direct access to an engine "under the hood", without using the
      # API. It must have this structure.
      #
      # ```rb
      # module MyEngine::Api::LegacyDependents
      #   FILES_WITH_DIRECT_ACCESS = [
      #     "app/models/some_old_legacy_model.rb",
      #     "engines/other_engine/app/services/other_engine/other_service.rb",
      #   ]
      # end
      # ```
      #
      # # Example `api/_whitelist.rb` file
      #
      # This file contains a list of modules that are allowed to be accessed
      # by code outside the engine. It must have this structure.
      #
      # ```rb
      # module MyEngine::Api::Whitelist
      #   PUBLIC_MODULES = [
      #     MyEngine::BarService,
      #     MyEngine::BazService,
      #     MyEngine::BatConstants,
      #   ]
      # end
      # ```
      #
      # # "StronglyProtectedEngines" parameter
      #
      # The Engine API is not actually a network API surface. Method invocations
      # may happen synchronously and assume they are part of the same
      # transaction. So if your engine is using modules whitelisted by
      # other engines, then you cannot extract your engine code into a
      # separate network-isolated service (even though within a big Rails
      # monolith using engines the cross-engine method call might have been
      # acceptable).
      #
      # The "StronglyProtectedEngines" parameter helps in the case you want to
      # extract your engine completely. If your engine is listed as a strongly
      # protected engine, then the following additional restricts apply:
      #
      # (1) Any use of your engine's code by code outside your engine is
      #     considered a violation, regardless of *your* _legacy_dependents.rb,
      #     _whitelist.rb, or engine API module. (no inbound access)
      # (2) Any use of other engines' code within your engine is considered
      #     a violation, regardless of *their* _legacy_dependents.rb,
      #     _whitelist.rb, or engine API module. (no outbound access)
      #
      # (Note: "EngineSpecificOverrides" parameter still has effect.)
      #
      # # "EngineSpecificOverrides" parameter
      #
      # This parameter allows defining bi-lateral private "APIs" between
      # engines. See example in global_model_access_from_engine_spec.rb.
      # This may be useful if you plan to extract several engines into the
      # same network-isolated service.
      #
      # # "Engines" parameter
      #
      # A list of engine names that can be used instead of the "EnginesPath" parameter.
      #
      # This helps in the case when engines are placed in a project's root directory.
      #
      #  ```yml
      #  Engines:
      #    - my_engine1
      #    - my_engine2
      #  ```
      #
      # # "EnginesPrefix" parameter
      #
      # Prefix/namespace of engine classes
      #
      # This helps in the case when engine classes have a namespace.
      #
      #  ```rb
      #  module MyNamespace
      #    class MyEngine::MyModel < ApplicationModel
      #    end
      #  end
      #  ```
      #
      #  ```yml
      #  EnginesPrefix: 'MyNamespace'
      #  ```
      #
      # @example
      #
      #   # bad
      #   class MyService
      #     m = ReallyImportantSharedEngine::InternalModel.find(123)
      #     m.destroy
      #   end
      #
      #   # good
      #   class MyService
      #     ReallyImportantSharedEngine::Api::SomeService.execute(123)
      #   end
      #
      # @example
      #
      #   # bad
      #
      #   class MyEngine::MyModel < ApplicationModel
      #     has_one :foo_model, class_name: "SharedEngine::FooModel"
      #   end
      #
      #   # good
      #
      #   class MyEngine::MyModel < ApplicationModel
      #     # (No direct associations to models in API-protected engines.)
      #   end
      #
      class EngineApiBoundary < Base
        include EngineApi
        include EngineNodeContext
        include FactoryBotUsage

        MSG = 'Direct access of %<accessed_engine>s engine. ' \
              'Only access engine via %<accessed_engine>s::Api.'

        STRONGLY_PROTECTED_MSG = 'All direct access of ' \
              '%<accessed_engine>s engine disallowed because ' \
              'it is in StronglyProtectedEngines list.'

        STRONGLY_PROTECTED_CURRENT_MSG = 'Direct ' \
              'access of %<accessed_engine>s is disallowed in this file ' \
              'because it\'s in the %<current_engine>s engine, which ' \
              'is in the StronglyProtectedEngines list.'

        MAIN_APP_NAME = 'MainApp::EngineApi'

        def_node_matcher :rails_association_hash_args, <<-PATTERN
          (send _ {:belongs_to :has_one :has_many} sym $hash)
        PATTERN

        def on_const(node)
          return if in_module_or_class_declaration?(node)
          # There might be value objects that are named
          # the same as engines like:
          #
          # Warehouse.new
          #
          # We don't want to warn on these cases either.
          return if sending_method_to_namespace_itself?(node)

          accessed_engine = extract_accessed_engine(node)
          return unless accessed_engine
          return if valid_engine_access?(node, accessed_engine)

          add_offense(node, message: message(accessed_engine))
        end

        def on_send(node)
          rails_association_hash_args(node) do |assocation_hash_args|
            check_for_cross_engine_rails_association(node, assocation_hash_args)
          end
          return unless check_for_cross_engine_factory_bot?

          factory_bot_usage(node) do |factory_node|
            check_for_cross_engine_factory_bot_usage(node, factory_node)
          end
        end

        def check_for_cross_engine_rails_association(node, assocation_hash_args)
          class_name_node = extract_class_name_node(assocation_hash_args)
          return if class_name_node.nil?

          accessed_engine = extract_model_engine(class_name_node)
          return if accessed_engine.nil?
          return if valid_engine_access?(node, accessed_engine)

          add_offense(class_name_node, message: message(accessed_engine))
        end

        def check_for_cross_engine_factory_bot_usage(node, factory_node)
          factory = factory_node.children[0]
          accessed_engine, model_class_name = factory_engines[factory]
          return if accessed_engine.nil? || !protected_engines.include?(accessed_engine)

          model_class_node = parse_ast(model_class_name)
          return if valid_engine_access?(model_class_node, accessed_engine)

          add_offense(node, message: message(accessed_engine))
        end

        def external_dependency_checksum
          @checksums ||= {}
          checksum = engines_paths.sum('') do |engine_path|
            @checksums[engine_path] ||= engine_api_files_modified_time_checksum(engine_path)
          end
          return checksum unless check_for_cross_engine_factory_bot?

          checksum + spec_factories_modified_time_checksum
        end

        private

        def message(accessed_engine)
          if strongly_protected_engine?(accessed_engine)
            format(STRONGLY_PROTECTED_MSG, accessed_engine: accessed_engine)
          elsif strongly_protected_engine?(current_engine)
            format(
              STRONGLY_PROTECTED_CURRENT_MSG,
              accessed_engine: accessed_engine,
              current_engine: current_engine
            )
          else
            format(MSG, accessed_engine: accessed_engine)
          end
        end

        def extract_accessed_engine(node)
          return MAIN_APP_NAME if disallowed_main_app_access?(node)
          return nil unless protected_engines.include?(node.const_name)

          node.const_name
        end

        def disallowed_main_app_access?(node)
          strongly_protected_engine?(current_engine) && main_app_access?(node)
        end

        def main_app_access?(node)
          node.const_name.start_with?(MAIN_APP_NAME)
        end

        def engines_path
          return './' if cop_config['Engines']

          path = cop_config['EnginesPath']
          path += '/' unless path.end_with?('/')
          path
        end

        def engines_paths
          return [engines_path] unless cop_config['Engines']

          cop_config['Engines'].map do |engine|
            engine.end_with?('/') ? engine : "#{engine}/"
          end
        end

        def protected_engines
          @protected_engines ||= begin
            unprotected = cop_config['UnprotectedEngines'] || []
            unprotected_camelized = camelize_all(unprotected)
            engines = all_engines_camelized - unprotected_camelized
            engines = engines.map { |engine| "#{cop_config['EnginesPrefix']}::#{engine}" } if cop_config['EnginesPrefix']
            engines
          end
        end

        def all_engines_camelized
          all_snake_case = cop_config['Engines'] || Dir["#{engines_path}*"].map do |e|
            e.gsub(engines_path, '')
          end
          camelize_all(all_snake_case)
        end

        def camelize_all(names)
          names.map { |n| ActiveSupport::Inflector.camelize(n) }
        end

        def sending_method_to_namespace_itself?(node)
          node.parent&.send_type?
        end

        def valid_engine_access?(node, accessed_engine)
          return true if in_engine_file?(accessed_engine)
          return true if engine_specific_override?(node)

          return false if strongly_protected_engine?(current_engine)
          return false if strongly_protected_engine?(accessed_engine)

          valid_engine_api_access?(node, accessed_engine)
        end

        def valid_engine_api_access?(node, accessed_engine)
          (
            in_legacy_dependent_file?(accessed_engine) ||
            through_api?(node) ||
            allowlisted?(node, accessed_engine)
          )
        end

        def extract_model_engine(class_name_node)
          class_name = class_name_node.value
          prefix = class_name.split('::')[0]
          is_engine_model = prefix && protected_engines.include?(prefix)
          is_engine_model ? prefix : nil
        end

        def extract_class_name_node(assocation_hash_args)
          return nil unless assocation_hash_args

          assocation_hash_args.each_pair do |key, value|
            # Note: The "value.str_type?" is necessary because you can do this:
            #
            # TYPE_CLIENT = "Client".freeze
            # belongs_to :recipient, class_name: TYPE_CLIENT
            #
            # The cop just ignores these cases. We could try to resolve the
            # value of the const from the source but that seems brittle.
            return value if key.value == :class_name && value.str_type?
          end
          nil
        end

        def current_engine
          @current_engine ||= engine_name_from_path(processed_source.path)
        end

        def engine_name_from_path(file_path)
          engine_dir = cop_config['Engines'] ? engine_dir_by_engines(file_path) : engine_dir_by_engines_path(file_path)
          [cop_config['EnginesPrefix'], ActiveSupport::Inflector.camelize(engine_dir)].compact.join('::') if engine_dir
        end

        def engine_dir_by_engines(file_path)
          cop_config['Engines'].each_with_object({ index: Float::INFINITY }) do |engine, hash|
            index = file_path&.index("/#{engine}/")
            hash[:engine] = engine if index && index < hash[:index]
          end[:engine]
        end

        def engine_dir_by_engines_path(file_path)
          return unless file_path&.include?(engines_path)

          parts = file_path.split(engines_path)
          parts.last.split('/').first
        end

        def in_engine_file?(accessed_engine)
          current_engine == accessed_engine
        end

        def in_legacy_dependent_file?(accessed_engine)
          legacy_dependents = read_api_file(accessed_engine, :legacy_dependents)
          # The file names are strings so we need to remove the escaped quotes
          # on either side from the source code.
          legacy_dependents = legacy_dependents.map do |source|
            source.delete('"')
          end
          legacy_dependents.any? do |legacy_dependent|
            processed_source.path.include?(legacy_dependent)
          end
        end

        def through_api?(node)
          node.parent&.const_type? && node.parent.children.last == :Api
        end

        def allowlisted?(node, engine)
          allowlist = read_api_file(engine, :allowlist)
          allowlist = read_api_file(engine, :whitelist) if allowlist.empty?
          return false if allowlist.empty?

          depth = 0
          max_depth = 5
          while node&.const_type? && depth < max_depth
            full_const_name = remove_leading_colons(node.source)
            return true if allowlist.include?(full_const_name)

            node = node.parent
            depth += 1
          end

          false
        end

        def remove_leading_colons(str)
          str.sub(/^:*/, '')
        end

        def read_api_file(engine, file_basename)
          extract_api_list(engines_path, engine, file_basename)
        end

        def overrides_by_engine
          overrides_by_engine = {}
          raw_overrides = cop_config['EngineSpecificOverrides']
          return overrides_by_engine if raw_overrides.nil?

          raw_overrides.each do |raw_override|
            engine = ActiveSupport::Inflector.camelize(raw_override['Engine'])
            overrides_by_engine[engine] = raw_override['AllowedModules']
          end
          overrides_by_engine
        end

        def engine_specific_override?(node)
          return false unless overrides_for_current_engine

          depth = 0
          max_depth = 5
          while node&.const_type? && depth < max_depth
            module_name = node.source
            return true if overrides_for_current_engine.include?(module_name)

            node = node.parent
            depth += 1
          end
          false
        end

        def overrides_for_current_engine
          overrides_by_engine[current_engine]
        end

        def strongly_protected_engines
          @strongly_protected_engines ||= begin
            strongly_protected = cop_config['StronglyProtectedEngines'] || []
            camelize_all(strongly_protected)
          end
        end

        def strongly_protected_engine?(engine)
          strongly_protected_engines.include?(engine)
        end

        def factory_bot_outbound_access_allowed_engines
          @factory_bot_outbound_access_allowed_engines ||=
            camelize_all(cop_config['FactoryBotOutboundAccessAllowedEngines'] || [])
        end

        def factory_bot_enabled?
          cop_config['FactoryBotEnabled']
        end

        def check_for_cross_engine_factory_bot?
          spec_file? &&
            factory_bot_enabled? &&
            !factory_bot_outbound_access_allowed_engines.include?(current_engine)
        end

        # Maps factories to the engine where they are defined.
        def factory_engines
          @factory_engines ||= find_factories.each_with_object({}) do |factory_file, h|
            path, factories = factory_file
            engine_name = engine_name_from_path(path)
            factories.each do |factory, model_class_name|
              h[factory] = [engine_name, model_class_name]
            end
          end
        end

        def spec_factories_modified_time_checksum
          mtimes = factory_files.sort.map { |f| File.mtime(f) }
          Digest::SHA1.hexdigest(mtimes.join)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
