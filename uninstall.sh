#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="ksteamtrayicon"

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
        echo -n "$1 [y/N] "
        read -r answer
        case $answer in
            [yY]*) return 0 ;;
            [nN]*|"") return 1 ;;
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

get_pipx_value() {
    pipx environment --global --value "$1" 2>/dev/null
}

remove_manpages() {
    local paths=(
        "/usr/share/man"
        "/usr/local/share/man"
    )

    local pipx_man
    pipx_man="$(get_pipx_value PIPX_MAN_DIR 2>/dev/null || true)"
    [[ -n "$pipx_man" ]] && paths+=("$pipx_man")

    for root in "${paths[@]}"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d '' f; do
            echo "  Removing $f"
            run_as_root rm -f "$f"
        done < <(find "$root" -name "${PACKAGE_NAME}.1" -print0 2>/dev/null)
    done
}

# --- Main ---

echo "You are about to uninstall $PACKAGE_NAME."
! ask "Do you want to continue?" && echo "Aborted." && exit 0

find_sudo

echo "Stopping $PACKAGE_NAME service..."
systemctl --user stop "$PACKAGE_NAME.service" 2>/dev/null || true

echo "Disabling $PACKAGE_NAME service..."
run_as_root systemctl --global disable "$PACKAGE_NAME.service" 2>/dev/null || true
systemctl --user disable "$PACKAGE_NAME.service" 2>/dev/null || true

echo "Reloading systemd daemon..."
systemctl --user daemon-reload

if is_arch_based && pacman -Qi "$PACKAGE_NAME" &>/dev/null; then
    echo "Package installed via pacman/AUR. Removing..."
    if helper="$(detect_aur_helper)"; then
        "$helper" -Rns "$PACKAGE_NAME"
    else
        run_as_root pacman -Rns "$PACKAGE_NAME"
    fi
else
    echo "$PACKAGE_NAME was installed from PyPI. Uninstalling it with pipx..."
    run_as_root pipx uninstall --global "$PACKAGE_NAME" || true
fi

echo "Checking for leftover man pages..."
remove_manpages

echo ""
echo "Uninstallation complete."