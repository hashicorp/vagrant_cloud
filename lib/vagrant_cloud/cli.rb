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
      version = get_version(options[:version])
      version.release
      puts "Box #{options[:box]} / version: #{versoin.version}; current status is #{version.status}" if options[:verbose]
      true
    end

    desc 'create_provider', 'creates a provider within a given box and version'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    method_option :provider, alias: '-p', default: 'virtualbox', desc: 'the provider for the box; default: virtualbox'
    method_option :provider_url, alias: '-pu', desc: 'URL to the file for remote hosting; either a _url or _file_path can be provided, not both'
    def create_provider
      provider = get_version(options[:version]).create_provider(options[:provider], options[:provider_url])
      puts "created #{provider.data['name']} provider within version #{provider.version.version}" if options[:verbose]
      provider
    end

    desc 'upload_file', 'upload a given file for Atlas to host to an existing version and provider'
    method_option :version, alias: '-v', required: true, desc: 'version within the box'
    method_option :provider, alias: '-p', default: 'virtualbox', desc: 'the provider for the box; default: virtualbox'
    method_option :provider_file_path, alias: '-pfp', required: true, desc: 'path to file to be uploaded for Atlast hosting'
    def upload_file
      provider = get_version(options[:version]).get_provider(options[:provider])
      provider.upload_file(options[:provider_file_path])
    end

    private

    def current_account
      VagrantCloud::Account.new(options[:username], options[:token])
    end

    def current_box
      current_account.get_box(options[:box])
    end

    def get_version(version_str)
      current_box.get_version(version_str)
    end

    def bump_version(version_str)
      parts = version_str.split('.')
      parts.push(parts.pop.to_i + 1)
      parts.join('.')
    end
  end
end
