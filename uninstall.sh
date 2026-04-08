#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KSteamTrayIcon"
PACKAGE_NAME="ksteamtrayicon"
LEGACY_XDG_AUTOSTART_DESKTOP_FILE="/etc/xdg/autostart/ksteamtrayicon.desktop"
LOCAL_BIN_DIR="${HOME}/.local/bin"
PIPX_BIN="${LOCAL_BIN_DIR}/pipx"
BOOTSTRAP_VENV="${HOME}/.local/share/pipx-bootstrap"
USER_SYSTEMD_UNIT_DIR="${HOME}/.config/systemd/user"
USER_SERVICE_PATH="${USER_SYSTEMD_UNIT_DIR}/${PACKAGE_NAME}.service"

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
    if [[ "$#" -ge 2 && "$2" == true ]]; then
        while true; do
            printf "%s [y/N] " "$1" > /dev/tty
            read -r answer < /dev/tty
            case $answer in
                [yY]*) return 0 ;;
                [nN]*|"") return 1 ;;
                *) ;;
            esac
        done
    else
        while true; do
            printf "%s [Y/n] " "$1" > /dev/tty
            read -r answer < /dev/tty
            case $answer in
                [yY]*|"") return 0 ;;
                [nN]*) return 1 ;;
                *) ;;
            esac
        done
    fi
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

has_user_pipx_install() {
    [[ -x "$PIPX_BIN" ]] || return 1
    "$PIPX_BIN" list --short 2>/dev/null | grep -q "^${PACKAGE_NAME} "
}

has_legacy_global_pipx_install() {
    if ! command_exists pipx; then
        return 1
    fi
    pipx list --global --short 2>/dev/null | grep -q "^${PACKAGE_NAME} "
}

remove_user_service() {
    echo "Stopping $APP_NAME user service..."
    systemctl --user stop "$PACKAGE_NAME.service" 2>/dev/null || true

    echo "Disabling $APP_NAME user service..."
    systemctl --quiet --user disable "$PACKAGE_NAME.service" 2>/dev/null || true

    echo "Removing user service file..."
    rm -f "$USER_SERVICE_PATH"

    echo "Reloading user systemd daemon..."
    systemctl --user daemon-reload 2>/dev/null || true
}

get_legacy_global_service_dirs() {
    local dirs=()
    local pkgconfig_dir=""

    pkgconfig_dir="$(pkg-config systemd --variable=systemduserunitdir 2>/dev/null || true)"

    [[ -n "$pkgconfig_dir" ]] && dirs+=("$pkgconfig_dir")
    dirs+=("/etc/systemd/user")

    printf '%s\n' "${dirs[@]}" | awk '!seen[$0]++'
}

remove_legacy_global_service() {
    find_sudo

    echo "Stopping legacy user service..."
    systemctl --user stop "$PACKAGE_NAME.service" 2>/dev/null || true

    echo "Disabling legacy global service..."
    run_as_root systemctl --quiet --global disable "$PACKAGE_NAME.service" 2>/dev/null || true
    systemctl --quiet --user disable "$PACKAGE_NAME.service" 2>/dev/null || true

    local dir
    while IFS= read -r dir; do
        [[ -n "$dir" ]] || continue
        if [[ -f "$dir/${PACKAGE_NAME}.service" ]]; then
            echo "Removing legacy global service file from $dir..."
            run_as_root rm -f "$dir/${PACKAGE_NAME}.service"
        fi
    done < <(get_legacy_global_service_dirs)

    echo "Reloading user systemd daemon..."
    systemctl --user daemon-reload 2>/dev/null || true
}

remove_pipx_bootstrap_if_unused() {
    [[ -x "$PIPX_BIN" ]] || return 0

    local remaining
    remaining="$("$PIPX_BIN" list --short 2>/dev/null || true)"

    if [[ -z "$remaining" ]]; then
        echo
        echo "A pipx bootstrap environment was created at ${BOOTSTRAP_VENV}"
        echo "during the installation of ${APP_NAME} and is no longer needed."
        if ask "Do you want to remove it?"; then
            rm -rf "$BOOTSTRAP_VENV"

            if [[ -L "$PIPX_BIN" ]]; then
                rm -f "$PIPX_BIN"
            fi
        fi
    fi
}

uninstall_aur() {
    remove_user_service
    find_sudo
    if helper="$(detect_aur_helper)"; then
        echo "Uninstalling with $helper..."
        "$helper" -Rns "$PACKAGE_NAME" < /dev/tty
    else
        echo "Uninstalling with pacman..."
        run_as_root pacman -Rns "$PACKAGE_NAME"
    fi
}

uninstall_user_pipx() {
    remove_user_service
    echo "Uninstalling with pipx..."
    "$PIPX_BIN" uninstall "$PACKAGE_NAME" || true
    remove_pipx_bootstrap_if_unused || true
}

uninstall_global_pipx() {
    remove_legacy_global_service
    find_sudo
    echo "Uninstalling legacy global package with pipx..."
    run_as_root pipx uninstall --global "$PACKAGE_NAME" || true
}

prompt_uninstall() {
    [[ "$#" -ge 1 && "$1" == true ]] && default_to_no=true || default_to_no=false
    if ! ask "Do you want to remove it?" $default_to_no; then
        echo "Aborted."
        exit 0
    fi
    echo ""
}

# --- Main ---

uninstalled=false
echo "Starting the $APP_NAME uninstall script..."

if is_arch_based && pacman -Qi "$PACKAGE_NAME" >/dev/null 2>&1; then
    echo
    echo "Found a $APP_NAME installation (AUR package)."
    prompt_uninstall true
    uninstall_aur
    uninstalled=true
fi

if has_user_pipx_install; then
    echo
    echo "Found a $APP_NAME installation (pipx user package)."
    prompt_uninstall true
    uninstall_user_pipx
    uninstalled=true
fi

if has_legacy_global_pipx_install; then
    echo
    echo "Found a $APP_NAME installation (legacy pipx global package)."
    prompt_uninstall
    uninstall_global_pipx
    uninstalled=true
fi

if [[ -f "$LEGACY_XDG_AUTOSTART_DESKTOP_FILE" ]]; then
    echo
    echo "Found a $APP_NAME legacy XDG autostart .desktop file."
    prompt_uninstall
    find_sudo
    run_as_root rm -f "$LEGACY_XDG_AUTOSTART_DESKTOP_FILE"
    uninstalled=true
fi

echo
if $uninstalled; then
    echo "$APP_NAME uninstalled successfully."
else
    echo "$APP_NAME is not installed."
    exit 1
fi