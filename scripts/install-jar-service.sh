#!/usr/bin/env bash
set -euo pipefail

#=== usage/help ===============================================================
show_help() {
  cat <<'EOF'
Usage:
  sudo ./install-jar-service.sh \
    --jar path/to/app.jar \
    --service-name my-app \
    --description "My App Service" \
    --java-flags "-Xms256m -Xmx512m" \
    --app-flags "--daemon --port=8081"

Uninstall:
  sudo ./install-jar-service.sh --service-name my-app --uninstall

Options:
  --jar            Path to the JAR (relative or absolute). Required for install.
  --service-name   Systemd service name (no spaces). Required.
  --description    Human-readable description (defaults to service name).
  --java-flags     Quoted string with JVM flags (optional).
  --app-flags      Quoted string with application flags (optional).
  --uninstall      Uninstall the service (ignores --jar/flags/description).

Notes:
  - The service runs in the JAR's directory (WorkingDirectory).
  - ExecStart uses absolute JAR path: /usr/bin/env java [java-flags] -jar /abs/jar [app-flags]
  - Service runs as the invoking user (SUDO_USER) if present, else current user.
EOF
}

#=== root check / sudo context ===============================================
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root. Try: sudo $0 $*" >&2
    exit 1
  fi
}

#=== path resolution ==========================================================
abs_path() {
  # Resolve to an absolute path without depending solely on readlink -f
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$p"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f -- "$p"
  else
    # Fallback: cd to dir and print $PWD/basename
    local dir base
    dir="$(cd "$(dirname -- "$p")" && pwd -P)"
    base="$(basename -- "$p")"
    echo "${dir}/${base}"
  fi
}

#=== argument parsing =========================================================
JAR_PATH=""
SERVICE_NAME=""
DESCRIPTION=""
JAVA_FLAGS=""
APP_FLAGS=""
UNINSTALL=0

if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jar)
      [[ $# -ge 2 ]] || { echo "Missing value for --jar" >&2; exit 1; }
      JAR_PATH="$2"; shift 2;;
    --service-name)
      [[ $# -ge 2 ]] || { echo "Missing value for --service-name" >&2; exit 1; }
      SERVICE_NAME="$2"; shift 2;;
    --description)
      [[ $# -ge 2 ]] || { echo "Missing value for --description" >&2; exit 1; }
      DESCRIPTION="$2"; shift 2;;
    --java-flags)
      [[ $# -ge 2 ]] || { echo "Missing value for --java-flags" >&2; exit 1; }
      JAVA_FLAGS="$2"; shift 2;;
    --app-flags)
      [[ $# -ge 2 ]] || { echo "Missing value for --app-flags" >&2; exit 1; }
      APP_FLAGS="$2"; shift 2;;
    --uninstall)
      UNINSTALL=1; shift;;
    -h|--help)
      show_help; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

#=== sanity checks ============================================================
if [[ -z "$SERVICE_NAME" ]]; then
  echo "--service-name is required." >&2
  exit 1
fi

require_root

# Determine which user the service should run as
RUN_AS="${SUDO_USER:-$(id -un)}"
RUN_GRP="$(id -gn "$RUN_AS")"

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

#=== uninstall path ===========================================================
if [[ "$UNINSTALL" -eq 1 ]]; then
  if systemctl is-enabled --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
    systemctl disable --now "${SERVICE_NAME}.service" || true
  else
    systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
  fi

  if [[ -f "$UNIT_FILE" ]]; then
    rm -f -- "$UNIT_FILE"
    systemctl daemon-reload
    echo "Service '${SERVICE_NAME}' uninstalled."
  else
    echo "Service '${SERVICE_NAME}' is not installed (no unit file)."
  fi
  exit 0
fi

#=== install path =============================================================
if [[ -z "$JAR_PATH" ]]; then
  echo "--jar is required for installation." >&2
  exit 1
fi

ABS_JAR="$(abs_path "$JAR_PATH")"
if [[ ! -f "$ABS_JAR" ]]; then
  echo "JAR not found: $ABS_JAR" >&2
  exit 1
fi

WORK_DIR="$(dirname -- "$ABS_JAR")"
DESCRIPTION="${DESCRIPTION:-$SERVICE_NAME}"

# systemd unit content
# Note: we avoid shell word-splitting by writing the flags literally into the unit.
# Users should quote flags when invoking this installer so they appear as intended.
unit_content=$(cat <<EOF
[Unit]
Description=${DESCRIPTION}
After=network.target

[Service]
Type=simple
User=${RUN_AS}
Group=${RUN_GRP}
WorkingDirectory=${WORK_DIR}
ExecStart=/usr/bin/env java ${JAVA_FLAGS} -jar ${ABS_JAR} ${APP_FLAGS}
Restart=always
RestartSec=5
# Hardening (tweak as needed)
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
)

# Write unit
printf "%s\n" "$unit_content" > "$UNIT_FILE"
chmod 0644 "$UNIT_FILE"

# Reload, enable, start
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"

# Show status summary
systemctl --no-pager --full status "${SERVICE_NAME}.service" || true

echo
echo "Installed '${SERVICE_NAME}.service'."
echo "Jar:           ${ABS_JAR}"
echo "Work dir:      ${WORK_DIR}"
echo "Run as:        ${RUN_AS}:${RUN_GRP}"
echo "Java flags:    ${JAVA_FLAGS:-<none>}"
echo "App flags:     ${APP_FLAGS:-<none>}"
