# -*- encoding: utf-8 -*-
# stub: fcm 0.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "fcm".freeze
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Kashif Rasul".freeze, "Shoaib Burq".freeze]
  s.date = "2016-08-04"
  s.description = "fcm provides ruby bindings to Firebase Cloud Messaging (FCM) a cross-platform messaging solution that lets you reliably deliver messages and notifications at no cost to Android, iOS or Web browsers.".freeze
  s.email = ["kashif@spacialdb.com".freeze, "shoaib@spacialdb.com".freeze]
  s.homepage = "https://github.com/spacialdb/fcm".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubyforge_project = "fcm".freeze
  s.rubygems_version = "2.7.0".freeze
  s.summary = "Reliably deliver messages and notifications via FCM".freeze

  s.installed_by_version = "2.7.0" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<httparty>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<json>.freeze, [">= 0"])
    else
      s.add_dependency(%q<httparty>.freeze, [">= 0"])
      s.add_dependency(%q<json>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<httparty>.freeze, [">= 0"])
    s.add_dependency(%q<json>.freeze, [">= 0"])
  end
end
