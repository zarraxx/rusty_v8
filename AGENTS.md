# Fork Agent Instructions

This fork is maintained to support future `rusty_v8` cross builds for
`loongarch64` and `riscv64`, intended for future Codex CLI use. Codex currently
uses the upstream tag `149.2.0`.

## Upstream Hygiene

- Do not modify upstream files directly when adding fork-specific behavior.
- Keep fork-specific changes under `fork_patches/` so this fork can be synced
  with upstream more easily.
- The following files and directories are allowed to live outside
  `fork_patches/`:
  - `AGENTS.md`
  - `my_fork_cross_build.sh`
  - GitHub workflow files added by this fork

## Cross-Build Target

- Cross builds are performed from an x86_64 Linux host.
- Supported target architectures:
  - `loongarch64`
  - `riscv64`
- The build workflow must be able to check out a requested upstream tag,
  including `149.2.0`.

## Sysroot Requirements

- Target sysroots may be prepared with QEMU using the container image
  `ghcr.io/zarraxx/debian:trixie`.
- Install the target architecture's required build dependencies and glibc
  development packages in the sysroot.

## Planned Build Script

Add a fork-specific script named `my_fork_cross_build.sh` that accepts the
target architecture as an argument. The script should perform these steps:

1. Build `gn`.
2. Build or prepare the target architecture sysroot.
3. Install Rust and switch to nightly.
4. Build `rusty_v8` for the requested architecture.

## Planned GitHub Workflow

Add a GitHub Actions workflow for cross compilation and release builds. The
workflow should accept:

- upstream tag version
- target architecture

The workflow should use the fork-specific build path described above and should
not require modifying upstream-managed files.
