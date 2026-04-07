# KSteamTrayIcon

*KSteamTrayIcon* is a small Python background application for KDE Plasma 6 that keeps the Steam tray icon in sync with the desktop color scheme.

## How does it work?

By default, Steam displays a tray icon that looks fine on dark panels, but is hard to see on light Plasma themes.

The application listens for changes on the current desktop color scheme and then acts as follows:

- if it detects that the current theme has a light color scheme, it overrides the default Steam tray icon by placing a dark-colored variant in `$HOME/.local/share/icons/steam_tray_mono.png`.
- if it detects that the current theme has a dark color scheme, it removes the dark-colored file, which prompts Steam to change its tray icon back to the default light-colored one.

## Requirements

- KDE Plasma 6
- Python 3
- `dbus-next` (python library)
- `pipx`*

*Note:* `pipx` is **not** required on Arch Linux and its derivatives if you run the `install.sh` script with its default parameters (more information below).

## Installation

First, check the contents of [install.sh](https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/install.sh) and if everything seems ok for you, simply run the following command:

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/install.sh | bash
```

This installation script will check if the required dependencies are available in your system and will guide you through the setup process.

For users of all distributions except Arch Linux (and distros based on it), the script will install the [*KSteamTrayIcon* PyPI package](https://pypi.org/project/ksteamtrayicon/) using `pipx`.

For those on Arch Linux or any Arch-based distro, the script defaults to install the [*KSteamTrayIcon* AUR package](https://aur.archlinux.org/packages/ksteamtrayicon), which doesn't require `pipx` at all. If, for whatever reason, you prefer to install the package from PyPI instead, make sure `pipx` is installed, then run `install.sh` with the `--force-pypi` flag.

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/install.sh | bash -s -- --force-pypi
```

## Uninstallation
Check the contents of [uninstall.sh](https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/uninstall.sh) and if everything seems ok for you, simply run the following command:

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/uninstall.sh | bash
```

## License

MIT
