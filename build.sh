#!/bin/bash
set -x -e

cd "$(dirname "$0")"

if [[ ! -d "simplybs" ]];
then
    git clone https://github.com/MrCyjaneK/simplybs
    cd simplybs
else
    cd simplybs
fi
git fetch -a
git checkout 1969df525db08b32f3848298225168dc0d7a9581

for target in "$@";
do
    if [[ "x$SIMPLYBS_DOWNLOAD_FIRST" == "xyes" ]];
    then
        for dep in $(go run . -host $target -package torch -list | awk '{ print $2 }');
        do
            go run . -host "$target" -download -package $dep
        done
    fi
done

# go run . -cleanup
for target in "$@";
do
    go run . -host "$target" -build -package torch
done
# go run . -cleanup

for target in "$@";
do
    SO_PATH=.buildlib/env
    if [[ ! "x$SIMPLYBS_ENV_DIR" == "x" ]];
    then
        SO_PATH=$SIMPLYBS_ENV_DIR
    fi
    go run . -host "$target" -extract -package torch
    if [[ "$target" == "aarch64-linux-android" ]];
    then
        cp $SO_PATH/aarch64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/arm64-v8a/libtorch.so
    elif [[ "$target" == "x86_64-linux-android" ]];
    then
        cp $SO_PATH/x86_64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/x86_64/libtorch.so
    elif [[ "$target" == "armv7a-linux-androideabi" ]];
    then
        cp $SO_PATH/armv7a-linux-androideabi/lib/libtorch.so ../android/src/main/jniLibs/armeabi-v7a/libtorch.so
    fi
done

# shellcheck disable=SC2199
if [[ "x$SKIP_XC" == "xyes" ]];
then
    exit 0
fi
if [[ "$@" == *"-apple-"* ]];
then
    pushd ..
        ./create-xcframework.sh
    popd
fi
