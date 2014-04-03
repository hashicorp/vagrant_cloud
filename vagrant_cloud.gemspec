Gem::Specification.new do |s|
  s.name        = 'vagrant_cloud'
  s.version     = '0.2.0'
  s.summary     = 'Vagrant Cloud API wrapper'
  s.description = 'Very minimalistic ruby wrapper for the Vagrant Cloud API'
  s.authors     = ['Cargo Media']
  s.email       = 'hello@cargomedia.ch'
  s.files       = Dir['LICENSE*', 'README*', '{bin,lib}/**/*']
  s.homepage    = 'https://github.com/cargomedia/vagrant_cloud'
  s.license     = 'MIT'

  s.add_runtime_dependency 'rest_client'

  s.add_development_dependency 'rake'
end
