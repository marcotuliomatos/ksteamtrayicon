#!/usr/bin/env python3
import asyncio
import os
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageType
from dbus_next.message import Message
from dbus_next.signature import Variant

PLASMA_ICON_DIR = os.path.expanduser("~/.local/share/icons/")
DARK_ICON_DIR = os.path.dirname(os.path.realpath(__file__))
DEFAULT_ICON_FILENAME = "steam_tray_mono.png"
DARK_ICON_FILENAME = "dark-icon.png"

def decode_color_scheme(value):
    if isinstance(value, Variant):
        value = value.value

    return {
        0: "no-preference",
        1: "dark",
        2: "light",
    }.get(value, f"unknown({value})")

def update_icon(scheme):
    destination = os.path.join(PLASMA_ICON_DIR, DEFAULT_ICON_FILENAME)

    if (scheme == "dark"):
        if os.path.islink(destination):
            os.unlink(destination)
    else:

        if os.path.exists(destination) and not os.path.islink(destination):
            print("Unable to fix the steam tray icon: \"" +
                  destination + "\" already exists")
            return

        if os.path.islink(destination):
            os.unlink(destination)

        os.symlink(os.path.join(DARK_ICON_DIR, DARK_ICON_FILENAME),
                   os.path.join(PLASMA_ICON_DIR, DEFAULT_ICON_FILENAME))

    print("Icon changed to match", scheme, "color scheme")


async def read_color_scheme(bus):
    msg = Message(
        destination="org.freedesktop.portal.Desktop",
        path="/org/freedesktop/portal/desktop",
        interface="org.freedesktop.portal.Settings",
        member="ReadOne",
        signature="ss",
        body=[
            "org.freedesktop.appearance",
            "color-scheme",
        ],
    )

    reply = await bus.call(msg)

    if reply.message_type == MessageType.ERROR:
        raise RuntimeError(f"D-Bus error: {reply.body}")

    return reply.body[0]


async def add_match(bus):
    msg = Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus",
        member="AddMatch",
        signature="s",
        body=[
            "type='signal',"
            "sender='org.freedesktop.portal.Desktop',"
            "interface='org.freedesktop.portal.Settings',"
            "member='SettingChanged',"
            "path='/org/freedesktop/portal/desktop'"
        ],
    )

    reply = await bus.call(msg)
    if reply.message_type == MessageType.ERROR:
        raise RuntimeError(f"AddMatch error: {reply.body}")

async def main():
    os.makedirs(PLASMA_ICON_DIR, exist_ok=True)

    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    current = await read_color_scheme(bus)
    last_color_scheme = decode_color_scheme(current)
    print("Current color scheme:", last_color_scheme)
    update_icon(last_color_scheme)

    def on_message(msg):
        nonlocal last_color_scheme
        if (
            msg.message_type == MessageType.SIGNAL
            and msg.interface == "org.freedesktop.portal.Settings"
            and msg.member == "SettingChanged"
        ):
            namespace, key, value = msg.body

            if (
                namespace != "org.freedesktop.appearance"
                or key != "color-scheme"
            ):
                return

            new_color_scheme = decode_color_scheme(value)

            if (
                last_color_scheme != new_color_scheme
            ):
                last_color_scheme = new_color_scheme
                print("Color scheme changed to:", last_color_scheme)
                update_icon(last_color_scheme)

    bus.add_message_handler(on_message)
    await add_match(bus)

    await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nProgram terminated by user request")
        pass
    except Exception as e:
        print(f"Fatal error: {e}")
