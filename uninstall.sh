#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    exec sudo sh "$0" "$@"
fi

PREFIX="/usr"
KSTEAMTRAYICON_DIR="$PREFIX/share/ksteamtrayicon"
BIN_DIR="$PREFIX/bin"
MAN_DIR="$PREFIX/share/man"
AUTOSTART_DIR="/etc/xdg/autostart"
PLASMA_ICON_DIR = "~/.local/share/icons"

rm -f "$KSTEAMTRAYICON_DIR/dark-icon.png"
rm -f "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py"
rm -rf "$KSTEAMTRAYICON_DIR"

rm -f "$BIN_DIR/ksteamtrayicon"

rm -f "$AUTOSTART_DIR/ksteamtrayicon.desktop"

rm -f "$MAN_DIR/man1/ksteamtrayicon.1.gz"

rm -f "$MAN_DIR/pt_BR/man1/ksteamtrayicon.1.gz"

rm -f "$PLASMA_ICON_DIR/steam_tray_mono.png"

command -v mandb >/dev/null 2>&1 || true

echo "ksteamtrayicon uninstalled successfully."
