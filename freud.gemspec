# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'freud/version'

Gem::Specification.new do |spec|
    spec.name = "freud"
    spec.version = Freud::VERSION
    spec.authors = [ "Don Werve" ]
    spec.email = [ "don@werve.net" ]
    spec.summary = %q{Help for your inner daemons.}
    spec.description = %q{A command-line tool for launching and managing daemons and associated infrastructure.}
    spec.homepage = "http://github.com/matadon/freud"
    spec.license = "Apache-2.0"
    spec.files = `git ls-files -z`.split("\x0")
    spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]
    spec.add_development_dependency "bundler", "~> 1.6"
    spec.add_development_dependency "rake", "~> 10.0"
    spec.add_development_dependency "rspec", "~> 3.0", ">= 3.0.0"
    spec.add_development_dependency "guard", "~> 2.8"
    spec.add_development_dependency "guard-rspec", "~> 4.3"
    spec.add_development_dependency "ruby_gntp", "~> 0"
    spec.add_development_dependency "simplecov", "~> 0"
    spec.add_development_dependency "pry", "~> 0"
end
