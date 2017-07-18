/*
* Copyright (c) 2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

[DBus (name = "io.elementary.appcenter")]
public interface AppCenterDBus : Object {
    public abstract void install (string component_id) throws IOError;
    public abstract void update (string component_id) throws IOError;
    public abstract void uninstall (string component_id) throws IOError;
    public abstract string get_component_from_desktop_id (string desktop_id) throws IOError;
    public abstract string[] search_components (string query) throws IOError;
}

public class Slingshot.Backend.AppCenter : Object {
    private const string DBUS_NAME = "io.elementary.appcenter";
    private const string DBUS_PATH = "/io/elementary/appcenter";

    private static AppCenter? instance;
    public static unowned AppCenter get_default () {
        if (instance == null) {
            instance = new AppCenter ();
        }

        return instance;
    }

    public AppCenterDBus? dbus { public get; private set; default = null; }

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.AUTO_START,
                        name_appeared_callback, name_vanished_callback);
    }

    private AppCenter () {

    }

    private void name_appeared_callback (DBusConnection connection, string name, string name_owner) {
        try {
            dbus = Bus.get_proxy_sync (BusType.SESSION, DBUS_NAME, DBUS_PATH);
        } catch (IOError e) {
            warning (e.message);
        }
    }

    private void name_vanished_callback (DBusConnection connection, string name) {
        dbus = null;
    }
}
