#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Unified Installer & Auto-Dispatcher
# ================================================================================================
# Auto-detects your Linux distribution or BSD flavor and dispatches to the
# appropriate installer, or allows manual distribution override via --distro <name>.
# ================================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Source common library
if [ -f "${SCRIPT_DIR}/lib/common.sh" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/common.sh"
else
  echo "Error: Cannot find '${SCRIPT_DIR}/lib/common.sh'." >&2
  exit 1
fi

canonicalize_distro() {
  local input="$1"
  local lower
  lower="$(echo "$input" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
  arch | archlinux | endeavouros | endeavour | manjaro | cachyos | cachy | artix | garuda)
    echo "arch"
    ;;
  debian | ubuntu | pop | pop_os | pop-os | mint | linuxmint | zorin | zorinos | elementary | elementaryos | kali | raspbian | tuxedo | neon)
    echo "debian"
    ;;
  fedora | nobara | rhel | centos | almalinux | rocky | rockylinux)
    echo "fedora"
    ;;
  bazzite | aurora | bluefin)
    echo "bazzite"
    ;;
  gentoo | funtoo)
    echo "gentoo"
    ;;
  opensuse | opensuse-tumbleweed | opensuse-leap | tumbleweed | leap | suse)
    echo "opensuse"
    ;;
  alpine | alpinelinux)
    echo "alpine"
    ;;
  freebsd)
    echo "freebsd"
    ;;
  openbsd)
    echo "openbsd"
    ;;
  *)
    echo "$lower"
    ;;
  esac
}

detect_system_distro() {
  # 1. BSD Detection via uname
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo '')"
  if [ "$uname_s" = "FreeBSD" ]; then
    echo "freebsd"
    return 0
  elif [ "$uname_s" = "OpenBSD" ]; then
    echo "openbsd"
    return 0
  fi

  # 2. Linux Distribution Detection via /etc/os-release
  if [ -f /etc/os-release ]; then
    # Parse without side effects
    local os_id os_id_like os_name
    os_id="$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'\'' ' | tr '[:upper:]' '[:lower:]' || true)"
    os_id_like="$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"'\'' ' | tr '[:upper:]' '[:lower:]' || true)"
    os_name="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"'\'' ' || true)"

    log_debug "OS Release detected: ID=${os_id}, ID_LIKE=${os_id_like}, NAME=${os_name}"

    # Explicit ID checks
    case "$os_id" in
    arch | cachyos | endeavouros | manjaro | artix | garuda)
      echo "arch"
      return 0
      ;;
    debian | ubuntu | pop | mint | zorin | elementary | kali | raspbian | tuxedo | neon)
      echo "debian"
      return 0
      ;;
    bazzite | aurora | bluefin)
      echo "bazzite"
      return 0
      ;;
    fedora | nobara)
      echo "fedora"
      return 0
      ;;
    gentoo | funtoo)
      echo "gentoo"
      return 0
      ;;
    opensuse* | suse)
      echo "opensuse"
      return 0
      ;;
    alpine)
      echo "alpine"
      return 0
      ;;
    esac

    # ID_LIKE Fallback checks (e.g. derivatives like Zorin, Linux Mint, Pop!_OS, Nobara, EndeavourOS)
    if [[ "$os_id_like" =~ (ubuntu|debian) ]]; then
      echo "debian"
      return 0
    elif [[ "$os_id_like" =~ arch ]]; then
      echo "arch"
      return 0
    elif [[ "$os_id_like" =~ (fedora|rhel) ]]; then
      echo "fedora"
      return 0
    elif [[ "$os_id_like" =~ suse ]]; then
      echo "opensuse"
      return 0
    fi
  fi

  echo "unknown"
}

main() {
  parse_common_args "$@"

  local target_distro=""

  if [ -n "$SPECIFIED_DISTRO" ]; then
    log_debug "Manual distribution specified: $SPECIFIED_DISTRO"
    target_distro="$(canonicalize_distro "$SPECIFIED_DISTRO")"
    log_info "Using specified distribution: ${GREEN}${target_distro}${NC} (from '${SPECIFIED_DISTRO}')"
  else
    log_debug "Auto-detecting system distribution..."
    target_distro="$(detect_system_distro)"
    if [ "$target_distro" != "unknown" ]; then
      log_info "Auto-detected system: ${GREEN}${target_distro}${NC}"
    fi
  fi

  local target_script="${SCRIPT_DIR}/install-${target_distro}.sh"

  if [ "$target_distro" != "unknown" ] && [ -f "$target_script" ]; then
    log_debug "Dispatching to: $target_script with args: $*"
    exec "$target_script" "$@"
  else
    echo ""
    log_error "✗ Unable to automatically determine a supported installer for this system."
    if [ "$target_distro" != "unknown" ]; then
      log_warn "Target installer not found: ${target_script}"
    fi
    echo ""
    echo "You can manually specify a distribution installer using --distro:"
    echo -e "  ${CYAN}./install.sh --distro <name>${NC}  (e.g., ${CYAN}./install.sh --distro debian${NC})"
    echo ""
    echo "To view all available distribution options:"
    echo -e "  ${CYAN}./install.sh --list-distros${NC}"
    echo ""
    exit 1
  fi
}

main "$@"
