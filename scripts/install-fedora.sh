#!/usr/bin/env bash

###############################################################################
# Fedora 42: Docker + Kubernetes + kubectl + kubectx + k9s installer
# Idempotent, non-interactive, with per-step and global animated progress bars.
###############################################################################

SCRIPT_NAME="$(basename "$0")"

STEPS=(
  "Docker Engine"
  "Add user to docker group"
  "Kubernetes core packages"
  "kubectl (official binary)"
  "kubectx"
  "k9s"
)
TOTAL_STEPS=${#STEPS[@]}
COMPLETED_STEPS=0

set -u

###############################################################################
# Helpers: OS check & progress bars
###############################################################################

repeat_char() {
  printf "%*s" "$2" "" | tr ' ' "$1"
}

draw_step_bar() {
  local label="$1" percent="$2"
  local width=30
  (( percent < 0 )) && percent=0
  (( percent > 100 )) && percent=100
  local filled=$(( percent * width / 100 ))
  local empty=$(( width - filled ))
  printf "\r[%s%s] %3d%% %s" \
    "$(repeat_char '#' "$filled")" \
    "$(repeat_char '.' "$empty")" \
    "$percent" "$label"
}

update_global_bar() {
  local width=40
  local percent=$(( COMPLETED_STEPS * 100 / TOTAL_STEPS ))
  local filled=$(( percent * width / 100 ))
  local empty=$(( width - filled ))
  printf "\rGlobal: [%s%s] %3d%% (%d/%d steps)" \
    "$(repeat_char '#' "$filled")" \
    "$(repeat_char '.' "$empty")" \
    "$percent" "$COMPLETED_STEPS" "$TOTAL_STEPS"
  [ "$percent" -eq 100 ] && echo
}

run_step() {
  local name="$1" func="$2"
  echo
  echo "==> $name"

  local log_file="/tmp/${SCRIPT_NAME}_${func}.log"

  (
    "$func"
  ) >"$log_file" 2>&1 &
  local pid=$!

  local percent=0
  while kill -0 "$pid" 2>/dev/null; do
    percent=$(( (percent + 3) % 100 ))
    draw_step_bar "$name" "$percent"
    sleep 0.2
  done

  wait "$pid"
  local status=$?
  if [ "$status" -ne 0 ]; then
    draw_step_bar "$name" 100
    echo
    echo "ERROR: '$name' failed. Log: $log_file"
    exit 1
  fi

  draw_step_bar "$name" 100
  echo
  COMPLETED_STEPS=$(( COMPLETED_STEPS + 1 ))
  update_global_bar
}

check_fedora() {
  . /etc/os-release
  [ "${ID:-}" != "fedora" ] && {
    echo "This script requires Fedora. Detected: ${ID:-unknown}"
    exit 1
  }
}

###############################################################################
# SKIP LOGIC: If tool is already installed, step is skipped
###############################################################################

check_skip() {
  local binary="$1"
  command -v "$binary" >/dev/null 2>&1
}

###############################################################################
# Install functions (idempotent)
###############################################################################

install_docker_repo() {
  if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
    echo "Docker repo already exists, skipping."
    return 0
  fi

  sudo dnf -y install dnf-plugins-core

  if command -v dnf-3 >/dev/null 2>&1; then
    sudo dnf-3 config-manager --add-repo \
      https://download.docker.com/linux/fedora/docker-ce.repo
  else
    sudo dnf config-manager addrepo \
      --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
  fi
}

install_docker() {
  if check_skip docker; then
    echo "Docker already installed — skipping."
    return 0
  fi

  install_docker_repo

  sudo dnf -y install \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  sudo systemctl enable --now docker
}

configure_docker_group() {
  local target_user="${SUDO_USER:-$USER}"

  # Already in group?
  groups "$target_user" | grep -q '\bdocker\b' && {
    echo "User already in docker group — skipping."
    return 0
  }

  sudo groupadd docker 2>/dev/null || true
  sudo usermod -aG docker "$target_user"
  echo "User '$target_user' added to 'docker' group (logout required)."
}

install_kubernetes() {
  if check_skip kubeadm; then
    echo "Kubernetes already installed — skipping."
    return 0
  fi

  sudo dnf -y install \
    kubernetes kubernetes-kubeadm kubernetes-client
}

install_kubectl() {
  if check_skip kubectl; then
    echo "kubectl already installed — skipping."
    return 0
  fi

  sudo dnf -y install curl

  local version
  version="$(curl -Ls https://dl.k8s.io/release/stable.txt)"

  local tmp
  tmp=$(mktemp -d)
  curl -Lo "$tmp/kubectl" \
    "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  chmod +x "$tmp/kubectl"
  sudo mv "$tmp/kubectl" /usr/local/bin/kubectl
  rm -rf "$tmp"
}

install_kubectx() {
  if check_skip kubectx; then
    echo "kubectx already installed — skipping."
    return 0
  fi

  sudo dnf -y install dnf-plugins-core
  sudo dnf -y copr enable audron/kubectx
  sudo dnf -y install kubectx
}

install_k9s() {
  if check_skip k9s; then
    echo "k9s already installed — skipping."
    return 0
  fi

  sudo dnf -y install curl tar

  local url
  url=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
        | grep browser_download_url \
        | grep Linux_x86_64.tar.gz \
        | cut -d '"' -f 4)

  local tmp
  tmp=$(mktemp -d)
  curl -Lo "$tmp/k9s.tgz" "$url"
  tar -xzf "$tmp/k9s.tgz" -C "$tmp"
  sudo mv "$tmp/k9s" /usr/local/bin/k9s
  sudo chmod +x /usr/local/bin/k9s
  rm -rf "$tmp"
}

###############################################################################
# Main
###############################################################################

main() {
  echo "Fedora 42 Kubernetes & Docker environment installer"
  echo "Components:"
  printf ' - %s\n' "${STEPS[@]}"
  echo

  check_fedora
  update_global_bar

  run_step "Docker Engine"            install_docker
  run_step "Add user to docker group" configure_docker_group
  run_step "Kubernetes core packages" install_kubernetes
  run_step "kubectl (official binary)" install_kubectl
  run_step "kubectx"                  install_kubectx
  run_step "k9s"                      install_k9s

  echo
  echo "✔ All steps completed!"
  echo "ℹ Logout/login required for Docker group to take effect."
}

main "$@"
