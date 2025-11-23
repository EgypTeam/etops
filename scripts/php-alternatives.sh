#!/usr/bin/env bash
#
# etops-php-alternatives.sh
# Clears existing php alternatives and rebuilds them from installed PHP binaries
#

set -euo pipefail

log() {
    printf '%b\n' "$*" >&2
}

log "🧹 Clearing existing PHP alternatives..."

if alternatives --display php &>/dev/null; then
    sudo alternatives --remove-all php || true
    log "✔ Existing php alternatives removed"
else
    log "ℹ No existing php alternatives found"
fi

# Ensure /usr/bin/php is not a stale symlink
if [[ -L /usr/bin/php ]]; then
    sudo rm -f /usr/bin/php
    log "✔ Removed stale /usr/bin/php symlink"
fi

if [[ -f /usr/bin/php && ! -L /usr/bin/php ]]; then
    log "⚠ Found real /usr/bin/php binary, backing up to /usr/bin/php.system-backup"
    sudo mv /usr/bin/php /usr/bin/php.system-backup
fi

log
log "🔎 Scanning for PHP CLI binaries..."

discover_php_binaries() {
    {
        ls -1 /usr/bin/php 2>/dev/null || true
        ls -1 /usr/bin/php[0-9][0-9] 2>/dev/null || true
        ls -1 /opt/remi/php*/root/usr/bin/php 2>/dev/null || true
    } | sort -u
}

mapfile -t PHP_PATHS < <(discover_php_binaries)

if [[ ${#PHP_PATHS[@]} -eq 0 ]]; then
    log "❌ No PHP binaries found."
    exit 1
fi

log "✅ PHP binaries discovered:"
for p in "${PHP_PATHS[@]}"; do
    printf '  - %s\n' "$p"
done
log

log "⚙ Rebuilding php alternatives..."

for php_bin in "${PHP_PATHS[@]}"; do
    [[ -x "$php_bin" ]] || { log "⏭ Skipping non-executable: $php_bin"; continue; }

    version_raw="$("$php_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "")"

    if [[ "$version_raw" =~ ^[0-9]+\.[0-9]+$ ]]; then
        priority="${version_raw/./}"
    else
        priority=50
    fi

    log "➡ Registering $php_bin (priority $priority)"
    sudo alternatives --install /usr/bin/php php "$php_bin" "$priority"
done

log
log "📋 Final php alternatives configuration:"
sudo alternatives --display php

log
log "✅ Completed. Use:"
log "   sudo alternatives --config php"
log "   php -v"
