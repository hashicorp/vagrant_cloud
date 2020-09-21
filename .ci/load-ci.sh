#!/usr/bin/env bash

echo "🤖 Loading VagrantCI 🤖"

ldir="$(realpath ./.ci-utility-files)"

# If utility files have not yet been pulled, fetch them
if [ ! -e "${ldir}/.complete" ]; then

    # Validate that we have the AWS CLI available
    command -v aws > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "⚠ ERROR: Missing required aws executable ⚠"
        exit 1
    fi

    # Create a local directory to stash our stuff in
    if ! mkdir -p "${ldir}"; then
        echo "⛔ ERROR: Failed to create utility file directory ⛔"
        exit 1
    fi

    # Jump into local directory and grab files
    pushd "${ldir}"
    if ! aws s3 sync "${VAGRANT_CI_LOADER_BUCKET}/ci-files/" ./; then
        echo "🛑 ERROR: Failed to retrieve utility files 🛑"
        exit 1
    fi

    chmod a+x ./*

    # Mark that we have pulled files
    touch .complete
fi

# Time to load and configure
popd
source "${ldir}/common.sh"
export PATH="${PATH}:${ldir}"

# And we are done!
echo "🎉 VagrantCI Loaded! 🎉"
