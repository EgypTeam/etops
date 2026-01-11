#!/usr/bin/env bash

###############################################################################
# Ubuntu 24.04.x LTS: Docker + Minikube + Kubernetes + kubectl + kubectx + k9s
# Idempotent, non-interactive, with per-step and global animated progress bars.
###############################################################################

SCRIPT_NAME="$(basename "$0")"

STEPS=(
  "Docker Engine"
  "Add user to docker group"
  "Minikube (official binary)"
  "Kubernetes core packages (kubelet + kubeadm)"
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
  # $1 = char, $2 = count
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

check_ubuntu() {
  if [ ! -r /etc/os-release ]; then
    echo "/etc/os-release not found. Cannot verify distribution."
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [ "${ID:-}" != "ubuntu" ]; then
    echo "This script requires Ubuntu. Detected: ${ID:-unknown}"
    exit 1
  fi

  # Accept 24.04, 24.04.1, 24.04.2, 24.04.3...
  if [[ "${VERSION_ID:-}" != 24.04* ]]; then
    echo "This script targets Ubuntu 24.04.x LTS. Detected VERSION_ID=${VERSION_ID:-unknown}"
    exit 1
  fi
}

###############################################################################
# SKIP LOGIC
###############################################################################

check_skip() {
  local binary="$1"
  command -v "$binary" >/dev/null 2>&1
}

###############################################################################
# Install functions (idempotent)
###############################################################################

install_docker_repo() {
  # Docker recommends /etc/apt/keyrings + docker.sources on Ubuntu 24.04 :contentReference[oaicite:5]{index=5}
  if [ -f /etc/apt/sources.list.d/docker.sources ]; then
    echo "Docker apt source already exists — skipping repo add."
    return 0
  fi

  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Prefer UBUNTU_CODENAME when present
  local suite
  suite="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${suite}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update -y
}

install_docker() {
  if check_skip docker; then
    echo "Docker already installed — skipping."
    return 0
  fi

  install_docker_repo

  sudo apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  sudo systemctl enable --now docker
}

configure_docker_group() {
  local target_user="${SUDO_USER:-$USER}"

  if groups "$target_user" | grep -q '\bdocker\b'; then
    echo "User '$target_user' is already in docker group — skipping."
    return 0
  fi

  sudo groupadd docker 2>/dev/null || true
  sudo usermod -aG docker "$target_user"
  echo "User '$target_user' added to 'docker' group (logout/login or 'newgrp docker' required)."
}

install_minikube() {
  if check_skip minikube; then
    echo "Minikube already installed — skipping."
    return 0
  fi

  sudo apt-get update -y
  sudo apt-get install -y curl

  local tmp
  tmp="$(mktemp -d)"
  echo "Downloading latest Minikube Linux amd64 binary..."
  # Official minikube docs show latest downloads for Linux :contentReference[oaicite:6]{index=6}
  curl -fLo "$tmp/minikube" \
    https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

  chmod +x "$tmp/minikube"
  sudo mv "$tmp/minikube" /usr/local/bin/minikube
  rm -rf "$tmp"
}

install_kubernetes() {
  # We treat "kubeadm" as the presence check for core components
  if check_skip kubeadm; then
    echo "Kubernetes (kubeadm) already installed — skipping."
    return 0
  fi

  # Use Kubernetes official pkgs.k8s.io repo; derive minor from stable.txt :contentReference[oaicite:7]{index=7}
  sudo apt-get update -y
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg

  sudo install -m 0755 -d /etc/apt/keyrings

  local release minor
  release="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  if [ -z "$release" ]; then
    echo "Could not determine Kubernetes stable release from https://dl.k8s.io/release/stable.txt" >&2
    exit 1
  fi

  # release looks like v1.35.0 -> minor v1.35
  minor="${release%.*}"
  echo "Detected Kubernetes stable release: ${release} (repo minor: ${minor})"

  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${minor}/deb/Release.key" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${minor}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

  sudo apt-get update -y

  # Install kubelet + kubeadm; keep kubectl as its own official-binary step (like your Fedora script)
  sudo apt-get install -y kubelet kubeadm
  sudo apt-mark hold kubelet kubeadm

  sudo systemctl enable --now kubelet
}

install_kubectl() {
  if check_skip kubectl; then
    echo "kubectl already installed — skipping."
    return 0
  fi

  sudo apt-get update -y
  sudo apt-get install -y curl

  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  if [ -z "$version" ]; then
    echo "Could not determine latest kubectl version from https://dl.k8s.io/release/stable.txt" >&2
    exit 1
  fi

  local tmp
  tmp="$(mktemp -d)"
  echo "Downloading kubectl ${version}..."
  curl -fLo "$tmp/kubectl" \
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

  sudo apt-get update -y
  sudo apt-get install -y software-properties-common

  # kubectx.org suggests installing via PPA on Ubuntu :contentReference[oaicite:8]{index=8}
  # Idempotent-ish: add-apt-repository is safe to re-run, but we still avoid duplicates by grepping.
  if ! grep -Rqs "ppa.launchpadcontent.net/ahmetb/kubectx" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    sudo add-apt-repository -y ppa:ahmetb/kubectx
  else
    echo "kubectx PPA already present — skipping PPA add."
  fi

  sudo apt-get update -y
  sudo apt-get install -y kubectx kubens
}

install_k9s() {
  if check_skip k9s; then
    echo "k9s already installed — skipping."
    return 0
  fi

  sudo apt-get update -y
  sudo apt-get install -y curl tar

  local url
  url="$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
          | grep -i 'browser_download_url' \
          | grep -Ei 'Linux_amd64\.tar\.gz|Linux_x86_64\.tar\.gz|linux_amd64\.tar\.gz|linux_x86_64\.tar\.gz' \
          | head -n1 \
          | cut -d '\"' -f 4)"

  if [ -z "$url" ]; then
    echo "GitHub API asset detection failed, falling back to default latest/download URL."
    url="https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"
  fi

  local tmp
  tmp="$(mktemp -d)"
  echo "Downloading k9s from $url ..."
  if ! curl -fLo "$tmp/k9s.tgz" "$url"; then
    echo "Error downloading k9s from $url" >&2
    rm -rf "$tmp"
    exit 1
  fi

  if ! tar -xzf "$tmp/k9s.tgz" -C "$tmp"; then
    echo "Error extracting k9s archive." >&2
    rm -rf "$tmp"
    exit 1
  fi

  if [ ! -f "$tmp/k9s" ]; then
    echo "k9s binary not found in extracted archive." >&2
    echo "Contents of temp dir:"
    ls -R "$tmp"
    rm -rf "$tmp"
    exit 1
  fi

  sudo mv "$tmp/k9s" /usr/local/bin/k9s
  sudo chmod +x /usr/local/bin/k9s
  rm -rf "$tmp"

  echo "k9s installed at /usr/local/bin/k9s"
}

###############################################################################
# Main
###############################################################################

main() {
  echo "Ubuntu 24.04.x LTS Kubernetes & Docker environment installer"
  echo "Components:"
  printf ' - %s\n' "${STEPS[@]}"
  echo

  check_ubuntu
  update_global_bar

  run_step "Docker Engine"                          install_docker
  run_step "Add user to docker group"               configure_docker_group
  run_step "Minikube (official binary)"             install_minikube
  run_step "Kubernetes core packages (kubelet+kubeadm)" install_kubernetes
  run_step "kubectl (official binary)"              install_kubectl
  run_step "kubectx"                                install_kubectx
  run_step "k9s"                                    install_k9s

  echo
  echo "✔ All steps completed!"
  echo "ℹ For Docker group membership, run:  newgrp docker"
  echo "  (or log out/in for a full session refresh)."
}

main "$@"
