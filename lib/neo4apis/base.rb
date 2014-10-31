module Neo4Apis
  class Base
    UUID_FIELDS = {}
    NODE_PROXIES = {}
    IMPORTERS = {}

    attr_reader :options

    def initialize(neo4j_session, options = {})
      @buffer = QueryBuffer.new(neo4j_session, options[:flush_size] || self.class.default_flush_size)
      @options = options

      UUID_FIELDS.each do |label, uuid_field|
        @buffer << create_constraint_query(label, uuid_field)
      end
      @buffer.flush
    end

    def add_node(label, props = {})
      require_batch

      raise ArgumentError, "No UUID specified for label `#{label}`" if not UUID_FIELDS[label.to_sym]

      self.class.node_proxy(label).new(props).tap do |node_proxy|
        @buffer << create_node_query(node_proxy)
      end
    end

    def add_relationship(type, source, target, props = {})
      raise ArgumentError, "No source specified" if not source
      raise ArgumentError, "No target specified" if not target

      require_batch

      @buffer << create_relationship_query(type, source, target, props)
    end

    def batch(&block)
      @in_batch = true

      instance_eval &block

      @buffer.close
    ensure
      @in_batch = false
    end

    def import(label, object)
      self.instance_exec object, &IMPORTERS[label.to_sym]
    end

    def self.prefix(prefix)
      @prefix = prefix
    end

    def self.importer(label, &block)
      IMPORTERS[label.to_sym] = block
    end

    def self.uuid(label, uuid_field)
      UUID_FIELDS[label.to_sym] = uuid_field.to_sym
    end

    def self.node_proxy(label)
      uuid_field = UUID_FIELDS[label.to_sym]

      NODE_PROXIES[label.to_sym] ||= node_proxy_from_uuid(label, uuid_field)
    end

    def self.node_proxy_from_uuid(label, uuid_field)
      Struct.new(:props) do
        const_set(:UUID_FIELD, uuid_field.to_sym)
        const_set(:LABEL, label.to_sym)

        def uuid_field
          self.class::UUID_FIELD
        end

        def label
          self.class::LABEL
        end

        def uuid_value
          raise ArgumentError, "props does not have UUID field `#{uuid_field}` for #{self.inspect}" if not props.has_key?(uuid_field)

          props[uuid_field]
        end
      end
    end

    def self.default_flush_size
      500
    end

    private

    def create_node_query(node_proxy)
      Neo4j::Core::Query.new.
        merge(node: {self.class.full_label(node_proxy.label) => {node_proxy.uuid_field => node_proxy.uuid_value}}).
        on_create_set(node: node_proxy.props)
    end

    def create_relationship_query(type, source, target, props)
      Neo4j::Core::Query.new.
        match(source: {self.class.full_label(source.label) => {source.uuid_field => source.uuid_value}}).
        match(target: {self.class.full_label(target.label) => {target.uuid_field => target.uuid_value}}).
        merge("source-[rel:#{type}]->target").
        on_create_set(rel: props)
    end

    def create_constraint_query(label, uuid_field)
      Neo4j::Core::Query.new.create("CONSTRAINT ON (node:#{self.class.full_label(label)}) ASSERT node.#{uuid_field} IS UNIQUE")
    end

    def self.full_label(label)
      "#{@prefix}#{label}".to_sym
    end

    def require_batch
      raise "Must be in a batch" if not @in_batch
    end
  end
end
