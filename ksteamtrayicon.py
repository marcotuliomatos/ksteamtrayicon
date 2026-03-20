#!/usr/bin/env python3
import asyncio
import shutil
from pathlib import Path
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType, MessageType, NameFlag, RequestNameReply
from dbus_next.message import Message
from dbus_next.service import ServiceInterface, method
from dbus_next.signature import Variant

PLASMA_ICON_DIR = Path.home() / ".local" / "share" / "icons"
DEFAULT_ICON_FILENAME = "steam_tray_mono.png"
DARK_ICON_FILENAME = "dark-icon.png"
APP_ID = "io.github.marcotuliomatos.ksteamtrayicon"

DARK_ICON_DIR = Path(__file__).resolve().parent
OBJECT_PATH = f"/{APP_ID.replace(".", "/")}"
CONTROL_INTERFACE = f"{APP_ID}.Control"


class ControlInterface(ServiceInterface):
    def __init__(self, shutdown_event: asyncio.Event):
        super().__init__(CONTROL_INTERFACE)
        self._shutdown_event = shutdown_event

    @method()
    def Quit(self) -> "b":
        print("Shutdown request received over D-Bus")
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


def update_icon(scheme):
    source = DARK_ICON_DIR / DARK_ICON_FILENAME
    destination = PLASMA_ICON_DIR / DEFAULT_ICON_FILENAME

    if destination.is_dir():
        raise RuntimeError(f'Unable to fix the steam tray icon: "{destination}" already exists and is a directory')
    elif destination.is_symlink() or destination.is_file():
        try:
            destination.unlink()
        except PermissionError:
            raise RuntimeError(f'Failed to remove "{destination}": Permission denied.')
        except IsADirectoryError:
            raise RuntimeError(f'Failed to remove "{destination}": this path is a directory, not a file or symlink')
        except Exception as e:
            raise RuntimeError(f'Failed to remove "{destination}" due to an unexpected error: {e}')

    if scheme != "dark":
        shutil.copy(source, destination)

    print(f"Icon set to match {scheme} color scheme")


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
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout

    while loop.time() < deadline:
        owner = await get_name_owner(bus, name)
        if owner is None:
            return True
        await asyncio.sleep(0.1)

    return False


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

    print("Another instance of ksteamtrayicon is already running. Waiting for it to shutdown...")
    await request_existing_instance_to_quit(bus)

    freed = await wait_until_name_is_free(bus, APP_ID, timeout=5.0)
    if not freed:
        raise RuntimeError("Existing instance did not exit in time. Unable to continue.")

    reply = await bus.request_name(APP_ID, NameFlag.DO_NOT_QUEUE)
    if reply != RequestNameReply.PRIMARY_OWNER:
        raise RuntimeError("Failed to acquire D-Bus name. Unable to continue.")

    print("The other instance has completed its shutdown. Continuing...")


async def main():
    PLASMA_ICON_DIR.mkdir(parents=True, exist_ok=True)

    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    shutdown_event = asyncio.Event()
    control_interface = ControlInterface(shutdown_event)
    bus.export(OBJECT_PATH, control_interface)

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

    await shutdown_event.wait()
    print("Exiting due to a request from another instance of ksteamtrayicon.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nProgram terminated by user request")
    except Exception as e:
        print(f"Fatal error: {e}")
