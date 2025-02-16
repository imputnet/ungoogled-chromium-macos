#!/usr/bin/env bash

# Script to retrieve and unpack resources to build Chromium macOS

set -eux

_target_cpu="$(/usr/bin/uname -m)"

# Paths for required toolchain binaries
_x86_64_homebrew_path="/usr/local/opt"
_arm64_homebrew_path="/opt/homebrew/opt"
_homebrew_path="$_x86_64_homebrew_path"
if [[ $_target_cpu == "arm64" ]]; then
  _homebrew_path="$_arm64_homebrew_path"
fi
_python_path="$_homebrew_path/python3/bin"

_root_dir=$(dirname $(greadlink -f $0))
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/ungoogled-chromium"

# Clone to get the Chromium Source
clone=true

while getopts 'dgp' OPTION; do
  case "$OPTION" in
    d)
        clone=false
        ;;
    g)
        # Retrieve and unpack Chromium Source
        if $clone; then
            if [[ $_target_cpu == "arm64" ]]; then
                # For arm64 (Apple Silicon)
                /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/clone.py" -p mac-arm -o "$_src_dir"
            else
                # For amd64 (Intel)
                /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/clone.py" -p mac -o "$_src_dir"
            fi
        else
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" retrieve -i "$_main_repo/downloads.ini" -c "$_download_cache"
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" unpack -i "$_main_repo/downloads.ini" -c "$_download_cache" "$_src_dir"
        fi

        # Retrieve and unpack general resources
        /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads.ini" -c "$_download_cache"
        /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads.ini" -c "$_download_cache" "$_src_dir"
        ;;
    p)
        rm -rf "$_src_dir/third_party/llvm-build/Release+Asserts/"
        rm -rf "$_src_dir/third_party/rust-toolchain/bin/"

        # Retrieve and unpack platform-specific resources
        if [[ $_target_cpu == "arm64" ]]; then
            # For arm64 (Apple Silicon)
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-arm64.ini" -c "$_download_cache"
            mkdir -p "$_src_dir/third_party/node/mac_arm64/node-darwin-arm64/"
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-arm64.ini" -c "$_download_cache" "$_src_dir"
        else
            # For x86-64 (Intel)
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" retrieve -i "$_root_dir/downloads-x86-64.ini" -c "$_download_cache"
            mkdir -p "$_src_dir/third_party/node/mac/node-darwin-x64/"
            /usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/downloads.py" unpack -i "$_root_dir/downloads-x86-64.ini" -c "$_download_cache" "$_src_dir"
        fi

        ## Rust Resource
        _rust_name="x86_64-apple-darwin"
        if [[ $_target_cpu == "arm64" ]]; then
            _rust_name="aarch64-apple-darwin"
        fi

        _rust_dir="$_src_dir/third_party/rust-toolchain"
        _rust_bin_dir="$_rust_dir/bin"
        _rust_flag_file="$_rust_dir/INSTALLED_VERSION"

        _rust_lib_dir="$_rust_dir/rust-std-$_rust_name/lib/rustlib/$_rust_name/lib"
        _rustc_dir="$_rust_dir/rustc"
        _rustc_lib_dir="$_rust_dir/rustc/lib/rustlib/$_rust_name/lib"

        echo "rustc 1.85.0-nightly (9e136a30a 2024-12-19)" > "$_rust_flag_file"

        mkdir -p "$_rust_bin_dir"
        mkdir -p "$_rust_dir/lib"
        ln -s "$_rust_dir/rustc/bin/rustc" "$_rust_bin_dir/rustc"
        ln -s "$_rust_dir/cargo/bin/cargo" "$_rust_bin_dir/cargo"
        ln -s "$_rust_lib_dir" "$_rustc_lib_dir"

        ;;
    ?)
        echo "Usage: $0 [-d] [-g] [-p]"
        echo "  -d: Use download instead of git clone to get Chromium Source"
        echo "  -g: Retrieve and unpack Chromium Source and general resources"
        echo "  -p: Retrieve and unpack platform-specific resources"
        exit 1
        ;;
    esac
done

shift "$(($OPTIND -1))"
