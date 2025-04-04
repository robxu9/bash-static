#!/bin/bash

bash_version="3.0"
bash_patch_level=22
musl_version="1.2.5"
CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int"

export bash_version
export bash_patch_level
export musl_version
export CFLAGS
