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

target="$1"

if [ -z "$target" ]; then
  echo "Missing target tuple to build (./build.sh <target-tuple>)" >&2
  exit 1
fi

echo "./build.sh called with target $1"

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
gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7C0135FB088AAF6C66C650B9BB5869F064EA74AB

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

# set minimum version of macOS to 10.13
export MACOSX_DEPLOYMENT_TARGET="10.13"
# bash uses CC_FOR_BUILD
if [[ "$target" != *"macos"* ]]; then
  export CC_FOR_BUILD="zig cc -target x86_64-linux-musl -static -Wl,-Bstatic"
else
  export CC_FOR_BUILD="zig cc"
fi

# https://www.gnu.org/software/bash/manual/html_node/Compilers-and-Options.html
export CC="zig cc -target $target -static -Wl,-Bstatic -std=c89 -Wno-implicit-function-declaration -Wno-return-type"
export AR="zig ar"
export RANLIB="zig ranlib"
export LD="zig build-lib"

echo "= building bash"

# get the host for cross-compiling
wget -O config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
wget -O config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'

chmod +x config.guess config.sub
export CC_BUILD="$(./config.guess)"
export CC_TARGET="$(./config.sub $target)"

pushd bash-${bash_version}
sed -i s/\$lo/@OBJEXT@/g lib/intl/Makefile.in
autoconf -f
cat > config.cache << "EOF"
ac_cv_func_mmap_fixed_mapped=yes
ac_cv_func_strcoll_works=yes
ac_cv_func_working_mktime=yes
bash_cv_func_sigsetjmp=present
bash_cv_getcwd_malloc=yes
bash_cv_job_control_missing=present
bash_cv_printf_a_format=yes
bash_cv_sys_named_pipes=present
bash_cv_ulimit_maxfds=yes
bash_cv_under_sys_siglist=yes
bash_cv_unusable_rtsigs=no
gt_cv_int_divbyzero_sigfpe=yes
EOF
./configure --build="$CC_BUILD" --host="$CC_TARGET" --without-bash-malloc --enable-static-link --cache-file=config.cache
make
if [[ "$target" == *"linux"* ]] || [[ "$target" == *"macos"* ]]; then
  make tests
fi
popd # bash-${bash_version}

popd # build

if [ ! -d releases ]; then
  mkdir releases
fi

echo "= extracting bash binary"
cp build/bash-${bash_version}/bash releases

echo "= done"
