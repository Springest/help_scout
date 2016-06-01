# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'help_scout/version'

Gem::Specification.new do |spec|
  spec.name          = "help_scout"
  spec.version       = HelpScout::VERSION
  spec.authors       = ["Dennis Paagman", "Miriam Tocino", "Mark Mulder"]
  spec.email         = ["dennispaagman@gmail.com", "miriam.tocino@gmail.com", "markmulder@gmail.com"]

  spec.summary       = "HelpScout is a an api client for Help Scout"
  spec.homepage      = "https://github.com/Springest/help_scout"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "httparty", "~> 0.13"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 2.0"
  spec.add_development_dependency "byebug"
end
