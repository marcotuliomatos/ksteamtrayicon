#!/bin/bash
run_tests() {
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
    PLASMA_VERSION="$(QT_QPA_PLATFORM=offscreen kded6 --version 2>/dev/null || true)"
    PLASMA_VERSION="KDE ${PLASMA_VERSION/kded6 /}"
    case "$PLASMA_VERSION" in
        "KDE 6."*|"KDE 6")
            echo " OK ($PLASMA_VERSION)."
            ;;
        *)
            echo " Error."
            echo "KDE Plasma 6 is required. Version found: ${PLASMA_VERSION:-unknown}"
            exit 1
            ;;
    esac

    printf "Checking Python 3..."
    if ! command -v python3 >/dev/null 2>&1; then
        echo " Error. Python 3 not found."
        exit 1
    fi
    echo " OK ($(python3 --version 2>&1))."

    while true; do
        printf "Checking Python 3 library dbus-next..."
        if ! python3 -c 'import dbus_next' >/dev/null 2>&1; then
            if python_is_ext_managed; then
                echo " Error. Python library dbus-next is not installed."
                echo
                echo "Since your python environment is externally managed, please install the dbus-next"
                echo "python library using your distro package manager. Check your distro documentation to"
                echo "confirm the exact package name and how to properly install it in your system."
                exit 1
            else
                echo "Not found."
                echo
                while true; do
                    echo -n "Do you want to try to install dbus-next using pip? [Y/n] "
                    read -r answer
                    case "$answer" in
                        [Yy]*|"") break;;
                           [Nn]*) echo "Unable to continue: dbus-next python library is not installed"; exit 1;;
                               *) ;;
                    esac
                done
                echo
                python3 -m pip install --user dbus-next
            fi
        else
            echo " OK."
            break
        fi
    done

    echo -n "Checking distro type..."
    if $IMMUTABLE; then
        echo " Immutable (using $PREFIX prefix instead of /usr)."
    else
        echo " Mutable (using the default $PREFIX prefix)."
    fi

    echo -n "Checking for previous installations..."
    if $UPGRADING; then
        echo " Found: $PREFIX/bin/ksteamtrayicon"
    else
        echo " Not found."
    fi

    echo
    while true; do
        echo "All tests passed."
        echo
        if $UPGRADING; then
            echo -n "Ready to upgrade. Continue? [Y/n] "
        else
            echo -n "Ready to install. Continue? [Y/n] "
        fi
        read -r answer
        echo
        case "$answer" in
            [Yy]*|"") break;;
            [Nn]*) echo "Aborting on user request."; exit;;
                *) ;;
        esac
    done
}

python_is_ext_managed() {
    return $([[ -e $(python3 -c '
import sysconfig
from pathlib import Path
print(Path(sysconfig.get_path("stdlib", sysconfig.get_default_scheme())) / "EXTERNALLY-MANAGED")'
    ) ]])
}

privileged_install() {
    KSTEAMTRAYICON_DIR="$PREFIX/share/ksteamtrayicon"
    BIN_DIR="$PREFIX/bin"
    MAN_DIR="$PREFIX/share/man"
    AUTOSTART_DIR="/etc/xdg/autostart"

    if $UPGRADING; then
        printf "\nUpgrading ksteamtrayicon..."
    else
        printf "\nInstalling ksteamtrayicon..."
    fi
    install -d "$KSTEAMTRAYICON_DIR"
    install -m 644 dark-icon.png "$KSTEAMTRAYICON_DIR/dark-icon.png"
    install -m 755 ksteamtrayicon.py "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py"

    install -d "$BIN_DIR"
    ln -sf "$KSTEAMTRAYICON_DIR/ksteamtrayicon.py" "$BIN_DIR/ksteamtrayicon"

    desktop_file="ksteamtrayicon.desktop"
    if $IMMUTABLE; then
        tmp_file=$(mktemp)
        sed 's/=\/usr/\=\/usr\/local/g' "$desktop_file" > "$tmp_file"
        desktop_file="$tmp_file"
    fi
    install -d "$AUTOSTART_DIR"
    install -m 644 "$desktop_file" "$AUTOSTART_DIR/ksteamtrayicon.desktop"

    install -d "$MAN_DIR/man1"
    gzip -c man/ksteamtrayicon.1.en_US > "$MAN_DIR/man1/ksteamtrayicon.1.gz"

    install -d "$MAN_DIR/pt_BR/man1"
    gzip -c man/ksteamtrayicon.1.pt_BR > "$MAN_DIR/pt_BR/man1/ksteamtrayicon.1.gz"

    if command -v mandb >/dev/null 2>&1; then
        mandb >/dev/null 2>&1 || true
    fi

    echo " Done."
    echo
    echo "********************************************************************"
    if $UPGRADING; then
        echo "*        Hooray! ksteamtrayicon was upgraded successfully.         *"
        the_new_version_of=" the new version of"
    else
        echo "*        Hooray! ksteamtrayicon was installed successfully.        *"
        the_new_version_of=""
    fi
    echo "********************************************************************"
    echo
    echo -n "Do you want to start$the_new_version_of ksteamtrayicon now? [Y/n] "
}

after_install_prompt() {
    local desktop_file="/etc/xdg/autostart/ksteamtrayicon.desktop"
    local kioclient=

    [[ -e "/etc/xdg/autostart/ksteamtrayicon.desktop" ]] || return

    for kioclient in kioclient6 kioclient5 kioclient; do
        command -v "$kioclient" >/dev/null 2>&1 && break
        kioclient=
    done

    [[ -n "$kioclient" ]] || return

    while true; do
        read -r answer
        case "$answer" in
            [Yy]*|"")
                echo;
                "$kioclient" exec "$desktop_file";
                exit;;
            [Nn]*)
                echo;
                break;;
            *)
                ;;
        esac
    done
}

set -e

# If / is read-only, assume the the distro is immutable
if [[ $(findmnt -n --raw / | sed -E 's/.* ([^,]+),.*/\1/') == "ro" ]]; then
    IMMUTABLE=true
else
    IMMUTABLE=false
fi

# if the distro is immutable, install to /usr/local, otherwise install to /usr
$IMMUTABLE && PREFIX="/usr/local" || PREFIX="/usr"

[[ -e "$PREFIX/bin/ksteamtrayicon" ]] && UPGRADING=true || UPGRADING=false

if [[ "$(id -u)" -eq 0 && $1 != "--privileged-install" ]]; then
    echo "This script is not intended to be run as root."
    echo "You may execute it as a regular user and when privileges are needed"
    echo "you will be prompted for escalation."
    exit
fi

if [[ "$(id -u)" -ne 0 && $1 == "--privileged-install" ]]; then
    #exec sudo bash "$0" $@
    echo "You need root privileges to run this script with the --privileged-install parameter"
    exit
fi

if [[ $1 != "--privileged-install" ]]; then
    run_tests
    sudo bash "$0" "--privileged-install" $@
    after_install_prompt
else
    privileged_install
fi
