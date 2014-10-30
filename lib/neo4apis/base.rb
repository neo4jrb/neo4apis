module Neo4Apis
  class Base
    DEFAULT_FLUSH_SIZE = 500

    NODE_PROXIES = {}
    IMPORTERS = {}

    attr_reader :options

    def initialize(neo4j_session, options = {})
      @buffer = QueryBuffer.new(neo4j_session)
      @options = options
      @flush_size = DEFAULT_FLUSH_SIZE
    end

    def add_node(label, props = {})
      require_batch

      node_proxy = NODE_PROXIES[label]
      raise ArgumentError, "No UUID specified for label `#{label}`" if not node_proxy

      node_proxy.new(label, props).tap do |node_proxy|
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

      @buffer.flush
    ensure
      @in_batch = false
    end

    def import(label, object)
      self.instance_exec object, &IMPORTERS[label.to_sym]
    end

    def self.importer(label, &block)
      IMPORTERS[label.to_sym] = block
    end

    def self.uuid(label, uuid_field)
      NODE_PROXIES[label.to_sym] = node_proxy_from_uuid(label.to_sym, uuid_field.to_sym)
    end

    def self.node_proxy_from_uuid(label, uuid_field)
      Struct.new(:label, :props) do
        const_set(:UUID_FIELD, uuid_field)

        def uuid_value
          raise ArgumentError, "props does not have UUID field `#{uuid_field}` for #{self.inspect}" if not props.has_key?(uuid_field)

          props[uuid_field]
        end

        def uuid_field
          self.class::UUID_FIELD
        end
      end
    end

    private

    def create_node_query(node_proxy)
      Neo4j::Core::Query.new.
        merge(node: {node_proxy.label => {node_proxy.uuid_field => node_proxy.uuid_value}}).
        on_create_set(node: node_proxy.props)
    end

    def create_relationship_query(type, source, target, props)
      Neo4j::Core::Query.new.
        match(source: {source.label => {source.uuid_field => source.uuid_value}}).
        match(target: {target.label => {target.uuid_field => target.uuid_value}}).
        merge("source-[:#{type}]->target")
    end

    def add_to_buffer(*args)
      flush_buffer if buffer.size >= FLUSH_SIZE

      @buffer << args
    end

    def require_batch
      raise "Must be in a batch" if not @in_batch
    end
  end
end
