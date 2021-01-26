#!/bin/bash
set -eux -o pipefail

PREFIX=`pwd`/install
rm -rf $PREFIX
mkdir $PREFIX
LOG=./log
rm -rf $LOG
mkdir $LOG

if [ -e ${PREFIX} ]
then
    echo removing ${PREFIX}
    rm -rf ${PREFIX}
fi

mkdir -p ${PREFIX}

echo "Building for device"
for f in "arm64"; do
    echo Building $f
    ./build_gdal_ios.sh -p ${PREFIX} -a $f device 2>&1 | tee "${LOG}/${f}.txt"
done

echo "Building for simulator"
for f in "x86_64"; do
    echo Building $f
    ./build_gdal_ios.sh -p ${PREFIX} -a $f simulator 2>&1 | tee "${LOG}/simulator.txt"
done


SDK_VERSION=12.0

lipo \
${PREFIX}/x86_64/iphonesimulator${SDK_VERSION}.sdk/lib/libgdal.a \
${PREFIX}/arm64/iphoneos${SDK_VERSION}.sdk/lib/libgdal.a \
-output ${PREFIX}/libgdal.a \
-create | tee $LOG/lipo.txt

lipo \
${PREFIX}/x86_64/iphonesimulator${SDK_VERSION}.sdk/lib/libproj.a \
${PREFIX}/arm64/iphoneos${SDK_VERSION}.sdk/lib/libproj.a \
-output ${PREFIX}/libproj.a \
-create | tee $LOG/lipo-proj.txt

# copy proj headers into place
mkdir -p ${PREFIX}/proj/
cp proj-4.9.3/src/*.h ${PREFIX}/proj/

#create zipfile for cocoapods distribution
cd ${PREFIX}
mkdir GDAL
cp libgdal.a GDAL
cp arm64/iphoneos${SDK_VERSION}.sdk/include/*.h GDAL
zip gdal.zip GDAL/*

cp libproj.a proj
zip proj-4.9.3.zip proj/*
