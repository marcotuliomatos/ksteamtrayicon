#!/bin/sh
privileged_uninstall() {
    if [[ $(findmnt -n --raw / | sed -E 's/.* ([^,]+),.*/\1/') == "ro" ]]; then
        IMMUTABLE=true
    else
        IMMUTABLE=false
    fi

    echo -n "Uninstalling ksteamtrayicon..."

    # if the distro is immutable, files are in /usr/local, instead of /usr
    $IMMUTABLE && PREFIX="/usr/local" || PREFIX="/usr"
    KSTEAMTRAYICON_DIR="$PREFIX/share/ksteamtrayicon"
    BIN_DIR="$PREFIX/bin"
    MAN_DIR="$PREFIX/share/man"
    AUTOSTART_DIR="/etc/xdg/autostart"
    PLASMA_ICON_DIR="$1/.local/share/icons"

    rm -f "$KSTEAMTRAYICON_DIR/dark-icon.png"
    rm -f "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py"
    rm -rf "$KSTEAMTRAYICON_DIR"

    rm -f "$BIN_DIR/ksteamtrayicon"

    rm -f "$AUTOSTART_DIR/ksteamtrayicon.desktop"

    rm -f "$MAN_DIR/man1/ksteamtrayicon.1.gz"

    rm -f "$MAN_DIR/pt_BR/man1/ksteamtrayicon.1.gz"

    rm -f "$PLASMA_ICON_DIR/steam_tray_mono.png"

    command -v mandb >/dev/null 2>&1 || true

    echo " Done."
}

stop_ksteamtrayicon() {
    echo -n "Stopping ksteamtrayicon..."

    result=$(qdbus io.github.marcotuliomatos.ksteamtrayicon \
        /io/github/marcotuliomatos/ksteamtrayicon \
        io.github.marcotuliomatos.ksteamtrayicon.Control.Quit 2>&1)

    if [[ $? -eq 0 ]]; then
        echo " Done."
    else
        echo " Unable: $result"
    fi
}

if [[ "$(id -u)" -eq 0 ]]; then
    if [[ ! $1 == "--privileged-uninstall" ]]; then
        echo "This script is not intended to be run as root."
        echo "You may execute it as a regular user and when privileges are needed"
        echo "you will be prompted for escalation."
        exit
    fi
    privileged_uninstall $2
    exit
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo
    while true; do
        echo -n "Are you sure you want to uninstall ksteamtrayicon? [y/N] "
        read -r answer
        echo
        case "$answer" in
            [Yy]*) break;;
            [Nn]*|"") echo "Aborting on user request."; exit;;
                *) ;;
        esac
    done

    stop_ksteamtrayicon

    exec sudo sh "$0" "--privileged-uninstall" "$HOME" $@
fi
