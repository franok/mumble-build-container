# =================================
# Build Enviroment
# =================================

FROM ubuntu:24.04 AS build_environment
RUN apt update && apt install -y wget xz-utils

ENV MUMBLE_ENVIRONMENT_VERSION=mumble_env.x64-linux.2025-02-27.d7001f6639

# download pre-built environment
RUN wget -q -O env.tar.xz "https://github.com/mumble-voip/vcpkg/releases/download/2025-02/$MUMBLE_ENVIRONMENT_VERSION.tar.xz"

# extract environment
RUN tar -xf env.tar.xz
RUN mv mumble_env.* /mumble-build-environment


# =================================
# Mumble
# =================================
FROM ubuntu:24.04 AS mumble_builder

RUN apt update && apt install -y git cmake vim file ninja-build g++-multilib python3

# additional dependencies
RUN apt-get install -y libdbus-1-dev libsystemd-dev

# download mumble
ENV MUMBLE_VERSION=05b4c95b 
RUN git clone https://github.com/mumble-voip/mumble.git /root/mumble
WORKDIR /root/mumble
RUN git checkout $MUMBLE_VERSION

# checkout submodules
RUN git submodule update --init

RUN mkdir build
WORKDIR /root/mumble/build 

COPY --from=build_environment /mumble-build-environment /mumble-build-environment

# provide libresolv.a in the mumble-build-environment
# TODO: quite hacky. we should rather find out how to adjust the cmake options
RUN ln -s /usr/lib/x86_64-linux-gnu/libresolv.a  /mumble-build-environment/installed/x64-linux/lib/libresolv.a

RUN cmake .. -G Ninja -DCMAKE_UNITY_BUILD=ON \
        -Dserver=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -Dclient=OFF \
        -Dice=ON \
        -Dstatic=ON \
        -Ddbus=OFF \
        -Dzeroconf=OFF \
        -Dplugins=OFF \
        -Doverlay=OFF \
        -Dtests=OFF \
        -Dsymbols=OFF \
        -Denable-postgresql=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
        -DCMAKE_C_FLAGS="-static-libgcc -static-libstdc++ -static" \
    	-DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -static" \
		-DIce_HOME="/mumble-build-environment/installed/x64-linux" \
        -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
		-DCMAKE_TOOLCHAIN_FILE=/mumble-build-environment/scripts/buildsystems/vcpkg.cmake \
		-DVCPKG_TARGET_TRIPLET=x64-linux

# replace every .so commandline argument with the static version
# TODO: similar hacky, see note above
RUN sed -i \
    -e 's| [^ ]*libdbus-1\.so| /usr/lib/x86_64-linux-gnu/libdbus-1.a|g' \
    -e 's| [^ ]*libresolv\.so| /usr/lib/x86_64-linux-gnu/libresolv.a /usr/lib/x86_64-linux-gnu/libsystemd.a|g' \
    build.ninja

RUN cmake --build .

# print file info (expect: "mumble-server: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, BuildID[sha1]=2fda729a9d550bf1698d015f0a80684b2a3e1a36, for GNU/Linux 3.2.0, not stripped")
RUN file mumble-server

# assert: file is statically linked
RUN ldd ./mumble-server || true

# collect files
RUN mkdir -p /dist && \
	cp mumble-server /dist/murmur.x86_64 && \
	cp mumble-server.ini /dist/murmur.ini && \
	cp /root/mumble/LICENSE /dist/LICENSE