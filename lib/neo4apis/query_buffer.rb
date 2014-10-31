module Neo4Apis
  class QueryBuffer < Array

    def initialize(neo4j_session, flush_size)
      @neo4j_session = neo4j_session
      @flush_size = flush_size

      uri = URI.parse(@neo4j_session.resource_url)

      @faraday_connection = Faraday.new(:url => "#{uri.scheme}://#{uri.host}:#{uri.port}") do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      super()
    end

    def <<(query)
      flush if size >= @flush_size

      super
    end

    def flush
      execute

      clear
    end

    def close
      flush
    end

    private

    def execute
      @faraday_connection.post do |req|
        req.url '/db/data/transaction/commit'
        req.headers['Accept'] = 'application/json; charset=UTF-8'
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Stream'] = 'true'
        req.body = request_body_data.to_json
      end
    end

    def request_body_data
      {
        statements: self.map do |query|
          {
            statement: query.to_cypher,
            parameters: query.send(:merge_params)
          }
        end
      }
    end

  end
end

