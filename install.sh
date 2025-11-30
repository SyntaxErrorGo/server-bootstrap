#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This installer must be run as root"
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_SCRIPT_PATH="/usr/local/bin/server-bootstrap.sh"
TARGET_CONFIG_PATH="/etc/server-bootstrap.conf"

install -m 755 "$SCRIPT_DIR/server-bootstrap.sh" "$TARGET_SCRIPT_PATH"

if [ ! -f "$TARGET_CONFIG_PATH" ]; then
	if [ -f "$SCRIPT_DIR/config/server-bootstrap.conf.example" ]; then
		install -m 644 "$SCRIPT_DIR/config/server-bootstrap.conf.example" "$TARGET_CONFIG_PATH"
	fi
fi

echo "Installed server-bootstrap.sh to $TARGET_SCRIPT_PATH"
echo "Config file (if used): $TARGET_CONFIG_PATH"
echo "Run:"
echo " sudo $TARGET_SCRIPT_PATH"
