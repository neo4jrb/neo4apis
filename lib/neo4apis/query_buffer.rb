module Neo4Apis
  class QueryBuffer < Array

    def initialize(neo4j_session, flush_size)
      @neo4j_session = neo4j_session
      @flush_size = flush_size

      @faraday_connection = @neo4j_session.connection

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
      return if empty?

      @faraday_connection.post do |req|
        req.url '/db/data/transaction/commit'
        req.headers['Accept'] = 'application/json; charset=UTF-8'
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Stream'] = 'true'
        req.body = request_body_data.to_json
      end.tap do |response|
        if response.status != 200
          fail "ERROR: response status #{response.status}:\n#{response.body}"
        else
          response_data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
          response_errors = response_data[:errors] || response_data['errors']

          if response_errors.size > 0
            error_string = response_errors.map do |error|
              [error[:code] || error['code'], error[:message] || error['message']].join("\n")
            end.join("\n\n")

            fail "ERROR: Cypher response error:\n" + error_string
          end
        end
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

