#!/bin/bash
set -x -e

cd "$(dirname "$0")"
SCRIPT_DIR=$PWD

if [[ ! -d "$HOME/.local/share/simplybs/repo" ]];
then
    echo "simplybs repo not found in $HOME/.local/share/simplybs/repo"
    echo "please install it first."
    exit 1
fi
cd $HOME/.local/share/simplybs/repo

# go run . -cleanup
for target in "$@";
do
    go run . -host "$target" -build -package torch
done
# go run . -cleanup

for target in "$@";
do
    if [[ "x$target" == "x" ]];
    then
        echo "target is not set '$target' - $@"
    fi
    SO_PATH=/opt/_/$target
    go run . -host "$target" -extract -package torch
    if [[ "$target" == "aarch64-linux-android" ]];
    then
        cp $SO_PATH/lib/libtorch.so $SCRIPT_DIR/android/src/main/jniLibs/arm64-v8a/libtorch.so
    elif [[ "$target" == "x86_64-linux-android" ]];
    then
        cp $SO_PATH/lib/libtorch.so $SCRIPT_DIR/android/src/main/jniLibs/x86_64/libtorch.so
    elif [[ "$target" == "armv7a-linux-androideabi" ]];
    then
        cp $SO_PATH/lib/libtorch.so $SCRIPT_DIR/android/src/main/jniLibs/armeabi-v7a/libtorch.so
    fi
done

if [[ "x$SKIP_XC" == "xyes" ]];
then
    exit 0
fi
apple_args=()
for target in "$@";
do
    if [[ "$target" == *-apple-* ]];
    then
        apple_args+=("$target")
    fi
done
if ((${#apple_args[@]}));
then
    pushd $SCRIPT_DIR
        ./create-xcframework.sh "${apple_args[@]}"
    popd
fi
