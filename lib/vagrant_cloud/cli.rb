require 'thor'

module VagrantCloud
  class Cli < Thor
    package_name 'VagrantCloud'

    class_option :username, alias: '-u', desc: 'Vagrant Cloud username'
    class_option :token, alias: '-t', desc: 'Vagrant Cloud access token'
    class_option :box, alias: '-b', desc: 'name of the box'
    class_option :version, alias: '-v', desc: 'version within the box'
    class_option :provider, alias: '-p', default: 'virtualbox', desc: 'the provider for the box; default: virtualbox'
    class_option :provider_url, alias: '-pu', desc: 'URL to the file for remote hosting; either a _url or _file_path can be provided, not both'
    class_option :provider_file_path, alias: '-pfp', desc: 'path to file to be uploaded for Atlast hosting'
    class_option :verbose, type: :boolean

    desc 'create_version', 'creates a new version within a given box'
    def create_version(version_str = options[:version])
      version = current_box.create_version(version_str)
      puts "created #{version.version} of box #{options[:box]}; current status is #{version.status}" if options[:verbose]
      version
    end

    desc 'release_version', 'release the specified version within a given box'
    def release_version(version_str = options[:version])
      version = current_box.get_version(version_str)
      puts "Box #{options[:box]} / version: #{versoin.version}; current status is #{version.status}" if options[:verbose]
      true
    end

    desc 'create_provider', 'creates a provider within a given box and version'
    def create_provider
      provider = current_version.create_provider(options[:provider], options[:provider_url])
      puts "created #{provider.data['name']} provider within version #{provider.version.version}" if options[:verbose]
      provider
    end

    desc 'versions', 'list all the versions of a given box'
    def versions
      box = current_box
      puts box.versions if options[:verbose]
      box.versions
    end

    desc 'upload_file', 'upload a given file for Atlas to host to an existing version and provider'
    def upload_file
      provider = current_version.get_provider(options[:provider])
      provider.upload_file(options[:provider_file_path])
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

    def bump_version(version_str)
      parts = version_str.split('.')
      parts.push(parts.pop.to_i + 1)
      parts.join('.')
    end
  end
end
