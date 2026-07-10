#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo_root/my_fork_cross_build.sh"
workflow="$repo_root/.github/workflows/fork-cross-release.yml"
clang_release_version="$(sed -n "s/^RELEASE_VERSION = '\([^']*\)'.*/\1/p" "$repo_root/tools/clang/scripts/update.py" | head -n1)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

output="$("$script" --dry-run riscv64)"
grep -F "profile=debug" <<<"$output" >/dev/null || fail "missing default debug profile"
grep -F "arch=riscv64" <<<"$output" >/dev/null || fail "missing riscv64 arch"
grep -F "docker_platform=linux/riscv64" <<<"$output" >/dev/null || fail "missing riscv64 platform"
grep -F "clang_target=riscv64-unknown-linux-gnu" <<<"$output" >/dev/null || fail "missing riscv64 clang target"
grep -F "system_libdir=lib/riscv64-linux-gnu" <<<"$output" >/dev/null || fail "missing riscv64 system libdir"
grep -F "multiarch_include=riscv64-linux-gnu" <<<"$output" >/dev/null || fail "missing riscv64 multiarch include"
grep -F "clang_release_version=$clang_release_version" <<<"$output" >/dev/null || fail "missing riscv64 clang release version"
grep -F "clang_resource_include=$repo_root/.fork_build/cargo-target/riscv64gc-unknown-linux-gnu/debug/clang/lib/clang/$clang_release_version/include" <<<"$output" >/dev/null || fail "missing riscv64 clang resource include"
grep -F "sysroot=$repo_root/.fork_build/sysroots/debian_trixie_riscv64-sysroot" <<<"$output" >/dev/null || fail "missing riscv64 sysroot"
grep -F "gn_target_sysroot=//.fork_build/sysroots/debian_trixie_riscv64-sysroot" <<<"$output" >/dev/null || fail "missing riscv64 GN target sysroot"
grep -F "fork_bindgen_extra_clang_args_env=RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS" <<<"$output" >/dev/null || fail "missing riscv64 fork bindgen env"
grep -F "bindgen_extra_clang_args=--target=riscv64-unknown-linux-gnu --sysroot=$repo_root/.fork_build/sysroots/debian_trixie_riscv64-sysroot -isystem$repo_root/.fork_build/cargo-target/riscv64gc-unknown-linux-gnu/debug/clang/lib/clang/$clang_release_version/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_riscv64-sysroot/usr/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_riscv64-sysroot/usr/include/riscv64-linux-gnu" <<<"$output" >/dev/null || fail "missing riscv64 bindgen args"

output="$("$script" --dry-run loongarch64)"
grep -F "arch=loongarch64" <<<"$output" >/dev/null || fail "missing loongarch64 arch"
grep -F "docker_platform=linux/loong64" <<<"$output" >/dev/null || fail "missing loong64 platform"
grep -F "clang_target=loongarch64-unknown-linux-gnu" <<<"$output" >/dev/null || fail "missing loong64 clang target"
grep -F "system_libdir=lib/loongarch64-linux-gnu" <<<"$output" >/dev/null || fail "missing loong64 system libdir"
grep -F "multiarch_include=loongarch64-linux-gnu" <<<"$output" >/dev/null || fail "missing loong64 multiarch include"
grep -F "clang_release_version=$clang_release_version" <<<"$output" >/dev/null || fail "missing loong64 clang release version"
grep -F "clang_resource_include=$repo_root/.fork_build/cargo-target/loongarch64-unknown-linux-gnu/debug/clang/lib/clang/$clang_release_version/include" <<<"$output" >/dev/null || fail "missing loong64 clang resource include"
grep -F "sysroot=$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot" <<<"$output" >/dev/null || fail "missing loong64 sysroot"
grep -F "gn_target_sysroot=//.fork_build/sysroots/debian_trixie_loong64-sysroot" <<<"$output" >/dev/null || fail "missing loong64 GN target sysroot"
grep -F "fork_bindgen_extra_clang_args_env=RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS" <<<"$output" >/dev/null || fail "missing loong64 fork bindgen env"
grep -F "bindgen_extra_clang_args=--target=loongarch64-unknown-linux-gnu --sysroot=$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot -isystem$repo_root/.fork_build/cargo-target/loongarch64-unknown-linux-gnu/debug/clang/lib/clang/$clang_release_version/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot/usr/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot/usr/include/loongarch64-linux-gnu" <<<"$output" >/dev/null || fail "missing loong64 bindgen args"

output="$("$script" --build --release --dry-run loongarch64)"
grep -F "build=1" <<<"$output" >/dev/null || fail "missing release build mode"
grep -F "profile=release" <<<"$output" >/dev/null || fail "missing release profile"
grep -F "clang_resource_include=$repo_root/.fork_build/cargo-target/loongarch64-unknown-linux-gnu/release/clang/lib/clang/$clang_release_version/include" <<<"$output" >/dev/null || fail "missing release clang resource include"
grep -F "bindgen_extra_clang_args=--target=loongarch64-unknown-linux-gnu --sysroot=$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot -isystem$repo_root/.fork_build/cargo-target/loongarch64-unknown-linux-gnu/release/clang/lib/clang/$clang_release_version/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot/usr/include -isystem$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot/usr/include/loongarch64-linux-gnu" <<<"$output" >/dev/null || fail "missing release bindgen args"

if "$script" --dry-run x86_64 >/tmp/my_fork_cross_build_invalid.out 2>&1; then
  fail "unsupported arch unexpectedly succeeded"
fi
grep -F "unsupported architecture: x86_64" /tmp/my_fork_cross_build_invalid.out >/dev/null || fail "missing unsupported arch error"

output="$("$script" --dry-run loongarch64)"
grep -F "image=ghcr.io/zarraxx/debian:trixie" <<<"$output" >/dev/null || fail "missing image"
grep -F "host_image=debian:bullseye" <<<"$output" >/dev/null || fail "missing host image"
grep -F "stamp=$repo_root/.fork_build/sysroots/debian_trixie_loong64-sysroot/.my_fork_sysroot_stamp" <<<"$output" >/dev/null || fail "missing stamp"
grep -F "packages=build-essential ca-certificates libc6-dev libglib2.0-dev pkg-config python3" <<<"$output" >/dev/null || fail "missing packages"

sysroot="$repo_root/.fork_build/sysroots/debian_trixie_riscv64-sysroot"
stamp="$sysroot/.my_fork_sysroot_stamp"
created_test_sysroot=0
if [[ ! -d "$sysroot" ]]; then
  created_test_sysroot=1
  mkdir -p "$sysroot"
fi
mkdir -p "$sysroot/usr/include/riscv64-linux-gnu/sys"
touch "$sysroot/usr/include/features.h"
touch "$sysroot/usr/include/riscv64-linux-gnu/sys/cdefs.h"
cat >"$stamp" <<'STAMP'
image=ghcr.io/zarraxx/debian:trixie
arch=riscv64
docker_platform=linux/riscv64
debian_arch=riscv64
rust_target=riscv64gc-unknown-linux-gnu
packages=build-essential ca-certificates libc6-dev libglib2.0-dev pkg-config python3
STAMP

output="$("$script" riscv64)"
grep -F "sysroot is up to date: $sysroot" <<<"$output" >/dev/null || fail "matching stamp did not skip sysroot creation"
if [[ "$created_test_sysroot" == 1 ]]; then
  rm -rf "$sysroot"
fi

for arch in riscv64 loongarch64; do
  output="$("$script" --dry-run "$arch")"
  grep -F "image=ghcr.io/zarraxx/debian:trixie" <<<"$output" >/dev/null || fail "missing image for $arch"
  grep -F "host_image=debian:bullseye" <<<"$output" >/dev/null || fail "missing host image for $arch"
  grep -F ".fork_build/sysroots/debian_trixie_" <<<"$output" >/dev/null || fail "missing fork build sysroot for $arch"
done

for patch_file in "$repo_root"/fork_patches/patches/*.patch; do
  git -C "$repo_root" apply --check "$patch_file" || fail "fork patch does not apply: $patch_file"
done

output="$("$script" --build --dry-run loongarch64)"
grep -F "build=1" <<<"$output" >/dev/null || fail "missing build mode"
grep -F "gn_cpu=loong64" <<<"$output" >/dev/null || fail "missing loong64 gn cpu"
grep -F "cargo_target_dir=$repo_root/.fork_build/cargo-target" <<<"$output" >/dev/null || fail "missing cargo target dir"
grep -F "fork_patches=$repo_root/fork_patches/patches/0001-build-config-add-loong64-sysroot.patch $repo_root/fork_patches/patches/0002-build-config-skip-loong64-clang-builtins.patch $repo_root/fork_patches/patches/0003-build-config-add-debian-multiarch-includes.patch $repo_root/fork_patches/patches/0004-build-rs-add-fork-bindgen-args-env.patch" <<<"$output" >/dev/null || fail "missing fork patches"
grep -F "host_sysroot=$repo_root/.fork_build/sysroots/debian_bullseye_amd64-sysroot" <<<"$output" >/dev/null || fail "missing host sysroot"
grep -F "host_multiarch_include=x86_64-linux-gnu" <<<"$output" >/dev/null || fail "missing host multiarch include"
grep -F "host_tools_dir=$repo_root/.fork_build/bin" <<<"$output" >/dev/null || fail "missing host tools dir"
grep -F 'target_cpu="loong64"' <<<"$output" >/dev/null || fail "missing target_cpu GN arg"
grep -F 'v8_target_cpu="loong64"' <<<"$output" >/dev/null || fail "missing v8_target_cpu GN arg"
grep -F 'target_sysroot="//.fork_build/sysroots/debian_trixie_loong64-sysroot"' <<<"$output" >/dev/null || fail "missing target_sysroot GN arg"
grep -F 'target_sysroot_dir="//.fork_build/sysroots"' <<<"$output" >/dev/null || fail "missing target_sysroot_dir GN arg"
grep -F 'system_libdir="lib/loongarch64-linux-gnu"' <<<"$output" >/dev/null || fail "missing system_libdir GN arg"
grep -F "pkg_config=\"$repo_root/.fork_build/bin/pkg-config\"" <<<"$output" >/dev/null || fail "missing pkg_config GN arg"
grep -F "host_pkg_config=\"$repo_root/.fork_build/bin/pkg-config\"" <<<"$output" >/dev/null || fail "missing host_pkg_config GN arg"

grep -F -- "--exclude=./dev/*" "$script" >/dev/null || fail "sysroot export should skip root device nodes"
grep -F -- "--exclude=dev/*" "$script" >/dev/null || fail "sysroot export should skip root device nodes from docker export"
grep -F -- "--anchored" "$script" >/dev/null || fail "sysroot export excludes should be anchored"
grep -F -- "--exclude=./sys/*" "$script" >/dev/null || fail "sysroot export should skip root sysfs"
grep -F -- "--exclude=sys/*" "$script" >/dev/null || fail "sysroot export should skip root sysfs from docker export"
grep -F "install_sysroot_multiarch_headers" "$script" >/dev/null || fail "script should install multiarch headers"
grep -F "inspect_sysroot_headers" "$script" >/dev/null || fail "script should inspect sysroot headers"
grep -F "normalize_sysroot_symlinks" "$script" >/dev/null || fail "script should normalize sysroot symlinks"
grep -F "realpath --relative-to" "$script" >/dev/null || fail "script should rewrite absolute sysroot symlinks"
grep -F "sysroot header check" "$script" >/dev/null || fail "script should print sysroot header check"
grep -F "ls -ld" "$script" >/dev/null || fail "script should list sysroot header paths"
grep -F "for header_dir in bits gnu sys asm" "$script" >/dev/null || fail "script should install libc multiarch header dirs"
grep -F "sys/cdefs.h" "$script" >/dev/null || fail "script should verify sys/cdefs.h"
grep -F ".git/info/exclude" "$script" >/dev/null || fail "script should update local git exclude"
grep -F ".fork_build/" "$script" >/dev/null || fail "script should ignore fork build directory"
grep -F "unset BINDGEN_EXTRA_CLANG_ARGS" "$script" >/dev/null || fail "script should avoid global bindgen args for host bindgen"
grep -F 'unset "$bindgen_target_env"' "$script" >/dev/null || fail "script should avoid target bindgen args for host bindgen"
if grep -F "export BINDGEN_EXTRA_CLANG_ARGS=" "$script" >/dev/null; then
  fail "script should not append target clang args to global bindgen args"
fi
if grep -F 'export "$bindgen_target_env=' "$script" >/dev/null; then
  fail "script should not append target clang args to target bindgen args"
fi
grep -F "RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS" "$script" >/dev/null || fail "script should export fork bindgen args"
grep -F 'host_sysroot/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2' "$script" >/dev/null || fail "pkg-config wrapper should use sysroot-relative dynamic loader"
if grep -F 'host_sysroot/lib64/ld-linux-x86-64.so.2' "$script" >/dev/null; then
  fail "pkg-config wrapper should not rely on absolute lib64 loader symlink"
fi

[[ -f "$workflow" ]] || fail "missing fork cross release workflow"
grep -F "name: fork-cross-release" "$workflow" >/dev/null || fail "missing workflow name"
grep -F "workflow_dispatch:" "$workflow" >/dev/null || fail "missing workflow_dispatch"
grep -F "tag:" "$workflow" >/dev/null || fail "missing tag input"
grep -F "arch:" "$workflow" >/dev/null || fail "missing arch input"
grep -F "repository: denoland/rusty_v8" "$workflow" >/dev/null || fail "missing upstream checkout"
grep -F "ref: \${{ steps.resolve_tag.outputs.tag }}" "$workflow" >/dev/null || fail "missing resolved tag checkout"
grep -F "repository: \${{ github.repository }}" "$workflow" >/dev/null || fail "missing fork checkout"
grep -F "ref: fork/cross-build-workflow" "$workflow" >/dev/null || fail "missing fork branch checkout"
grep -F "cp -R ../fork-tools/fork_patches ./fork_patches" "$workflow" >/dev/null || fail "missing fork patch injection"
grep -F "./my_fork_cross_build.sh --build --release \"\${{ inputs.arch }}\"" "$workflow" >/dev/null || fail "missing release build command"
grep -F "actions/upload-artifact@v4" "$workflow" >/dev/null || fail "missing artifact upload"
grep -F "softprops/action-gh-release" "$workflow" >/dev/null || fail "missing release upload"

multiarch_patch="$repo_root/fork_patches/patches/0003-build-config-add-debian-multiarch-includes.patch"
[[ -f "$multiarch_patch" ]] || fail "missing multiarch include patch"
grep -F 'current_cpu == "x64"' "$multiarch_patch" >/dev/null || fail "missing x64 multiarch mapping"
grep -F 'x86_64-linux-gnu' "$multiarch_patch" >/dev/null || fail "missing x64 multiarch include"
grep -F 'current_cpu == "loong64"' "$multiarch_patch" >/dev/null || fail "missing loong64 multiarch mapping"
grep -F 'loongarch64-linux-gnu' "$multiarch_patch" >/dev/null || fail "missing loong64 multiarch include"
grep -F 'current_cpu == "riscv64"' "$multiarch_patch" >/dev/null || fail "missing riscv64 multiarch mapping"
grep -F 'riscv64-linux-gnu' "$multiarch_patch" >/dev/null || fail "missing riscv64 multiarch include"
grep -F 'usr/include/$_multiarch_include' "$multiarch_patch" >/dev/null || fail "missing sysroot multiarch include path"

fork_bindgen_patch="$repo_root/fork_patches/patches/0004-build-rs-add-fork-bindgen-args-env.patch"
[[ -f "$fork_bindgen_patch" ]] || fail "missing fork bindgen args patch"
grep -F 'RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS' "$fork_bindgen_patch" >/dev/null || fail "missing fork bindgen env in patch"
grep -F 'split_whitespace' "$fork_bindgen_patch" >/dev/null || fail "missing fork bindgen arg parsing"
