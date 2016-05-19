lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name     = "neo4apis"
  s.version  = '0.9.1'
  s.required_ruby_version = ">= 1.9.1"

  s.authors  = "Brian Underwood"
  s.email    = 'public@brian-underwood.codes'
  s.homepage = "https://github.com/neo4jrb/neo4apis/"
  s.summary = "An API to import web API data to neo4j"
  s.license = 'MIT'
  s.description = <<-EOF
A core library for importing data from APIs into neo4j.  Designed to be used with an adapter
  EOF

  s.require_path = 'lib'
  s.files = Dir.glob("{bin,lib,config}/**/*") + %w(README.md Gemfile neo4apis.gemspec)

  s.bindir = 'bin'
  s.executables << 'neo4apis'

  s.add_dependency('faraday', "~> 0.9.0")
  s.add_dependency("neo4j-core", ">= 4.0.5")
  s.add_dependency('thor', '~> 0.19.1')
  s.add_dependency('colorize', '~> 0.7.3')

end
