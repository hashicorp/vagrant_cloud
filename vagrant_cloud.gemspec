Gem::Specification.new do |s|
  s.name        = 'vagrant_cloud'
  s.version     = '1.0.0'
  s.summary     = 'HashiCorp Atlas API client'
  s.description = 'Minimalistic ruby client for the HashiCorp Atlas API (previously Vagrant Cloud API)'
  s.authors     = ['Cargo Media']
  s.email       = 'tech@cargomedia.ch'
  s.files       = Dir['LICENSE*', 'README*', '{bin,lib}/**/*'].reject { |f|
    f.end_with?('~')
  }
  s.homepage    = 'https://github.com/cargomedia/vagrant_cloud'
  s.license     = 'MIT'
  s.executables << 'vagrant_cloud'

  s.add_runtime_dependency 'rest-client', '~> 2.0.2'
  s.add_runtime_dependency 'thor', '~> 0.19.4'

  s.add_development_dependency 'rake', '~> 10.4'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'webmock', '~> 3.0'
  s.add_development_dependency 'rubocop', '~> 0.41.2'
end
