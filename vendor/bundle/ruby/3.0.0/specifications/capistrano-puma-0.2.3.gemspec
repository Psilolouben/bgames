# -*- encoding: utf-8 -*-
# stub: capistrano-puma 0.2.3 ruby lib

Gem::Specification.new do |s|
  s.name = "capistrano-puma".freeze
  s.version = "0.2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Johannes Opper".freeze]
  s.date = "2013-12-08"
  s.description = "Provide deployment tasks for puma".freeze
  s.email = ["xijo@gmx.de".freeze]
  s.homepage = "http://github.com/xijo/capistrano-puma".freeze
  s.licenses = ["WTFPL".freeze]
  s.rubygems_version = "3.2.3".freeze
  s.summary = "Provide deployment tasks for puma".freeze

  s.installed_by_version = "3.2.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<capistrano>.freeze, [">= 3.0"])
  else
    s.add_dependency(%q<capistrano>.freeze, [">= 3.0"])
  end
end
