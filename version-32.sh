#!/bin/bash

bash_version="3.2"
bash_patch_level=57
musl_version="1.2.5"
CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=return-mismatch"

export bash_version
export bash_patch_level
export musl_version
export CFLAGS
