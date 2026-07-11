#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: ./my_fork_cross_build.sh [--build] [--dry-run] <riscv64|loongarch64>
       ./my_fork_cross_build.sh [--build] [--release] [--dry-run] <riscv64|loongarch64>
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=0
build=0
profile="debug"
cargo_profile_args=()

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --build)
      build=1
      ;;
    --release)
      profile="release"
      cargo_profile_args=(--release)
      ;;
    --dry-run)
      dry_run=1
      ;;
    *)
      echo "unsupported option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

arch="${1:-}"
if [[ -z "$arch" ]]; then
  usage
  exit 2
fi

case "$arch" in
  riscv64)
    docker_platform="linux/riscv64"
    debian_arch="riscv64"
    rust_target="riscv64gc-unknown-linux-gnu"
    clang_target="riscv64-unknown-linux-gnu"
    sysroot_suffix="riscv64"
    gn_cpu="riscv64"
    system_libdir="lib/riscv64-linux-gnu"
    ;;
  loongarch64)
    docker_platform="linux/loong64"
    debian_arch="loong64"
    rust_target="loongarch64-unknown-linux-gnu"
    clang_target="loongarch64-unknown-linux-gnu"
    sysroot_suffix="loong64"
    gn_cpu="loong64"
    system_libdir="lib/loongarch64-linux-gnu"
    ;;
  *)
    echo "unsupported architecture: $arch" >&2
    usage
    exit 2
    ;;
esac

build_dir="$repo_root/.fork_build"
sysroot="$build_dir/sysroots/debian_trixie_${sysroot_suffix}-sysroot"
gn_target_sysroot="//.fork_build/sysroots/debian_trixie_${sysroot_suffix}-sysroot"
host_sysroot="$build_dir/sysroots/debian_bullseye_amd64-sysroot"
image="ghcr.io/zarraxx/debian:trixie"
host_image="debian:bullseye"
packages=(build-essential ca-certificates libc6-dev libglib2.0-dev pkg-config python3)
stamp="$sysroot/.my_fork_sysroot_stamp"
host_stamp="$host_sysroot/.my_fork_sysroot_stamp"
cargo_target_dir="$build_dir/cargo-target"
host_tools_dir="$build_dir/bin"
multiarch_include="${system_libdir#lib/}"
host_multiarch_include="x86_64-linux-gnu"
bindgen_extra_clang_args="--target=$clang_target --sysroot=$sysroot -isystem$sysroot/usr/include -isystem$sysroot/usr/include/$multiarch_include"
bindgen_target_env="BINDGEN_EXTRA_CLANG_ARGS_${rust_target//-/_}"
fork_bindgen_extra_clang_args_env="RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS"
fork_patches=(
  "$repo_root/fork_patches/patches/0001-build-config-add-loong64-sysroot.patch"
  "$repo_root/fork_patches/patches/0002-build-config-skip-loong64-clang-builtins.patch"
  "$repo_root/fork_patches/patches/0003-build-config-add-debian-multiarch-includes.patch"
  "$repo_root/fork_patches/patches/0004-build-rs-add-fork-bindgen-args-env.patch"
)
fork_gn_args="target_os=\"linux\" target_cpu=\"$gn_cpu\" v8_target_cpu=\"$gn_cpu\" use_sysroot=true target_sysroot=\"$gn_target_sysroot\" target_sysroot_dir=\"//.fork_build/sysroots\" system_libdir=\"$system_libdir\" pkg_config=\"$host_tools_dir/pkg-config\" host_pkg_config=\"$host_tools_dir/pkg-config\""

ensure_fork_build_ignored() {
  local exclude_file="$repo_root/.git/info/exclude"
  if [[ -d "$repo_root/.git" ]]; then
    mkdir -p "$(dirname "$exclude_file")"
    grep -Fx ".fork_build/" "$exclude_file" >/dev/null 2>&1 ||
      printf '.fork_build/\n' >>"$exclude_file"
  fi
}

stamp_content() {
  local stamp_image="$1"
  local stamp_arch="$2"
  local stamp_platform="$3"
  local stamp_debian_arch="$4"
  local stamp_rust_target="$5"

  printf 'image=%s\n' "$stamp_image"
  printf 'arch=%s\n' "$stamp_arch"
  printf 'docker_platform=%s\n' "$stamp_platform"
  printf 'debian_arch=%s\n' "$stamp_debian_arch"
  printf 'rust_target=%s\n' "$stamp_rust_target"
  printf 'packages=%s\n' "${packages[*]}"
}

prepare_sysroot() {
  local sysroot_path="$1"
  local stamp_path="$2"
  local stamp_image="$3"
  local stamp_arch="$4"
  local stamp_platform="$5"
  local stamp_debian_arch="$6"
  local stamp_rust_target="$7"
  local tmp_name="$8"

  local need_sysroot=1
  if [[ -f "$stamp_path" ]] &&
    diff -u "$stamp_path" <(stamp_content "$stamp_image" "$stamp_arch" "$stamp_platform" "$stamp_debian_arch" "$stamp_rust_target") >/dev/null; then
    need_sysroot=0
  fi

  if [[ "$need_sysroot" == 0 ]]; then
    echo "sysroot is up to date: $sysroot_path"
    return
  fi

  command -v docker >/dev/null 2>&1 || {
    echo "docker is required to create the sysroot" >&2
    exit 1
  }

  local tmp_root="$build_dir/sysroots/$tmp_name"
  rm -rf "$tmp_root"
  mkdir -p "$tmp_root"

  local install_cmd="apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${packages[*]} && apt-get clean && rm -rf /var/lib/apt/lists/*"
  local container_id
  container_id="$(
    docker create --platform "$stamp_platform" "$stamp_image" bash -lc "$install_cmd"
  )"

  cleanup_container() {
    docker rm -f "$container_id" >/dev/null 2>&1 || true
  }
  trap cleanup_container EXIT

  docker start -a "$container_id"
  docker export "$container_id" | tar \
    --anchored \
    --exclude=./dev/* \
    --exclude=dev/* \
    --exclude=./proc/* \
    --exclude=proc/* \
    --exclude=./run/* \
    --exclude=run/* \
    --exclude=./sys/* \
    --exclude=sys/* \
    --exclude=./tmp/* \
    --exclude=tmp/* \
    -C "$tmp_root" \
    -xf -
  cleanup_container
  trap - EXIT

  rm -rf "$sysroot_path"
  mv "$tmp_root" "$sysroot_path"
  stamp_content "$stamp_image" "$stamp_arch" "$stamp_platform" "$stamp_debian_arch" "$stamp_rust_target" >"$stamp_path"
  echo "created sysroot: $sysroot_path"
}

install_sysroot_multiarch_headers() {
  local sysroot_path="$1"
  local multiarch="$2"
  local include_dir="$sysroot_path/usr/include"
  local multiarch_dir="$include_dir/$multiarch"
  local header_dir

  [[ -d "$multiarch_dir" ]] || return

  for header_dir in bits gnu sys asm; do
    if [[ -L "$include_dir/$header_dir" ]]; then
      rm "$include_dir/$header_dir"
    fi
    if [[ -e "$multiarch_dir/$header_dir" && ! -e "$include_dir/$header_dir" ]]; then
      cp -a "$multiarch_dir/$header_dir" "$include_dir/$header_dir"
      echo "installed sysroot multiarch headers: $include_dir/$header_dir"
    fi
  done

  if [[ -e "$multiarch_dir/sys/cdefs.h" && ! -e "$include_dir/sys/cdefs.h" ]]; then
    echo "failed to install sysroot multiarch header: $include_dir/sys/cdefs.h" >&2
    find "$include_dir" -maxdepth 3 \( -path "*/sys/cdefs.h" -o -path "*/features.h" \) -print >&2
    exit 1
  fi
}

normalize_sysroot_symlinks() {
  local sysroot_path="$1"
  local link_path
  local link_target
  local relative_target

  while IFS= read -r -d '' link_path; do
    link_target="$(readlink "$link_path")"
    [[ "$link_target" == /* ]] || continue
    [[ -e "$sysroot_path$link_target" ]] || continue

    relative_target="$(realpath --relative-to="$(dirname "$link_path")" "$sysroot_path$link_target")"
    ln -snf "$relative_target" "$link_path"
    echo "normalized sysroot symlink: $link_path -> $relative_target"
  done < <(find "$sysroot_path" -type l -print0)
}

inspect_sysroot_headers() {
  local sysroot_path="$1"
  local multiarch="$2"
  local include_dir="$sysroot_path/usr/include"

  echo "sysroot header check: $sysroot_path"
  ls -ld \
    "$include_dir" \
    "$include_dir/features.h" \
    "$include_dir/$multiarch" \
    "$include_dir/$multiarch/sys" \
    "$include_dir/$multiarch/sys/cdefs.h" \
    "$include_dir/sys" \
    "$include_dir/sys/cdefs.h"
  find "$include_dir" -maxdepth 3 \( \
    -path "*/features.h" -o \
    -path "*/sys/cdefs.h" \
  \) -print | sort
}

write_host_tools() {
  mkdir -p "$host_tools_dir"
  cat >"$host_tools_dir/pkg-config" <<EOF
#!/usr/bin/env bash
set -euo pipefail
host_sysroot="$host_sysroot"
if [[ -n "\${PKG_CONFIG_LIBDIR:-}" ]]; then
  pkg_config_libdir="\$PKG_CONFIG_LIBDIR"
  IFS=: read -r -a pkg_config_paths <<<"\$PKG_CONFIG_LIBDIR"
  for pkg_config_path in "\${pkg_config_paths[@]}"; do
    case "\$pkg_config_path" in
      */usr/lib/pkgconfig)
        pkg_config_sysroot="\${pkg_config_path%/usr/lib/pkgconfig}"
        for multiarch in x86_64-linux-gnu loongarch64-linux-gnu riscv64-linux-gnu; do
          pkg_config_multiarch="\$pkg_config_sysroot/usr/lib/\$multiarch/pkgconfig"
          if [[ -d "\$pkg_config_multiarch" ]]; then
            pkg_config_libdir="\$pkg_config_libdir:\$pkg_config_multiarch"
          fi
        done
        ;;
    esac
  done
  export PKG_CONFIG_LIBDIR="\$pkg_config_libdir"
fi
exec "\$host_sysroot/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2" \\
  --library-path "\$host_sysroot/usr/lib/x86_64-linux-gnu:\$host_sysroot/lib/x86_64-linux-gnu" \\
  "\$host_sysroot/usr/bin/pkg-config" "\$@"
EOF
  chmod +x "$host_tools_dir/pkg-config"
}

if [[ "$dry_run" == 1 ]]; then
  printf 'build=%s\n' "$build"
  printf 'profile=%s\n' "$profile"
  printf 'arch=%s\n' "$arch"
  printf 'docker_platform=%s\n' "$docker_platform"
  printf 'debian_arch=%s\n' "$debian_arch"
  printf 'rust_target=%s\n' "$rust_target"
  printf 'clang_target=%s\n' "$clang_target"
  printf 'gn_cpu=%s\n' "$gn_cpu"
  printf 'system_libdir=%s\n' "$system_libdir"
  printf 'multiarch_include=%s\n' "$multiarch_include"
  printf 'sysroot=%s\n' "$sysroot"
  printf 'gn_target_sysroot=%s\n' "$gn_target_sysroot"
  printf 'host_sysroot=%s\n' "$host_sysroot"
  printf 'host_multiarch_include=%s\n' "$host_multiarch_include"
  printf 'host_tools_dir=%s\n' "$host_tools_dir"
  printf 'image=%s\n' "$image"
  printf 'host_image=%s\n' "$host_image"
  printf 'stamp=%s\n' "$stamp"
  printf 'packages=%s\n' "${packages[*]}"
  printf 'cargo_target_dir=%s\n' "$cargo_target_dir"
  printf 'fork_bindgen_extra_clang_args_env=%s\n' "$fork_bindgen_extra_clang_args_env"
  printf 'bindgen_extra_clang_args=%s\n' "$bindgen_extra_clang_args"
  printf 'fork_patches=%s\n' "${fork_patches[*]}"
  printf 'extra_gn_args=%s\n' "$fork_gn_args"
  exit 0
fi

ensure_fork_build_ignored
mkdir -p "$build_dir/sysroots"

prepare_sysroot \
  "$sysroot" \
  "$stamp" \
  "$image" \
  "$arch" \
  "$docker_platform" \
  "$debian_arch" \
  "$rust_target" \
  ".debian_trixie_${sysroot_suffix}-sysroot.tmp"
install_sysroot_multiarch_headers "$sysroot" "$multiarch_include"
normalize_sysroot_symlinks "$sysroot"
inspect_sysroot_headers "$sysroot" "$multiarch_include"

if [[ "$build" == 0 ]]; then
  exit 0
fi

prepare_sysroot \
  "$host_sysroot" \
  "$host_stamp" \
  "$host_image" \
  "amd64" \
  "linux/amd64" \
  "amd64" \
  "x86_64-unknown-linux-gnu" \
  ".debian_bullseye_amd64-sysroot.tmp"
install_sysroot_multiarch_headers "$host_sysroot" "$host_multiarch_include"
normalize_sysroot_symlinks "$host_sysroot"
inspect_sysroot_headers "$host_sysroot" "$host_multiarch_include"

write_host_tools

applied_patches=()

apply_fork_patch() {
  local patch_file="$1"
  if git -C "$repo_root" apply --check "$patch_file"; then
    git -C "$repo_root" apply "$patch_file"
    applied_patches+=("$patch_file")
  elif git -C "$repo_root" apply --reverse --check "$patch_file"; then
    echo "fork patch already applied: $patch_file"
  else
    echo "fork patch cannot be applied cleanly: $patch_file" >&2
    exit 1
  fi
}

revert_applied_patches() {
  local i
  for ((i = ${#applied_patches[@]} - 1; i >= 0; i--)); do
    git -C "$repo_root" apply --reverse "${applied_patches[$i]}" || true
  done
}
trap revert_applied_patches EXIT

for fork_patch in "${fork_patches[@]}"; do
  apply_fork_patch "$fork_patch"
done

rustup target add "$rust_target"

mkdir -p "$cargo_target_dir"
(
  cd "$repo_root"
  export V8_FROM_SOURCE=1
  export CARGO_TARGET_DIR="$cargo_target_dir"
  export EXTRA_GN_ARGS="${EXTRA_GN_ARGS:-} ${fork_gn_args}"
  fork_bindgen_existing_args="${RUSTY_V8_FORK_BINDGEN_EXTRA_CLANG_ARGS:-}"
  bindgen_global_args="${BINDGEN_EXTRA_CLANG_ARGS:-}"
  bindgen_existing_args="$(printenv "$bindgen_target_env" || true)"
  unset BINDGEN_EXTRA_CLANG_ARGS
  unset "$bindgen_target_env"
  export "$fork_bindgen_extra_clang_args_env=${fork_bindgen_existing_args:+$fork_bindgen_existing_args }${bindgen_global_args:+$bindgen_global_args }${bindgen_existing_args:+$bindgen_existing_args }$bindgen_extra_clang_args"
  export PATH="$host_tools_dir:$PATH"
  cargo build -vv "${cargo_profile_args[@]}" --target "$rust_target"
)
