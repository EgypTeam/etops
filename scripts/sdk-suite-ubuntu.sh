#!/usr/bin/env bash
set -euo pipefail

# sdksuite-ubuntu: meta-manager for SDK meta-tools (dotnet, sdkman, nvm, pyenv, rbenv, phpbrew, swi)
#
# Commands (as requested):
#   sdksuite --list
#   sdksuite --list <meta-sdk>
#   sdksuite install <meta-sdk>
#   sdksuite install <meta-sdk>/<sdk>/<version>
#   sdksuite uninstall <meta-sdk>
#   sdksuite uninstall <meta-sdk>/<sdk>/<version>
#   sdksuite reinstall <meta-sdk>
#   sdksuite reinstall <meta-sdk>/<sdk>/<version>
#
# Added:
#   sdksuite install --all
#   sdksuite uninstall --all
#   sdksuite reinstall --all
#   sdksuite install sdksuite   (integrates sdksuite itself into PATH via ~/.bashrc.d)
#
# Philosophy:
# - Shared SDK storage under /c/development/sdk/...
# - User-level integration via symlinks into $HOME (where applicable)
# - Shell integration via ~/.bashrc.d/*.sh loaded by ~/.bashrc

SDK_ROOT="/c/development/sdk"
BASHRCD="$HOME/.bashrc.d"

DOTNET_SHARED="$SDK_ROOT/dotnet/dotnet"
SDKMAN_SHARED="$SDK_ROOT/sdkman/sdkman"
NVM_SHARED="$SDK_ROOT/nvm/nvm"
PYENV_SHARED="$SDK_ROOT/pyenv/pyenv"
RBENV_SHARED="$SDK_ROOT/rbenv/rbenv"
PHPBREW_SHARED="$SDK_ROOT/phpbrew/phpbrew"
SWI_ROOT="$SDK_ROOT/swi-prolog"

UPSTREAM_NVM="https://github.com/nvm-sh/nvm.git"
UPSTREAM_PYENV="https://github.com/pyenv/pyenv.git"
UPSTREAM_RBENV="https://github.com/rbenv/rbenv.git"
UPSTREAM_RUBYBUILD="https://github.com/rbenv/ruby-build.git"
UPSTREAM_PHPBREW_PHAR="https://github.com/phpbrew/phpbrew/releases/latest/download/phpbrew.phar"

# -----------------------------
# Ubuntu/Debian dependency helper
# -----------------------------
# This variant auto-installs missing OS packages via apt-get (when available).
# It is safe to run multiple times.
have_apt() { command -v apt-get >/dev/null 2>&1; }

apt_install() {
  have_apt || die "apt-get not found. This sdksuite-ubuntu script is intended for Ubuntu/Debian."
  local pkgs=("$@")
  # shellcheck disable=SC2145
  info "Ensuring Ubuntu packages: ${pkgs[*]}"
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

ensure_cmd_or_apt() {
  # ensure_cmd_or_apt <command> <apt packages...>
  local cmd="$1"; shift
  if ! command -v "$cmd" >/dev/null 2>&1; then
    apt_install "$@"
  fi
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "$*"; }

ensure_dir() { mkdir -p "$1"; }

ensure_bashrcd_loader() {
  ensure_dir "$BASHRCD"
  local bashrc="$HOME/.bashrc"
  local marker_begin="# sdksuite: load ~/.bashrc.d/*.sh (begin)"

  if [ ! -f "$bashrc" ]; then
    touch "$bashrc"
  fi

  if ! grep -qF "$marker_begin" "$bashrc"; then
    cat >> "$bashrc" <<'BLOCK'

# sdksuite: load ~/.bashrc.d/*.sh (begin)
if [ -d "$HOME/.bashrc.d" ]; then
  for f in "$HOME/.bashrc.d"/*.sh; do
    [ -r "$f" ] && . "$f"
  done
  unset f
fi
# sdksuite: load ~/.bashrc.d/*.sh (end)
BLOCK
  fi
}

safe_symlink() {
  # safe_symlink <target> <linkpath>
  local target="$1"
  local linkpath="$2"

  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    mv "$linkpath" "${linkpath}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  ln -sfn "$target" "$linkpath"
}

rm_if_exists() {
  local p="$1"
  [ -L "$p" ] && rm -f "$p" && return 0
  [ -f "$p" ] && rm -f "$p" && return 0
  [ -d "$p" ] && rm -rf "$p" && return 0
  return 0
}

write_bashrcd() {
  # write_bashrcd <filename> <content>
  local fname="$1"
  local content="$2"
  ensure_dir "$BASHRCD"
  printf "%s\n" "$content" > "$BASHRCD/$fname"
  chmod 644 "$BASHRCD/$fname"
}

meta_list() {
  cat <<LIST
dotnet
sdkman
nvm
pyenv
rbenv
phpbrew
swi
LIST
}

# -----------------------------
# List functions
# -----------------------------

list_dotnet() {
  if command -v dotnet >/dev/null 2>&1; then
    dotnet --list-sdks || true
  else
    echo "dotnet not on PATH (install meta-sdk: sdksuite install dotnet)"
  fi
}

list_sdkman() {
  local cand="$HOME/.sdkman/candidates"
  if [ ! -d "$cand" ]; then
    echo "sdkman not initialized (install meta-sdk: sdksuite install sdkman)"
    return 0
  fi
  echo "Installed candidates under ~/.sdkman/candidates:"
  find "$cand" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V
  echo
  echo "Tip: list versions per candidate: sdksuite --list sdkman/<candidate>"
}

list_sdkman_candidate() {
  local candidate="$1"
  local dir="$HOME/.sdkman/candidates/$candidate"
  if [ ! -d "$dir" ]; then
    echo "Candidate not found: $candidate"
    return 1
  fi
  echo "Installed versions for sdkman candidate '$candidate':"
  find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | sed '/^current$/d'
  if [ -L "$dir/current" ]; then
    echo "current -> $(readlink -f "$dir/current" | sed 's#.*/##')"
  fi
}

list_nvm() {
  if command -v nvm >/dev/null 2>&1; then
    nvm ls || true
  else
    echo "nvm not loaded (install meta-sdk: sdksuite install nvm; then exec bash -l)"
  fi
}

list_pyenv() {
  if command -v pyenv >/dev/null 2>&1; then
    pyenv versions || true
  else
    echo "pyenv not on PATH (install meta-sdk: sdksuite install pyenv; then exec bash -l)"
  fi
}

list_rbenv() {
  if command -v rbenv >/dev/null 2>&1; then
    rbenv versions || true
  else
    echo "rbenv not on PATH (install meta-sdk: sdksuite install rbenv; then exec bash -l)"
  fi
}

list_phpbrew() {
  if command -v phpbrew >/dev/null 2>&1; then
    phpbrew list || true
  else
    echo "phpbrew not on PATH (install meta-sdk: sdksuite install phpbrew; then exec bash -l)"
  fi
}

list_swi() {
  if [ -x "$SWI_ROOT/bin/swi-mgr" ]; then
    "$SWI_ROOT/bin/swi-mgr" list || true
    if [ -L "$SWI_ROOT/current" ]; then
      echo "current -> $(readlink -f "$SWI_ROOT/current" | sed 's#.*/##')"
    else
      echo "current -> none"
    fi
  else
    echo "swi-mgr not found (install meta-sdk: sdksuite install swi)"
  fi
}

# -----------------------------
# Install/uninstall meta-sdks
# -----------------------------

install_dotnet() {
  ensure_bashrcd_loader
  [ -d "$DOTNET_SHARED" ] || die "Missing shared dotnet folder: $DOTNET_SHARED"

  safe_symlink "$DOTNET_SHARED" "$HOME/.dotnet"
  mkdir -p "$HOME/.dotnet/tools"

  write_bashrcd "10-dotnet.sh" \
'# .NET (dotnet) user install
if [ -d "$HOME/.dotnet" ] && [ -x "$HOME/.dotnet/dotnet" ]; then
  export DOTNET_ROOT="$HOME/.dotnet"

  case ":$PATH:" in
    *":$HOME/.dotnet:"*) : ;;
    *) export PATH="$HOME/.dotnet:$PATH" ;;
  esac

  case ":$PATH:" in
    *":$HOME/.dotnet/tools:"*) : ;;
    *) export PATH="$HOME/.dotnet/tools:$PATH" ;;
  esac
fi'

  info "dotnet meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_dotnet() {
  rm_if_exists "$BASHRCD/10-dotnet.sh"
  [ -L "$HOME/.dotnet" ] && rm -f "$HOME/.dotnet" || true
  info "dotnet meta-sdk integration removed (did not delete $DOTNET_SHARED)."
}

install_sdkman() {
# deps: curl + zip/unzip for SDKMAN bootstrap
ensure_cmd_or_apt curl curl ca-certificates
ensure_cmd_or_apt unzip unzip
ensure_cmd_or_apt zip zip
  ensure_bashrcd_loader
  [ -d "$SDKMAN_SHARED" ] || die "Missing shared sdkman folder: $SDKMAN_SHARED"

  safe_symlink "$SDKMAN_SHARED" "$HOME/.sdkman"

  write_bashrcd "20-sdkman.sh" \
'# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  . "$SDKMAN_DIR/bin/sdkman-init.sh"
fi'

  info "sdkman meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_sdkman() {
  rm_if_exists "$BASHRCD/20-sdkman.sh"
  [ -L "$HOME/.sdkman" ] && rm -f "$HOME/.sdkman" || true
  info "sdkman meta-sdk integration removed (did not delete $SDKMAN_SHARED)."
}

install_nvm() {
ensure_cmd_or_apt git git
ensure_cmd_or_apt curl curl ca-certificates
  ensure_bashrcd_loader

  if [ ! -d "$NVM_SHARED" ]; then
    ensure_dir "$SDK_ROOT/nvm"
    command -v git >/dev/null 2>&1 || die "Missing dependency: git"
    git clone "$UPSTREAM_NVM" "$NVM_SHARED"
  fi

  safe_symlink "$NVM_SHARED" "$HOME/.nvm"

  write_bashrcd "30-nvm.sh" \
'# NVM
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi
if [[ $- == *i* ]] && [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi'

  info "nvm meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_nvm() {
  rm_if_exists "$BASHRCD/30-nvm.sh"
  [ -L "$HOME/.nvm" ] && rm -f "$HOME/.nvm" || true
  info "nvm meta-sdk integration removed (did not delete $NVM_SHARED)."
}

install_pyenv() {
ensure_cmd_or_apt git git
ensure_cmd_or_apt make build-essential
# pyenv build deps (covers curses/readline/sqlite/tk/lzma/ssl, etc.)
apt_install     build-essential make gcc g++     libssl-dev zlib1g-dev libbz2-dev libreadline-dev     libsqlite3-dev libncursesw5-dev xz-utils tk-dev     libffi-dev liblzma-dev uuid-dev curl ca-certificates
  ensure_bashrcd_loader

  if [ ! -d "$PYENV_SHARED" ]; then
    ensure_dir "$SDK_ROOT/pyenv"
    command -v git >/dev/null 2>&1 || die "Missing dependency: git"
    git clone "$UPSTREAM_PYENV" "$PYENV_SHARED"
  fi

  safe_symlink "$PYENV_SHARED" "$HOME/.pyenv"

  write_bashrcd "40-pyenv.sh" \
'# PYENV
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  case ":$PATH:" in
    *":$PYENV_ROOT/bin:"*) : ;;
    *) export PATH="$PYENV_ROOT/bin:$PATH" ;;
  esac
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi
fi'

  info "pyenv meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_pyenv() {
  rm_if_exists "$BASHRCD/40-pyenv.sh"
  [ -L "$HOME/.pyenv" ] && rm -f "$HOME/.pyenv" || true
  info "pyenv meta-sdk integration removed (did not delete $PYENV_SHARED)."
}

install_rbenv() {
ensure_cmd_or_apt git git
apt_install build-essential autoconf bison     libssl-dev libyaml-dev libreadline-dev zlib1g-dev     libncurses5-dev libffi-dev libgdbm-dev libdb-dev
  ensure_bashrcd_loader

  if [ ! -d "$RBENV_SHARED" ]; then
    ensure_dir "$SDK_ROOT/rbenv"
    command -v git >/dev/null 2>&1 || die "Missing dependency: git"
    git clone "$UPSTREAM_RBENV" "$RBENV_SHARED"
    ensure_dir "$RBENV_SHARED/plugins"
    git clone "$UPSTREAM_RUBYBUILD" "$RBENV_SHARED/plugins/ruby-build"
  fi

  safe_symlink "$RBENV_SHARED" "$HOME/.rbenv"

  write_bashrcd "50-rbenv.sh" \
'# RBENV
export RBENV_ROOT="$HOME/.rbenv"
if [ -d "$RBENV_ROOT" ]; then
  case ":$PATH:" in
    *":$RBENV_ROOT/bin:"*) : ;;
    *) export PATH="$RBENV_ROOT/bin:$PATH" ;;
  esac
  if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init - bash)"
  fi
fi'

  info "rbenv meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_rbenv() {
  rm_if_exists "$BASHRCD/50-rbenv.sh"
  [ -L "$HOME/.rbenv" ] && rm -f "$HOME/.rbenv" || true
  info "rbenv meta-sdk integration removed (did not delete $RBENV_SHARED)."
}

install_phpbrew() {
# phpbrew needs a system PHP to bootstrap (cli + simplexml)
apt_install php-cli php-xml php-curl php-mbstring php-zip     php-gd php-intl ca-certificates curl git pkg-config     build-essential autoconf bison re2c     libxml2-dev libcurl4-openssl-dev libzip-dev libonig-dev     libxslt1-dev libssl-dev libreadline-dev libsqlite3-dev libicu-dev
  ensure_bashrcd_loader
  ensure_dir "$PHPBREW_SHARED"

  command -v php >/dev/null 2>&1 || die "System 'php' not found. Install php-cli (+ php-xml)."

  if [ ! -x "$PHPBREW_SHARED/phpbrew" ]; then
    command -v curl >/dev/null 2>&1 || die "Missing dependency: curl"
    curl -fL -o "$PHPBREW_SHARED/phpbrew" "$UPSTREAM_PHPBREW_PHAR"
    chmod +x "$PHPBREW_SHARED/phpbrew"
  fi

  safe_symlink "$PHPBREW_SHARED" "$HOME/.phpbrew"

  write_bashrcd "60-phpbrew.sh" \
'# PHPBrew
export PHPBREW_ROOT="$HOME/.phpbrew"
export PHPBREW_HOME="$HOME/.phpbrew"
case ":$PATH:" in
  *":$PHPBREW_ROOT:"*) : ;;
  *) export PATH="$PHPBREW_ROOT:$PATH" ;;
esac
if [ -s "$PHPBREW_ROOT/bashrc" ]; then
  source "$PHPBREW_ROOT/bashrc"
fi'

  if [ ! -s "$HOME/.phpbrew/bashrc" ]; then
    "$HOME/.phpbrew/phpbrew" init
  fi

  info "phpbrew meta-sdk installed (symlink + bashrc.d). Reload: exec bash -l"
}

uninstall_phpbrew() {
  rm_if_exists "$BASHRCD/60-phpbrew.sh"
  [ -L "$HOME/.phpbrew" ] && rm -f "$HOME/.phpbrew" || true
  info "phpbrew meta-sdk integration removed (did not delete $PHPBREW_SHARED)."
}

install_swi() {
# Build essentials for SWI-Prolog from source
apt_install git cmake ninja-build build-essential     libgmp-dev libreadline-dev libncurses-dev libssl-dev     zlib1g-dev libarchive-dev uuid-dev
  ensure_bashrcd_loader
  ensure_dir "$SWI_ROOT/bin" "$SWI_ROOT/versions" "$SWI_ROOT/src"

  # Auto-bootstrap swi-mgr if missing
  if [ ! -x "$SWI_ROOT/bin/swi-mgr" ]; then
    info "swi-mgr not found. Bootstrapping to $SWI_ROOT/bin/swi-mgr"
    cat > "$SWI_ROOT/bin/swi-mgr" <<'SWI_MGR_EOF'
#!/usr/bin/env bash
# swi-mgr
#
# SWI-Prolog version manager using a simple "versions + current symlink" layout.
#
# Layout:
#   /c/development/sdk/swi-prolog/
#     versions/<version>/
#     current -> versions/<version>
#     src/swipl-<version>/  (build sources)
#
# Commands:
#   swi-mgr list
#   swi-mgr remote
#   swi-mgr current
#   swi-mgr install <version>
#   swi-mgr use <version> [--project]
#   swi-mgr uninstall <version> [--force]
#   swi-mgr help
#
# Notes:
# - remote lists available versions by querying git tags from SWI-Prolog upstream (V<version>)
# - install builds from SWI-Prolog git tag: V<version>
# - use updates the 'current' symlink
# - --project writes .swi-prolog-version in the current directory

set -euo pipefail

ROOT="/c/development/sdk/swi-prolog"
VERSIONS_DIR="$ROOT/versions"
SRC_DIR="$ROOT/src"
CURRENT_LINK="$ROOT/current"
UPSTREAM_REPO="https://github.com/SWI-Prolog/swipl-devel.git"

usage() {
  cat <<USAGE
Usage:
  swi-mgr list
  swi-mgr remote
  swi-mgr current
  swi-mgr install <version>
  swi-mgr use <version> [--project]
  swi-mgr uninstall <version> [--force]
  swi-mgr help

Examples:
  swi-mgr list
  swi-mgr remote
  swi-mgr install 9.2.9
  swi-mgr use 9.2.9
  swi-mgr use 9.2.9 --project
  swi-mgr uninstall 9.0.4
  swi-mgr uninstall 9.2.9 --force

Notes:
  - Versions install to: $VERSIONS_DIR/<version>
  - Upstream git tags used: V<version> from $UPSTREAM_REPO
  - 'use' switches by updating: $CURRENT_LINK
  - --project writes .swi-prolog-version to current directory
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

ensure_dirs() {
  mkdir -p "$VERSIONS_DIR" "$SRC_DIR"
}

is_version_string() {
  # Allow e.g. 9.2.9 or 9.2.9-rc1 (loose)
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]
}

list_versions() {
  if [ ! -d "$VERSIONS_DIR" ]; then
    exit 0
  fi
  find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V
}

list_remote_versions() {
  command -v git >/dev/null 2>&1 || die "Missing dependency: git"

  # Query tags from upstream without cloning; normalize V9.2.9 -> 9.2.9
  git ls-remote --tags --refs "$UPSTREAM_REPO" \
    | awk -F/ '{print $NF}' \
    | sed 's/^V//' \
    | sort -V
}

show_current() {
  if [ -L "$CURRENT_LINK" ]; then
    local target
    target="$(readlink -f "$CURRENT_LINK" || true)"
    if [ -n "$target" ]; then
      echo "${target##*/}"
      return 0
    fi
  fi
  echo "none"
}

install_version() {
  local ver="$1"
  is_version_string "$ver" || die "Invalid version format: $ver"

  ensure_dirs

  local prefix="$VERSIONS_DIR/$ver"
  if [ -d "$prefix" ]; then
    echo "Version already installed: $ver"
    return 0
  fi

  # Require core build tools (soft check)
  command -v git >/dev/null 2>&1 || die "Missing dependency: git"
  command -v cmake >/dev/null 2>&1 || die "Missing dependency: cmake"
  command -v ninja >/dev/null 2>&1 || die "Missing dependency: ninja (install ninja-build)"

  echo "Installing SWI-Prolog $ver"
  local src="$SRC_DIR/swipl-$ver"

  if [ ! -d "$src" ]; then
    git clone --depth 1 --branch "V$ver" \
      "$UPSTREAM_REPO" "$src" \
      || die "Failed to clone SWI-Prolog tag V$ver (check version exists: try 'swi-mgr remote')"
  fi

  # Ensure required package sources are present (SWI-Prolog packages are git submodules)
  git -C "$src" submodule update --init --recursive

  mkdir -p "$src/build"
  cd "$src/build"

  # Default to OFF to avoid doc/man build failures on minimal systems
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DINSTALL_DOCUMENTATION=OFF \
    ..

  ninja
  ninja install

  [ -x "$prefix/bin/swipl" ] || die "Install failed: $prefix/bin/swipl not found or not executable"

  echo "Installed SWI-Prolog $ver"
}

switch_to() {
  local ver="$1"
  local project="${2:-false}"

  is_version_string "$ver" || die "Invalid version format: $ver"

  local target="$VERSIONS_DIR/$ver"
  [ -d "$target" ] || die "Version not installed: $ver"

  [ -x "$target/bin/swipl" ] || die "Invalid install: $target/bin/swipl not executable"

  ln -sfn "$target" "$CURRENT_LINK"

  if [ "$project" = "true" ]; then
    echo "$ver" > .swi-prolog-version
  fi

  echo "Switched SWI-Prolog to: $ver"
  "$CURRENT_LINK/bin/swipl" --version || true
}

uninstall_version() {
  local ver="$1"
  local force="${2:-false}"

  is_version_string "$ver" || die "Invalid version format: $ver"

  local target="$VERSIONS_DIR/$ver"
  [ -d "$target" ] || die "Version not installed: $ver"

  local current="none"
  if [ -L "$CURRENT_LINK" ]; then
    current="$(readlink -f "$CURRENT_LINK" | sed 's#.*/##' || echo "none")"
  fi

  if [ "$current" = "$ver" ] && [ "$force" != "true" ]; then
    die "Cannot uninstall active version: $ver (switch first or use --force)"
  fi

  echo "Uninstalling SWI-Prolog $ver"
  rm -rf "$target"

  # Optional: also remove build sources to reclaim space
  rm -rf "$SRC_DIR/swipl-$ver" 2>/dev/null || true

  # If we force-removed the active version, remove current symlink
  if [ "$current" = "$ver" ] && [ "$force" = "true" ]; then
    rm -f "$CURRENT_LINK" || true
  fi

  echo "Removed SWI-Prolog $ver"
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    list|ls)
      list_versions
      ;;
    remote|available|ls-remote)
      list_remote_versions
      ;;
    current)
      show_current
      ;;
    install)
      [ $# -eq 1 ] || { usage; exit 2; }
      install_version "$1"
      ;;
    use)
      [ $# -ge 1 ] || { usage; exit 2; }
      local ver="$1"
      shift || true
      local project="false"
      if [ "${1:-}" = "--project" ]; then
        project="true"
      fi
      switch_to "$ver" "$project"
      ;;
    uninstall|rm|remove)
      [ $# -ge 1 ] || { usage; exit 2; }
      local ver="$1"
      shift || true
      local force="false"
      if [ "${1:-}" = "--force" ]; then
        force="true"
      fi
      uninstall_version "$ver" "$force"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
SWI_MGR_EOF
    chmod +x "$SWI_ROOT/bin/swi-mgr"
  fi

  write_bashrcd "70-swi-prolog.sh" \
'# SWI-Prolog (shared SDK + current symlink)
_swi_root="/c/development/sdk/swi-prolog"
if [ -d "$_swi_root/bin" ]; then
  case ":$PATH:" in
    *":$_swi_root/bin:"*) : ;;
    *) export PATH="$_swi_root/bin:$PATH" ;;
  esac
fi
if [ -d "$_swi_root/current/bin" ]; then
  case ":$PATH:" in
    *":$_swi_root/current/bin:"*) : ;;
    *) export PATH="$_swi_root/current/bin:$PATH" ;;
  esac
fi
unset _swi_root'

  info "swi meta-sdk installed (bashrc.d). Reload: exec bash -l"
}

uninstall_swi() {
  rm_if_exists "$BASHRCD/70-swi-prolog.sh"
  info "swi meta-sdk integration removed (did not delete $SWI_ROOT)."
}

install_meta() {
  local meta="$1"
  case "$meta" in
    dotnet) install_dotnet ;;
    sdkman) install_sdkman ;;
    nvm) install_nvm ;;
    pyenv) install_pyenv ;;
    rbenv) install_rbenv ;;
    phpbrew) install_phpbrew ;;
    swi) install_swi ;;
    *) die "Unknown meta-sdk: $meta" ;;
  esac
}

uninstall_meta() {
  local meta="$1"
  case "$meta" in
    dotnet) uninstall_dotnet ;;
    sdkman) uninstall_sdkman ;;
    nvm) uninstall_nvm ;;
    pyenv) uninstall_pyenv ;;
    rbenv) uninstall_rbenv ;;
    phpbrew) uninstall_phpbrew ;;
    swi) uninstall_swi ;;
    *) die "Unknown meta-sdk: $meta" ;;
  esac
}

reinstall_meta() {
  local meta="$1"
  uninstall_meta "$meta"
  install_meta "$meta"
}

install_all_meta() {
  local metas=(dotnet sdkman nvm pyenv rbenv phpbrew swi)
  for m in "${metas[@]}"; do
    info "==> Installing meta-sdk: $m"
    install_meta "$m"
  done
}

uninstall_all_meta() {
  local metas=(dotnet sdkman nvm pyenv rbenv phpbrew swi)
  for m in "${metas[@]}"; do
    info "==> Uninstalling meta-sdk integration: $m"
    uninstall_meta "$m"
  done
}

reinstall_all_meta() {
  uninstall_all_meta
  install_all_meta
}

# -----------------------------
# Leaf install/uninstall
# -----------------------------

install_leaf() {
  local spec="$1"
  IFS='/' read -r meta sdk ver <<<"$spec"
  [ -n "${meta:-}" ] && [ -n "${sdk:-}" ] && [ -n "${ver:-}" ] || die "Expected <meta-sdk>/<sdk>/<version>, got: $spec"

  case "$meta" in
    sdkman)
      command -v sdk >/dev/null 2>&1 || die "sdk not available. Run: sdksuite install sdkman; exec bash -l"
      sdk install "$sdk" "$ver"
      ;;
    nvm)
      [ "$sdk" = "node" ] || die "For nvm, use nvm/node/<version>"
      command -v nvm >/dev/null 2>&1 || die "nvm not available. Run: sdksuite install nvm; exec bash -l"
      nvm install "$ver"
      ;;
    pyenv)
      [ "$sdk" = "python" ] || die "For pyenv, use pyenv/python/<version>"
      command -v pyenv >/dev/null 2>&1 || die "pyenv not available. Run: sdksuite install pyenv; exec bash -l"
      pyenv install "$ver"
      ;;
    rbenv)
      [ "$sdk" = "ruby" ] || die "For rbenv, use rbenv/ruby/<version>"
      command -v rbenv >/dev/null 2>&1 || die "rbenv not available. Run: sdksuite install rbenv; exec bash -l"
      rbenv install "$ver"
      rbenv rehash || true
      ;;
    phpbrew)
      [ "$sdk" = "php" ] || die "For phpbrew, use phpbrew/php/<version>"
      command -v phpbrew >/dev/null 2>&1 || die "phpbrew not available. Run: sdksuite install phpbrew; exec bash -l"
      phpbrew install "$ver" +default
      ;;
    dotnet)
      [ "$sdk" = "sdk" ] || die "For dotnet, use dotnet/sdk/<version>"
      local installer="$SDK_ROOT/dotnet/dotnet-install.sh"
      [ -x "$installer" ] || die "dotnet-install.sh not found/executable at: $installer"
      "$installer" --version "$ver" --install-dir "$HOME/.dotnet"
      ;;
    swi)
      [ "$sdk" = "swipl" ] || die "For swi, use swi/swipl/<version>"
      [ -x "$SWI_ROOT/bin/swi-mgr" ] || die "swi-mgr not available. Run: sdksuite install swi"
      "$SWI_ROOT/bin/swi-mgr" install "$ver"
      ;;
    *)
      die "Unknown meta-sdk in leaf install: $meta"
      ;;
  esac
}

uninstall_leaf() {
  local spec="$1"
  IFS='/' read -r meta sdk ver <<<"$spec"
  [ -n "${meta:-}" ] && [ -n "${sdk:-}" ] && [ -n "${ver:-}" ] || die "Expected <meta-sdk>/<sdk>/<version>, got: $spec"

  case "$meta" in
    sdkman)
      command -v sdk >/dev/null 2>&1 || die "sdk not available. Run: sdksuite install sdkman; exec bash -l"
      sdk uninstall "$sdk" "$ver"
      ;;
    nvm)
      [ "$sdk" = "node" ] || die "For nvm, use nvm/node/<version>"
      command -v nvm >/dev/null 2>&1 || die "nvm not available. Run: sdksuite install nvm; exec bash -l"
      nvm uninstall "$ver"
      ;;
    pyenv)
      [ "$sdk" = "python" ] || die "For pyenv, use pyenv/python/<version>"
      command -v pyenv >/dev/null 2>&1 || die "pyenv not available. Run: sdksuite install pyenv; exec bash -l"
      pyenv uninstall -f "$ver"
      ;;
    rbenv)
      [ "$sdk" = "ruby" ] || die "For rbenv, use rbenv/ruby/<version>"
      command -v rbenv >/dev/null 2>&1 || die "rbenv not available. Run: sdksuite install rbenv; exec bash -l"
      rbenv uninstall -f "$ver"
      rbenv rehash || true
      ;;
    phpbrew)
      [ "$sdk" = "php" ] || die "For phpbrew, use phpbrew/php/<version>"
      command -v phpbrew >/dev/null 2>&1 || die "phpbrew not available. Run: sdksuite install phpbrew; exec bash -l"
      phpbrew uninstall "php-$ver" || phpbrew uninstall "$ver"
      ;;
    dotnet)
      [ "$sdk" = "sdk" ] || die "For dotnet, use dotnet/sdk/<version>"
      local d="$HOME/.dotnet/sdk/$ver"
      [ -d "$d" ] || die "dotnet SDK not found at: $d"
      rm -rf "$d"
      ;;
    swi)
      [ "$sdk" = "swipl" ] || die "For swi, use swi/swipl/<version>"
      [ -x "$SWI_ROOT/bin/swi-mgr" ] || die "swi-mgr not available. Run: sdksuite install swi"
      "$SWI_ROOT/bin/swi-mgr" uninstall "$ver"
      ;;
    *)
      die "Unknown meta-sdk in leaf uninstall: $meta"
      ;;
  esac
}

reinstall_leaf() {
  local spec="$1"
  uninstall_leaf "$spec"
  install_leaf "$spec"
}

# -----------------------------
# Listing router
# -----------------------------

list_meta() {
  local arg="${1:-}"

  case "$arg" in
    "") meta_list ;;
    dotnet) list_dotnet ;;
    sdkman) list_sdkman ;;
    sdkman/*)
      local candidate="${arg#sdkman/}"
      list_sdkman_candidate "$candidate"
      ;;
    nvm) list_nvm ;;
    pyenv) list_pyenv ;;
    rbenv) list_rbenv ;;
    phpbrew) list_phpbrew ;;
    swi) list_swi ;;
    *) die "Unknown meta-sdk for list: $arg" ;;
  esac
}

# -----------------------------
# Integrate sdksuite itself
# -----------------------------

install_sdksuite_self() {
  ensure_bashrcd_loader
  ensure_dir "$SDK_ROOT/sdksuite/bin"

  write_bashrcd "05-sdksuite.sh" \
'# sdksuite (meta manager)
_sdksuite="/c/development/sdk/sdksuite/bin"
if [ -d "$_sdksuite" ]; then
  case ":$PATH:" in
    *":$_sdksuite:"*) : ;;
    *) export PATH="$_sdksuite:$PATH" ;;
  esac
fi
unset _sdksuite'

  info "sdksuite integrated. Reload: exec bash -l"
  info "Tip: run 'sdksuite install --all' to integrate all meta-sdks."
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    --list)
      list_meta "${1:-}"
      ;;
    install)
      [ $# -eq 1 ] || die "Usage: sdksuite install <meta-sdk | meta-sdk/sdk/version | --all>"
      local what="$1"

      if [[ "$what" == "--all" ]]; then
        install_all_meta
      elif [[ "$what" == */*/* ]]; then
        install_leaf "$what"
      elif [[ "$what" == "sdksuite" ]]; then
        install_sdksuite_self
      else
        install_meta "$what"
      fi
      ;;
    uninstall)
      [ $# -eq 1 ] || die "Usage: sdksuite uninstall <meta-sdk | meta-sdk/sdk/version | --all>"
      local what="$1"

      if [[ "$what" == "--all" ]]; then
        uninstall_all_meta
      elif [[ "$what" == */*/* ]]; then
        uninstall_leaf "$what"
      else
        uninstall_meta "$what"
      fi
      ;;
    reinstall)
      [ $# -eq 1 ] || die "Usage: sdksuite reinstall <meta-sdk | meta-sdk/sdk/version | --all>"
      local what="$1"

      if [[ "$what" == "--all" ]]; then
        reinstall_all_meta
      elif [[ "$what" == */*/* ]]; then
        reinstall_leaf "$what"
      else
        reinstall_meta "$what"
      fi
      ;;
    ""|help|-h|--help)
      cat <<HELP
sdksuite: meta-manager for SDK meta-tools (dotnet, sdkman, nvm, pyenv, rbenv, phpbrew, swi)

Commands:
  sdksuite --list
      list managed meta-sdks
  sdksuite --list <meta-sdk>
      list installed SDKs/versions under that meta-sdk
      extra: sdksuite --list sdkman/<candidate>

  sdksuite install <meta-sdk>
      install/integrate the meta-sdk (symlinks + ~/.bashrc.d)
  sdksuite install <meta-sdk>/<sdk>/<version>
      install a version under the meta-sdk
  sdksuite install --all
      install/integrate ALL meta-sdks

  sdksuite uninstall <meta-sdk>
      remove the meta-sdk integration (does NOT delete the shared folder)
  sdksuite uninstall <meta-sdk>/<sdk>/<version>
      uninstall a version under the meta-sdk
  sdksuite uninstall --all
      remove integration for ALL meta-sdks (does NOT delete /c/development/sdk/*)

  sdksuite reinstall <meta-sdk>
      uninstall then install (integration only)
  sdksuite reinstall <meta-sdk>/<sdk>/<version>
      uninstall then install the SDK version
  sdksuite reinstall --all
      reinstall integration for ALL meta-sdks

Meta SDK leaf formats:
  sdkman/<candidate>/<version>   e.g. sdkman/java/21.0.9-tem
  nvm/node/<version>             e.g. nvm/node/20
  pyenv/python/<version>         e.g. pyenv/python/3.12.2
  rbenv/ruby/<version>           e.g. rbenv/ruby/3.3.4
  phpbrew/php/<version>          e.g. phpbrew/php/8.3.0
  dotnet/sdk/<version>           e.g. dotnet/sdk/9.0.307
  swi/swipl/<version>            e.g. swi/swipl/10.1.1

Self integration:
  sdksuite install sdksuite
      adds /c/development/sdk/sdksuite/bin to PATH via ~/.bashrc.d/05-sdksuite.sh

Typical flow:
  /c/development/sdk/sdksuite/bin/sdksuite install sdksuite
  exec bash -l
  sdksuite install --all
  exec bash -l
HELP
      ;;
    *)
      die "Unknown command: $cmd (try: sdksuite --help)"
      ;;
  esac
}

main "$@"
