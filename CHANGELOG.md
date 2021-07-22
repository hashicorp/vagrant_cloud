# v3.0.6 (UNRELEASED)

# v3.0.5 (July 22, 2021)

* Updates for Ruby 3 compatibility [GH-76](https://github.com/hashicorp/vagrant_cloud/pull/76)

# v3.0.4 (March 18, 2021)

* Ensure URL is included when saving provider [GH-69](https://github.com/hashicorp/vagrant_cloud/pull/69)

# v3.0.3 (February 19, 2021)

* Save box before saving versions [GH-70](https://github.com/hashicorp/vagrant_cloud/pull/70)

# v3.0.2 (October 30, 2020)

* Raise custom exception on request error [GH-67](https://github.com/hashicorp/vagrant_cloud/pull/67)

# v3.0.1 (October 27, 2020)

* Fixes on authentication related client methods [GH-65](https://github.com/hashicorp/vagrant_cloud/pull/65)
* Prevent frozen data modifications on deletions [GH-65](https://github.com/hashicorp/vagrant_cloud/pull/65)
* Update direct upload callback behaviors [GH-65](https://github.com/hashicorp/vagrant_cloud/pull/65)

# v3.0.0 (September 21, 2020)

* Refactor library implementation [GH-59](https://github.com/hashicorp/vagrant_cloud/pull/59)
* Add support for direct storage uploads [GH-62](https://github.com/hashicorp/vagrant_cloud/pull/62)

_NOTE_: This release includes breaking changes and is not backwards compatible

# v2.0.3 (October 8, 2019)

* Pass access_token and base_url into legacy ensure methods [GH-50](https://github.com/hashicorp/vagrant_cloud/pull/50)
* Support passing checksum and checksum type values [GH-51](https://github.com/hashicorp/vagrant_cloud/pull/51)

# v2.0.2 (January 9, 2019)

* Properly raise error if CLI is invoked [GH-40](https://github.com/hashicorp/vagrant_cloud/pull/40)
* Only update Box attribute if non-empty hash is given [GH-44](https://github.com/hashicorp/vagrant_cloud/pull/44)
* Raise InvalidVersion error if version number for Version attribute is invalid [GH-45](https://github.com/hashicorp/vagrant_cloud/pull/45)
* Fix `ensure_box` when box does not exist [GH-43](https://github.com/hashicorp/vagrant_cloud/pull/43)

# v2.0.1

* Remove JSON runtime dependency [GH-39](https://github.com/hashicorp/vagrant_cloud/pull/39)

# v2.0.0

* Refactor with updated APIs [GH-35](https://github.com/hashicorp/vagrant_cloud/pull/35)
* Use header for authentication token [GH-33](https://github.com/hashicorp/vagrant_cloud/pull/33)

# v1.1.0
