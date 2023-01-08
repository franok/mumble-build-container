FROM ubuntu:22.04

RUN apt update
RUN apt upgrade -y
RUN apt install -y build-essential git cmake python3 python-is-python3 perl vim 

WORKDIR /root

ENV MUMBLE_VERSION=v1.4.230
ENV OPENSSL_VERSION=OpenSSL_1_1_1-stable
ENV QT5_VERSION=5.15

# get dependencies to build from source
RUN git clone https://github.com/mumble-voip/mumble.git mumble --branch ${MUMBLE_VERSION} --single-branch
RUN git clone https://github.com/openssl/openssl openssl --branch ${OPENSSL_VERSION} --single-branch
RUN git clone https://github.com/qt/qt5.git qt5 --branch ${QT5_VERSION} --single-branch

# install more dependencies

RUN apt install -y zlib1g-dev


# build openssl

WORKDIR /root/openssl
# uname -m
# well we could also simply use the prebuilt static libssl from libssl-dev on ubuntu ...
RUN ./Configure no-shared --prefix=/static-prefix  linux-x86_64
RUN make -j$(nproc)
RUN make install


# now build "the big one" (aka "qt5")

WORKDIR /root/qt5

# only checkout required submodules
RUN ./init-repository --module-subset=qtbase

ENV MAKEFLAGS="-j 4"
RUN ./configure -confirm-license -opensource -v \
	-prefix /static-prefix \ 
	-plugin-sql-sqlite \
	-nomake examples \
	-nomake tests \
	-skip qt3d \
	-skip qtactiveqt \
	-skip qtandroidextras \
	-skip qtcanvas3d \
	-skip qtcharts \
	-skip qtconnectivity \
	-skip qtdatavis3d \
	-skip qtdeclarative \
	-skip qtdoc \
	-skip qtdocgallery \
	-skip qtfeedback \
	-skip qtgamepad \
	-skip qtgraphicaleffects \
	-skip qtimageformats \
	-skip qtlocation \
	-skip qtlottie \
	-skip qtmacextras \
	-skip qtmultimedia \ 
	-skip qtnetworkauth \
	-skip qtpim \
	-skip qtpurchasing \
	-skip qtqa \
	-skip qtquick3d \
	-skip qtquickcontrols \
	-skip qtquickcontrols2 \
	-skip qtquicktimeline \
	-skip qtremoteobjects \
	-skip qtrepotools \ 
	-skip qtscript \
	-skip qtscxml \
	-skip qtsensors \
	-skip qtserialbus \
	-skip qtserialport \
	-skip qtspeech \
	-skip qtsvg \
	-skip qtsystems \
	-skip qttranslations \
	-skip qtvirtualkeyboard \
	-skip qtwayland \
	-skip qtwebchannel \
	-skip qtwebengine \
	-skip qtwebglplugin \
	-skip qtwebsockets \
	-skip qtwebview \
	-skip qtwinextras \
	-skip qtx11extras \
	-skip qtxmlpatterns \
	-no-gui \
	-no-widgets \
	-no-dbus \
	-no-strip \
	-openssl-linked \
	-I /static-prefix/include \
	-L /static-prefix/lib \
	-static \
	-no-shared

RUN make -j$(nproc)
RUN make install


# install further dependencies required to compile mumble

RUN apt install -y libprotobuf-dev libcap-dev protobuf-compiler protobuf-c-compiler libboost1.74-dev


# build mumble/murmur

WORKDIR /root/mumble

RUN git submodule update --init

RUN apt install -y ninja-build file

RUN mkdir build

WORKDIR /root/mumble/build

RUN cmake .. -Dserver=ON \
	-Dclient=OFF \
	-Dice=OFF \
	-Dstatic=ON \
	-Ddbus=OFF \
	-Dgrpc=OFF \
	-Dzeroconf=OFF \
	-Dplugins=OFF \
	-Doverlay=OFF \
	-Dtests=OFF \
	-DCMAKE_SYSTEM_PREFIX_PATH="/static-prefix;/root/static-prefix" \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
	-DCMAKE_C_FLAGS="-static-libgcc -static-libstdc++ -static" \
	-DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -static" \
	-DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
	-GNinja

# replace every .so commandline argument with the static version
RUN sed -i -e 's/\.so/.a/g' build.ninja
RUN ninja -v

# print file info (expect: "mumble-server: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, BuildID[sha1]=2fda729a9d550bf1698d015f0a80684b2a3e1a36, for GNU/Linux 3.2.0, not stripped")
RUN file mumble-server
# assert: file is statically linked
RUN ldd ./mumble-server || true

# rename server binary
RUN mv mumble-server murmur.x86_64

CMD ["bash"]
