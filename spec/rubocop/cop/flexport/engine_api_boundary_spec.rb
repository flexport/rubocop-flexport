# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Flexport::EngineApiBoundary do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new(
      'Flexport/EngineApiBoundary' => config_params
    )
  end

  let(:config_params) do
    {
      'UnprotectedEngines' => %w[
        UnprotectedEngine
        unprotected_engine_snake_case
      ],
      'EnginesPath' => 'engines'
    }
  end

  let(:api_path) { 'engines/my_engine/app/api/my_engine/api/' }
  let(:legacy_dependents_file) { api_path + '_legacy_dependents.rb' }
  let(:whitelist_file) { api_path + '_whitelist.rb' }
  let(:allowlist_file) { api_path + '_allowlist.rb' }

  before do
    allow(File).to receive(:file?).and_call_original
    allow(Dir).to(
      receive(:[])
        .with('engines/*')
        .and_return([
                      'engines/my_engine',
                      'engines/other_engine',
                      'engines/generic_name',
                      'engines/unprotected_engine',
                      'engines/override_engine'
                    ])
    )
    allow(File).to(
      receive(:file?).with(/_legacy_dependents/).and_return(false)
    )
    allow(File).to(
      receive(:file?).with(/_whitelist/).and_return(false)
    )
    allow(File).to(
      receive(:file?).with(/_allowlist/).and_return(false)
    )
  end

  context 'method call on the constant itself' do
    context 'when constructor' do
      let(:source) do
        <<~RUBY
          GenericName.new
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when random method' do
      let(:source) do
        <<~RUBY
          GenericName.from_foo_bar
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when namepsaced not engine leading ::' do
      let(:source) do
        <<~RUBY
          ::Types::GenericName.from_foo
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when namepsaced not engine' do
      let(:source) do
        <<~RUBY
          Types::GenericName.from_foo
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end
  end

  context 'when going through interface' do
    let(:source) do
      <<~RUBY
        class Controller < ApplicationController
          def foo
            MyEngine::Api.foo
            MyEngine::Api::Nested.foo
            EndsWithMyEngine::NoApi.foo
            res = MyEngine::Api::NestedClass
          end
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when module declaration' do
    let(:source) do
      <<~RUBY
        module Mutations
          module GenericName
            module Foo
              class Bar < Mutations::BaseMutation
                def baz
                  1
                end
              end
            end
          end
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when top-level module declaration' do
    let(:source) do
      <<~RUBY
        module OtherEngine::Constants::Countries::Usa
          FOO = "bar"
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when main app API and not StronglyProtectedEngine' do
    let(:file) do
      '/root/engines/my_engine/app/services/my_engine/my_service.rb'
    end
    let(:source) do
      <<~RUBY
        class MyEngine
          def foo
            MainApp::EngineApi::ApiModule.bar
          end
        end
      RUBY
    end

    it 'adds offense' do
      expect_no_offenses(source, file)
    end
  end

  context 'when unprotected engine' do
    let(:source) do
      <<~RUBY
        class Controller < ApplicationController
          def foo
            UnprotectedEngine::NoApi.foo
          end
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when unprotected engine' do
    let(:source) do
      <<~RUBY
        class Controller < ApplicationController
          def foo
            UnprotectedEngineSnakeCase::NoApi.foo
          end
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when inside engine' do
    let(:file) do
      '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
    end
    let(:source) do
      <<~RUBY
        module MyEngine
          class FooController
          end
        end
        class MyEngine::NestedController < MyEngine::FooController
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source, file)
    end
  end

  context 'when class has same name as engine' do
    let(:source) do
      <<~RUBY
        module Foo
          class MyEngine
            def bar
              1
            end
          end
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'when non-engine association' do
    let(:source) do
      <<~RUBY
        class Foo < ApplicationModel
          has_one :bar, class_name: "Bar", inverse_of: :foo
        end
      RUBY
    end

    it 'does not add any offenses' do
      expect_no_offenses(source)
    end
  end

  context 'Reaching into an engine' do
    describe 'with no leading ::' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::Model.new
              ^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              MyEngine::NoApi::Nested.foo
              ^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              res = MyEngine::NestedClass
                    ^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              MyEngine
              ^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
            end
          end
        RUBY
      end

      it 'adds an offense' do
        expect_offense(source)
      end
    end

    describe 'with leading ::' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              ::MyEngine::Model.new
              ^^^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              ::MyEngine::NoApi::Nested.foo
              ^^^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              res = ::MyEngine::NestedClass
                    ^^^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
              ::MyEngine
              ^^^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
            end
          end
        RUBY
      end

      it 'adds an offense' do
        expect_offense(source)
      end
    end

    describe 'cross-engine association' do
      let(:source) do
        <<~RUBY
          class Foo < ApplicationModel
            has_one :delivery, class_name: "MyEngine::MyModel", inverse_of: :foo
                                           ^^^^^^^^^^^^^^^^^^^ Direct access of MyEngine engine. Only access engine via MyEngine::Api.
          end
        RUBY
      end

      it 'adds an offense' do
        expect_offense(source)
      end
    end

    describe 'using spec factories' do
      let(:file_path) { 'engines/my_engine/spec/foo_spec.rb' }
      let(:factory_path) { 'engines/other_engine/spec/factories/port.rb' }
      let(:factory) do
        <<~RUBY
          FactoryBot.define do
            factory :port, class: ::OtherEngine::Port
          end
        RUBY
      end
      let(:source) do
        <<~RUBY
          create(:port)
        RUBY
      end
      let(:config_params) do
        {
          'EnginesPath' => 'engines',
          'FactoryBotEnabled' => true
        }
      end

      before do
        allow(Dir)
          .to receive(:[])
          .with(a_string_matching(/factories/))
          .and_return([factory_path])
        allow(File)
          .to receive(:read)
          .with(factory_path)
          .and_return(factory)
      end

      # We cache factories at the class level, so that we don't have to compute
      # them again for every file. Clear the cache after each test to ensure we
      # run each test with a clean slate.
      after do
        RuboCop::Cop::FactoryBotUsage.factories_cache = nil
      end

      context 'when file is not a spec' do
        let(:file_path) { 'engines/my_engine/lib/foo.rb' }

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end

      context 'when factory is defined in same engine' do
        let(:factory_path) { 'engines/my_engine/spec/factories/port.rb' }

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end

      context 'when factory is defined in other engine' do
        let(:source) do
          <<~RUBY
            create(:port)
            ^^^^^^^^^^^^^ Direct access of OtherEngine engine. Only access engine via OtherEngine::Api.
          RUBY
        end

        it 'adds an offense' do
          expect_offense(source, file_path)
        end
      end

      context "when model is in other engine's allowlist" do
        let(:allowlist_source) do
          <<~RUBY
            module OtherEngine::Api::Allowlist
              PUBLIC_TYPES = [
                OtherEngine::Port,
              ]
            end
          RUBY
        end
        let(:allowlist_file) { 'engines/other_engine/app/api/other_engine/api/_allowlist.rb' }

        before do
          allow(File).to(
            receive(:file?)
              .with(allowlist_file)
              .and_return(true)
          )
          allow(File).to(
            receive(:read)
              .with(allowlist_file)
              .and_return(allowlist_source)
          )
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end

      context 'when engine is in the allowed list' do
        let(:config_params) do
          {
            'EnginesPath' => 'engines',
            'FactoryBotOutboundAccessAllowedEngines' => ['my_engine']
          }
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end

      context 'when engine is unprotected' do
        let(:config_params) do
          {
            'EnginesPath' => 'engines',
            'UnprotectedEngines' => ['other_engine']
          }
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end

      context 'when feature is disabled' do
        let(:config_params) do
          {
            'EnginesPath' => 'engines',
            'FactoryBotEnabled' => false
          }
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file_path)
        end
      end
    end
  end

  context 'when allowlist defined' do
    let(:allowlist_source) do
      <<~RUBY
        module MyEngine::Api::Allowlist
          PUBLIC_MODULES = [
            MyEngine::AllowlistedModule,
          ]
        end
      RUBY
    end

    before do
      allow(File).to(
        receive(:file?)
          .with(allowlist_file)
          .and_return(true)
      )
      allow(File).to(
        receive(:read)
          .with(allowlist_file)
          .and_return(allowlist_source)
      )
    end

    context 'when allowlisted public service' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::AllowlistedModule.bar
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when allowlisted public constant' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::AllowlistedModule::CRUX
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when allowlisted method accessed with leading :: and expect' do
      let(:source) do
        <<~RUBY
          expect(::MyEngine::AllowlistedModule).to_not receive(:foo)
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when allowlisted public constant in array' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              if [
                MyEngine::AllowlistedModule::NOT_MANIFESTED,
              ]
                1
              end
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end
  end

  context 'when whitelist defined' do
    let(:whitelist_source) do
      <<~RUBY
        module MyEngine::Api::Whitelist
          PUBLIC_MODULES = [
            MyEngine::WhitelistedModule,
          ]
        end
      RUBY
    end

    before do
      allow(File).to(
        receive(:file?)
          .with(whitelist_file)
          .and_return(true)
      )
      allow(File).to(
        receive(:read)
          .with(whitelist_file)
          .and_return(whitelist_source)
      )
    end

    context 'when whitelisted public service' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::WhitelistedModule.bar
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when whitelisted public constant' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::WhitelistedModule::CRUX
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when whitelisted method accessed with leading :: and expect' do
      let(:source) do
        <<~RUBY
          expect(::MyEngine::WhitelistedModule).to_not receive(:foo)
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end

    context 'when whitelisted public constant in array' do
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              if [
                MyEngine::WhitelistedModule::NOT_MANIFESTED,
              ]
                1
              end
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source)
      end
    end
  end

  context 'when LegacyDependents defined' do
    let(:legacy_dependents_source) do
      <<~RUBY
        module MyEngine::Api::LegacyDependents
          FILES_WITH_DIRECT_ACCESS = [
            "app/models/some_old_legacy_model.rb",
            "engines/other_engine/app/services/other_engine/other_service.rb",
          ]
        end
      RUBY
    end

    before do
      allow(File).to(
        receive(:file?)
          .with(legacy_dependents_file)
          .and_return(true)
      )
      allow(File).to(
        receive(:read)
          .with(legacy_dependents_file)
          .and_return(legacy_dependents_source)
      )
    end

    context 'when in legacy dependent file' do
      let(:file) { '/root/app/models/some_old_legacy_model.rb' }
      let(:source) do
        <<~RUBY
          class Controller < ApplicationController
            def foo
              MyEngine::SomethingPrivateFoo.bar
            end
          end
        RUBY
      end

      it 'does not add any offenses' do
        expect_no_offenses(source, file)
      end
    end
  end

  describe '#external_dependency_checksum' do
    it 'returns a string' do
      expect(cop.external_dependency_checksum.is_a?(String)).to be(true)
    end
  end

  context 'engine-specific overrides' do
    context 'when defined' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine::AllowedModel']
            }]
          }
        )
      end

      context 'when allowed model' do
        let(:source) do
          <<~RUBY
            OverrideEngine::AllowedModel.first
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed model' do
        let(:source) do
          <<~RUBY
            OverrideEngine::NotAllowedDelivery.first
            ^^^^^^^^^^^^^^ Direct access of OverrideEngine engine. Only access engine via OverrideEngine::Api.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end
  end

  context 'strongly protected engines' do
    let(:config) do
      RuboCop::Config.new(
        'Flexport/EngineApiBoundary' => {
          'StronglyProtectedEngines' => ['MyEngine'],
          'EnginesPath' => 'engines'
        }
      )
    end

    context 'outbound access' do
      let(:file) do
        '/root/engines/my_engine/app/services/my_engine/my_service.rb'
      end
      context 'when main app API' do
        let(:source) do
          <<~RUBY
            class MyEngine
              def foo
                MainApp::EngineApi::ApiModule.bar
                ^^^^^^^^^^^^^^^^^^ Direct access of MainApp::EngineApi is disallowed in this file because it's in the MyEngine engine, which is in the StronglyProtectedEngines list.
              end
            end
          RUBY
        end

        it 'adds offense' do
          expect_offense(source, file)
        end
      end

      context 'when other engine has API' do
        context 'when other engine api' do
          let(:source) do
            <<~RUBY
              class MyEngine
                def foo
                  OtherEngine::Api::ApiModule.bar
                  ^^^^^^^^^^^ Direct access of OtherEngine is disallowed in this file because it's in the MyEngine engine, which is in the StronglyProtectedEngines list.
                end
              end
            RUBY
          end

          it 'adds offense' do
            expect_offense(source, file)
          end
        end
      end

      context 'when other engine has whitelist' do
        let(:whitelist_source) do
          <<~RUBY
            module OtherEngine::Api::Whitelist
              PUBLIC_MODULES = [
                OtherEngine::WhitelistedModule,
              ]
            end
          RUBY
        end
        let(:file) do
          '/root/engines/my_engine/app/services/my_engine/my_service.rb'
        end
        let(:api_path) { 'engines/other_engine/app/api/other_engine/api/' }
        let(:whitelist_file) { api_path + '_whitelist.rb' }

        before do
          allow(File).to(
            receive(:file?)
              .with(whitelist_file)
              .and_return(true)
          )
          allow(File).to(
            receive(:read)
              .with(whitelist_file)
              .and_return(whitelist_source)
          )
        end

        context 'when whitelisted public service' do
          let(:source) do
            <<~RUBY
              class MyEngine
                def foo
                  OtherEngine::WhitelistedModule.bar
                  ^^^^^^^^^^^ Direct access of OtherEngine is disallowed in this file because it's in the MyEngine engine, which is in the StronglyProtectedEngines list.
                end
              end
            RUBY
          end

          it 'adds offense' do
            expect_offense(source, file)
          end
        end
      end

      context 'when other engine has legacy_dependents' do
        let(:legacy_dependents_source) do
          <<~RUBY
            module OtherEngine::Api::LegacyDependents
              FILES_WITH_DIRECT_ACCESS = [
                'engines/my_engine/app/services/my_engine/my_service.rb',
              ]
            end
          RUBY
        end
        let(:file) do
          '/root/engines/my_engine/app/services/my_engine/my_service.rb'
        end
        let(:api_path) { 'engines/other_engine/app/api/other_engine/api/' }
        let(:legacy_dependents_file) { api_path + '_legacy_dependents.rb' }

        before do
          allow(File).to(
            receive(:file?)
              .with(legacy_dependents_file)
              .and_return(true)
          )
          allow(File).to(
            receive(:read)
              .with(legacy_dependents_file)
              .and_return(legacy_dependents_source)
          )
        end

        context 'when legacy dependent' do
          let(:source) do
            <<~RUBY
              class MyEngine
                def foo
                  OtherEngine::WhitelistedModule.bar
                  ^^^^^^^^^^^ Direct access of OtherEngine is disallowed in this file because it's in the MyEngine engine, which is in the StronglyProtectedEngines list.
                end
              end
            RUBY
          end

          it 'adds offense' do
            expect_offense(source, file)
          end
        end
      end
    end

    context 'inbound access' do
      context 'when whitelist defined' do
        let(:whitelist_source) do
          <<~RUBY
            module MyEngine::Api::Whitelist
              PUBLIC_MODULES = [
                MyEngine::WhitelistedModule,
              ]
            end
          RUBY
        end

        before do
          allow(File).to(
            receive(:file?)
              .with(whitelist_file)
              .and_return(true)
          )
          allow(File).to(
            receive(:read)
              .with(whitelist_file)
              .and_return(whitelist_source)
          )
        end

        context 'when whitelisted public service' do
          let(:source) do
            <<~RUBY
              class Controller < ApplicationController
                def foo
                  MyEngine::WhitelistedModule.bar
                  ^^^^^^^^ All direct access of MyEngine engine disallowed because it is in StronglyProtectedEngines list.
                end
              end
            RUBY
          end

          it 'adds offense' do
            expect_offense(source)
          end
        end
      end

      context 'when whitelisted public constant' do
        let(:source) do
          <<~RUBY
            class Controller < ApplicationController
              def foo
                MyEngine::WhitelistedModule::CRUX
                ^^^^^^^^ All direct access of MyEngine engine disallowed because it is in StronglyProtectedEngines list.
              end
            end
          RUBY
        end

        it 'adds offense' do
          expect_offense(source)
        end
      end

      context 'when legacy dependents defined' do
        let(:legacy_dependents_source) do
          <<~RUBY
            module MyEngine::Api::LegacyDependents
              FILES_WITH_DIRECT_ACCESS = [
                "app/models/some_old_legacy_model.rb",
                "engines/other_engine/app/services/other_engine/other_service.rb",
              ]
            end
          RUBY
        end

        before do
          allow(File).to(
            receive(:file?)
              .with(legacy_dependents_file)
              .and_return(true)
          )
          allow(File).to(
            receive(:read)
              .with(legacy_dependents_file)
              .and_return(legacy_dependents_source)
          )
        end

        context 'when in legacy dependent file' do
          let(:file) { '/root/app/models/some_old_legacy_model.rb' }
          let(:source) do
            <<~RUBY
              class Controller < ApplicationController
                def foo
                  MyEngine::SomethingPrivateFoo.bar
                  ^^^^^^^^ All direct access of MyEngine engine disallowed because it is in StronglyProtectedEngines list.
                end
              end
            RUBY
          end

          it 'adds offenses' do
            expect_offense(source, file)
          end
        end
      end
    end

    context 'when EngineSpecificOverrides defined' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'StronglyProtectedEngines' => ['OverrideEngine'],
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine::AllowedModel']
            }]
          }
        )
      end

      context 'when allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::AllowedModel.first
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::NotAllowedDelivery.first
            ^^^^^^^^^^^^^^ All direct access of OverrideEngine engine disallowed because it is in StronglyProtectedEngines list.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end

    context 'when EngineSpecificOverrides for entire top-level module' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'StronglyProtectedEngines' => ['OverrideEngine'],
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine']
            }]
          }
        )
      end

      context 'when allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::Constants::Foo::BAR
            OverrideEngine::Constants::Foo::BAZ
            OverrideEngine.new
            OverrideEngine::FooBatBar
            OverrideEngine::FooBatBar.new
            OverrideEngine::FooBatBar::BAZAP
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed module' do
        let(:source) do
          <<~RUBY
            OtherEngine::Constants::Foo::BAR
            ^^^^^^^^^^^ Direct access of OtherEngine engine. Only access engine via OtherEngine::Api.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end

    context 'when EngineSpecificOverrides defined with constant' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'StronglyProtectedEngines' => ['OverrideEngine'],
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine::Constants::Foo']
            }]
          }
        )
      end

      context 'when allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::Constants::Foo::BAR
            OverrideEngine::Constants::Foo::BAZ
            OverrideEngine::Constants::Foo
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::Constants::NotFoo::BAR
            ^^^^^^^^^^^^^^ All direct access of OverrideEngine engine disallowed because it is in StronglyProtectedEngines list.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end

    context 'when EngineSpecificOverrides defined with specific constant' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'StronglyProtectedEngines' => ['OverrideEngine'],
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine::Constants::Foo::BAR']
            }]
          }
        )
      end

      context 'when allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::Constants::Foo::BAR
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::Constants::Foo::BAZ
            ^^^^^^^^^^^^^^ All direct access of OverrideEngine engine disallowed because it is in StronglyProtectedEngines list.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end

    context 'when EngineSpecificOverrides defined at class level with new' do
      let(:file) do
        '/root/engines/my_engine/app/controllers/my_engine/foo_controller.rb'
      end

      let(:config) do
        RuboCop::Config.new(
          'Flexport/EngineApiBoundary' => {
            'StronglyProtectedEngines' => ['OverrideEngine'],
            'UnprotectedEngines' => ['FooIgnoredEngine'],
            'EnginesPath' => 'engines',
            'EngineSpecificOverrides' => [{
              'Engine' => 'my_engine',
              'AllowedModules' => ['OverrideEngine::SomeOtherModule::Foo']
            }]
          }
        )
      end

      context 'when allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::SomeOtherModule::Foo.new
          RUBY
        end

        it 'does not add any offenses' do
          expect_no_offenses(source, file)
        end
      end

      context 'when not allowed module' do
        let(:source) do
          <<~RUBY
            OverrideEngine::SomeOtherModule::NotFoo.new
            ^^^^^^^^^^^^^^ All direct access of OverrideEngine engine disallowed because it is in StronglyProtectedEngines list.
          RUBY
        end

        it 'adds offenses' do
          expect_offense(source, file)
        end
      end
    end
  end
end
