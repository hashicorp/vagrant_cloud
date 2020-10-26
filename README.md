# vagrant_cloud

Ruby client for the [Vagrant Cloud API](https://www.vagrantup.com/docs/vagrant-cloud/api.html).

[![Gem Version](https://img.shields.io/gem/v/vagrant_cloud.svg)](https://rubygems.org/gems/vagrant_cloud)

This library provides the functionality to create, modify, and delete boxes, versions,
and providers on Vagrant Cloud.

## Usage

The Vagrant Cloud library provides two methods for interacting with the Vagrant Cloud API. The
first is direct interaction using a `VagrantCloud::Client` instance. The second is a basic
model based approach using a `VagrantCloud::Account` instance.

### Direct Client

The `VagrantCloud::Client` class contains all the underlying functionality which with
`vagrant_cloud` library uses for communicating with Vagrant Cloud. It can be used directly
for quickly and easily sending requests to Vagrant Cloud. The `VagrantCloud::Client`
class will automatically handle any configured authentication, request parameter
structuring, and response validation. All API related methods in the `VagrantCloud::Client`
class will return `Hash` results.

Example usage (display box details):

```ruby
require "vagrant_cloud"

client = VagrantCloud::Client.new(access_token: "MY_TOKEN")
box = client.box_get(username: "hashicorp", name: "bionic64")

puts "Box: #{box[:tag]} Description: #{box[:description]}"
```

Example usage (creating box and releasing a new version):

```ruby
require "vagrant_cloud"
require "net/http"

# Create a new client
client = VagrantCloud::Client.new(access_token: "MY_TOKEN")

# Create a new box
client.box_create(
  username: "hashicorp",
  name: "test-bionic64",
  short_description: "Test Box",
  long_description: "Testing box for an example",
  is_private: false
)

# Create a new version
client.box_version_create(
  username: "hashicorp",
  name: "test-bionic64",
  version: "1.0.0",
  description: "Version 1.0.0 release"
)

# Create a new provider
client.box_version_provider_create(
  username: "hashicorp",
  name: "test-bionic64",
  version: "1.0.0",
  provider: "virtualbox"
)

# Request box upload URL
upload_url = client.box_version_provider_upload(
  username: "hashicorp",
  name: "test-bionic64",
  version: "1.0.0",
  provider: "virtualbox"
)

# Upload box asset
uri = URI.parse(upload_url[:upload_path])
request = Net::HTTP::Post.new(uri)
box = File.open(BOX_PATH, "rb")
request.set_form([["file", box]], "multipart/form-data")
response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme.eql?("https")) do |http|
  http.request(request)
end

# Release the version
client.box_version_release(
  username: "hashicorp",
  name: "test-bionic64",
  version: "1.0.0"
)
```

### Simple Models

The `VagrantCloud::Account` class is the entry point for using simple models to
interact with Vagrant Cloud.

Example usage (display box details):

```ruby
require "vagrant_cloud"

account = VagrantCloud::Account.new(access_token: "MY_TOKEN")
org = account.organization(name: "hashicorp")
box = org.boxes.select { |b| b.name == "bionic64" }

puts "Box: #{box[:tag]} Description: #{box[:description]}"
```

Example usage (creating box and releasing a new version):

```ruby
require "vagrant_cloud"

# Load our account
account = VagrantCloud::Account.new(access_token: "MY_TOKEN")

# Load organization
org = account.organization(name: "hashicorp")

# Create a new box
box = org.add_box("test-bionic64")
box.description = "Testing box for an example"
box.short_description = "Test Box"

# Create a new version
version = box.add_version("1.0.0")
version.description = "Version 1.0.0 release"

# Create a new provider
provider = version.add_provider("virtualbox")

# Save the box, version, and provider
box.save

# Upload box asset
provider.upload(path: BOX_PATH)

# Release the version
version.release
```

## Development & Contributing

Pull requests are very welcome!

Install dependencies:
```
bundle install
```

Run the tests:
```
bundle exec rspec
```

## Releasing

Release a new version:

1. Update the version in the `version.txt` file
1. Commit the change to master
1. Create a new version tag in git: `git tag vX.X.X`
1. Push the new tag and master to GitHub `git push origin main --tags`

The new release will be automatically built and published.

## History

- This gem was developed and maintained by [Cargo Media](https://www.cargomedia.ch) from April 2014 until October 2017.
- The `vagrant_cloud` CLI tool included in this RubyGem has been deprecated and removed. See `vagrant cloud` for a replacement.
