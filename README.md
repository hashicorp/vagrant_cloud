vagrant_cloud
=============

*Very* minimalistic ruby wrapper for the [Vagrant Cloud API](https://vagrantcloud.com/api).

Consisting of four basic classes for your *account*, *boxes*, *versions* and *providers*.

Usage
-----

```ruby
account = VagrantCloud::Account.new('<username>', '<access_token>')
box = vagrant_cloud.ensure_box('my_box')
version = box.ensure_version('0.0.1')
provider_foo = version.ensure_provider('foo', 'http://example.com/foo.box')
provider_bar = version.ensure_provider('bar', 'http://example.com/bar.box')

version.release
puts provider_foo.download_url
```
