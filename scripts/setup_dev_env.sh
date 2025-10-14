#!/usr/bin/env bash
#
# Bootstrap macOS + iOS developer tooling for UTM.
#
# This script captures the manual steps documented in:
#   - Documentation/MacDevelopment.md
#   - Documentation/iOSDevelopment.md
# It keeps the steps in one repeatable place so local developers
# and automation agents can stand up the same toolchain.
#
# The script is intentionally cautious: it detects prerequisites
# and prints actionable guidance instead of blindly installing
# heavyweight tooling like Xcode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

prepend_path_if_dir() {
  local dir="$1"
  if [[ -d "${dir}" ]]; then
    export PATH="${dir}:${PATH}"
  fi
}

prepend_path_if_dir "/usr/local/opt/bison/bin"
prepend_path_if_dir "/opt/homebrew/opt/bison/bin"

MAC_BREW_PACKAGES=(bison pkg-config gettext glib libgpg-error nasm make meson)
IOS_BREW_PACKAGES=(bison pkg-config gettext glib libgpg-error nasm meson)
PYTHON_PACKAGES=(six pyparsing)

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERR ]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: setup_dev_env.sh [--mac] [--ios] [--agents] [--build-deps] [--dry-run]

--mac         : ensure macOS build prerequisites (Homebrew deps, pip deps, sysroot hints)
--ios         : ensure iOS / visionOS prerequisites
--agents      : prepare automation agent toolchains (Rust / cargo build)
--build-deps  : invoke scripts/build_dependencies.sh for requested platforms
--dry-run     : print actions only; do not modify the system

If no flags are supplied the script will run with --mac --ios --agents.
EOF
}

DRY_RUN=0
DO_MAC=0
DO_IOS=0
DO_AGENTS=0
BUILD_DEPS=0

if [[ $# -eq 0 ]]; then
  DO_MAC=1
  DO_IOS=1
  DO_AGENTS=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac) DO_MAC=1 ;;
    --ios) DO_IOS=1 ;;
    --agents) DO_AGENTS=1 ;;
    --build-deps) BUILD_DEPS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      usage
      error "Unknown flag: $1"
      exit 1
      ;;
  esac
  shift
done

do_run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "[dry-run] $*"
  else
    "$@"
  fi
}

ensure_command() {
  local cmd="$1"
  local install_hint="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Missing command '${cmd}'. ${install_hint}"
    return 1
  fi
  return 0
}

ensure_xcode() {
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools are missing. Install via 'xcode-select --install'."
    return 1
  fi
  return 0
}

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew is not installed. Visit https://brew.sh and install before continuing."
    return 1
  fi
  return 0
}

brew_install_packages() {
  local packages=("$@")
  ensure_homebrew || return 1
  [[ "${#packages[@]}" -gt 0 ]] || return 0
  for pkg in "${packages[@]}"; do
    if brew ls --versions "${pkg}" >/dev/null 2>&1; then
      info "Homebrew package '${pkg}' already installed."
      continue
    fi
    info "Installing Homebrew package: ${pkg}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      info "[dry-run] brew install ${pkg}"
      continue
    fi
    if ! brew install "${pkg}"; then
      warn "Failed to install '${pkg}'. Check Homebrew output and adjust manually."
    fi
  done
}

pip_install_packages() {
  local packages=("$@")
  ensure_command pip3 "Install Python 3 (via Xcode or Homebrew) before continuing." || return 1
  if [[ "${#packages[@]}" -eq 0 ]]; then
    return 0
  fi
  info "Installing Python packages: ${packages[*]}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "[dry-run] pip3 install --user ${packages[*]}"
  else
    pip3 install --user "${packages[@]}"
  fi
}

ensure_submodules() {
  info "Ensuring git submodules are up to date."
  do_run git submodule update --init --recursive
}

ensure_sysroot_hint() {
  local search_pattern="$1"
  if compgen -G "${REPO_ROOT}/${search_pattern}" >/dev/null; then
    info "Detected existing sysroot in ${search_pattern}"
  else
    warn "No sysroot matching '${search_pattern}' found. Download release artifacts from https://github.com/utmapp/UTM/actions?query=event%3Arelease+workflow%3ABuild and extract to repository root."
  fi
}

build_dependencies() {
  local platform="$1"
  local arch="$2"
  info "Building dependencies for ${platform}-${arch} (advanced workflow)."
  do_run "${REPO_ROOT}/scripts/build_dependencies.sh" -p "${platform}" -a "${arch}"
}

prepare_mac() {
  info "=== macOS host prerequisites ==="
  ensure_xcode || true
  brew_install_packages "${MAC_BREW_PACKAGES[@]}" || true
  pip_install_packages "${PYTHON_PACKAGES[@]}" || true
  ensure_sysroot_hint "sysroot-macOS-*"
  if [[ "${BUILD_DEPS}" -eq 1 ]]; then
    build_dependencies macos arm64 || true
    build_dependencies macos x86_64 || true
    info "Remember to pack universal sysroot via ./scripts/pack_dependencies.sh . macos arm64 x86_64"
  fi
}

prepare_ios() {
  info "=== iOS / visionOS prerequisites ==="
  ensure_xcode || true
  brew_install_packages "${IOS_BREW_PACKAGES[@]}" || true
  pip_install_packages "${PYTHON_PACKAGES[@]}" || true
  ensure_sysroot_hint "sysroot-ios*"
  ensure_sysroot_hint "sysroot-visionos*"
  if [[ "${BUILD_DEPS}" -eq 1 ]]; then
    build_dependencies ios arm64 || true
    build_dependencies ios-tci arm64 || true
    build_dependencies ios_simulator arm64 || true
  fi
}

prepare_agents() {
  info "=== Automation agents prerequisites ==="
  if ! command -v rustup >/dev/null 2>&1; then
    warn "Rust toolchain not found. Install via https://rustup.rs/ to build agents."
  else
    do_run rustup target add aarch64-apple-darwin x86_64-apple-darwin || true
  fi
  if command -v cargo >/dev/null 2>&1; then
    info "Building agents publisher workspace (release mode)."
    (cd "${REPO_ROOT}/Scripting/agents_publisher" && do_run cargo build --release)
  else
    warn "Cargo not available. Skip building agents publisher."
  fi
}

main() {
  ensure_submodules

  if [[ "${DO_MAC}" -eq 1 ]]; then
    prepare_mac
  fi
  if [[ "${DO_IOS}" -eq 1 ]]; then
    prepare_ios
  fi
  if [[ "${DO_AGENTS}" -eq 1 ]]; then
    prepare_agents
  fi

  info "Environment bootstrap complete."
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "Dry-run mode: review commands above before re-running without --dry-run."
  fi
}

main "$@"
