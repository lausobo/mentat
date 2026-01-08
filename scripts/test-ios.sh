#!/bin/bash
set -euo pipefail

# Install iOS targets with Rustup for 64-bit device/simulator builds.
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Use the current cargo-lipo release to avoid yanked dependencies.
cargo install cargo-lipo --locked

# If we don't list the devices available then, when we come to pick one during the test run, Travis doesn't
# think that there are any devices available and the build fails.
# TODO: See if there is a less time consuming way of doing this.
# instruments -s devices

# Build Mentat as a universal iOS library.
pushd ffi
cargo lipo --release
popd

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
xcodebuild -configuration Debug -scheme "Mentat Debug" -sdk iphonesimulator test -destination "platform=iOS Simulator,id=$SIM_DEVICE_ID"
popd
