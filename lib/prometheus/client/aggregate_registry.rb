require 'pstore'

module Prometheus
  module Client
    class AggregateMetric
      attr_reader :name

      def initialize(aggregate_registry, name)
        @aggregate_registry = aggregate_registry
        @name = name
      end

      def type
        first_instance[:type]
      end

      def docstring
        first_instance[:docstring]
      end

      def base_labels
        first_instance[:base_labels]
      end

      def values
        @aggregate_registry.values(@name).each_with_object({}) do |values, h|
          values.each do |k,v|
            h[k] = v
          end
        end
      end

      private

      def first_instance
        @first_instance ||= @aggregate_registry.first_instance(@name)
        @first_instance
      end
      
    end

    class AggregateRegistry
      def initialize
      end

      def scan
        store_dir = "#{Dir.tmpdir()}/prometheus-#{Process.ppid}"
        @files = Dir["#{store_dir}/**/*.pstore"]
        @names = []
        get_names
      end

      def get_names
        @files.each do |file|
          store = PStore.new(file)
          store.transaction(true) do
            store.roots.each do |root_name| # might not need to loop here, store.roots.values or something
              @names << root_name
            end
          end
        end

        @names.uniq!
      end

      def metrics
        @names.map { |name| AggregateMetric.new(self, name) }
      end

      def first_instance(name)
        @files.each do |file|
          store = PStore.new(file)
          store.transaction(true) do
            return store[name] if store[name]
          end
        end

        return nil
      end

      def values(name)
        values = []

        @files.each do |file|
          store = PStore.new(file)
          store.transaction(true) do
            values << store[name][:values] if store[name] && store[name][:values]
          end
        end
        
        values
      end
    end
  end
end
