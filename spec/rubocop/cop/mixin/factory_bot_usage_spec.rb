# frozen_string_literal: true

RSpec.describe RuboCop::Cop::FactoryBotUsage do
  let(:test_cop) do
    Class.new do
      include RuboCop::Cop::FactoryBotUsage

      def engines_path
        'engines/'
      end
    end
  end

  after do
    described_class.factories_cache = nil
  end

  describe '#find_factories' do
    subject(:factories) { test_cop.new.find_factories }

    let(:factory_files) do
      {
        'engines/network_engine/spec/factories/port_factories.rb' => <<~'RUBY',
          FactoryBot.define do
            sequence :port_name do |n|
              "Test Port ##{n}"
            end

            # Model class defined explicitly
            factory :port, class: ::NetworkEngine::Port do
              port_name { FactoryBot.generate(:port_name) }
              iata_code { nil }
              airport { false }

              # Model class derived from parent factory
              factory :airport, aliases: [:airfield] do
                airport { true }

                factory :lax do
                  iata_code { "LAX" }
                end
              end
            end
          end
        RUBY
        'spec/factories/warehouse_factories.rb' => <<~'RUBY',
          FactoryBot.define do
            # Model class defined as string
            factory :warehouse, parent: :location, class: "WarehouseEngine::Warehouse"
          end
        RUBY
        'spec/factories/cfs_factories.rb' => <<~'RUBY',
          FactoryBot.define do
            # Explicit parent
            factory :cfs, parent: :location do
              factory :flexport_cfs
            end

            factory :flexport_chicago_cfs, parent: :flexport_cfs
          end
        RUBY
        'spec/factories/location_factories.rb' => <<~'RUBY'
          FactoryBot.define do
            # Implicit model class derived from factory name
            factory :location
          end
        RUBY
      }
    end
    let(:engine_factory_paths) do
      factory_files.keys.select { |path| path.start_with?('engines/') }
    end
    let(:global_factory_paths) do
      factory_files.keys - engine_factory_paths
    end

    before do
      allow(Dir).to receive(:[]).with('spec/factories/**/*.rb').and_return(global_factory_paths)
      allow(Dir).to receive(:[]).with('engines/*/spec/factories/**/*.rb').and_return(engine_factory_paths)
      allow(File).to receive(:read) { |path| factory_files.fetch(path) }
    end

    it 'returns a mapping of factory names to model class names' do
      expect(factories).to eq(
        'engines/network_engine/spec/factories/port_factories.rb' => {
          port: 'NetworkEngine::Port',
          airport: 'NetworkEngine::Port',
          airfield: 'NetworkEngine::Port',
          lax: 'NetworkEngine::Port'
        },
        'spec/factories/warehouse_factories.rb' => {
          warehouse: 'WarehouseEngine::Warehouse'
        },
        'spec/factories/cfs_factories.rb' => {
          cfs: 'Location',
          flexport_cfs: 'Location',
          flexport_chicago_cfs: 'Location'
        },
        'spec/factories/location_factories.rb' => {
          location: 'Location'
        }
      )
    end
  end
end
