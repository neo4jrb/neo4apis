
neo4apis is a ruby gem for building gems which import data into neo4j.  Takes care of batching of queries for better import performance

In the below example we assume that a variable `awesome_client` is passed in which allows us to make requests to the API.  This may be, for example, provided by another gem.

```ruby
  require 'neo4apis'

  module Neo4Apis
    class AwesomeSite < Base
      # Adds a prefix to labels so that they become AwesomeSiteUser and AwesomeSiteWidget
      prefix :AwesomeSite

      uuid :User, :id
      uuid :Widget, :uuid

      def import_widget_search(*args)
        @client.widget_search(*args).each do |widget|
          add_widget(widget)
        end
      end

      importer :Widget do |widget|
        user_node = add_user(widget.owner)

        # add_node comes from From Neo4Apis::Base
        # Imports the uuid and text values from the widget object to the node 
        node = add_node(:Widget, widget, [:uuid, :text]) do |node|
          # Imports the double_foo property to the node which isn't a simple copy
          node.double_foo = widget.foo * 2
        end

        # add_relationship comes from Neo4Apis::Base
        add_relationship(:owns, user_node, node)

        node
      end

      importer :User do |user|
        add_node :User, user, [:id, :username, :name]
      end

    end
  end
```

Then somebody else could use your gem in the following manner:

```ruby

neo4j_session = Neo4j::Session.open # From the neo4j-core gem
awesome_client = Awesome.open # From a theoretical API wrapping gem

neo4apis_awesome = Neo4Apis::AwesomeSite.new(neo4j_session)

neo4apis_awesome.batch do
  awesome_client.widget_search('cool').each do |widget|
    import :Widget, widget # import is provided by neo4apis
  end
end

```

