#!/bin/bash
set -x -e

cd "$(dirname "$0")"

if [[ ! -d "simplybs" ]];
then
    git clone https://github.com/MrCyjaneK/simplybs
    cd simplybs
else
    cd simplybs
    git fetch -a
fi
git checkout 7e67cde682cf6b8dfbbb8b82511c0c4dd70f9dcc

go run . -cleanup
for target in "$@";
do
    go run . -host "$target" -build -package torch
done
go run . -cleanup

GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
builder=${GOOS}_${GOARCH}

for target in "$@";
do
    go run . -host "$target" -extract -package torch
    if [[ "$target" == "aarch64-linux-android" ]];
    then
        cp .buildlib/"$builder"/env/aarch64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/arm64-v8a/libtorch.so
    elif [[ "$target" == "x86_64-linux-android" ]];
    then
        cp .buildlib/"$builder"/env/x86_64-linux-android/lib/libtorch.so ../android/src/main/jniLibs/x86_64/libtorch.so
    elif [[ "$target" == "armv7a-linux-androideabi" ]];
    then
        cp .buildlib/"$builder"/env/armv7a-linux-androideabi/lib/libtorch.so ../android/src/main/jniLibs/armeabi-v7a/libtorch.so
    fi
done

# shellcheck disable=SC2199
if [[ "$@" == *"-apple-"* ]];
then
    pushd ..
        ./create-xcframework.sh
    popd
fi