/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.dock.items", timeout = 120000)]
public interface DockDBus : Object {
    public abstract void add_launcher (string app_id) throws DBusError, IOError;
    public abstract void remove_launcher (string app_id) throws DBusError, IOError;
    public abstract string[] list_launchers () throws DBusError, IOError;
}

public class Slingshot.Backend.Dock : Object {
    public DockDBus? dbus { get; private set; default = null; }

    private const string DBUS_NAME = "io.elementary.dock";
    private const string DBUS_PATH = "/io/elementary/dock";
    private const uint RECONNECT_TIMEOUT = 5000U;

    private static Once<Dock> instance;
    public static unowned Dock get_default () {
        return instance.once (() => {
            return new Dock ();
        });
    }

    private Dock () { }

    construct {
        Bus.watch_name (
            BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.AUTO_START,
            () => try_connect (), name_vanished_callback
        );
    }

    private void try_connect () {
        Bus.get_proxy.begin<DockDBus> (BusType.SESSION, DBUS_NAME, DBUS_PATH, 0, null, (obj, res) => {
            try {
                dbus = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning (e.message);
                Timeout.add (RECONNECT_TIMEOUT, () => {
                    try_connect ();
                    return false;
                });
            }
        });
    }

    private void name_vanished_callback (DBusConnection connection, string name) {
        dbus = null;
    }
}
