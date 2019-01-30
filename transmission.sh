#!/bin/bash

set -e
set -x

mkdir ~/transmission && cd ~/transmission

PREFIX=/opt

BASE=`pwd`
SRC=$BASE/src
WGET="tsocks wget --prefer-family=IPv4"
DEST=$BASE$PREFIX
LDFLAGS="-L$DEST/lib -Wl,--gc-sections"
CPPFLAGS="-I$DEST/include"
CFLAGS="-mtune=mips32 -mips32 -ffunction-sections -fdata-sections"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=$PREFIX --host=mipsel-openwrt-linux"
MAKE="make -j`nproc`"

mkdir -p $SRC

#############
# TOOLCHAIN #
#############

$WGET http://archive.openwrt.org/barrier_breaker/14.07/ramips/mt7620a/OpenWrt-Toolchain-ramips-for-mipsel_24kec+dsp-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
tar jxvf OpenWrt-Toolchain-ramips-for-mipsel_24kec+dsp-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2

TOOLCHAINE_DIR="$BASE/OpenWrt-Toolchain-ramips-for-mipsel_24kec+dsp-gcc-4.8-linaro_uClibc-0.9.33.2/toolchain-mipsel_24kec+dsp_gcc-4.8-linaro_uClibc-0.9.33.2"
export PATH=$PATH:$TOOLCHAINE_DIR/bin

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.11.tar.gz
tar zxvf zlib-1.2.11.tar.gz
cd zlib-1.2.11

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=mipsel-openwrt-linux- \
./configure \
--prefix=$PREFIX

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.0.2g.tar.gz
tar zxvf openssl-1.0.2g.tar.gz
cd openssl-1.0.2g

./Configure linux-mips32 \
-mtune=mips32 -mips32 -ffunction-sections -fdata-sections -Wl,--gc-sections \
--prefix=$PREFIX zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=mipsel-openwrt-linux-gcc
make CC=mipsel-openwrt-linux-gcc install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# GETTEXT # #################################################################
########### #################################################################

mkdir $SRC/gettext && cd $SRC/gettext
$WGET http://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.3.tar.gz
tar zxvf gettext-0.19.3.tar.gz
cd gettext-0.19.3

$WGET https://raw.githubusercontent.com/lancethepants/tomatoware/master/patches/gettext/spawn.patch
patch -p1 < spawn.patch

LDFLAGS="$LDFLAGS -lrt -lpthread" \
CPPFLAGS=$CPPFLAGS \
CFLAGS="$CFLAGS -ldl" \
CXXFLAGS="$CXXFLAGS -ldl" \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

######## ####################################################################
# CURL # ####################################################################
######## ####################################################################

mkdir $SRC/curl && cd $SRC/curl
$WGET https://curl.haxx.se/download/curl-7.48.0.tar.gz
tar zxvf curl-7.48.0.tar.gz
cd curl-7.48.0

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--with-ca-path=$PREFIX/ssl/certs \
--enable-static \
--disable-shared

$MAKE LIBS="-ldl"
make install DESTDIR=$BASE

############ ################################################################
# LIBEVENT # ################################################################
############ ################################################################

mkdir $SRC/libevent && cd $SRC/libevent
$WGET https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz
tar zxvf libevent-2.0.22-stable.tar.gz
cd libevent-2.0.22-stable

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE LIBS="-ldl -lz"
make install DESTDIR=$BASE

################ ############################################################
# TRANSMISSION # ############################################################
################ ############################################################

mkdir $SRC/transmission && cd $SRC/transmission
$WGET https://github.com/transmission/transmission-releases/raw/master/transmission-2.94.tar.xz
tar xvJf transmission-2.94.tar.xz
cd transmission-2.94

ZLIB_CFLAGS="-I$DEST/include" \
ZLIB_LIBS=-L$DEST/lib \
OPENSSL_CFLAGS="-I$DEST/include" \
OPENSSL_LIBS=-L$DEST/lib \
LIBCURL_CFLAGS="-I$DEST/include" \
LIBCURL_LIBS=-L$DEST/lib \
LIBEVENT_CFLAGS="-I$DEST/include" \
LIBEVENT_LIBS=$DEST/lib/libevent.la \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-lightweight \
--with-crypto=openssl \
--enable-cli \
--disable-nls

make LDFLAGS="-zmuldefs" LIBS="-all-static -lcurl -ldl"
make install DESTDIR=$BASE/transmission
