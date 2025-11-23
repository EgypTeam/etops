#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version>"
  echo "  Examples: $0 php84  |  $0 84  |  $0 8.4"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

raw_version="$1"

# Normalize:
#   php84 -> 84
#   8.4   -> 84
#   84    -> 84
norm="${raw_version#php}"   # strip leading 'php' if present
norm="${norm//./}"          # remove dots

if [[ ! "$norm" =~ ^[0-9]{2}$ ]]; then
  echo "Error: could not normalize version '$raw_version' to a two-digit form like '84'." >&2
  exit 1
fi

prefix="php${norm}-php"

packages=(
  "${prefix}-cli"
  "${prefix}-common"
  "${prefix}-mysqlnd"      # mysqli + pdo_mysql
  "${prefix}-pdo"
  "${prefix}-gd"
  "${prefix}-intl"
  "${prefix}-xml"
  "${prefix}-mbstring"
  "${prefix}-opcache"
  "${prefix}-process"
  "${prefix}-pecl-zip"
  "${prefix}-pecl-imagick"
)

echo "Installing Remi multi-version PHP for ${raw_version} (normalized -> ${norm})"
echo "Using prefix: ${prefix}"
echo "Packages:"
printf '  %s\n' "${packages[@]}"

sudo dnf install -y "${packages[@]}" --skip-unavailable

