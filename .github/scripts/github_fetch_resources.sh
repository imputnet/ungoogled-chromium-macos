#!/bin/bash -eux

# Simple script for downloading and unpacking required resources to build Ungoogled-Chromium macOS binaries on GitHub Actions

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

mkdir -p "$_src_dir"
sudo df -h
sudo du -hs "$_src_dir"

rm -rf "$_src_dir/out" || true
mkdir -p "$_download_cache"

/usr/bin/arch -$_target_cpu /bin/bash "$_root_dir/retrieve_and_unpack_resource.sh" -g

mkdir -p "$_src_dir/out/Default"

/usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
/usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
/usr/bin/arch -$_target_cpu $_python_path/python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"

mkdir -p "$_src_dir/third_party/rust-toolchain/bin"

/usr/bin/arch -$_target_cpu /bin/bash "$_root_dir/retrieve_and_unpack_resource.sh" -p

rm -rvf "$_download_cache"
