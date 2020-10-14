#!/usr/bin/env zsh

cd $SRCROOT/extern

if [[ ! -d $SRCROOT/extern/libzmq ]]; then
    xcrun git clone --branch v4.3.3 --depth 1 https://github.com/zeromq/libzmq
fi

cd $CONFIGURATION_BUILD_DIR

mkdir -p build-libzmq

cd build-libzmq

cmake $SRCROOT/extern/libzmq \
    -DCMAKE_BUILD_TYPE=$CONFIGURATION \
    -G"Unix Makefiles" \
    -DBUILD_SHARED=OFF \
    -DBUILD_STATIC=ON \
    -DWITH_LIBSODIUM=OFF \
    -DWITH_PERF_TOOL=OFF \
    -DZMQ_BUILD_TESTS=OFF \
    -DENABLE_CPACK=OFF \
    -DENABLE_WS=OFF \
    -DPOLLER="kqueue"

xcrun make -j$(sysctl -n hw.ncpu)
