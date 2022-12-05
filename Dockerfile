FROM ubuntu:22.04

RUN apt update
RUN apt upgrade -y
RUN apt install -y build-essential git cmake python3 python-is-python3 perl vim 

WORKDIR /root

RUN git clone https://github.com/mumble-voip/mumble.git mumble --branch 1.4.x --single-branch
RUN git clone https://github.com/openssl/openssl openssl --branch OpenSSL_1_1_1-stable --single-branch
RUN git clone https://invent.kde.org/qt/qt/qt5.git qt5 --branch 5.15 --single-branch

# install more dependencies

RUN apt install -y zlib1g-dev

WORKDIR /root/openssl
# uname -m
# well we could also simply use the prebuilt static libssl from libssl-dev on ubuntu ...
RUN ./Configure no-shared --prefix=/static-prefix  linux-x86_64
RUN make -j$(nproc)
RUN make install

# now to the big one

WORKDIR /root/qt5

RUN git submodule update --init

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

RUN apt install -y libprotobuf-dev libcap-dev protobuf-compiler protobuf-c-compiler libboost1.74-dev

WORKDIR /root/mumble

RUN git submodule update --init

RUN apt install -y ninja-build file

RUN mkdir build

WORKDIR /root/mumble
# COPY libcap.patch .
# COPY libprotobuf.patch .
# RUN git apply < libcap.patch
# RUN git apply < libprotobuf.patch

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
	-DCMAKE_C_FLAGS="-static-libgcc -static-libstdc++" \
	-DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++" \
	-DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
	-GNinja
	# -DCMAKE_EXE_LINKER_FLAGS="-Wl,-Bstatic -static-libgcc -static-libstdc++" \
RUN ninja -v
RUN file mumble-server
RUN ldd ./mumble-server

ENTRYPOINT bash
