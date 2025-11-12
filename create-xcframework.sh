#!/bin/bash
# 
# LibTorch XCFramework Builder
# 
# This script creates XCFrameworks for LibTorch (Tor wrapper) for iOS and macOS platforms.
# It processes the following dylibs:
# - aarch64-apple-ios/lib/libtorch.dylib (iOS device)
# - aarch64-apple-ios-simulator/lib/libtorch.dylib (iOS simulator)  
# - aarch64-apple-darwin/lib/libtorch.dylib (macOS arm64)
# - x86_64-apple-darwin/lib/libtorch.dylib (macOS x86_64)
#
# Output:
# - ios/LibTorch.xcframework (iOS device + simulator)
# - macos/LibTorch.xcframework (macOS universal)
#
set -e

cd "$(dirname "$0")"

# Configuration
BASE_DIR="$(pwd)"
DYLIB_PATH="${BASE_DIR}/simplybs/.buildlib/env"
IOS_DIR="${BASE_DIR}/ios"
MACOS_DIR="${BASE_DIR}/macos"
TMP_DIR="${BASE_DIR}/tmp_torch_frameworks"

# Clean up any existing temporary directory
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Ensure output directories exist
mkdir -p "$IOS_DIR" "$MACOS_DIR"

write_info_plist() {
    local framework_bundle="$1"
    local framework_name="$2"
    local target="$3"
    local arch="$4"
    local plist_path="${framework_bundle}/Info.plist"

    local platform min_os_version device_family

    if [[ "$target" == "ios-simulator" ]]; then
        platform="iPhoneSimulator"
        min_os_version="12.0"
        device_family="<integer>1</integer><integer>2</integer>"
    elif [[ "$target" == "ios" ]]; then
        platform="iPhoneOS"
        min_os_version="12.0"
        device_family="<integer>1</integer><integer>2</integer>"
    elif [[ "$target" == "darwin" ]]; then
        platform="MacOSX"
        min_os_version="10.15"
        device_family=""
    else 
        echo "Unknown target: $target"
        exit 1
    fi

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>com.torch-dart.${framework_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>${platform}</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>${min_os_version}</string>
EOF

    if [[ -n "$device_family" ]]; then
        cat >> "$plist_path" <<EOF
    <key>UIDeviceFamily</key>
    <array>
        ${device_family}
    </array>
EOF
    fi

    cat >> "$plist_path" <<EOF
</dict>
</plist>
EOF
}

create_framework() {
    local dylib_path="$1"
    local framework_name="$2"
    local target="$3"
    local out_dir="$4"
    local arch="$5"

    echo "Creating ${framework_name}.framework for target ${target} (${arch}) in ${out_dir}..."

    local framework_bundle="${out_dir}/${framework_name}.framework"
    
    rm -rf "$framework_bundle"
    mkdir -p "$framework_bundle"

    if [[ ! -f "$dylib_path" ]]; then
        echo "Error: Input dylib not found: $dylib_path"
        exit 1
    fi

    if [[ "$target" == "darwin" ]]; then
        mkdir -p "${framework_bundle}/Versions/A/Resources"
        mkdir -p "${framework_bundle}/Versions/A/Headers"
        
        ln -sf "A" "${framework_bundle}/Versions/Current"
        ln -sf "Versions/Current/${framework_name}" "${framework_bundle}/${framework_name}"
        ln -sf "Versions/Current/Resources" "${framework_bundle}/Resources"
        ln -sf "Versions/Current/Headers" "${framework_bundle}/Headers"
        
        cp "$dylib_path" "${framework_bundle}/Versions/A/${framework_name}"
        echo "Created binary: ${framework_bundle}/Versions/A/${framework_name}"
        
        install_name_tool -id "@rpath/${framework_name}.framework/Versions/A/${framework_name}" "${framework_bundle}/Versions/A/${framework_name}"
        echo "Updated install name for: ${framework_bundle}/Versions/A/${framework_name}"

        write_info_plist "${framework_bundle}/Versions/A/Resources" "$framework_name" "$target" "$arch"
    else
        cp "$dylib_path" "${framework_bundle}/${framework_name}"
        echo "Created binary: ${framework_bundle}/${framework_name}"
        
        install_name_tool -id "@rpath/${framework_name}.framework/${framework_name}" "${framework_bundle}/${framework_name}"
        echo "Updated install name for: ${framework_bundle}/${framework_name}"

        write_info_plist "$framework_bundle" "$framework_name" "$target" "$arch"
        
        mkdir -p "${framework_bundle}/Headers"
    fi
    
    echo "Framework created: ${framework_bundle}"
}

create_xcframework() {
    local framework_name="$1"
    local xcframework_output="$2"
    shift 2
    local frameworks=("$@")

    echo "Creating ${xcframework_output} by bundling:"
    for fw in "${frameworks[@]}"; do
        echo "  Framework: ${fw}"
    done

    local xcodebuild_args=()
    for fw in "${frameworks[@]}"; do
        xcodebuild_args+=("-framework" "$fw")
    done

    rm -rf "$xcframework_output"
    xcodebuild -create-xcframework "${xcodebuild_args[@]}" -output "$xcframework_output"

    echo "Created XCFramework: ${xcframework_output}"
}

# Framework name
FRAMEWORK_NAME="LibTorch"

echo "Building LibTorch XCFrameworks..."

# Create temporary directories for each target
IOS_DEVICE_OUT="${TMP_DIR}/ios_device"
IOS_SIMULATOR_OUT="${TMP_DIR}/ios_simulator"
MACOS_ARM64_OUT="${TMP_DIR}/macos_arm64"
MACOS_X86_64_OUT="${TMP_DIR}/macos_x86_64"
MACOS_UNIVERSAL_OUT="${TMP_DIR}/macos_universal"

mkdir -p "$IOS_DEVICE_OUT" "$IOS_SIMULATOR_OUT" "$MACOS_ARM64_OUT" "$MACOS_X86_64_OUT" "$MACOS_UNIVERSAL_OUT"

IOS_DEVICE_DYLIB="${DYLIB_PATH}/aarch64-apple-ios/lib/libtorch.dylib"
IOS_SIMULATOR_DYLIB="${DYLIB_PATH}/aarch64-apple-ios-simulator/lib/libtorch.dylib"
MACOS_ARM64_DYLIB="${DYLIB_PATH}/aarch64-apple-darwin/lib/libtorch.dylib"
MACOS_X86_64_DYLIB="${DYLIB_PATH}/x86_64-apple-darwin/lib/libtorch.dylib"

echo "Validating dylib files..."
missing_files=()
available_files=()

for dylib in "$IOS_DEVICE_DYLIB" "$IOS_SIMULATOR_DYLIB" "$MACOS_ARM64_DYLIB" "$MACOS_X86_64_DYLIB"; do
    if [[ ! -f "$dylib" ]]; then
        missing_files+=("$dylib")
    else
        available_files+=("$dylib")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "Warning: The following dylib files are missing:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
fi

if [[ ${#available_files[@]} -eq 0 ]]; then
    echo "Error: No dylib files found. Cannot create any frameworks."
    exit 1
fi

echo "Found ${#available_files[@]} dylib files. Continuing with available files..."
for file in "${available_files[@]}"; do
    echo "   - $file"
done

ios_device_available=false
ios_simulator_available=false
macos_arm64_available=false
macos_x86_64_available=false

if [[ -f "$IOS_DEVICE_DYLIB" ]]; then
    create_framework "$IOS_DEVICE_DYLIB" "$FRAMEWORK_NAME" "ios" "$IOS_DEVICE_OUT" "arm64"
    ios_device_available=true
fi

if [[ -f "$IOS_SIMULATOR_DYLIB" ]]; then
    create_framework "$IOS_SIMULATOR_DYLIB" "$FRAMEWORK_NAME" "ios-simulator" "$IOS_SIMULATOR_OUT" "arm64"
    ios_simulator_available=true
fi

if [[ -f "$MACOS_ARM64_DYLIB" ]]; then
    macos_arm64_available=true
fi

if [[ -f "$MACOS_X86_64_DYLIB" ]]; then
    macos_x86_64_available=true
fi

# Create macOS framework (universal if both architectures are available, single arch otherwise)
if [[ "$macos_arm64_available" == true ]] || [[ "$macos_x86_64_available" == true ]]; then
    echo "Creating macOS framework..."
    MACOS_UNIVERSAL_FRAMEWORK="${MACOS_UNIVERSAL_OUT}/${FRAMEWORK_NAME}.framework"
    
    mkdir -p "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/Resources"
    mkdir -p "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/Headers"
    
    ln -sf "A" "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/Current"
    ln -sf "Versions/Current/${FRAMEWORK_NAME}" "${MACOS_UNIVERSAL_FRAMEWORK}/${FRAMEWORK_NAME}"
    ln -sf "Versions/Current/Resources" "${MACOS_UNIVERSAL_FRAMEWORK}/Resources"
    ln -sf "Versions/Current/Headers" "${MACOS_UNIVERSAL_FRAMEWORK}/Headers"

    if [[ "$macos_arm64_available" == true ]] && [[ "$macos_x86_64_available" == true ]]; then
        echo "Creating universal macOS binary (arm64 + x86_64)..."
        lipo -create "$MACOS_ARM64_DYLIB" "$MACOS_X86_64_DYLIB" -output "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"
        write_info_plist "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/Resources" "$FRAMEWORK_NAME" "darwin" "arm64,x86_64"
    elif [[ "$macos_arm64_available" == true ]]; then
        echo "Creating arm64-only macOS binary..."
        cp "$MACOS_ARM64_DYLIB" "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"
        write_info_plist "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/Resources" "$FRAMEWORK_NAME" "darwin" "arm64"
    else
        echo "Creating x86_64-only macOS binary..."
        cp "$MACOS_X86_64_DYLIB" "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"
        write_info_plist "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/Resources" "$FRAMEWORK_NAME" "darwin" "x86_64"
    fi

    echo "Created macOS binary: ${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"

    install_name_tool -id "@rpath/${FRAMEWORK_NAME}.framework/Versions/A/${FRAMEWORK_NAME}" "${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"
    echo "Updated install name for: ${MACOS_UNIVERSAL_FRAMEWORK}/Versions/A/${FRAMEWORK_NAME}"

    echo "macOS framework created: ${MACOS_UNIVERSAL_FRAMEWORK}"
fi

# Define framework paths
IOS_DEVICE_FRAMEWORK="${IOS_DEVICE_OUT}/${FRAMEWORK_NAME}.framework"
IOS_SIMULATOR_FRAMEWORK="${IOS_SIMULATOR_OUT}/${FRAMEWORK_NAME}.framework"
MACOS_FRAMEWORK="${MACOS_UNIVERSAL_FRAMEWORK}"

created_xcframeworks=()

# Create iOS XCFramework if we have at least one iOS framework
if [[ "$ios_device_available" == true ]] || [[ "$ios_simulator_available" == true ]]; then
    IOS_XCFRAMEWORK="${IOS_DIR}/${FRAMEWORK_NAME}.xcframework"
    ios_frameworks=()
    
    if [[ "$ios_device_available" == true ]]; then
        ios_frameworks+=("$IOS_DEVICE_FRAMEWORK")
    fi
    
    if [[ "$ios_simulator_available" == true ]]; then
        ios_frameworks+=("$IOS_SIMULATOR_FRAMEWORK")
    fi
    
    create_xcframework "$FRAMEWORK_NAME" "$IOS_XCFRAMEWORK" "${ios_frameworks[@]}"
    created_xcframeworks+=("iOS XCFramework: ${IOS_XCFRAMEWORK}")
fi

# Create macOS XCFramework if we have macOS framework
if [[ "$macos_arm64_available" == true ]] || [[ "$macos_x86_64_available" == true ]]; then
    MACOS_XCFRAMEWORK="${MACOS_DIR}/${FRAMEWORK_NAME}.xcframework"
    create_xcframework "$FRAMEWORK_NAME" "$MACOS_XCFRAMEWORK" "$MACOS_FRAMEWORK"
    created_xcframeworks+=("macOS XCFramework: ${MACOS_XCFRAMEWORK}")
fi

echo ""
if [[ ${#created_xcframeworks[@]} -gt 0 ]]; then
    echo "XCFrameworks created successfully:"
    for xcframework in "${created_xcframeworks[@]}"; do
        echo "   $xcframework"
    done
else
    echo "No XCFrameworks were created (insufficient dylib files available)"
fi
echo ""

# Clean up temporary directory
rm -rf "$TMP_DIR"
echo "Temporary files cleaned up."
