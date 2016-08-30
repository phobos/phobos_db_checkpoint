# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'phobos_db_checkpoint/version'

Gem::Specification.new do |spec|
  spec.name          = 'phobos_db_checkpoint'
  spec.version       = PhobosDBCheckpoint::VERSION
  spec.authors       = [
    'Túlio Ornelas',
    'Mathias Klippinge',
    'Sergey Evstifeev',
    'Thiago R. Colucci',
    'Martin Svalin',
    'Francisco Juan'
  ]
  spec.email         = [
    'ornelas.tulio@gmail.com',
    'mathias.klippinge@gmail.com',
    'sergey.evstifeev@gmail.com',
    'ticolucci@gmail.com',
    'martin@lite.nu',
    'francisco.juan@gmail.com'
  ]

  spec.summary       = %q{Phobos DB Checkpoint is a plugin to Phobos and is meant as a drop in replacement to Phobos::Handler}
  spec.description   = %q{Phobos DB Checkpoint is a plugin to Phobos and is meant as a drop in replacement to Phobos::Handler}
  spec.homepage      = "https://github.com/klarna/phobos_db_checkpoint"
  spec.license       = 'Apache License Version 2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/phobos_db_checkpoint}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.3'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'rspec_junit_formatter', '0.2.2'

  spec.add_dependency 'thor'
  spec.add_dependency 'rake'
  spec.add_dependency 'activerecord', '>= 4.0.0'
  spec.add_dependency 'phobos', '>= 1.0.0'
end
