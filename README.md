vagrant_cloud [![Build Status](https://travis-ci.org/cargomedia/vagrant_cloud.svg)](https://travis-ci.org/cargomedia/vagrant_cloud)
=============

*Very* minimalistic ruby wrapper for the [Vagrant Cloud API](https://atlas.hashicorp.com/docs).

Consisting of four basic classes for your *account*, *boxes*, *versions* and *providers*.

Usage
-----
The *vagrant_cloud* gem is hosted on [RubyGems](https://rubygems.org/gems/vagrant_cloud), see installation instructions there.

Example usage:
```ruby
account = VagrantCloud::Account.new('<username>', '<access_token>')
box = vagrant_cloud.ensure_box('my_box')
version = box.ensure_version('0.0.1')
provider_foo = version.ensure_provider('foo', 'http://example.com/foo.box')
provider_bar = version.ensure_provider('bar', 'http://example.com/bar.box')

version.release
puts provider_foo.download_url
```
