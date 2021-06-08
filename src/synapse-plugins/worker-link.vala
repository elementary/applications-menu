/*
* Copyright 2020 elementary, Inc.
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

public class Synapse.WorkerLink : GLib.Object {
    public string address { get; private set; }
    private GLib.DBusAuthObserver auth_observer;

    public signal void on_connection_accepted (GLib.DBusConnection connection);

    construct {
        if (GLib.UnixSocketAddress.abstract_names_supported ()) {
            address = "unix:abstract=/tmp/applications-menu-%u".printf ((uint)Posix.getpid ());
        } else {
            try {
                var tmpdir = GLib.DirUtils.make_tmp ("applications-menu-XXXXXX");
                address = "unix:tmpdir=%s".printf (tmpdir);
            } catch (Error e) {
                error ("Failed to determine temporary directory for D-Bus: %s", e.message);
            }
        }

        var guid = GLib.DBus.generate_guid ();
        auth_observer = new GLib.DBusAuthObserver ();
        auth_observer.allow_mechanism.connect ((mechanism) => {
            return mechanism == "EXTERNAL";
        });

        auth_observer.authorize_authenticated_peer.connect ((stream, credentials) => {
            if (credentials == null) {
                return false;
            }

            var own_credentials = new GLib.Credentials ();
            try {
                return credentials.is_same_user (own_credentials);
            } catch (GLib.Error e) {
                return false;
            }
        });

        try {
            var dbus_server = new GLib.DBusServer.sync (
                address,
                GLib.DBusServerFlags.NONE,
                guid,
                auth_observer,
                null
            );

            dbus_server.new_connection.connect ((connection) => {
                connection.exit_on_close = false;
                unowned GLib.Credentials? credentials = connection.get_peer_credentials ();
                if (credentials == null) {
                    return false;
                }

                try {
                    credentials.get_unix_user ();
                } catch (GLib.Error e) {
                    return false;
                }

                on_connection_accepted (connection);
                return true;
            });

            debug ("D-Bus Server listening at %s", address);
            dbus_server.start ();
        } catch (Error e) {
            error ("Failed to create D-Bus server: %s", e.message);
        }
    }
}
