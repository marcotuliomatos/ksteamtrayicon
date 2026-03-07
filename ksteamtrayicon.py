#!/usr/bin/env python3
import asyncio
import os
import signal
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageType, NameFlag, RequestNameReply
from dbus_next.message import Message
from dbus_next.signature import Variant

PLASMA_ICON_DIR = os.path.expanduser("~/.local/share/icons/")
DARK_ICON_DIR = os.path.dirname(os.path.realpath(__file__))
DEFAULT_ICON_FILENAME = "steam_tray_mono.png"
DARK_ICON_FILENAME = "dark-icon.png"
BUS_NAME = "com.github.marcotuliomatos.ksteamtrayicon"

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

    if scheme == "dark":
        if os.path.islink(destination):
            os.unlink(destination)
    else:

        if os.path.exists(destination) and not os.path.islink(destination):
            print('Unable to fix the steam tray icon: "' + destination + 
                  '" already exists')
            return

        if os.path.islink(destination):
            os.unlink(destination)

        os.symlink(
            os.path.join(DARK_ICON_DIR, DARK_ICON_FILENAME),
            os.path.join(PLASMA_ICON_DIR, DEFAULT_ICON_FILENAME)
        )

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

async def get_name_owner(bus, name):
    msg = Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus",
        member="GetNameOwner",
        signature="s",
        body=[name],
    )

    reply = await bus.call(msg)
    if reply.message_type == MessageType.ERROR:
        return None

    return reply.body[0]


async def get_connection_unix_pid(bus, unique_name):
    msg = Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus",
        member="GetConnectionUnixProcessID",
        signature="s",
        body=[unique_name],
    )

    reply = await bus.call(msg)
    if reply.message_type == MessageType.ERROR:
        return None

    return reply.body[0]


async def wait_until_name_is_free(bus, name, timeout=5.0):
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout

    while loop.time() < deadline:
        owner = await get_name_owner(bus, name)
        if owner is None:
            return True
        await asyncio.sleep(0.1)

    return False


async def acquire_or_replace_name(bus):
    reply = await bus.request_name(BUS_NAME, NameFlag.DO_NOT_QUEUE)

    if reply == RequestNameReply.PRIMARY_OWNER:
        return

    owner = await get_name_owner(bus, BUS_NAME)
    if owner is None:
        reply = await bus.request_name(BUS_NAME, NameFlag.DO_NOT_QUEUE)
        if reply == RequestNameReply.PRIMARY_OWNER:
            return
        raise RuntimeError("Unable to acquire D-Bus name")

    pid = await get_connection_unix_pid(bus, owner)
    if pid is None:
        raise RuntimeError("Unable to determine PID of existing instance")

    print(f"Existing instance detected (PID {pid}). Sending SIGTERM to it...")
    os.kill(pid, signal.SIGTERM)

    freed = await wait_until_name_is_free(bus, BUS_NAME, timeout=5.0)
    if not freed:
        raise RuntimeError("Existing instance did not exit in time after SIGTERM")

    reply = await bus.request_name(BUS_NAME, NameFlag.DO_NOT_QUEUE)
    if reply != RequestNameReply.PRIMARY_OWNER:
        raise RuntimeError("Unable to acquire D-Bus name after replacing old instance")

async def main():
    os.makedirs(PLASMA_ICON_DIR, exist_ok=True)

    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    await acquire_or_replace_name(bus)

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
    except Exception as e:
        print(f"Fatal error: {e}")
