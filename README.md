# ksteamtrayicon

*ksteamtrayicon* is a small Python script for KDE Plasma 6 that keeps the Steam tray icon in sync with the desktop color scheme.

## What it does

By default, steam displays a tray icon that looks fine on dark panels, but is hard to see on light Plasma themes.

The script listens for changes on the current desktop color scheme and then acts as follows:

- if it detects that the current theme has a light color scheme, it overrides the default Steam tray icon by placing a symlink in `~/.local/share/icons/steam_tray_mono.png` which points to a custom dark-colored tray icon.
- if it detects that the current theme has a dark color scheme, it removes the symlink, which changes the Steam tray icon to the default light-colored one.

## Requirements

- KDE Plasma 6
- Python 3
- `dbus-next`

## Installation

### Arch Linux and Arch-based distros (AUR)

An AUR package is available for Arch Linux and Arch-based distros. Install it with your preferred AUR helper. For example:

```text
yay -S ksteamtrayicon
```

### Other distros (`install.sh` script)

First, make sure you are running KDE Plasma version 6.x.x and that Python 3 is installed in your system. If not, please refer to your distro documentation in order to properly install the correct packages.

Next, install `dbus-next` with pip:

```text
pip install dbus-next
```

```text
./install.sh
```

Please note that the `install.sh` script requires **root privileges** to run. If you execute it without root permissions, it will ask for your root password.

## Uninstall

If you installed *ksteamtrayicon* via AUR, just remove the `ksteamtrayicon` package using pacman:
```text
sudo pacman -Rns ksteamtrayicon
```

If you installed *ksteamtrayicon* using the provided `install.sh` script, just run the equally provided `uninstall.sh` script:
```text
./uninstall.sh
```

Please note that the `uninstall.sh` script requires **root privileges** to run. If you execute it without root permissions, it will ask for your root password.

## License

MIT
