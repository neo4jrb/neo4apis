require 'ostruct'

module Neo4Apis
  class Base
    UUID_FIELDS = {}
    NODE_PROXIES = {}
    IMPORTERS = {}
    DEFAULT_BATCH_SIZE = 500

    attr_reader :options

    def initialize(neo4j_session, options = {})
      @buffer = QueryBuffer.new(neo4j_session, options[:batch_size] || self.class.batch_size || DEFAULT_BATCH_SIZE)
      @options = options

      UUID_FIELDS.each do |label, uuid_field|
        @buffer << create_constraint_query(label, uuid_field)
      end
      @buffer.flush
    end

    def add_node(label, object = nil, columns = [])
      props = OpenStruct.new

      if object
        columns.each do |column|
          props[column] = object.send(column)
        end
      end

      yield props if block_given?

      require_batch

      fail ArgumentError, "No UUID specified for label `#{label}`" if not UUID_FIELDS[label.to_sym]

      self.class.node_proxy(label).new(props.marshal_dump).tap do |node_proxy|
        @buffer << create_node_query(node_proxy)
      end
    end

    def add_relationship(type, source, target, props = {})
      fail ArgumentError, "No source specified" if not source
      fail ArgumentError, "No target specified" if not target

      require_batch

      @buffer << create_relationship_query(type, source, target, props)
    end

    def batch
      @in_batch = true

      yield

      @buffer.close
    ensure
      @in_batch = false
    end

    def import(label, *args)
      self.instance_exec(*args, &IMPORTERS[label.to_sym])
    end

    def self.common_label(common_label = nil)
      if common_label.nil?
        @common_label
      else
        @common_label = common_label
      end
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
          fail ArgumentError, "props does not have UUID field `#{uuid_field}` for #{self.inspect}" if not props.has_key?(uuid_field)

          props[uuid_field]
        end
      end
    end

    def self.batch_size(batch_size = nil)
      if batch_size.is_a?(Integer)
        @batch_size = batch_size
      elsif batch_size.nil?
        @batch_size
      else
        fail ArgumentError, "Invalid value for batch_size: #{batch_size.inspect}"
      end
    end

    private

    def create_node_query(node_proxy)
      return if node_proxy.props.empty?

      props = node_proxy.props
      extra_labels = props.delete(:_extra_labels)

      cypher = <<-QUERY
      MERGE (node:`#{node_proxy.label}` {#{node_proxy.uuid_field}: {uuid_value}})
      SET #{set_attributes(:node, props.keys)}
QUERY

      cypher << " SET node:`#{self.class.common_label}`" if self.class.common_label

      (extra_labels || []).each do |label|
        cypher << " SET node:`#{label}`"
      end

      OpenStruct.new({to_cypher: cypher,
                      merge_params: {uuid_value: node_proxy.uuid_value, props: props}})
    end

    def create_relationship_query(type, source, target, props)
      type = type.to_s.send(relationship_transform) if relationship_transform != :none

      cypher = <<-QUERY
              MATCH (source:`#{source.label}`), (target:`#{target.label}`)
              WHERE source.#{source.uuid_field}={source_value} AND target.#{target.uuid_field}={target_value}
              MERGE (source)-[rel:`#{type}`]->(target)
QUERY

      cypher << " SET #{set_attributes(:rel, props.keys)}" unless props.empty?

      OpenStruct.new({to_cypher: cypher,
                      merge_params: {source_value: source.uuid_value, target_value: target.uuid_value, props: props}})
    end

    def relationship_transform
      (@options[:relationship_transform] || :upcase).to_sym.tap do |transform|
        fail "Invalid relationship_transform value: #{transform.inspect}" if not [:upcase, :downcase, :none].include?(transform)
      end
    end

    def set_attributes(var, properties)
      properties.map do |property|
        "#{var}.`#{property}` = {props}.`#{property}`"
      end.join(', ')
    end

    def create_constraint_query(label, uuid_field)
      Neo4j::Core::Query.new.create("CONSTRAINT ON (node:`#{label}`) ASSERT node.#{uuid_field} IS UNIQUE")
    end

    def require_batch
      fail "Must be in a batch" if not @in_batch
    end
  end
end
