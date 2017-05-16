vagrant_cloud
=============
Minimalistic ruby client for the [HashiCorp Atlas API](https://atlas.hashicorp.com/docs) (previously *Vagrant Cloud API*).

[![Build Status](https://img.shields.io/travis/cargomedia/vagrant_cloud/master.svg)](https://travis-ci.org/cargomedia/vagrant_cloud)
[![Gem Version](https://img.shields.io/gem/v/vagrant_cloud.svg)](https://rubygems.org/gems/vagrant_cloud)


This client allows to create, modify and delete *boxes*, *versions* and *providers*.
The main entry point is an object referencing your *account*.

Usage
-----
Example usage:
```ruby
account = VagrantCloud::Account.new('<username>', '<access_token>')
box = account.ensure_box('my_box')
version = box.ensure_version('0.0.1')
provider = version.ensure_provider('virtualbox', 'http://example.com/foo.box')

version.release
puts provider.download_url
```

Example CLI usage:
Create a version and provider within an existing Box, upload a file to be hosted by Vagrant/Atlas, and release the version
```sh
vagrant_cloud create_version --username $USERNAME --token $VAGRANT_CLOUD_TOKEN --box $BOX_NAME --version $BOX_VERSION
vagrant_cloud create_provider --username $USERNAME --token $VAGRANT_CLOUD_TOKEN --box $BOX_NAME --version $BOX_VERSION
vagrant_cloud upload_file --username $USERNAME --token $VAGRANT_CLOUD_TOKEN --box $BOX_NAME --version $BOX_VERSION --provider_file_path $PACKAGE_PATH
vagrant_cloud release_version --username $USERNAME --token $VAGRANT_CLOUD_TOKEN --box $BOX_NAME --version $BOX_VERSION
```
If you installed vagrant_cloud with bundler, then you may have to invoke using `bundle exec vagrant_cloud`

Development & Contributing
--------------------------
Pull requests are very welcome! Please try to follow these simple rules if applicable:

* Make sure you run `bundle exec rspec` before creating a pull request.  all specs must pass and all new code needs test coverage
* Run `rubocop` locally before pulling
* Update the README as appropriate
* Please do not change the version number.
