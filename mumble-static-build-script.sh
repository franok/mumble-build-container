#!/bin/bash
# mumble build script for x86_static server binary
# https://github.com/mumble-voip/mumble/blob/c317d57008714edff2f77f7ae6a313fdf1685539/docs/dev/build-instructions/build_static.md

echo "Starting to compile a static mumble build. This might take several minutes to hours!"

apt update --no-install-recommends -y
apt install -y git curl zip build-essential
export DEBIAN_FRONTEND=noninteractive
apt install -y pkg-config
apt install -y libx11-dev \
	libx11-xcb-dev \
	libxi-dev \
	libxext-dev \
	libgl1-mesa-dev \
	libglu1-mesa \
	libglu1-mesa-dev \
	bison
apt install -y python3 \
	python \
	python3-distutils \
	gperf \
	autoconf #remove python ?
apt install -y qt5-default \
	qttools5-dev \
	qttools5-dev-tools \
	libqt5svg5-dev \
	libboost-dev \
	libssl-dev # are these needed at all?
apt install -y libxcb*-dev \
	libxkbcommon-dev \
	libxkbcommon-x11-dev \
	libdbus-1-dev \
	libbluetooth-dev
#apt install -y qt5-base qt5-x11extras

#cd /mumble-build/sources
#mkdir -p /root/vcpkg/ports
#cp -r /mumble-build/sources/helpers/vcpkg/ports/zeroc-ice /root/vcpkg/ports/
echo "running get_mumble_dependencies.sh ..."
(cd /mumble-build/sources; bash scripts/vcpkg/get_mumble_dependencies.sh)

apt install -y cmake libspeechd-dev libavahi-compat-libdnssd-dev libasound2-dev g++-multilib
apt install --no-install-recommends -y \
	ca-certificates \
	git \
	build-essential \
	cmake \
	pkg-config \
	qt5-default \
	libboost-dev \
	libasound2-dev \
	libssl-dev \
	libspeechd-dev \
	libzeroc-ice-dev \
	libpulse-dev \
	libcap-dev \
	libprotobuf-dev \
	protobuf-compiler \
	protobuf-compiler-grpc \
	libprotoc-dev \
	libogg-dev \
	libavahi-compat-libdnssd-dev \
	libsndfile1-dev \
	libgrpc++-dev \
	libxi-dev \
	libbz2-dev

echo "Prepare cmake build..."
(cd /mumble-build/sources; git submodule update --init --recursive)
mkdir -p /mumble-build/sources/build
#cd build
(cd /mumble-build/sources/build; cmake "-DVCPKG_TARGET_TRIPLET=x64-linux" "-Dstatic=ON" "-Dclient=OFF" "-Dgrpc=ON" "-DCMAKE_TOOLCHAIN_FILE=/root/vcpkg/scripts/buildsystems/vcpkg.cmake" "-DIce_HOME=/root/vcpkg/installed/x64-linux" "-DCMAKE_BUILD_TYPE=Release" /mumble-build/sources/)

echo "Run cmake --build..."
(cd /mumble-build/sources/build; cmake --build /mumble-build/sources/build/)

echo "Package static binary..."
build_timestamp=$(date '+%FT%H-%M-%S')
tar cfvz "/mumble-build/sources/build/mumble-server_static-x86_64-linux_${build_timestamp}.tar.gz" /mumble-build/sources/build/mumble-server /mumble-build/sources/build/murmur.ini
cp -p "/mumble-build/sources/build/mumble-server_static-x86_64-linux_${build_timestamp}.tar.gz" /mumble-build/dist/

echo "==============="
echo "Finished!"
echo "==============="
