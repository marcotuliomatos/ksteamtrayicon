#!/usr/bin/env python3
import asyncio
import shutil
import signal
import logging

from pathlib import Path
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageType, NameFlag, RequestNameReply
from dbus_next.message import Message
from dbus_next.service import ServiceInterface, method
from dbus_next.signature import Variant

DARK_ICON_FILENAME = "dark-icon.png"
STEAM_ICON_DIR = Path.home() / ".local" / "share" / "icons"
STEAM_ICON_FILENAME = "steam_tray_mono.png"
APP_ID = "io.github.marcotuliomatos.ksteamtrayicon"

DARK_ICON_DIR = Path(__file__).resolve().parent

DARK_ICON_PATH = DARK_ICON_DIR / DARK_ICON_FILENAME
STEAM_ICON_PATH = STEAM_ICON_DIR / STEAM_ICON_FILENAME

OBJECT_PATH = f"/{APP_ID.replace(".", "/")}"
CONTROL_INTERFACE = f"{APP_ID}.Control"


class ControlInterface(ServiceInterface):
    def __init__(self, shutdown_event: asyncio.Event):
        super().__init__(CONTROL_INTERFACE)
        self._shutdown_event = shutdown_event

    @method()
    def Quit(self) -> "b":
        logging.info("Shutdown request received over D-Bus")
        logging.info("Exiting due to a request from another instance of ksteamtrayicon.")
        self._shutdown_event.set()
        return True


def decode_color_scheme(value):
    if isinstance(value, Variant):
        value = value.value

    return {
        0: "no-preference",
        1: "dark",
        2: "light",
    }.get(value, f"unknown({value})")


def clean_icon():
    if STEAM_ICON_PATH.is_dir():
        raise RuntimeError(f'Unable to fix the steam tray icon: "{STEAM_ICON_PATH}" already exists and is a directory')
    elif STEAM_ICON_PATH.is_symlink() or STEAM_ICON_PATH.is_file():
        try:
            STEAM_ICON_PATH.unlink()
        except PermissionError:
            raise RuntimeError(f'Failed to remove "{STEAM_ICON_PATH}": Permission denied.')
        except IsADirectoryError:
            raise RuntimeError(f'Failed to remove "{STEAM_ICON_PATH}": this path is a directory, not a file or symlink')
        except Exception as e:
            raise RuntimeError(f'Failed to remove "{STEAM_ICON_PATH}" due to an unexpected error: {e}')


def update_icon(scheme):
    clean_icon()
    icon_color = "light"

    if scheme != "dark":
        icon_color = "dark"
        shutil.copy(DARK_ICON_PATH, STEAM_ICON_PATH)

    logging.info(f"Displaying the {icon_color}-colored Steam tray icon, to contrast with it.")


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


async def add_match(bus: MessageBus):
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


async def get_name_owner(bus: MessageBus, name: str):
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


async def wait_until_name_is_free(bus: MessageBus, name: str, timeout: float = 5.0):
    freed = asyncio.Event()

    def on_name_owner_changed(msg):
        if (
            msg.message_type != MessageType.SIGNAL
            or msg.interface != "org.freedesktop.DBus"
            or msg.member != "NameOwnerChanged"
        ):
            return

        changed_name, old_owner, new_owner = msg.body

        if changed_name == name and new_owner == "":
            freed.set()

    msg = Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface="org.freedesktop.DBus",
        member="AddMatch",
        signature="s",
        body=[
            "type='signal',"
            "sender='org.freedesktop.DBus',"
            "interface='org.freedesktop.DBus',"
            "member='NameOwnerChanged',"
            f"arg0='{name}'"
        ],
    )

    reply = await bus.call(msg)
    if reply.message_type == MessageType.ERROR:
        raise RuntimeError(f"AddMatch error while waiting for {name} to be released: {reply.body}")

    bus.add_message_handler(on_name_owner_changed)

    try:
        owner = await get_name_owner(bus, name)
        if owner is None:
            return True

        await asyncio.wait_for(freed.wait(), timeout)
        return True
    except asyncio.TimeoutError:
        return False
    finally:
        bus.remove_message_handler(on_name_owner_changed)


async def request_existing_instance_to_quit(bus: MessageBus):
    msg = Message(
        destination=APP_ID,
        path=OBJECT_PATH,
        interface=CONTROL_INTERFACE,
        member="Quit",
    )

    reply = await bus.call(msg)

    if reply.message_type == MessageType.ERROR:
        raise RuntimeError(f"Quit request failed: {reply.body}")

    if reply.body != [True]:
        raise RuntimeError(f"Unexpected Quit reply: {reply.body}")


async def acquire_or_replace_name(bus: MessageBus):
    reply = await bus.request_name(APP_ID, NameFlag.DO_NOT_QUEUE)

    if reply == RequestNameReply.PRIMARY_OWNER:
        return

    owner = await get_name_owner(bus, APP_ID)
    if owner is None:
        reply = await bus.request_name(APP_ID, NameFlag.DO_NOT_QUEUE)
        if reply == RequestNameReply.PRIMARY_OWNER:
            return
        raise RuntimeError("Unable to acquire D-Bus name")

    logging.info("Another instance of ksteamtrayicon is already running. Waiting for it to shutdown...")
    await request_existing_instance_to_quit(bus)

    freed = await wait_until_name_is_free(bus, APP_ID, timeout=5.0)
    if not freed:
        raise RuntimeError("Existing instance did not exit in time. Unable to continue.")

    reply = await bus.request_name(APP_ID, NameFlag.DO_NOT_QUEUE)
    if reply != RequestNameReply.PRIMARY_OWNER:
        raise RuntimeError("Failed to acquire D-Bus name. Unable to continue.")

    logging.info("The other instance has completed its shutdown. Continuing...")


async def main(shutdown_event):
    STEAM_ICON_DIR.mkdir(parents=True, exist_ok=True)

    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    control_interface = ControlInterface(shutdown_event)
    bus.export(OBJECT_PATH, control_interface)

    await acquire_or_replace_name(bus)

    current = await read_color_scheme(bus)
    last_color_scheme = decode_color_scheme(current)
    logging.info("Current KDE Plasma color scheme: %s.", last_color_scheme)
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
                logging.info("Color scheme changed to: %s", last_color_scheme)
                try:
                    update_icon(last_color_scheme)
                except Exception as e:
                    logging.error(f"Failed to update icon: {e}")

    bus.add_message_handler(on_message)
    await add_match(bus)

    await shutdown_event.wait()


def cleanup() -> None:
    try:
        clean_icon()
    except Exception as e:
        logging.info(f"Cleanup error: {e}")


def cli() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
    )

    shutdown_event = asyncio.Event()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def request_shutdown(reason):
        logging.info(f"Received a {reason} signal. Shutting down...")
        shutdown_event.set()

    try:
        loop.add_signal_handler(signal.SIGTERM, request_shutdown, "SIGTERM")
        loop.add_signal_handler(signal.SIGINT, request_shutdown, "SIGINT")
        loop.add_signal_handler(signal.SIGHUP, request_shutdown, "SIGHUP")
        loop.run_until_complete(main(shutdown_event))
    except KeyboardInterrupt:
        logging.info("\nProgram interrupted by user.")
    except Exception as e:
        logging.info(f"Fatal error: {e}")
        raise SystemExit(1)
    finally:
        cleanup()
        loop.close()
