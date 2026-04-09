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

*Note:* `pipx` is only required when installing *KSteamTrayIcon* from PyPI. Installing it from the AUR (on Arch Linux and its derivatives) does not require `pipx` (check the *Install* section below for more details).

## Install

First, check the contents of [setup.sh](https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/setup.sh) and if everything seems ok for you, simply run the following command:

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/setup.sh | bash -s -- install
```

The installation script checks whether all required dependencies are available on your system and guides you through the setup process.

On all distributions except Arch Linux and its derivatives, `setup.sh install` installs the [*KSteamTrayIcon* PyPI package](https://pypi.org/project/ksteamtrayicon/) using `pipx`.

On Arch Linux and Arch-based distributions, `setup.sh install` defaults to installing the [*KSteamTrayIcon* AUR package](https://aur.archlinux.org/packages/ksteamtrayicon), which does not require `pipx`. If, for whatever reason, you would prefer to install the package from PyPI instead, use `setup.sh install-from-pypi`:

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/setup.sh | bash -s -- install-from-pypi
```

## Uninstall

Check the contents of [setup.sh](https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/setup.sh) and if everything seems ok for you, simply run the following command:

```text
curl -fsSL https://raw.githubusercontent.com/marcotuliomatos/ksteamtrayicon/main/setup.sh | bash -s -- uninstall
```

## License

MIT
