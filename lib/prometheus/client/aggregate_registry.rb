require 'gdbm'

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
      end
      
    end

    class AggregateRegistry
      def initialize
      end

      def scan
        store_dir = "#{Dir.tmpdir()}/prometheus-#{Process.ppid}"
        @files = Dir["#{store_dir}/**/*.gdbm"]
        @names = []
        get_names
      end

      def get_names
        @files.each do |file|
          store = GDBM.new(file, 0600, GDBM::READER)
          store.keys.each do |key|
            @names << Marshal.load(key)
          end
        end

        @names.uniq!
      end

      def metrics
        @names.map { |name| AggregateMetric.new(self, name) }
      end

      def first_instance(name)
        @files.each do |file|
          store = GDBM.new(file, 0600, GDBM::READER)
          val = store[Marshal.dump(name)]
          return Marshal.load(val) if val
        end

        return nil
      end

      def values(name)
        values = []

        @files.each do |file|
          store = GDBM.new(file, 0600, GDBM::READER)
          data = Marshal.load(store[Marshal.dump(name)])
          next unless data
          values << data[:values]
        end
        
        values.compact
      end
    end
  end
end
