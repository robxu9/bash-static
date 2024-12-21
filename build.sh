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

set -euo pipefail
shopt -s nullglob

# Silence these
pushd() { command pushd "$@" >/dev/null; }

popd() { command popd >/dev/null; }

# Only pull files that don't already exist
mycurl() {
  (($# == 2)) || return
  [[ -f ${1##*/} ]] || { echo "File: ${1##*/} | Url: ${1}" && curl -sLO "$1"; }
  [[ -f ${1##*/}.${2} || ${NO_SIGS:-} ]] || {
    echo "File: ${1##*/}.${2} | Url: ${1}.${2}" && curl -sLO "${1}.${2}"
    gpg --trust-model always --verify "${1##*/}.${2}" "${1##*/}" 2>/dev/null
  }
}

main() {
  [[ ${1:-} ]] || { echo "! no target specified" >&2 && exit 1; }
  [[ ${2:-} ]] || { echo "! no arch specified" >&2 && exit 1; }

  declare -r target=${1} arch=${2} tag=${3:-}
  declare -r bash_mirror='https://ftp.gnu.org/gnu/bash'
  declare -r musl_mirror='https://musl.libc.org/releases'

  # Ensure we are in the project root
  pushd "${0%/*}"
  # load version info
  # shellcheck source=version.sh
  . "./version${tag:+-$tag}.sh"

  # make build directory
  mkdir -p build && pushd build

  # pre-prepare gpg for verificaiton
  echo "= preparing gpg"
  export GNUPGHOME=${PWD}/.gnupg
  # public key for bash
  gpg --quiet --list-keys 7C0135FB088AAF6C66C650B9BB5869F064EA74AB ||
    gpg --quiet --keyserver hkps://keyserver.ubuntu.com:443 \
      --recv-keys 7C0135FB088AAF6C66C650B9BB5869F064EA74AB
  # public key for musl
  gpg --quiet --list-keys 836489290BB6B70F99FFDA0556BCDB593020450F ||
    gpg --quiet --keyserver hkps://keyserver.ubuntu.com:443 \
      --recv-keys 836489290BB6B70F99FFDA0556BCDB593020450F

  # download tarballs
  echo "= downloading bash ${bash_version}"
  mycurl ${bash_mirror}/bash-${bash_version}.tar.gz sig

  echo "= extracting bash ${bash_version}"
  rm -fr bash-${bash_version}
  tar -xf "bash-${bash_version}.tar.gz"

  echo "= patching bash ${bash_version} | patches: ${bash_patch_level}"
  for ((lvl = 1; lvl <= bash_patch_level; lvl++)); do
    printf -v bash_patch 'bash%s-%03d' "${bash_version/\./}" "${lvl}"
    mycurl "${bash_mirror}/bash-${bash_version}-patches/${bash_patch}" sig
    pushd bash-${bash_version} && patch -sp0 <../"${bash_patch}" && popd
  done

  echo "= patching with any custom patches we have"
  for patch in ../custom/bash"${bash_version/\./}"*.patch; do
    echo "Applying ${patch}"
    pushd bash-${bash_version} && patch -sp1 <../"${patch}" && popd
  done

  configure_args=(--enable-silent-rules)

  if [[ $target == linux ]]; then
    if . /etc/os-release && [[ $ID == alpine ]]; then
      echo "= skipping installation of musl (already installed on Alpine)"
    else
      install_dir=${PWD}/musl-install-${musl_version}
      if [[ -f ${install_dir}/bin/musl-gcc ]]; then
        echo "= reusing existing musl ${musl_version}"
      else
        echo "= downloading musl ${musl_version}"
        mycurl ${musl_mirror}/musl-${musl_version}.tar.gz asc

        echo "= extracting musl ${musl_version}"
        rm -fr musl-${musl_version}
        tar -xf musl-${musl_version}.tar.gz

        echo "= building musl ${musl_version}"
        pushd musl-${musl_version}
        ./configure --prefix="${install_dir}" "${configure_args[@]}"
        make -s install
        popd # musl-${musl-version}
        rm -fr musl-${musl_version}
      fi

      echo "= setting CC to musl-gcc ${musl_version}"
      export CC=${install_dir}/bin/musl-gcc
    fi
    export CFLAGS="${CFLAGS:-} -Os -static"
  else
    echo "= WARNING: your platform does not support static binaries."
    echo "= (This is mainly due to non-static libc availability.)"
    if [[ $target == macos ]]; then
      # set minimum version of macOS to 10.13
      export MACOSX_DEPLOYMENT_TARGET="10.13"
      export CC="clang -std=c89 -Wno-return-type"

      # use included gettext to avoid reading from other places, like homebrew
      configure_args=("${configure_args[@]}" "--with-included-gettext")

      # if $arch is aarch64 for mac, target arm64e
      if [[ $arch == aarch64 ]]; then
        export CFLAGS="${CFLAGS:-} -Os -target arm64-apple-macos"
        configure_args=("${configure_args[@]}" "--host=aarch64-apple-darwin")
      else
        export CFLAGS="${CFLAGS:-} -Os -target x86_64-apple-macos10.12"
        configure_args=("${configure_args[@]}" "--host=x86_64-apple-macos10.12")
      fi
    fi
  fi

  echo "= building bash ${bash_version}"
  pushd bash-${bash_version}
  export CPPFLAGS="${CFLAGS}" # Some versions need both set
  autoconf -f && ./configure --without-bash-malloc "${configure_args[@]}"
  make -s && make -s tests
  popd # bash-${bash_version}
  popd # build

  echo "= extracting bash ${bash_version} binary"
  mkdir -p releases
  cp build/bash-${bash_version}/bash releases/bash-${bash_version}-static
  strip -s releases/bash-${bash_version}-static
  rm -fr build/bash-${bash_version}
  echo "= done"
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0 && main "$@"
