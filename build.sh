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
git checkout 4be941acdf7fe85ca011f6ab356fb211b5aeb69c

go run . -cleanup
for target in "$@";
do
    go run . -host "$target" -build -package torch
done
go run . -cleanup

for target in "$@";
do
    go run . -host "$target" -extract -package torch
    if [[ "$target" == "aarch64-linux-android" ]];
    then
        cp .buildlib/env/aarch64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/arm64-v8a/libtorch.so
    elif [[ "$target" == "x86_64-linux-android" ]];
    then
        cp .buildlib/env/x86_64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/x86_64/libtorch.so
    elif [[ "$target" == "armv7a-linux-androideabi" ]];
    then
        cp .buildlib/env/armv7a-linux-androideabi/lib/libtorch.so ../android/src/main/jniLibs/armeabi-v7a/libtorch.so
    fi
done

# shellcheck disable=SC2199
if [[ "$@" == *"-apple-"* ]];
then
    pushd ..
        ./create-xcframework.sh
    popd
fi
