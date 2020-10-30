#!/usr/bin/env bash

export SLACK_USERNAME="Vagrant Cloud RubyGem"
export SLACK_ICON="https://avatars.slack-edge.com/2017-10-17/257000837696_070f98107cdacc0486f6_36.png"
export SLACK_TITLE="💎 RubyGems Publishing"

csource="${BASH_SOURCE[0]}"
while [ -h "$csource" ] ; do csource="$(readlink "$csource")"; done
root="$( cd -P "$( dirname "$csource" )/../" && pwd )"

. "${root}/.ci/init.sh"

pushd "${root}" > "${output}"

slack "📢 New vagrant_cloud release has been triggered"

# Build and publish our gem
publish_to_rubygems

slack -m "New version of vagrant_cloud published ${tag}"
