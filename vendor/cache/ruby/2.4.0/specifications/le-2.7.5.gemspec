# -*- encoding: utf-8 -*-
# stub: le 2.7.5 ruby lib

Gem::Specification.new do |s|
  s.name = "le".freeze
  s.version = "2.7.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Mark Lacomber".freeze, "Stephen Hynes".freeze]
  s.date = "2017-02-20"
  s.description = "\n\n".freeze
  s.email = "support@logentries.com".freeze
  s.homepage = "https://github.com/rapid7/le_ruby".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.7.0".freeze
  s.summary = "Logentries plugin".freeze

  s.installed_by_version = "2.7.0" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
    else
      s.add_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<minitest>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<minitest>.freeze, [">= 0"])
  end
end
