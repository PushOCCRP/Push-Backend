# -*- encoding: utf-8 -*-
# stub: memcachier 0.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "memcachier".freeze
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Amit Levy".freeze]
  s.date = "2011-01-30"
  s.description = "Simple gem that sets the memcached environment variables to the values of corresponding memcachier environment variables.\n                   This makes it seemless to use MemCachier in environments like Heroku using the Dalli or other compatible memcached gem.".freeze
  s.email = "support@memcachier.com".freeze
  s.homepage = "http://www.memcachier.com".freeze
  s.rubygems_version = "2.7.0".freeze
  s.summary = "Compatibility gem for using memcached libraries with MemCachier".freeze

  s.installed_by_version = "2.7.0" if s.respond_to? :installed_by_version
end
