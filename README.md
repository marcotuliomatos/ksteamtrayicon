# ksteamtrayicon

ksteamtrayicon is a small Python script for KDE Plasma 6 that keeps the Steam tray icon in sync with the desktop color scheme.

## What it does

By default, steam displays a tray icon that looks fine on dark panels but is hard to see on light Plasma themes.

This script listens for changes on the current desktop color scheme and overrides the default Steam tray icon by placing a symlink in ~/.local/share/icons/steam_tray_mono.png pointing to:

- a custom dark-colored tray icon when a theme with light color scheme is in use
- the default Steam light-colored tray icon, when a theme with dark color scheme is in use

## Requirements

- KDE Plasma 6
- Python 3
- `dbus-next`

## Installation

### AUR

An AUR package is available for Arch Linux and Arch-based distros. Install it with your preferred AUR helper.

```text
yay -S ksteamtrayicon
```

### Manual

#### Install the required dependencies:

For Arch-based distros:

```text
sudo pacman -S python-dbus-next
```

For other distros, install with pip:

```text
pip install dbus-next
```

#### Install the script:

Create the asset directory:

```text
sudo mkdir /usr/share/ksteamtrayicon/
```

Copy the script and the dark Steam tray icon:

```text
sudo cp ksteamtrayicon.py /usr/bin/
sudo cp steam-tray-dark-icon.png /usr/share/ksteamtrayicon/
sudo chmod +x /usr/bin/ksteamtrayicon.py
```

#### Install the autostart file:

```text
sudo cp ksteamtrayicon.desktop /etc/xdg/autostart/ksteamtrayicon.desktop
```

## Uninstall

Remove the installed files:

```text
sudo rm -rf /usr/share/ksteamtrayicon/
sudo rm -f /usr/bin/ksteamtrayicon.py
sudo rm -f /etc/xdg/autostart/ksteamtrayicon.desktop
```

Remove the Steam tray icon override symlink if it exists:

```text
rm -f ~/.local/share/icons/steam_tray_mono.png
```

## License

MIT
