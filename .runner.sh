#!/usr/bin/env bash

set -e

gem build *.gemspec
mkdir -p assets
mv vagrant_cloud-*.gem assets/
