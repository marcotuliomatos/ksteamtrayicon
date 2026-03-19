# ksteamtrayicon

*ksteamtrayicon* is a small Python script for KDE Plasma 6 that keeps the Steam tray icon in sync with the desktop color scheme.

## How does it work?

By default, steam displays a tray icon that looks fine on dark panels, but is hard to see on light Plasma themes.

The script listens for changes on the current desktop color scheme and then acts as follows:

- if it detects that the current theme has a light color scheme, it overrides the default Steam tray icon by placing a symlink in `~/.local/share/icons/steam_tray_mono.png` pointing to a custom dark-colored tray icon.
- if it detects that the current theme has a dark color scheme, it removes the symlink, which changes the Steam tray icon back to the default light-colored one.

## Requirements

- KDE Plasma 6
- Python 3
- `dbus-next` (Python library)

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
```text
pikaur -S ksteamtrayicon
```

After installation, **restart your KDE Plasma session** to autorun the script or simply issue the following command:
```text
kioclient exec /etc/xdg/autostart/ksteamtrayicon.desktop
```

### Other distros (`install.sh` script)

First, make sure you are running KDE Plasma version 6.x.x and that Python 3 is installed in your system. If not, please refer to your distro documentation in order to properly install the correct packages.

Next, install the python library `dbus-next`, either with your distro's package manager or with pip:

```text
pip install dbus-next
```

Then, download the source code (tarball) for the latest release of *ksteamtrayicon* from [here](https://github.com/marcotuliomatos/ksteamtrayicon/releases/latest/) and extract its contents. For example:

```text
tar zvxf ./ksteamtrayicon-v1.0.3.tar.gz
```

Now, cd into the *ksteamtrayicon* folder:
```text
cd ksteamtrayicon
```

Last, but not least, run the `install.sh` script, which will take care of the rest of the installation process:

```text
./install.sh
```

**Note:** the `install.sh` script requires **root privileges** to run. If you execute it without root permissions, it will ask for your root password.

After installation, **restart your KDE Plasma session** to autorun the script or simply issue the following command:
```text
kioclient exec /etc/xdg/autostart/ksteamtrayicon.desktop
```

## Uninstall

If you installed *ksteamtrayicon* via AUR, just remove the `ksteamtrayicon` package using pacman:
```text
sudo pacman -Rns ksteamtrayicon
```

If you installed *ksteamtrayicon* using the provided `install.sh` script, just run the also provided `uninstall.sh` script:
```text
./uninstall.sh
```

**Note:** the `uninstall.sh` script requires **root privileges** to run. If you execute it without root permissions, it will ask for your root password.

## License

MIT
