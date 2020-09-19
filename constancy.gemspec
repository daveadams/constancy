require_relative 'lib/constancy/version.rb'

Gem::Specification.new do |s|
  s.name = 'constancy'
  s.version = Constancy::VERSION
  s.authors = ['David Adams']
  s.email = 'daveadams@gmail.com'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.license = 'CC0'
  s.homepage = 'https://github.com/daveadams/constancy'
  s.required_ruby_version = '>=2.4.0'

  s.summary = 'Simple filesystem-to-Consul KV synchronization'
  s.description =
    'Syncs content from the filesystem to the Consul KV store.'

  s.require_paths = ['lib']
  s.files = Dir["lib/**/*.rb"] + [
    'bin/constancy',
    'README.md',
    'LICENSE',
    'constancy.gemspec'
  ]
  s.bindir = 'bin'
  s.executables = ['constancy']

  s.add_dependency 'imperium', '~>0.3'
  s.add_dependency 'diffy', '~>3.2'
  s.add_dependency 'vault', '~>0.12'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake', '~> 12.0'
end
