#!/usr/bin/env bash

# Generates code for and builds loro-swift's loroFFI rlib, in the form needed for Renewed Vision projects.  We just need the .rlib, built for arm64 + x86_64, and don't wrap it in an .xcframework.

# This script was cribbed from build_swift_ffi.sh
# which was cribbed from build_macos.sh
# which was cribbed from https://github.com/automerge/automerge-swift/blob/main/scripts/build-xcframework.sh
# which was cribbed from https://github.com/y-crdt/y-uniffi/blob/7cd55266c11c424afa3ae5b3edae6e9f70d9a6bb/lib/build-xcframework.sh
# which was written by Joseph Heck and  Aidar Nugmanoff and licensed under the MIT license.

set -euxo pipefail
THIS_SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LIB_NAME="libloro.a"
RUST_FOLDER="$THIS_SCRIPT_DIR/../loro-rs"
FRAMEWORK_NAME="loroFFI"

SWIFT_PACKAGE_FOLDER="$THIS_SCRIPT_DIR/.."
SWIFT_FOLDER="$THIS_SCRIPT_DIR/../gen-swift"
BUILD_FOLDER="$RUST_FOLDER/target"

XCFRAMEWORK_FOLDER="$THIS_SCRIPT_DIR/../${FRAMEWORK_NAME}.xcframework"

# The specific issue with an earlier nightly version and linking into an
# XCFramework appears to be resolved with latest versions of +nightly toolchain
# (as of 10/10/23), but leaving it open to float seems less useful than
# moving the pinning forward, since Catalyst support (target macabi) still
# requires an active, nightly toolchain.
RUST_NIGHTLY="nightly-2024-10-09"

echo "Install nightly and rust-src for Catalyst"
rustup toolchain install ${RUST_NIGHTLY}
rustup component add rust-src --toolchain ${RUST_NIGHTLY}
rustup update
rustup default ${RUST_NIGHTLY}


echo "▸ Install toolchains"
rustup target add aarch64-apple-darwin # macOS ARM/M1
rustup target add x86_64-apple-darwin # macOS Intel/x86
cargo_build="cargo build --manifest-path $RUST_FOLDER/Cargo.toml"
cargo_build_nightly="cargo +${RUST_NIGHTLY} build --manifest-path $RUST_FOLDER/Cargo.toml"
cargo_build_nightly_with_std="cargo -Zbuild-std build --manifest-path $RUST_FOLDER/Cargo.toml"

echo "▸ Clean state"
rm -rf "${XCFRAMEWORK_FOLDER}"
rm -rf "${SWIFT_FOLDER}"
mkdir -p "${SWIFT_FOLDER}"
echo "▸ Generate Swift Scaffolding Code"
cargo run --manifest-path "$RUST_FOLDER/Cargo.toml"  \
    --features=cli \
    --bin uniffi-bindgen generate \
    "$RUST_FOLDER/src/loro.udl" \
    --no-format \
    --language swift \
    --out-dir "${SWIFT_FOLDER}"

bash "${THIS_SCRIPT_DIR}/refine_trait.sh"

echo "▸ Building for aarch64-apple-darwin"
CFLAGS_aarch64_apple_darwin="-target aarch64-apple-darwin" \
$cargo_build --target aarch64-apple-darwin --locked --release

echo "▸ Building for x86_64-apple-darwin"
CFLAGS_x86_64_apple_darwin="-target x86_64-apple-darwin" \
$cargo_build --target x86_64-apple-darwin --locked --release

# Copy the generated loroFFI.h into our Swift package loroFFI target's sources.
echo "▸ Copying ${SWIFT_FOLDER}/loroFFI.h to ${SWIFT_PACKAGE_FOLDER}/Sources/loroFFI/include/loroFFI.h"
cp "${SWIFT_FOLDER}/loroFFI.h" "${SWIFT_PACKAGE_FOLDER}/Sources/loroFFI/include/loroFFI.h"

# Copy the generated loro.swift into our Swift package LoroSwift target's sources.
cp "${SWIFT_FOLDER}/loro.swift" "${SWIFT_PACKAGE_FOLDER}/Sources/Loro/LoroFFI.swift"

echo "▸ Done. Check for changes to these files that should be committed to git:"
echo "Sources/loroFFI/include/loroFFI.h"
echo "Sources/Loro/LoroFFI.swift"

echo "Dumping _loro_ffi_ symbols in .rlib:"
objdump -t target/aarch64-apple-darwin/release/libloro_swift.rlib | grep _ffi_loro_

echo "▸ Ready to run swift build"
