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
- `pipx` (only for those not installing the AUR package)

## Installation

### Arch Linux and Arch-based distros (AUR)

[An AUR package is available](https://aur.archlinux.org/packages/ksteamtrayicon) for Arch Linux and Arch-based distros. To install it using your preferred AUR helper, you can issue a command like `aur-helper-command-name -S ksteamtrayicon`.

If you use `yay`:
```text
yay -S ksteamtrayicon
```

If you use `paru`:
```text
paru -S ksteamtrayicon
```

If you use `pikaur`:
```
pikaur -S ksteamtrayicon
```

After installation, you should enable the *KSteamTrayIcon* systemd service.

To enable it just for the current user:
```text
systemctl --user enable ksteamtrayicon.service
```

To enable it for all users:
```text
sudo systemctl --global enable ksteamtrayicon.service
```

After enabling the service, you should start *KSteamTrayIcon*:
```text
systemctl --user start ksteamtrayicon.service
```

### Other distros

First, make sure you are running KDE Plasma 6.x.x and that Python 3 is installed on your system, along with `pipx` and the `dbus-next` Python library. Then run the following command:

```text
sudo pipx install --global ksteamtrayicon
```

After installation, you should enable the *KSteamTrayIcon* systemd service.

To enable it just for the current user:
```text
systemctl --user enable ksteamtrayicon.service
```

To enable it for all users:
```text
sudo systemctl --global enable ksteamtrayicon.service
```

After enabling the service, you should start *KSteamTrayIcon*:
```text
systemctl --user start ksteamtrayicon.service
```

## Uninstall

### Arch Linux and Arch-based distros (AUR)

```text
systemctl --user stop ksteamtrayicon.service
sudo systemctl --global disable ksteamtrayicon.service
sudo pacman -Rns ksteamtrayicon
```

### Other distros

```text
systemctl --user stop ksteamtrayicon.service
sudo systemctl --global disable ksteamtrayicon.service
sudo pipx uninstall --global ksteamtrayicon
```

## License

MIT
