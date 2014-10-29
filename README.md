
neo4apis is a ruby gem for building gems which import data into neo4j.  Takes care of batching of queries for better import performance

In the below example we assume that a variable `awesome_client` is passed in which allows us to make requests to the API.  This may be, for example, provided by another gem.

```ruby
  require 'neo4apis'

  module Neo4Apis
    class AwesomeSite < Base
      PREFIX = 'awesome_site'

      def initialize(neo4j_client, options = {})
        @client = options[:awesome_client]

        options[:uuids] = (options[:uuids] || {}).merge({
          User: :id,
          Widget: :uuid
        })

        super(neo4j_client, options)
      end

      def import_widget_search(*args)
        @client.widget_search(*args).each do |widget|
          add_widget(widget)
        end
      end

      private
      
      def add_widget(widget)
        user_node = add_user(widget.owner)

        # add_node comes from From Neo4Apis::Base
        node = add_node :Widget, {
          uuid: widget.uuid,
          text: widget.text,
        }

        # add_relationship comes from Neo4Apis::Base
        add_relationship(:owns, user_node, node)

        node
      end

      def add_user(user)
        add_node :User, {
          id: user.id,
          username: user.username,
          name: user.name,
        }
      end

    end
  end
```

Then somebody else could use your gem in the following manner:

```ruby

neo4j_session = Neo4j::Session.open # From the neo4j-core gem
awesome_client = Awesome.open # From a theoretical API wrapping gem

neo4apis_awesome = Neo4Apis::AwesomeSite.new(neo4j_session, awesome_client: awesome_client)

neo4apis_awesome.batch do
  neo4apis_awesome.import_widget_search('cool') # Does a search for 'cool' via the Awesome gem and imports to the neo4j database
end

```

