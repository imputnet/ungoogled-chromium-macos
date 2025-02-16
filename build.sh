#!/usr/bin/env bash

set -eux

# Build script for local macOS environment

# The architecture of the running shell
# Also used to determine the build target architecture
_arch="$(/usr/bin/uname -m)"

# Paths for required toolchain binaries
_x86_64_homebrew_path="/usr/local/opt"
_arm64_homebrew_path="/opt/homebrew/opt"
_homebrew_path="$_x86_64_homebrew_path"
if [[ $_arch == "arm64" ]]; then
  _homebrew_path="$_arm64_homebrew_path"
fi
_clangxx_path="$_homebrew_path/llvm/bin"
_ninja_path="$_homebrew_path/ninja/bin"
_python_path="$_homebrew_path/python3/bin"

export PATH="$_clangxx_path:$_ninja_path:$_python_path:$PATH"
export CXX="$_clangxx_path/clang++"
export NINJA="$_ninja_path/ninja"
export LDFLAGS="-L$_homebrew_path/llvm/lib"
export CPPFLAGS="-I$_homebrew_path/llvm/include"

# Some path variables
_root_dir=$(dirname $(greadlink -f $0))
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/ungoogled-chromium"

# Clone to get the Chromium Source
clone=true
while getopts 'd' OPTION; do
  case "$OPTION" in
    d)
      clone=false
      ;;
  esac
done

rm -rf "$_src_dir/out" || true
mkdir -p "$_download_cache"

if $clone; then
  /usr/bin/arch -$_arch /bin/zsh "$_root_dir/retrieve_and_unpack_resource.sh" -g
else
  /usr/bin/arch -$_arch /bin/zsh "$_root_dir/retrieve_and_unpack_resource.sh" -d -g
fi

mkdir -p "$_src_dir/out/Default"

# Apply patches and substitutions
/usr/bin/arch -$_arch $_python_path/python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
/usr/bin/arch -$_arch $_python_path/python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
/usr/bin/arch -$_arch $_python_path/python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"
# Set build flags
cat "$_main_repo/flags.gn" "$_root_dir/flags.macos.gn" > "$_src_dir/out/Default/args.gn"

if command -v ccache 2>&1 >/dev/null; then
  echo 'cc_wrapper="env CCACHE_SLOPPINESS=time_macros ccache"' >> "$_src_dir/out/Default/args.gn";
else
  echo 'warn: ccache is not available' >&2
fi

# Set target_cpu to the corresponding architecture
if [[ $_arch == "arm64" ]]; then
  echo 'target_cpu = "arm64"' >> "$_src_dir/out/Default/args.gn"
else
  echo 'target_cpu = "x64"' >> "$_src_dir/out/Default/args.gn"
fi

mkdir -p "$_src_dir/third_party/rust-toolchain/bin"

/usr/bin/arch -$_arch /bin/zsh "$_root_dir/retrieve_and_unpack_resource.sh" -p

cd "$_src_dir"

_rust_target="x86_64-apple-darwin"
if [[ $_arch == "arm64" ]]; then
  _rust_target="aarch64-apple-darwin"
fi

/usr/bin/arch -$_arch $_python_path/python3 ./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
/usr/bin/arch -$_arch $_python_path/python3 ./tools/rust/build_bindgen.py --rust-target $_rust_target

/usr/bin/arch -$_arch ./out/Default/gn gen out/Default --fail-on-unused-args

ln -s "$_src_dir/third_party" "$_src_dir/../third_party"

/usr/bin/arch -$_arch $_ninja_path/ninja -C out/Default chrome chromedriver

/bin/zsh "$_root_dir/sign_and_package_app.sh"
