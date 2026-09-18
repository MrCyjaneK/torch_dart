#!/bin/bash
#
# Minimal stand-in for `xcodebuild -create-xcframework` on hosts without Xcode,
# so create-xcframework.sh can run on the Linux cross-build. It accepts exactly
# the arguments that script passes and refuses anything else -- this is not a
# general xcodebuild replacement.
#
#   ./xcodebuild_shim.sh -create-xcframework -framework <path> [-framework <path> ...] -output <path>
#
# Per slice: platform and variant come from the framework's own Info.plist
# (CFBundleSupportedPlatforms), architectures from `lipo -archs` on its binary.
# Nothing is hardcoded, so a universal slice yields e.g. ios-arm64_x86_64-simulator.
set -e

usage_error() {
    echo "xcodebuild_shim: $1" >&2
    echo "  supported: -create-xcframework -framework <path> ... -output <path>" >&2
    exit 1
}

create_xcframework=0
frameworks=()
output=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -create-xcframework)
            create_xcframework=1
            shift
            ;;
        -framework)
            [[ $# -ge 2 ]] || usage_error "-framework requires a path"
            frameworks+=("$2")
            shift 2
            ;;
        -output)
            [[ $# -ge 2 ]] || usage_error "-output requires a path"
            output="$2"
            shift 2
            ;;
        *)
            usage_error "unsupported argument: $1"
            ;;
    esac
done

[[ $create_xcframework -eq 1 ]] || usage_error "only -create-xcframework is implemented"
[[ ${#frameworks[@]} -gt 0 ]]   || usage_error "no -framework given"
[[ -n "$output" ]]              || usage_error "no -output given"
[[ ! -e "$output" ]]            || usage_error "output already exists: $output"

# cctools-port symlinks its tools to unprefixed names, but fall back to the
# prefixed form and then to PATH so this works on macOS too.
find_lipo() {
    if [[ -n "${SIMPLYBS_NATIVE_ENV_DIR:-}" ]]; then
        if [[ -x "$SIMPLYBS_NATIVE_ENV_DIR/bin/lipo" ]]; then
            echo "$SIMPLYBS_NATIVE_ENV_DIR/bin/lipo"
            return 0
        fi
        local prefixed
        prefixed="$(ls "$SIMPLYBS_NATIVE_ENV_DIR"/bin/*-lipo 2>/dev/null | head -1)"
        if [[ -n "$prefixed" ]]; then
            echo "$prefixed"
            return 0
        fi
    fi
    command -v lipo 2>/dev/null || true
}

LIPO="$(find_lipo)"
[[ -n "$LIPO" ]] || usage_error "no lipo found (set SIMPLYBS_NATIVE_ENV_DIR or put lipo on PATH)"

records="$(mktemp)"
trap 'rm -f "$records"' EXIT

mkdir -p "$output"

for fw in "${frameworks[@]}"; do
    [[ -d "$fw" ]] || usage_error "not a directory: $fw"

    bundle="$(basename "$fw")"
    name="${bundle%.framework}"
    [[ "$bundle" != "$name" ]] || usage_error "not a .framework: $fw"

    # Versioned (macOS) bundles keep the binary and Info.plist under Versions/A.
    if [[ -f "$fw/Versions/A/$name" ]]; then
        binary="$fw/Versions/A/$name"
        binary_rel="$bundle/Versions/A/$name"
        plist="$fw/Versions/A/Resources/Info.plist"
    elif [[ -f "$fw/$name" ]]; then
        binary="$fw/$name"
        binary_rel="$bundle/$name"
        plist="$fw/Info.plist"
    else
        usage_error "no binary found in $fw"
    fi
    [[ -f "$plist" ]] || usage_error "no Info.plist found at $plist"

    sdk="$(sed -n '/<key>CFBundleSupportedPlatforms<\/key>/,/<\/array>/p' "$plist" \
         | grep -o '<string>[^<]*</string>' | head -1 \
         | sed -e 's|<string>||' -e 's|</string>||')"
    case "$sdk" in
        iPhoneOS)        platform="ios";   variant=""          ;;
        iPhoneSimulator) platform="ios";   variant="simulator" ;;
        MacOSX)          platform="macos"; variant=""          ;;
        *) usage_error "unsupported CFBundleSupportedPlatforms '$sdk' in $plist" ;;
    esac

    archs=()
    while read -r arch; do
        [[ -n "$arch" ]] && archs+=("$arch")
    done < <("$LIPO" -archs "$binary" | tr ' ' '\n' | sort)
    [[ ${#archs[@]} -gt 0 ]] || usage_error "no architectures in $binary"

    joined="$(IFS=_; echo "${archs[*]}")"
    identifier="$platform-$joined"
    if [[ -n "$variant" ]]; then
        identifier="$identifier-$variant"
    fi

    if [[ -e "$output/$identifier" ]]; then
        usage_error "duplicate slice $identifier (from $fw)"
    fi

    mkdir -p "$output/$identifier"
    cp -a "$fw" "$output/$identifier/"

    # "-" rather than an empty field: bash collapses adjacent tabs on read,
    # which would silently shift every field after an absent variant.
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$identifier" "$bundle" "$binary_rel" "$platform" "${variant:--}" "${archs[*]}" >> "$records"
done

# Sorted so the output is byte-stable for content-addressed caching.
sort -o "$records" "$records"

plist_out="$output/Info.plist"
{
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    printf '<plist version="1.0">\n'
    printf '<dict>\n'
    printf '\t<key>AvailableLibraries</key>\n'
    printf '\t<array>\n'
    while IFS=$'\t' read -r identifier bundle binary_rel platform variant archs; do
        [[ "$variant" == "-" ]] && variant=""
        printf '\t\t<dict>\n'
        printf '\t\t\t<key>BinaryPath</key>\n\t\t\t<string>%s</string>\n' "$binary_rel"
        printf '\t\t\t<key>LibraryIdentifier</key>\n\t\t\t<string>%s</string>\n' "$identifier"
        printf '\t\t\t<key>LibraryPath</key>\n\t\t\t<string>%s</string>\n' "$bundle"
        printf '\t\t\t<key>SupportedArchitectures</key>\n\t\t\t<array>\n'
        for arch in $archs; do
            printf '\t\t\t\t<string>%s</string>\n' "$arch"
        done
        printf '\t\t\t</array>\n'
        printf '\t\t\t<key>SupportedPlatform</key>\n\t\t\t<string>%s</string>\n' "$platform"
        if [[ -n "$variant" ]]; then
            printf '\t\t\t<key>SupportedPlatformVariant</key>\n\t\t\t<string>%s</string>\n' "$variant"
        fi
        printf '\t\t</dict>\n'
    done < "$records"
    printf '\t</array>\n'
    printf '\t<key>CFBundlePackageType</key>\n\t<string>XFWK</string>\n'
    printf '\t<key>XCFrameworkFormatVersion</key>\n\t<string>1.0</string>\n'
    printf '</dict>\n'
    printf '</plist>\n'
} > "$plist_out"

echo "xcframework successfully written out to: $output"
