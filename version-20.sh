#!/bin/bash

bash_version="2.05b"
bash_patch_level=13
musl_version="1.2.5"
CFLAGS="-std=c89 -Wno-error=implicit-function-declaration -Wno-error=implicit-int"
NO_SIGS=1

export bash_version
export bash_patch_level
export musl_version
export CFLAGS
export NO_SIGS
