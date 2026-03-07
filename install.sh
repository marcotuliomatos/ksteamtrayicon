#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    exec sudo sh "$0" "$@"
fi

for cmd in install ln gzip; do
    echo -n "Checking for $cmd..."
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo " Error. Command not found."
        exit 1
    else
        echo " Found: `(which "$cmd")`"
    fi
done

printf "Checking for KDE Plasma..."
if ! command -v plasmashell >/dev/null 2>&1; then
    echo " Error. KDE Plasma was not found."
    exit 1
fi
echo " Found."

printf "Checking KDE Plasma version..."
PLASMA_VERSION="$(plasmashell --version 2>/dev/null || true)"
case "$PLASMA_VERSION" in
    *" 6."*|*" 6")
        echo " OK ($PLASMA_VERSION)."
        ;;
    *)
        echo " Error. KDE Plasma 6 is required."
        echo " Detected: ${PLASMA_VERSION:-unknown}"
        exit 1
        ;;
esac

printf "Checking Python 3..."
if ! command -v python3 >/dev/null 2>&1; then
    echo " Error. Python 3 not found."
    exit 1
fi
echo " OK ($(python3 --version 2>&1))."

printf "Checking Python library dbus-next..."
if ! python3 -c 'import dbus_next' >/dev/null 2>&1; then
    echo " Error. Python library dbus-next is not installed."
    exit 1
fi
echo " Found."

PREFIX="/usr"
KSTEAMTRAYICON_DIR="$PREFIX/share/ksteamtrayicon"
BIN_DIR="$PREFIX/bin"
MAN_DIR="$PREFIX/share/man"
AUTOSTART_DIR="/etc/xdg/autostart"

install -d "$KSTEAMTRAYICON_DIR"
install -m 644 dark-icon.png "$KSTEAMTRAYICON_DIR/dark-icon.png"
install -m 755 ksteamtrayicon.py "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py"

install -d "$BIN_DIR"
ln -sf "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py" "$BIN_DIR/ksteamtrayicon"

install -d "$AUTOSTART_DIR"
install -m 644 ksteamtrayicon.desktop "$AUTOSTART_DIR/ksteamtrayicon.desktop"

install -d "$MAN_DIR/man1"
gzip -c man/ksteamtrayicon.1.en_US > "$MAN_DIR/man1/ksteamtrayicon.1.gz"

install -d "$MAN_DIR/pt_BR/man1"
gzip -c man/ksteamtrayicon.1.pt_BR > "$MAN_DIR/pt_BR/man1/ksteamtrayicon.1.gz"

command -v mandb >/dev/null 2>&1 || true

echo "ksteamtrayicon installed successfully."
