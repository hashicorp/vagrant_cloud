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

Development & Contributing
--------------------------
Pull requests are very welcome!

Install dependencies:
```
bundle install
```

Run the tests:
```
bundle exec rspec
```

Check the code syntax:
```
bundle exec rubocop
```

Release a new version:

1. Bump the version in `vagrant_cloud.gemspec`, merge to master.
2. Push a new tag to master.
3. Release to RubyGems with `bundle exec rake release`.
