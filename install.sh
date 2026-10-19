#!/bin/sh
# Installer for laptop-server.
#   curl -fsSL https://raw.githubusercontent.com/mekanismvibe/laptop-server/main/install.sh | sudo sh
#   curl -fsSL https://raw.githubusercontent.com/mekanismvibe/laptop-server/main/install.sh | sudo sh -s -- --dry-run
# Any arguments are passed to `laptop-server setup`.
set -eu

REPO=${LAPTOP_SERVER_REPO:-mekanismvibe/laptop-server}
BRANCH=${LAPTOP_SERVER_BRANCH:-main}
URL="https://raw.githubusercontent.com/$REPO/$BRANCH/laptop-server"
DEST=/usr/local/sbin/laptop-server

[ "$(id -u)" = 0 ] || { echo "Run as root, e.g. with: ... | sudo sh" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$URL" -o "$tmp"
head -1 "$tmp" | grep -q bash || { echo "Download from $URL doesn't look like the script, stopping" >&2; exit 1; }
install -m 755 "$tmp" "$DEST"
echo "Installed $DEST ($("$DEST" version))"

# Read answers from the terminal even though this script arrived through a pipe.
if [ -r /dev/tty ]; then exec "$DEST" setup "$@" < /dev/tty; else exec "$DEST" setup --yes "$@"; fi
