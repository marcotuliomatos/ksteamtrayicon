#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="ksteamtrayicon"
REPO_URL="https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main"
SERVICE_FILE="ksteamtrayicon.service"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        $SUDO "$@"
    fi
}

ask() {
    while true; do
        printf "%s [Y/n] " "$1" > /dev/tty
        read -r answer < /dev/tty
        case $answer in
            [yY]*|"") return 0 ;;
            [nN]*) return 1 ;;
            *) ;;
        esac
    done
}

find_sudo() {
    SUDO=""
    for candidate in sudo doas; do
        if command_exists "$candidate"; then
            SUDO="$candidate"
            if run_as_root true 2>/dev/null; then
                return 0
            fi
        fi
    done
    echo "Error: root privileges are needed, but neither sudo nor doas were found."
    exit 1
}

is_arch_based() {
    [[ -f /etc/arch-release ]] || pacman --version &>/dev/null
}

detect_aur_helper() {
    for helper in yay paru pikaur; do
        if command_exists "$helper"; then
            echo "$helper"
            return 0
        fi
    done
    return 1
}

install_arch() {
    local helper
    if helper="$(detect_aur_helper)"; then
        echo "Detected AUR helper: $helper"
        INSTALLER_MARKER="/tmp/ksteamtrayicon-installer.marker"
        touch "$INSTALLER_MARKER"
        trap 'rm -f "$INSTALLER_MARKER"' EXIT
        "$helper" -S --needed "$PACKAGE_NAME" < /dev/tty
    else
        echo "No AUR helper found (yay, paru, or pikaur)."
        echo "Install one first, or install manually: aur-helper -S $PACKAGE_NAME"
        exit 1
    fi
}

install_pipx() {
    for cmd in python3 pipx; do
        if ! command_exists "$cmd"; then
            echo "Error: $cmd is not installed or not available in PATH."
            exit 1
        fi
    done

    find_sudo

    echo "Installing $PACKAGE_NAME using pipx..."
    run_as_root pipx ensurepath --global
    run_as_root pipx install --global --force "$PACKAGE_NAME"
}

get_systemd_user_unit_dir() {
    local dir
    dir="$(pkg-config systemd --variable=systemduserunitdir 2>/dev/null || true)"
    if [[ -z "$dir" ]]; then
        echo "Error: unable to determine the systemd user unit directory with pkg-config."
        exit 1
    fi
    printf '%s\n' "$dir"
}

get_service_file() {
    local tmp
    tmp="$(mktemp)"
    if curl -fsSL "$REPO_URL/$SERVICE_FILE" -o "$tmp"; then
        echo "$tmp"
        return 0
    fi

    echo "Error: could not find or download $SERVICE_FILE."
    exit 1
}

install_service() {
    if ! command_exists pkg-config; then
        echo "Error: pkg-config is not installed or not available in PATH."
        exit 1
    fi

    local unit_dir service_src
    unit_dir="$(get_systemd_user_unit_dir)"
    service_src="$(get_service_file)"

    echo "Installing systemd user service in $unit_dir..."
    run_as_root mkdir -p "$unit_dir"
    run_as_root install -Dm644 "$service_src" "$unit_dir/$SERVICE_FILE"
}

enable_and_start() {
    echo ""
    ! ask "Do you want to enable $PACKAGE_NAME for all users?" && {
        ! ask "Enable just for the current user?" && return 0
        systemctl --quiet --user enable "$PACKAGE_NAME.service"
        echo "Enabled for current user."
        ! ask "Start $PACKAGE_NAME now?" && return 0
        systemctl --user start "$PACKAGE_NAME.service"
        echo "Started."
        return 0
    }

    find_sudo
    run_as_root systemctl --global enable "$PACKAGE_NAME.service"
    echo "Enabled for all users."

    ! ask "Start $PACKAGE_NAME now?" && return 0
    systemctl --user start "$PACKAGE_NAME.service"
    echo "Started."
}

# --- Main ---

FORCE_PYPI=false
for arg in "$@"; do
    case $arg in
        --force-pypi) FORCE_PYPI=true ;;
    esac
done

if [[ "$FORCE_PYPI" == false ]] && is_arch_based; then
    echo "Arch-based distro detected."
    install_arch
else
    install_pipx
    install_service
fi

echo ""
echo "Installation complete."
enable_and_start