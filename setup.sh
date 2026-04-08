#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KSteamTrayIcon"
PACKAGE_NAME="ksteamtrayicon"
REPO_URL="https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main"
SERVICE_FILE="ksteamtrayicon.service"
LEGACY_XDG_AUTOSTART_DESKTOP_FILE="/etc/xdg/autostart/ksteamtrayicon.desktop"
BOOTSTRAP_VENV="${HOME}/.local/share/pipx-bootstrap"
LOCAL_BIN_DIR="${HOME}/.local/bin"
PIPX_BIN="${LOCAL_BIN_DIR}/pipx"
USER_SYSTEMD_UNIT_DIR="${HOME}/.config/systemd/user"
USER_SERVICE_PATH="${USER_SYSTEMD_UNIT_DIR}/${PACKAGE_NAME}.service"
REAL_EXEC="${HOME}/.local/bin/ksteamtrayicon"

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
            if ! sudo -n true > /dev/null 2>&1; then
                echo
            fi
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

ensure_python3() {
    if ! command_exists python3; then
        echo "python3 is not installed or not available in PATH."
        exit 1
    fi
}

ensure_local_bin_dir() {
    mkdir -p "$LOCAL_BIN_DIR"
}

ensure_bootstrap_venv() {
    if [[ ! -x "${BOOTSTRAP_VENV}/bin/python" ]]; then
        echo "Creating pipx bootstrap virtual environment in:"
        echo "  $BOOTSTRAP_VENV"
        python3 -m venv "$BOOTSTRAP_VENV"
    fi
}

ensure_pip_in_bootstrap_venv() {
    if [[ -x "${BOOTSTRAP_VENV}/bin/pip" ]]; then
        return 0
    fi

    echo "pip was not found inside the bootstrap virtual environment."

    if ! ask "Do you want to bootstrap pip with ensurepip?" true; then
        echo "Cannot continue without pip. Aborting."
        exit 1
    fi

    "${BOOTSTRAP_VENV}/bin/python" -m ensurepip --upgrade
}

ensure_pipx() {
    ensure_python3
    ensure_local_bin_dir

    if [[ -x "$PIPX_BIN" ]]; then
        return 0
    fi

    echo "The pipx Python tool was not found in ${LOCAL_BIN_DIR}."

    if ! ask "Do you want to install it in your home directory?"; then
        echo "Cannot continue without pipx. Aborting."
        exit 1
    fi

    ensure_bootstrap_venv
    ensure_pip_in_bootstrap_venv

    echo "Installing pipx in the bootstrap virtual environment..."
    "${BOOTSTRAP_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel
    "${BOOTSTRAP_VENV}/bin/python" -m pip install --upgrade pipx

    ln -sf "${BOOTSTRAP_VENV}/bin/pipx" "$PIPX_BIN"

    echo ""
    echo "pipx installed at:"
    echo "  $PIPX_BIN"
    echo ""
    echo "If needed, add this to your shell profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
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

get_legacy_global_service_dirs() {
    local dirs=()
    local pkgconfig_dir=""

    if ! pacman -Qi "$PACKAGE_NAME" >/dev/null 2>&1; then
        pkgconfig_dir="$(pkg-config systemd --variable=systemduserunitdir 2>/dev/null || true)"
    fi

    [[ -n "$pkgconfig_dir" ]] && dirs+=("$pkgconfig_dir")
    dirs+=("/etc/systemd/user")

    printf '%s\n' "${dirs[@]}" | awk '!seen[$0]++'
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
        echo -n "A pipx bootstrap environment was created at ${BOOTSTRAP_VENV} "
        echo "during the installation of the ${APP_NAME} PyPI package and is no longer needed."
        if ask "Do you want to remove it?"; then
            rm -rf "$BOOTSTRAP_VENV"

            if [[ -L "$PIPX_BIN" ]]; then
                rm -f "$PIPX_BIN"
            fi
            echo "Removed."
        fi
    fi
}

uninstall_aur() {
    remove_user_service
    find_sudo
    if helper="$(detect_aur_helper)"; then
        echo "Uninstalling $APP_NAME AUR package with $helper..."
        "$helper" -Rns "$PACKAGE_NAME" < /dev/tty
    else
        echo "Uninstalling $APP_NAME AUR package with pacman..."
        run_as_root pacman -Rns "$PACKAGE_NAME"
    fi
}

uninstall_user_pipx() {
    remove_user_service
    echo "Uninstalling $APP_NAME PyPI package with pipx..."
    "$PIPX_BIN" uninstall "$PACKAGE_NAME" || true
    remove_pipx_bootstrap_if_unused || true
}

uninstall_global_pipx() {
    remove_legacy_global_service
    find_sudo
    echo "Uninstalling legacy global PyPI package with pipx..."
    run_as_root pipx uninstall --global "$PACKAGE_NAME" || true
}

prompt_uninstall() {
    local default_to_no=false
    [[ "$#" -ge 1 && "$1" == true ]] && default_to_no=true

    if ! ask "Do you want to remove it?" "$default_to_no"; then
        echo "Aborted by user request."
        exit 0
    fi
    echo ""
}

safe_proceed() {
    echo "To safely proceed, it has to be removed."
    if ! ask "Do you want to continue?"; then
        echo "Cannot continue safely without removing it. Aborting."
        exit 1
    fi
}

remove_legacy_global_install() {
    echo -n "A legacy global installation of $APP_NAME was found. "
    safe_proceed
    uninstall_global_pipx
}

remove_legacy_xdg_desktop_autostart_file() {
    echo -n "A legacy $APP_NAME XDG autostart .desktop file was found. "
    safe_proceed
    find_sudo
    run_as_root rm -f "$LEGACY_XDG_AUTOSTART_DESKTOP_FILE"
}

patch_service_file() {
    local service_src="$1"
    local detected_exec=""

    if [[ -x "$REAL_EXEC" ]]; then
        detected_exec="$REAL_EXEC"
    elif command -v ksteamtrayicon >/dev/null 2>&1; then
        detected_exec="$(command -v ksteamtrayicon)"
    else
        echo "Error: could not find ksteamtrayicon executable."
        exit 1
    fi

    if grep -q '^ExecStart=' "$service_src"; then
        sed -i "s|^ExecStart=.*|ExecStart=$detected_exec|" "$service_src"
    else
        echo "Error: no ExecStart line found in $SERVICE_FILE."
        exit 1
    fi
}

install_aur() {
    local helper
    if helper="$(detect_aur_helper)"; then
        echo
        echo "Detected AUR helper: $helper"
        echo ""
        echo "Installing the AUR package..."
        INSTALLER_MARKER="/tmp/ksteamtrayicon-installer.marker"
        touch "$INSTALLER_MARKER"
        trap 'rm -f "$INSTALLER_MARKER"' EXIT
        "$helper" -S --needed "$PACKAGE_NAME" < /dev/tty
    else
        echo "No AUR helper found (yay, paru, or pikaur)."
        echo ""
        echo "! WARNING !"
        echo ""
        echo "For Arch Linux (and distros based on it) it is recommended to install the"
        echo "$APP_NAME AUR package. Since no AUR helper was found, this is"
        echo "currently not possible."
        echo ""
        echo "You are advised to install an AUR helper first (yay, paru, or pikaur), and"
        echo "then re-run this installer script."
        echo ""
        echo "However, you can proceed by installing the $APP_NAME"
        echo "PyPI package with pipx in your home directory."
        echo ""
        if ! ask "Do you want to install $APP_NAME using its PyPI package?" true; then
            exit 1
        fi
        install_pipx
        install_service
    fi
}

install_pipx() {
    ensure_pipx

    echo "Installing $APP_NAME using pipx..."
    "$PIPX_BIN" install --force "$PACKAGE_NAME"
}

install_service() {
    local unit_dir service_src
    unit_dir="$USER_SYSTEMD_UNIT_DIR"
    service_src="$(get_service_file)"

    patch_service_file "$service_src"

    echo "Installing systemd user service in $unit_dir..."
    mkdir -p "$unit_dir"
    install -Dm644 "$service_src" "$unit_dir/$SERVICE_FILE"
}

enable_and_start() {
    echo ""

    if ! command_exists systemctl; then
        echo "systemctl is not installed or not available in PATH."
        return 0
    fi

    systemctl --user daemon-reload > /dev/null 2>&1 || true

    if ! ask "Enable $APP_NAME for the current user?"; then
        return 0
    fi
    set +e
    systemctl --quiet --user enable "$PACKAGE_NAME.service" > /dev/null 2>&1
    [ $? -eq 0 ] && echo "Enabled for the current user." || echo "An error occured while trying to enable it."
    set -e

    echo

    if ! ask "Start $APP_NAME now?"; then
        return 0
    fi
    set +e
    systemctl --quiet --user start "$PACKAGE_NAME.service" > /dev/null 2>&1
    [[ $? -eq 0 ]] && echo "Started." || echo "Unable to start it."
    set -e
}

check_pipx_installation() {
    if has_user_pipx_install; then
        echo
        echo -n "Found a $APP_NAME PyPI package previously installed with pipx. "
        safe_proceed
        uninstall_user_pipx
    fi
}

check_aur_installation() {
    if is_arch_based && pacman -Qi "$PACKAGE_NAME" >/dev/null 2>&1; then
        echo "$APP_NAME is already installed via AUR."
        echo "Aborting."
        exit 1
    fi
}

run_install_main() {
    echo "Starting the $APP_NAME install script..."
    echo ""

    if has_legacy_global_pipx_install; then
        remove_legacy_global_install
    fi

    if [[ -f "$LEGACY_XDG_AUTOSTART_DESKTOP_FILE" ]]; then
        remove_legacy_xdg_desktop_autostart_file
    fi

    if [[ "$FORCE_PYPI" == false ]] && is_arch_based; then
        echo "Arch-based distro detected."
        check_pipx_installation
        install_aur
    else
        check_aur_installation
        install_pipx
        install_service
    fi

    echo
    echo "Installation complete."
    enable_and_start
}

run_uninstall_main() {
    local uninstalled=false

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

    if $uninstalled; then
        echo "$APP_NAME uninstalled successfully."
    else
        echo
        echo "$APP_NAME is not installed."
        exit 1
    fi
}

main() {
    local mode="${1:-}"

    case "$mode" in
        install)
            FORCE_PYPI=false
            shift
            run_install_main "$@"
            ;;
        install-from-pypi)
            FORCE_PYPI=true
            shift
            run_install_main "$@"
            ;;
        uninstall)
            shift
            run_uninstall_main "$@"
            ;;
        *)
            echo "Usage: $0 {install|uninstall} [args...]"
            exit 1
            ;;
    esac
}

main "$@"