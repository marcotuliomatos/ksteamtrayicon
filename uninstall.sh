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

rm "$KSTEAMTRAYICON_DIR/dark-icon.png"
rm "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py"
rm -r "$KSTEAMTRAYICON_DIR"

rm "$BIN_DIR/ksteamtrayicon"

rm "$AUTOSTART_DIR/ksteamtrayicon.desktop"

rm "$MAN_DIR/man1/ksteamtrayicon.1.gz"

rm "$MAN_DIR/pt_BR/man1/ksteamtrayicon.1.gz"

command -v mandb >/dev/null 2>&1 || true

echo "ksteamtrayicon uninstalled successfully."
