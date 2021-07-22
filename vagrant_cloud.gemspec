require_relative "lib/vagrant_cloud/version"

Gem::Specification.new do |s|
  s.name        = 'vagrant_cloud'
  s.version     = VagrantCloud::VERSION.to_s
  s.summary     = 'Vagrant Cloud API Library'
  s.description = 'Ruby library for the HashiCorp Vagrant Cloud API'
  s.authors     = ['HashiCorp', 'Cargo Media']
  s.email       = 'vagrant@hashicorp.com'
  s.files       = Dir['LICENSE*', 'README*', '{lib}/**/*'].reject { |f|
    f.end_with?('~')
  }
  s.homepage    = 'https://github.com/hashicorp/vagrant_cloud'
  s.license     = 'MIT'

  s.add_runtime_dependency 'excon', '~> 0.73'
  s.add_runtime_dependency 'log4r', '~> 1.1.10'
  s.add_runtime_dependency 'rexml', '~> 3.2.5'

  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'webmock', '~> 3.0'
end
