#!/usr/bin/env bash
# Public one-shot installer for redotpay-payment (prod binary + MCP + multi-agent skills).
#
#   curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
#
# Downloads prebuilt binaries from GitHub Releases on redotpay/redotpay-payment-skill.
set -euo pipefail

RDP_GITHUB_REPO="${RDP_GITHUB_REPO:-redotpay/redotpay-payment-skill}"
RDP_VERSION="${RDP_VERSION:-latest}"
RDP_INSTALL_DIR="${RDP_INSTALL_DIR:-}"
RDP_PLATFORM="${RDP_PLATFORM:-}"
RDP_REQUIRE_SIGNATURE="${RDP_REQUIRE_SIGNATURE:-}"
SIGNATURE_MODE="auto"
RDP_API_BASE="${RDP_API_BASE:-https://apiv2.redotpay.com}"
RDP_CLIENT_ID="${RDP_CLIENT_ID:-cursor}"

HOSTS_DEFAULT="cursor-global,claude-code,claude-desktop,windsurf"
HOSTS="$HOSTS_DEFAULT"
SKILL_HOSTS_DEFAULT="cursor,claude,codex,cline"
SKILL_HOSTS="$SKILL_HOSTS_DEFAULT"
DRY_RUN=0
UNINSTALL=0
MCP_SERVER_NAME="redotpay-payment"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Zero-argument install (recommended):

  curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh

Defaults: latest release, auto-detect OS/arch, all MCP hosts + agent skills.

Options (optional):
  --version <version>           Pin version (default: latest GitHub release)
  --install-dir <path>          Install destination (default: /usr/local/bin if writable, else ~/.local/bin)
  --platform <os-arch>          darwin-x86_64 | darwin-aarch64 | linux-x86_64 | linux-aarch64
  --hosts <csv>                 MCP hosts (default: cursor-global,claude-code,claude-desktop,windsurf)
  --skill-hosts <csv>           Agent skill dirs (default: cursor,claude,codex,cline)
  --client-id <id>              REDOTPAY_CLIENT_ID (default: cursor)
  --require-signature           Fail unless release has a valid Ed25519 .sig
  --skip-signature-verify       Never verify Ed25519 (SHA-256 still enforced)
  --dry-run                     Print actions only
  --uninstall                   Remove binary, MCP entries, global skill
  -h, --help                    Show help
EOF
}

log()     { printf '%s\n' "$*"; }
section() { printf '\n==> %s\n' "$*"; }

do_or_dry() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] %s\n' "$*"
  else
    printf '    %s\n' "$*"
    eval "$@"
  fi
}

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    local bak="$f.redotpay-bak.$(date +%s)"
    do_or_dry "cp -f \"$f\" \"$bak\""
  fi
}

host_config_path() {
  case "$1" in
    cursor-global)  echo "$HOME/.cursor/mcp.json" ;;
    claude-code)    echo "$HOME/.claude.json" ;;
    claude-desktop) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
    windsurf)       echo "$HOME/.codeium/windsurf/mcp_config.json" ;;
    *)              echo "" ;;
  esac
}

host_agent_id() {
  case "$1" in
    cursor-global)  echo "cursor" ;;
    claude-code)    echo "claude-code" ;;
    claude-desktop) echo "claude-desktop" ;;
    windsurf)       echo "windsurf" ;;
    *)              echo "agent" ;;
  esac
}

is_valid_host() {
  case "$1" in
    cursor-global|claude-code|claude-desktop|windsurf) return 0 ;;
    *) return 1 ;;
  esac
}

build_server_json() {
  local agent_id="$1"
  local bin_path="$2"
  jq -n \
    --arg cmd "$bin_path" \
    --arg agent "$agent_id" \
    --arg cid "$RDP_CLIENT_ID" \
    --arg base "$RDP_API_BASE" \
    '{
      command: $cmd,
      args: ["mcp"],
      env: {
        REDOTPAY_AGENT_ID: $agent,
        REDOTPAY_CLIENT_ID: $cid,
        REDOTPAY_API_BASE: $base
      }
    }'
}

resolve_latest_version() {
  local api="https://api.github.com/repos/${RDP_GITHUB_REPO}/releases/latest"
  local body tag
  if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] would GET %s\n' "$api" >&2
    printf '%s' "0.0.0-dry-run"
    return
  fi
  body="$(curl -fsSL -H "Accept: application/vnd.github+json" "$api")"
  tag="$(printf '%s' "$body" | jq -r '.tag_name // empty')"
  if [ -z "$tag" ]; then
    echo "failed to resolve latest release from GitHub API" >&2
    exit 1
  fi
  printf '%s' "${tag#v}"
}

detect_platform() {
  if [ -n "$RDP_PLATFORM" ]; then
    PLATFORM="$RDP_PLATFORM"
  else
    local os arch
    case "$(uname -s)" in
      Darwin) os=darwin ;;
      Linux) os=linux ;;
      *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
    case "$(uname -m)" in
      x86_64|amd64) arch=x86_64 ;;
      arm64|aarch64) arch=aarch64 ;;
      *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
    esac
    PLATFORM="${os}-${arch}"
  fi
  case "$PLATFORM" in
    darwin-x86_64|darwin-aarch64|linux-x86_64|linux-aarch64) ;;
    *) echo "unsupported platform: $PLATFORM" >&2; exit 1 ;;
  esac
}

download_and_install_binary() {
  local VERSION="$1"
  local os="${PLATFORM%-*}"
  local arch="${PLATFORM#*-}"
  local archive_ext="tar.gz"
  local archive_name="redotpay-payment_${VERSION}_${os}_${arch}.${archive_ext}"
  local release_tag="v${VERSION}"
  local base="https://github.com/${RDP_GITHUB_REPO}/releases/download/${release_tag}"
  local archive_url="${base}/${archive_name}"
  local checksums_url="${base}/checksums.txt"
  local sig_url="${archive_url}.sig"
  local pubkey_url="https://raw.githubusercontent.com/${RDP_GITHUB_REPO}/main/pubkey.pem"

  if [ -z "${RDP_INSTALL_DIR}" ]; then
    if [ -w /usr/local/bin ] 2>/dev/null; then
      RDP_INSTALL_DIR=/usr/local/bin
    else
      RDP_INSTALL_DIR="${HOME}/.local/bin"
    fi
  fi
  INSTALL_DIR="$RDP_INSTALL_DIR"
  BIN_DEST="${INSTALL_DIR}/redotpay-payment"

  section "[1/3] download binary (${PLATFORM}, v${VERSION})"
  log "    repo         : $RDP_GITHUB_REPO"
  log "    archive_url  : $archive_url"

  if [ "$DRY_RUN" = 1 ]; then
    log "    [dry-run] skip download/verify/install"
    return
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  curl -fsSL "$archive_url" -o "${tmp}/pkg.${archive_ext}"
  curl -fsSL "$checksums_url" -o "${tmp}/checksums.txt"

  local expected_sha actual_sha
  expected_sha="$(awk -v target="$archive_name" '
  {
    file=$2
    sub("^\\./", "", file)
    n=split(file, parts, "/")
    base=parts[n]
    if (base == target) { print $1; exit }
  }' "${tmp}/checksums.txt")"

  if [ -z "$expected_sha" ]; then
    echo "checksum for ${archive_name} not found in checksums.txt" >&2
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "${tmp}/pkg.${archive_ext}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual_sha="$(shasum -a 256 "${tmp}/pkg.${archive_ext}" | awk '{print $1}')"
  else
    echo "no sha256 tool available (need sha256sum or shasum)" >&2
    exit 1
  fi

  if [ "$actual_sha" != "$expected_sha" ]; then
    echo "checksum verification FAILED for ${archive_name}" >&2
    echo "expected: ${expected_sha}" >&2
    echo "actual:   ${actual_sha}" >&2
    exit 2
  fi

  if [ "$RDP_REQUIRE_SIGNATURE" = "1" ]; then
    SIGNATURE_MODE=require
  elif [ "$RDP_REQUIRE_SIGNATURE" = "0" ]; then
    SIGNATURE_MODE=skip
  fi

  case "$SIGNATURE_MODE" in
    skip)
      log "    signature verification skipped"
      ;;
    require|auto)
      if ! command -v openssl >/dev/null 2>&1; then
        if [ "$SIGNATURE_MODE" = require ]; then
          echo "signature verification required but openssl not found" >&2
          exit 2
        fi
        log "    openssl not found; SHA-256 only"
      elif curl -fsSL "$sig_url" -o "${tmp}/pkg.sig" 2>/dev/null; then
        curl -fsSL "$pubkey_url" -o "${tmp}/pubkey.pem"
        log "    verifying Ed25519 signature"
        if ! openssl pkeyutl -verify -pubin -inkey "${tmp}/pubkey.pem" \
            -rawin -in "${tmp}/pkg.${archive_ext}" -sigfile "${tmp}/pkg.sig" >/dev/null 2>&1; then
          echo "signature verification FAILED for ${archive_name}" >&2
          exit 2
        fi
      elif [ "$SIGNATURE_MODE" = require ]; then
        echo "signature file not found: ${sig_url}" >&2
        exit 2
      else
        log "    no .sig on release; SHA-256 only"
      fi
      ;;
  esac

  tar -xzf "${tmp}/pkg.${archive_ext}" -C "${tmp}"
  mkdir -p "$INSTALL_DIR"
  local staging="${INSTALL_DIR}/.redotpay-payment.$$"
  install -m 0755 "${tmp}/redotpay-payment" "$staging"
  mv -f "$staging" "$BIN_DEST"
  log "    installed -> $BIN_DEST"

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      log "    note: $INSTALL_DIR is NOT in your PATH."
      log "          Add: export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
}

do_install_mcp_one() {
  local host="$1"
  local cfg_path agent_id server_json
  cfg_path="$(host_config_path "$host")"
  if [ -z "$cfg_path" ]; then
    log "    skip $host (unknown host)"
    return
  fi
  agent_id="$(host_agent_id "$host")"
  log "    [$host] $cfg_path (agent_id=$agent_id)"

  server_json="$(build_server_json "$agent_id" "$BIN_DEST")"

  if [ ! -f "$cfg_path" ]; then
    do_or_dry "mkdir -p \"$(dirname "$cfg_path")\""
    if [ "$DRY_RUN" != 1 ]; then
      echo '{}' > "$cfg_path"
    fi
  fi

  backup_file "$cfg_path"

  if [ "$DRY_RUN" != 1 ] && ! jq -e . "$cfg_path" >/dev/null 2>&1; then
    echo "    error: $cfg_path is not valid JSON — refusing to merge." >&2
    exit 4
  fi

  if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] merge mcpServers["%s"]\n' "$MCP_SERVER_NAME"
    return
  fi

  local tmpf
  tmpf="$(mktemp)"
  jq --argjson srv "$server_json" --arg name "$MCP_SERVER_NAME" \
    '.mcpServers = (.mcpServers // {}) | .mcpServers[$name] = $srv' \
    "$cfg_path" > "$tmpf"
  mv "$tmpf" "$cfg_path"
}

do_install_mcp() {
  section "[2/3] merge MCP server ($MCP_SERVER_NAME)"
  log "    api_base     : $RDP_API_BASE"
  local IFS=','
  for h in $HOSTS; do
    if ! is_valid_host "$h"; then
      echo "    skip $h (not a recognized host id)" >&2
      continue
    fi
    do_install_mcp_one "$h"
  done
}

is_valid_skill_host() {
  case "$1" in
    cursor|claude|codex|cline) return 0 ;;
    *) return 1 ;;
  esac
}

skill_host_dir() {
  case "$1" in
    cursor) echo "$HOME/.cursor/skills/redotpay-payment" ;;
    claude) echo "$HOME/.claude/skills/redotpay-payment" ;;
    codex)  echo "$HOME/.agents/skills/redotpay-payment" ;;
    cline)  echo "$HOME/.cline/skills/redotpay-payment" ;;
    *)      echo "" ;;
  esac
}

fetch_skill_body() {
  local tmp="$1"
  local skill_url="https://raw.githubusercontent.com/${RDP_GITHUB_REPO}/main/skills/redotpay-payment/SKILL.md"
  if [ "$DRY_RUN" = 1 ]; then
    log "    [dry-run] curl $skill_url"
    return 0
  fi
  curl -fsSL "$skill_url" -o "$tmp"
}

do_install_skill_one() {
  local host="$1"
  local dst_dir dst
  dst_dir="$(skill_host_dir "$host")"
  if [ -z "$dst_dir" ]; then
    log "    skip $host (unknown skill host)"
    return
  fi
  dst="$dst_dir/SKILL.md"
  log "    [$host] $dst"
  do_or_dry "mkdir -p \"$dst_dir\""
  if [ -f "$dst" ]; then
    backup_file "$dst"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    log "    [dry-run] write SKILL.md"
    return
  fi
  local tmp
  tmp="$(mktemp)"
  fetch_skill_body "$tmp"
  mv -f "$tmp" "$dst"
}

do_install_skills() {
  section "[3/3] install agent skills"
  log "    skill-hosts  : $SKILL_HOSTS"
  local IFS=','
  for h in $SKILL_HOSTS; do
    if ! is_valid_skill_host "$h"; then
      echo "    skip $h (not a recognized skill-host id)" >&2
      continue
    fi
    do_install_skill_one "$h"
  done
}

do_uninstall_skill_one() {
  local host="$1"
  local dst_dir
  dst_dir="$(skill_host_dir "$host")"
  if [ -z "$dst_dir" ]; then
    return
  fi
  if [ -d "$dst_dir" ]; then
    log "    [$host] $dst_dir"
    do_or_dry "rm -rf \"$dst_dir\""
  else
    log "    [$host] $dst_dir not present, skipping"
  fi
}

do_uninstall_skills() {
  section "[3/3] remove agent skills"
  local IFS=','
  for h in $SKILL_HOSTS; do
    if ! is_valid_skill_host "$h"; then
      continue
    fi
    do_uninstall_skill_one "$h"
  done
}

do_uninstall_binary() {
  section "[1/3] remove binary"
  if [ -f "$BIN_DEST" ]; then
    do_or_dry "rm -f \"$BIN_DEST\""
  else
    log "    $BIN_DEST not present, skipping"
  fi
}

do_uninstall_mcp_one() {
  local host="$1"
  local cfg_path
  cfg_path="$(host_config_path "$host")"
  if [ -z "$cfg_path" ] || [ ! -f "$cfg_path" ]; then
    log "    [$host] skip (no config)"
    return
  fi
  if [ "$DRY_RUN" != 1 ] && ! jq -e . "$cfg_path" >/dev/null 2>&1; then
    echo "    error: $cfg_path is not valid JSON" >&2
    return
  fi
  if [ "$DRY_RUN" != 1 ]; then
    local exists
    exists="$(jq --arg name "$MCP_SERVER_NAME" '.mcpServers[$name] // empty' "$cfg_path")"
    if [ -z "$exists" ]; then
      log "    [$host] mcpServers[\"$MCP_SERVER_NAME\"] not found, skipping"
      return
    fi
  fi
  log "    [$host] $cfg_path"
  backup_file "$cfg_path"
  if [ "$DRY_RUN" = 1 ]; then
    log "    [dry-run] would remove mcpServers[\"$MCP_SERVER_NAME\"]"
    return
  fi
  local tmpf
  tmpf="$(mktemp)"
  jq --arg name "$MCP_SERVER_NAME" \
    'if .mcpServers? then .mcpServers |= del(.[$name]) else . end' \
    "$cfg_path" > "$tmpf"
  mv "$tmpf" "$cfg_path"
}

do_uninstall_mcp() {
  section "[2/3] remove MCP server entry"
  local IFS=','
  for h in $HOSTS; do
    do_uninstall_mcp_one "$h"
  done
}

do_uninstall_skill_global() {
  do_uninstall_skills
}

#-----------------------------------------------------------------------------
# Args

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)           shift; RDP_VERSION="${1:-}" ;;
    --version=*)         RDP_VERSION="${1#--version=}" ;;
    --install-dir)       shift; RDP_INSTALL_DIR="${1:-}" ;;
    --install-dir=*)     RDP_INSTALL_DIR="${1#--install-dir=}" ;;
    --platform)          shift; RDP_PLATFORM="${1:-}" ;;
    --platform=*)        RDP_PLATFORM="${1#--platform=}" ;;
    --hosts)             shift; HOSTS="${1:-}" ;;
    --hosts=*)           HOSTS="${1#--hosts=}" ;;
    --skill-hosts)       shift; SKILL_HOSTS="${1:-}" ;;
    --skill-hosts=*)     SKILL_HOSTS="${1#--skill-hosts=}" ;;
    --client-id)         shift; RDP_CLIENT_ID="${1:-}" ;;
    --client-id=*)       RDP_CLIENT_ID="${1#--client-id=}" ;;
    --require-signature) SIGNATURE_MODE=require ;;
    --skip-signature-verify) SIGNATURE_MODE=skip ;;
    --dry-run)           DRY_RUN=1 ;;
    --uninstall)         UNINSTALL=1 ;;
    -h|--help)           usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: `jq` not found in PATH.

Install jq first:
  macOS:  brew install jq
  Linux:  apt-get install jq  /  dnf install jq
EOF
  exit 2
fi

detect_platform

if [ -z "${RDP_INSTALL_DIR}" ]; then
  if [ -w /usr/local/bin ] 2>/dev/null; then
    RDP_INSTALL_DIR=/usr/local/bin
  else
    RDP_INSTALL_DIR="${HOME}/.local/bin"
  fi
fi
INSTALL_DIR="$RDP_INSTALL_DIR"
BIN_DEST="${INSTALL_DIR}/redotpay-payment"

if [ "$DRY_RUN" = 1 ]; then
  log "==> DRY-RUN: no files will be modified"
fi

if [ "$UNINSTALL" = 1 ]; then
  log "==> uninstall redotpay-payment"
  log "    mcp hosts    : $HOSTS"
  log "    skill-hosts  : $SKILL_HOSTS"
  log "    install-dir  : $INSTALL_DIR"
  do_uninstall_binary
  do_uninstall_mcp
  do_uninstall_skill_global
  printf '\n==> uninstall done\n'
  exit 0
fi

VERSION="$RDP_VERSION"
if [ "$VERSION" = "latest" ]; then
  VERSION="$(resolve_latest_version)"
fi

log "==> install redotpay-payment"
log "    version      : $VERSION"
log "    platform     : $PLATFORM"
log "    mcp hosts    : $HOSTS"
log "    skill-hosts  : $SKILL_HOSTS"
log "    install-dir  : $INSTALL_DIR"
log "    client-id    : $RDP_CLIENT_ID"
log "    api_base     : $RDP_API_BASE"

download_and_install_binary "$VERSION"
do_install_mcp
do_install_skills

printf '\n==> install done\n'
log "    binary      : $BIN_DEST"
log "    next steps  :"
log "      redotpay-payment --version"
log "      redotpay-payment doctor"
log "      # Restart your agent host (Cursor / Claude / etc.) to reload MCP."
