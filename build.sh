#!/bin/bash
#
# build static bash because we need exercises in minimalism
# MIT licensed: google it or see robxu9.mit-license.org.
#
# For Linux, also builds musl for truly static linking.

bash_version="4.3.30"
musl_version="1.1.5"

platform=$(uname -s)

if [ -d build ]; then
  echo "= removing previous build directory"
  rm -rf build
fi

mkdir build # make build directory
pushd build

# download tarballs
echo "= downloading bash"
curl -LO http://ftp.gnu.org/gnu/bash/bash-${bash_version}.tar.gz

echo "= extracting bash"
tar -xf bash-${bash_version}.tar.gz

if [ "$platform" = "Linux" ]; then
  echo "= downloading musl"
  curl -LO http://www.musl-libc.org/releases/musl-${musl_version}.tar.gz

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
  export CFLAGS="-static"
else
  echo "= WARNING: your platform does not support static binaries."
  echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building bash"

pushd bash-${bash_version}
CFLAGS="$CFLAGS -Os" ./configure --without-bash-malloc
make
popd # bash-${bash_version}

popd # build

if [ ! -d releases ]; then
  mkdir releases
fi

echo "= extracting bash binary"
cp build/bash-${bash_version}/bash releases

echo "= done"
