module Neo4Apis
  module CLI
    class Base < ::Thor
      class_option :neo4j_url, type: :string,  default: 'http://localhost:7474'
    end
  end
end


