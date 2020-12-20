#!/bin/bash
# generate changelog text

# read version information
. version.sh

# and just output to NOTES.txt
echo "bash ${bash_version}-$(printf '%03d' $bash_patch_level), with musl ${musl_version}" > NOTES.txt