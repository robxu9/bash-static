#!/bin/bash

bash_version="3.1"
bash_patch_level=23
musl_version="1.2.5"
CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=return-mismatch"

export bash_version
export bash_patch_level
export musl_version
export CFLAGS
