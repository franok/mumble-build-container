FROM ubuntu:latest
ARG VERSION="1.4.287"

# install timezone asking for interactive shell
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update && apt-get -y install tzdata
RUN apt-get update && apt-get install -y \
  # cloning
  git \
  # to make mumble-scripts work
  sudo \
  # vcpkg
  curl tar unzip zip \
  # configure
  cmake

RUN git clone --depth 1 --branch v$VERSION --recursive https://github.com/mumble-voip/mumble.git
WORKDIR "mumble"

# temporary fix of missing newline escape
RUN sed -i 's/libxcb-xinput-dev/libxcb-xinput-dev \\/g' .github/actions/install-dependencies/install_ubuntu_static_64bit.sh
# temporary fix for different name of package
RUN sed -i 's/libl1-mesa-dev/libgl1-mesa-dev/g' .github/actions/install-dependencies/install_ubuntu_static_64bit.sh

# install dependencies & ignore error
RUN .github/actions/install-dependencies/install_ubuntu_static_64bit.sh; exit 0

# install NOT mentioned dependencies
RUN apt-get update && apt-get install -y \
  autoconf \
  bison \
  gperf \
  '^libxcb.*-dev' \
  libx11-xcb-dev \
  libbluetooth-dev

# check dependencies
RUN ./scripts/vcpkg/get_mumble_dependencies.sh

# run configure
RUN mkdir -p build
WORKDIR "build"
RUN cmake \
  -G "Ninja" \
  "-DVCPKG_TARGET_TRIPLET=x64-linux" \
  "-Dstatic=ON" \
  "-Dclient=OFF" \
  "-Dzeroconf=OFF" \
  "-DCMAKE_TOOLCHAIN_FILE=/root/vcpkg/scripts/buildsystems/vcpkg.cmake" \
  "-DIce_HOME=/root/vcpkg/installed/x64-linux" \
  "-DCMAKE_BUILD_TYPE=Release" \
  ..

# compilation
RUN cmake --build . --config Release
