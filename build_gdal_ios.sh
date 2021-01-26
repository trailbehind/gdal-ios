#!/bin/bash
set -eux -o pipefail

default_iphoneos_version=12.0
default_architecture=arm64

export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-$default_iphoneos_version}"
DEFAULT_ARCHITECTURE="${DEFAULT_ARCHITECTURE:-$default_architecture}"
DEFAULT_PREFIX="${HOME}/Desktop/iOS_GDAL"


usage ()
    {
cat >&2 << EOF
    Usage: ${0} [-h] [-p prefix] [-a arch] target [configure_args]
        -h  Print help message
        -p  Installation prefix (default: \$HOME/Documents/iOS_GDAL...)
        -a  Architecture target for compilation (default: arm64)

    The target must be "device" or "simulator".  Any additional arguments
    are passed to configure.

    The following environment variables affect the build process:

        IPHONEOS_DEPLOYMENT_TARGET  (default: $default_iphoneos_version)
        DEFAULT_PREFIX  (default: $default_prefix)
EOF
    }

prefix="${DEFAULT_PREFIX}"

while getopts ":hp:a:" opt; do
        case $opt in
        h  ) usage ; exit 0 ;;
        p  ) prefix="$OPTARG" ;;
        a  ) DEFAULT_ARCHITECTURE="$OPTARG" ;;
        \? ) usage ; exit 2 ;;
        esac
done
shift $(( $OPTIND - 1 ))

if (( $# < 1 )); then
    usage
    exit 2
fi

target=$1
shift

case $target in
        device )
        arch="${DEFAULT_ARCHITECTURE}"
        platform=iphoneos
        extra_cflags=" "
        ;;

        simulator )
        arch="${DEFAULT_ARCHITECTURE}"
        platform=iphonesimulator
        extra_cflags="-D__IPHONE_OS_VERSION_MIN_REQUIRED=${IPHONEOS_DEPLOYMENT_TARGET%%.*}0000"
        ;;

        * )
        echo No target found!!!
        usage
        exit 2
esac

if [ $arch = "arm64" ]; then
    host="arm-apple-darwin"
else
    host="${arch}-apple-darwin"
fi

echo "building for host ${host}"

platform_dir=`xcrun -find -sdk ${platform} --show-sdk-platform-path`
platform_sdk_dir=`xcrun -find -sdk ${platform} --show-sdk-path`
prefix="${prefix}/${arch}/${platform}${IPHONEOS_DEPLOYMENT_TARGET}.sdk"

echo
echo library will be exported to $prefix

#setup compiler flags
export CC=`xcrun -find -sdk iphoneos clang`
export CFLAGS="-Wno-error=implicit-function-declaration -arch ${arch} -pipe -Os -gdwarf-2 -isysroot ${platform_sdk_dir} ${extra_cflags}"
export LDFLAGS="-arch ${arch} -isysroot ${platform_sdk_dir}"
export CXX=`xcrun -find -sdk iphoneos clang++`
export CXXFLAGS="${CFLAGS}"
export CPP=`xcrun -find -sdk iphoneos cpp`
export CXXCPP="${CXX} -E"
GDAL_CPP_FLAGS="-isysroot${platform_sdk_dir}"

if [ $arch = "arm64" ]; then
    GDAL_CPP_FLAGS="$GDAL_CPP_FLAGS -D__arm__=1"
fi

echo CFLAGS ${CFLAGS}

#set proj4 install destination
proj_prefix=$prefix
echo install proj to $proj_prefix

#download proj4 if necesary
PROJ_DIR=proj-4.9.3
if [ ! -e $PROJ_DIR ]; then
    if [ ! -e proj-4.9.3.tar.gz ]; then
        echo "proj missing, downloading"
        wget https://download.osgeo.org/proj/proj-4.9.3.tar.gz
    fi
    tar -xzf proj-4.9.3.tar.gz
fi

#configure and build proj4
pushd $PROJ_DIR

echo "cleaning proj"
make clean || echo "clean failed"

echo "configure proj"
./configure \
    --prefix=${proj_prefix} \
    --enable-shared=no \
    --enable-static=yes \
    --host=$host \
    "$@"

echo "make install proj"
time make -j8
time make install

popd

GDAL_DIR=gdal-2.4.3
#download gdal if necesary
if [ ! -e $GDAL_DIR ]; then
    if [ ! -e gdal-2.4.3.tar.gz ]; then
        echo "gdal missing, downloading"
        wget https://download.osgeo.org/gdal/2.4.3/gdal-2.4.3.tar.gz
    fi
    tar -xzf gdal-2.4.3.tar.gz
fi

#configure and build gdal
pushd $GDAL_DIR

echo "cleaning gdal"
make clean || echo "clean failed"

echo "configure gdal"
CPPFLAGS=$GDAL_CPP_FLAGS \
./configure \
    --prefix="${prefix}" \
    --with-local="${prefix}" \
    --host=$host \
    --disable-debug \
    --with-sysroot=$platform_sdk_dir \
    --disable-shared \
    --enable-static \
    --with-hide-internal-symbols=yes \
    --with-unix-stdio-64=no \
    --with-sse=no \
    --with-avx=no \
    --with-static-proj4=${prefix} \
    --with-libz=${platform_sdk_dir} \
    --with-libtiff=yes \
    --without-cfitsio \
    --without-curl \
    --without-fme \
    --without-geos \
    --without-grass \
    --without-grib \
    --without-hdf4 \
    --without-hdf5 \
    --without-idb \
    --without-ingres \
    --without-jasper \
    --without-jp2mrsid \
    --without-jpeg12 \
    --without-kakadu \
    --without-libgrass \
    --without-mrsid \
    --without-msg \
    --without-mysql \
    --without-netcdf \
    --without-oci \
    --without-odbc \
    --without-ogdi \
    --without-openjpeg \
    --without-pcraster \
    --without-perl \
    --without-pg \
    --without-php \
    --without-podofo \
    --without-poppler \
    --without-python \
    --without-sde \
    --with-sfcgal=no \
    --without-sqlite3 \
    --without-xerces

echo "building gdal"
time make -j8
time make install

echo "Gdal build complete"

popd
