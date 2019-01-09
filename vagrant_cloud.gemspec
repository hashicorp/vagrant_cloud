Gem::Specification.new do |s|
  s.name        = 'vagrant_cloud'
  s.version     = '2.0.2'
  s.summary     = 'Vagrant Cloud API Library'
  s.description = 'Ruby library for the HashiCorp Vagrant Cloud API'
  s.authors     = ['HashiCorp', 'Cargo Media']
  s.email       = 'vagrant@hashicorp.com'
  s.files       = Dir['LICENSE*', 'README*', '{bin,lib}/**/*'].reject { |f|
    f.end_with?('~')
  }
  s.homepage    = 'https://github.com/hashicorp/vagrant_cloud'
  s.license     = 'MIT'

  s.add_runtime_dependency 'rest-client', '~> 2.0.2'

  s.add_development_dependency 'rake', '~> 10.4'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rubocop', '~> 0.59.1'
  s.add_development_dependency 'webmock', '~> 3.0'

  s.post_install_message = "NOTICE: As of the 2.0.0 release, the vagrant_cloud gem provides library functionality
        and no longer includes a command line client. For a command line client,
        use the `vagrant cloud` subcommand from Vagrant. Vagrant can be downloaded
        from: https://www.vagrantup.com/downloads.html"
end
