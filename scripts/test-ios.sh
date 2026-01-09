#!/bin/bash
set -euo pipefail

# Install Rust targets for iOS and macOS builds.
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios aarch64-apple-darwin x86_64-apple-darwin

# Use the current cargo-lipo release to avoid yanked dependencies.
cargo install cargo-lipo --locked

# Align Rust/C build min version with the Swift SDK deployment target to avoid linker warnings.
export IPHONEOS_DEPLOYMENT_TARGET=15.0

# If we don't list the devices available then, when we come to pick one during the test run, Travis doesn't
# think that there are any devices available and the build fails.
# TODO: See if there is a less time consuming way of doing this.
# instruments -s devices

# Build Mentat for device, simulator, and macOS, then create an xcframework.
ROOT_DIR="$(pwd)"
pushd ffi
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
popd

XCFRAMEWORK_PATH="$ROOT_DIR/sdks/swift/Mentat/External-Dependencies/MentatFFI.xcframework"
SIM_FAT_DIR="$ROOT_DIR/target/universal-sim/release"
MAC_FAT_DIR="$ROOT_DIR/target/universal-macos/release"
mkdir -p "$SIM_FAT_DIR"
mkdir -p "$MAC_FAT_DIR"
XCODE_LIPO="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/lipo"
LIPO_SIM_LIB="$SIM_FAT_DIR/libmentat_ffi.a"
LIPO_MAC_LIB="$MAC_FAT_DIR/libmentat_ffi.a"
rm -f "$LIPO_SIM_LIB"
rm -f "$LIPO_MAC_LIB"
"$XCODE_LIPO" -create \
  "$ROOT_DIR/target/aarch64-apple-ios-sim/release/libmentat_ffi.a" \
  "$ROOT_DIR/target/x86_64-apple-ios/release/libmentat_ffi.a" \
  -output "$LIPO_SIM_LIB"
"$XCODE_LIPO" -create \
  "$ROOT_DIR/target/aarch64-apple-darwin/release/libmentat_ffi.a" \
  "$ROOT_DIR/target/x86_64-apple-darwin/release/libmentat_ffi.a" \
  -output "$LIPO_MAC_LIB"
rm -rf "$XCFRAMEWORK_PATH"
xcodebuild -create-xcframework \
  -library "$ROOT_DIR/target/aarch64-apple-ios/release/libmentat_ffi.a" -headers "$ROOT_DIR/sdks/swift/Mentat/Mentat" \
  -library "$LIPO_SIM_LIB" -headers "$ROOT_DIR/sdks/swift/Mentat/Mentat" \
  -library "$LIPO_MAC_LIB" -headers "$ROOT_DIR/sdks/swift/Mentat/Mentat" \
  -output "$XCFRAMEWORK_PATH"

# Run the iOS SDK tests using xcodebuild.
pushd sdks/swift/Mentat
SIM_DEVICE_ID="$(xcrun simctl list devices available -j | python3 -c '
import json
import sys

data = json.load(sys.stdin)
devices = data.get("devices", {})

def runtime_version(runtime):
    if "iOS-" not in runtime:
        return None
    version = runtime.split("iOS-")[1]
    parts = version.split("-")
    major = int(parts[0]) if parts[0].isdigit() else 0
    minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
    return (major, minor)

ios_runtimes = []
for runtime in devices.keys():
    version = runtime_version(runtime)
    if version is not None:
        ios_runtimes.append((version, runtime))

if not ios_runtimes:
    print("")
    sys.exit(0)

ios_runtimes.sort(reverse=True)
preferred = [rt for ver, rt in ios_runtimes if ver[0] <= 18]
runtime_order = preferred if preferred else [rt for _, rt in ios_runtimes]

for runtime in runtime_order:
    for device in devices.get(runtime, []):
        if device.get("name", "").startswith("iPhone") and device.get("isAvailable", False):
            print(device.get("udid", ""))
            sys.exit(0)
print("")
'
)"
if [ -z "$SIM_DEVICE_ID" ]; then
  echo "No available iPhone Simulator device found." >&2
  exit 1
fi
xcodebuild -scheme Mentat -sdk iphonesimulator test -destination "platform=iOS Simulator,id=$SIM_DEVICE_ID"
popd
