# -*- encoding: utf-8 -*-
require File.expand_path('../lib/crawl/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tor Erik Linnerud"]
  gem.email         = ["tor@alphasights.com"]
  gem.description   = "Crawl all pages on a domain, checking for errors"
  gem.summary       = "Crawl pages witin a domain, reporting any page that returns a bad response code"
  gem.homepage      = "http://github.com/alphasights/crawl"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "crawl"
  gem.require_paths = ["lib"]
  gem.version       = Crawl::VERSION
  gem.add_dependency('nokogiri')
  gem.add_dependency('rest-client')
  gem.add_dependency('eventmachine', '~> 1.0.0')
  gem.add_dependency('em-http-request')
end
