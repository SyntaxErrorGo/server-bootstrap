#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1090
CONFIG_PATH_DEFAULT="/etc/server-bootstrap.conf"

if [ -r "$CONFIG_PATH_DEFAULT" ]; then
	. "$CONFIG_PATH_DEFAULT"
fi

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script must be run as root"
	exit 1
fi

if [ ! -r /etc/os-release ]; then
	echo "Cannot detect OS (no /etc/os-release)"
	exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
UPDATE_CMD=""
INSTALL_CMD=""

case "${ID_LIKE:-$ID}" in
	*debian*|*ubuntu*)
	UPDATE_CMD="apt update -y || apt update"
	INSTALL_CMD="apt install -y"
	;;
	*)
	echo "Unsupported distro: $ID"
	exit 1;
	;;
esac

DEFAULT_NEW_USER="${NEW_USER:-deploy}"
read -rp "New sudo user name [${DEFAULT_NEW_USER}]: " NEW_USER_INPUT
if [ -z "${NEW_USER_INPUT:-}" ]; then
	NEW_USER="$DEFAULT_NEW_USER"
else
	NEW_USER="$NEW_USER_INPUT"
fi

DEFAULT_SSH_PORT="${SSH_PORT:-22}"
read -rp "SSH port [${DEFAULT_SSH_PORT}]: " SSH_PORT_INPUT
if [ -z "${SSH_PORT_INPUT:-}" ]; then
	SSH_PORT="$DEFAULT_SSH_PORT"
else
	SSH_PORT="$SSH_PORT_INPUT"
fi

CURRENT_TZ="$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")"
DEFAULT_TIMEZONE="${TIMEZONE:-$CURRENT_TZ}"
read -rp "Timezone [${DEFAULT_TIMEZONE}]: " TIMEZONE_INPUT
if [ -z "${TIMEZONE_INPUT:-}" ]; then
	TIMEZONE="$DEFAULT_TIMEZONE"
else
	TIMEZONE="$TIMEZONE_INPUT"
fi

CURRENT_HOSTNAME="$(hostname)"
DEFAULT_NEW_HOSTNAME="${NEW_HOSTNAME:-$CURRENT_HOSTNAME}"
read -rp "Hostname [${DEFAULT_NEW_HOSTNAME}]: " NEW_HOSTNAME_INPUT
if [ -z "${NEW_HOSTNAME_INPUT}" ]; then
	NEW_HOSTNAME="$DEFAULT_NEW_HOSTNAME"
else
	NEW_HOSTNAME="$NEW_HOSTNAME_INPUT"
fi

DEFAULT_SSH_KEY_PATH="${SSH_KEY_PATH:-}"
read -rp "Path to SSH public key for new user (leave empty to copy root's authorized_keys) [${DEFAULT_SSH_KEY_PATH}]: " SSH_KEY_PATH_INPUT
if [ -z "${SSH_KEY_PATH_INPUT:-}" ]; then
	SSH_KEY_PATH="$DEFAULT_SSH_KEY_PATH"
else
	SSH_KEY_PATH="$SSH_KEY_PATH_INPUT"
fi

BASE_PACKAGES_DEFAULT="sudo curl git htop vim nano ufw fail2ban"
BASE_PACKAGES="${BASE_PACKAGES:-$BASE_PACKAGES_DEFAULT}"

echo "Updating package index..."
eval "$UPDATE_CMD"

echo "Installing base pacckages: $BASE_PACKAGES"
eval "$INSTALL_CMD $BASE_PACKAGES"

if ! id "$NEW_USER" >/dev/null 2>&1; then
	echo "Creating user $NEW_USER"
	useradd -m -s /bin/bash "$NEW_USER"
else
	echo "User $NEW_USER already exists"
fi

if id "$NEW_USER" >/dev/null 2>&1; then
	if getent group sudo >/dev/null 2>&1; then
		usermod -aG sudo "$NEW_USER"
	elif getent group wheel >/dev/null 2>&1; then
		usermod -aG wheel "$NEW_USER"
	fi
fi

if [ -n "${SSH_KEY_PATH:-}" ]; then
	if [ -r "$SSH_KEY_PATH" ]; then
		install -d -m 700 "/home/$NEW_USER/.ssh"
		install -m 600 "$SSH_KEY_PATH" "/home/$NEW_USER/.ssh/authorized_keys"
		chown -R "$NEW_USER":"$NEW_USER" "/home/$NEW_USER/.ssh"
	else
		echo "SSH key file not readable: $SSH_KEY_PATH"
	fi
else
	if [ -r /root/.ssh/authorized_keys ]; then
		install -d -m 700 "/home/$NEW_USER/.ssh"
		install -m 600 /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/authorized_keys"
		chown -R  "$NEW_USER":"$NEW_USER" "/home/$NEW_USER/.ssh"
	fi
fi

SSHD_CONFIG_MAIN="/etc/ssh/sshd_config"
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSHD_HARDEN_FILE="$SSHD_CONFIG_DIR/99-server-bootstrap.conf"

if [ -d "$SSHD_CONFIG_DIR" ]; then
	printf "Port %s\n" "$SSH_PORT" >"$SSHD_HARDEN_FILE"
	printf "PermitRootLogin no\n" >>"$SSHD_HARDEN_FILE"
	printf "PasswordAuthentification no\n" >>"$SSHD_HARDEN_FILE"
else
	if grep -qE '^[#[:space:]]*Port ' "$SSHD_CONFIG_MAIN"; then
		sed -i "s/^[#[:space:]]*Port .*/Port $SSH_PORT/" "SSHD_CONFIG_MAIN"
	else
	printf "PermitRootLogin no\n" >> "$SSHD_CONFIG_MAIN"
	fi
fi

if command -v timedatectl >/dev/null 2>&1; then
	echo "Setting Timezone to $TIMEZONE"
	timedatectl set-timezone "$TIMEZONE" || echo "Failed to set timezone"
fi

if command -v hostnamect >/dev/null 2>&1; then
	echo "Setting hostname to $HOSTNAME"
	hostnamectl set-hostname "$NEW_HOSTNAME" || echo "Failed to set hostname"
fi

if command -v ufw >/dev/null 2>&1; then
	echo "Configuring UFW"
	ufw --force disable || true
	ufw default deny incoming
	ufw default allow outgoing
	ufw allow "${SSH_PORT}/tcp"
	ufw allow 80/tcp
	ufw allow 443/tcp
	ufw --force enable
fi

if [ -w /etc/motd ]; then
	cat >/etc/motd <<EOF
Welcome to $(hostname)

Managed by server-bootstrap.sh
EOF
fi

echo "Testing SSH configuration..."

if sshd -t >/dev/null 2>&1; then
	systemctl restart ssh || systemctl restart sshd || true
	echo "sshd config is valid and service restarted"
else
	echo "sshd configuration test failed, please check /etc/ssh/"
fi

echo
echo "Bootstrap finished."
echo "Remember to set a password for the new user (if needed):"
echo "  passwd $NEW_USER"
echo
echo "If you changed SSH port to $SSH_PORT, update your SSH client:"
echo "  ssh -p $SSH_PORT $NEW_USER@your-server"


































































































































