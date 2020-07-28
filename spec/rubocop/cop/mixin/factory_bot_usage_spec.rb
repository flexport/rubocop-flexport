# frozen_string_literal: true

RSpec.describe RuboCop::Cop::FactoryBotUsage do
  let(:test_cop) do
    Class.new do
      include RuboCop::Cop::FactoryBotUsage
    end
  end

  describe '#find_factories' do
    subject(:factories) { test_cop.new.find_factories(ast) }

    let(:ast) do
      source = RuboCop::ProcessedSource.new(source_code, RUBY_VERSION.to_f)
      source.ast
    end

    let(:source_code) do
      <<~'RUBY'
        module NetworkEngine
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

            # Implicit model class
            factory :terminal

            # Model class defined as string
            factory :warehouse, class: "WarehouseEngine::Warehouse"
          end
        end
      RUBY
    end

    it 'returns [factory_name, model_class_name] 2-tuples' do
      expect(factories).to contain_exactly(
        [:port, 'NetworkEngine::Port'],
        [:airport, 'NetworkEngine::Port'],
        [:airfield, 'NetworkEngine::Port'],
        [:lax, 'NetworkEngine::Port'],
        [:terminal, 'Terminal'],
        [:warehouse, 'WarehouseEngine::Warehouse']
      )
    end
  end
end
