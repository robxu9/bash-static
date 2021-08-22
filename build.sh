#!/bin/bash
#
# build static bash because we need exercises in minimalism
# Copyright © 2015 Robert Xu <robxu9@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# For Linux, also builds musl for truly static linking if
# musl is not installed.

set -e 
set -o pipefail

# load version info
. version.sh

platform=$(uname -s)

if [ -d build ]; then
  echo "= removing previous build directory"
  rm -rf build
fi

mkdir build # make build directory
pushd build

# pre-prepare gpg for verificaiton
echo "= preparing gpg"
export GNUPGHOME="$(mktemp -d)"
# public key for bash
gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys 7C0135FB088AAF6C66C650B9BB5869F064EA74AB
# public key for musl
gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys 836489290BB6B70F99FFDA0556BCDB593020450F

# download tarballs
echo "= downloading bash"
curl -LO http://ftp.gnu.org/gnu/bash/bash-${bash_version}.tar.gz
curl -LO http://ftp.gnu.org/gnu/bash/bash-${bash_version}.tar.gz.sig
gpg --batch --verify bash-${bash_version}.tar.gz.sig bash-${bash_version}.tar.gz

echo "= extracting bash"
tar -xf bash-${bash_version}.tar.gz

echo "= patching bash"
bash_patch_prefix=$(echo "bash${bash_version}" | sed -e 's/\.//g')
for lvl in $(seq $bash_patch_level); do
    curl -LO http://ftp.gnu.org/gnu/bash/bash-${bash_version}-patches/${bash_patch_prefix}-$(printf '%03d' $lvl)
    curl -LO http://ftp.gnu.org/gnu/bash/bash-${bash_version}-patches/${bash_patch_prefix}-$(printf '%03d' $lvl).sig
    gpg --batch --verify ${bash_patch_prefix}-$(printf '%03d' $lvl).sig ${bash_patch_prefix}-$(printf '%03d' $lvl)

    pushd bash-${bash_version}
    cat ../${bash_patch_prefix}-$(printf '%03d' $lvl) | patch -p0
    popd
done

if [ "$platform" = "Linux" ]; then
  if [ "$(cat /etc/os-release | grep ID= | head -n1)" = "ID=alpine" ]; then
    echo "= skipping installation of musl because this is alpine linux (and it is already installed)"
  else
    echo "= downloading musl"
    curl -LO https://musl.libc.org/releases/musl-${musl_version}.tar.gz
    curl -LO https://musl.libc.org/releases/musl-${musl_version}.tar.gz.asc
    gpg --batch --verify musl-${musl_version}.tar.gz.asc musl-${musl_version}.tar.gz

    echo "= extracting musl"
    tar -xf musl-${musl_version}.tar.gz

    echo "= building musl"
    working_dir=$(pwd)

    install_dir=${working_dir}/musl-install

    pushd musl-${musl_version}
    ./configure --prefix=${install_dir}
    make install
    popd # musl-${musl-version}

    echo "= setting CC to musl-gcc"
    export CC=${working_dir}/musl-install/bin/musl-gcc
  fi
  export CFLAGS="-static"
else
  echo "= WARNING: your platform does not support static binaries."
  echo "= (This is mainly due to non-static libc availability.)"
  if [ "$platform" = "Darwin" ]; then
    # set minimum version of macOS to 10.13
    export MACOSX_DEPLOYMENT_TARGET="10.13"
    # https://www.gnu.org/software/bash/manual/html_node/Compilers-and-Options.html
    export CC="gcc -std=c89 -Wno-implicit-function-declaration -Wno-return-type"
  fi
fi

echo "= building bash"

pushd bash-${bash_version}
CFLAGS="$CFLAGS -Os" ./configure --without-bash-malloc
make
make tests
popd # bash-${bash_version}

popd # build

if [ ! -d releases ]; then
  mkdir releases
fi

echo "= extracting bash binary"
cp build/bash-${bash_version}/bash releases

echo "= done"
