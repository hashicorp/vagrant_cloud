require 'thor'

module VagrantCloud
  class Cli < Thor
    package_name 'VagrantCloud'

    class_option :username, alias: '-u', required: true, desc: 'Vagrant Cloud username'
    class_option :token, alias: '-t', required: true, desc: 'Vagrant Cloud access token'
    class_option :box, alias: '-b', required: true, desc: 'name of the box'
    class_option :verbose, type: :boolean

    desc 'create_version', 'creates a new version within a given box'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    def create_version
      version = current_box.create_version(options[:version])
      puts "created #{version.version} of box #{options[:box]}; current status is #{version.status}" if options[:verbose]
      version
    end

    desc 'release_version', 'release the specified version within a given box'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    def release_version
      version = current_version
      version.release
      puts "Box #{options[:box]} / version: #{version.version}; current status is #{version.status}" if options[:verbose]
      true
    end

    desc 'create_provider', 'creates a provider within a given box and version'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    method_option :provider, alias: '-p', default: 'virtualbox', desc: 'the provider for the box; default: virtualbox'
    method_option :provider_url, alias: '-pu', desc: 'URL to the file for remote hosting; do not include if you intend to upload a file subsequently'
    def create_provider
      provider = current_version.create_provider(options[:provider], options[:provider_url])
      puts "created #{provider.data['name']} provider within version #{provider.version.version}" if options[:verbose]
      provider
    end

    desc 'upload_file', 'upload a file for Atlas to host to an existing version and provider'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    method_option :provider, alias: '-p', default: 'virtualbox', desc: 'the provider for the box; default: virtualbox'
    method_option :provider_file_path, alias: '-pfp', required: true, desc: 'path to file to be uploaded for Atlast hosting'
    def upload_file
      get_provider(options[:provider]).upload_file(options[:provider_file_path])
    end

    private

    def current_account
      VagrantCloud::Account.new(options[:username], options[:token])
    end

    def current_box
      current_account.get_box(options[:box])
    end

    def current_version
      current_box.get_version(options[:version])
    end

    def get_provider(provider_str)
      current_version.get_provider(provider_str)
    end
  end
end
