#!/bin/bash

bash_version="4.3"
bash_patch_level=48
musl_version="1.2.5"
CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types"

export bash_version
export bash_patch_level
export musl_version
export CFLAGS
