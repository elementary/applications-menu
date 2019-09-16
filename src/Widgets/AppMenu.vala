/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Slingshot.AppMenu : Gtk.Menu {
    public signal void app_launched ();

    public string desktop_id { get; construct; }
    public string desktop_path { get; construct; }

    private bool has_system_item = false;
    private string appstream_comp_id = "";

#if HAS_PLANK
    private static Plank.DBusClient plank_client;
    private bool docked = false;
    private string desktop_uri {
        owned get {
            return File.new_for_path (desktop_path).get_uri ();
        }
    }
#endif

    public AppMenu (string desktop_id, string desktop_path) {
        Object (
            desktop_id: desktop_id,
            desktop_path: desktop_path
        );
    }

#if HAS_PLANK
    static construct {
        Plank.Paths.initialize ("plank", Build.PKGDATADIR);
        plank_client = Plank.DBusClient.get_instance ();
    }
#endif

    construct {
        var app_info = new DesktopAppInfo (desktop_id);
        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var menuitem = new Gtk.MenuItem.with_mnemonic (app_info.get_action_name (action));
            add (menuitem);

            menuitem.activate.connect (() => {
                app_info.launch_action (action, new AppLaunchContext ());
                app_launched ();
            });
        }

#if HAS_PLANK
        if (plank_client != null && plank_client.is_connected) {
            if (get_children ().length () > 0) {
                add (new Gtk.SeparatorMenuItem ());
            }

            has_system_item = true;

            docked = (desktop_uri in plank_client.get_persistent_applications ());

            var plank_menuitem = new Gtk.MenuItem ();
            plank_menuitem.set_use_underline (true);

            if (docked) {
                plank_menuitem.set_label (_("Remove from _Dock"));
            } else {
                plank_menuitem.set_label (_("Add to _Dock"));
            }

            plank_menuitem.activate.connect (plank_menuitem_activate);


            add (plank_menuitem );
        }
#endif

        var appcenter = Backend.AppCenter.get_default ();
        appcenter.notify["dbus"].connect (() => on_appcenter_dbus_changed.begin (appcenter));
        on_appcenter_dbus_changed.begin (appcenter);

        show_all ();
    }

    private void uninstall_menuitem_activate () {
        var appcenter = Backend.AppCenter.get_default ();
        if (appcenter.dbus == null || appstream_comp_id == "") {
            return;
        }

        appcenter.dbus.uninstall.begin (appstream_comp_id, (obj, res) => {
            try {
                appcenter.dbus.uninstall.end (res);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        });
    }

    private async void on_appcenter_dbus_changed (Backend.AppCenter appcenter) {
        if (appcenter.dbus != null) {
            try {
                appstream_comp_id = yield appcenter.dbus.get_component_from_desktop_id (desktop_id);
                if (appstream_comp_id != "") {
                    if (!has_system_item && get_children ().length () > 0) {
                        add (new Gtk.SeparatorMenuItem ());
                    }

                    var uninstall_menuitem = new Gtk.MenuItem.with_label (_("Uninstall"));
                    uninstall_menuitem.activate.connect (uninstall_menuitem_activate);

                    add (uninstall_menuitem);
                    show_all ();
                }
            } catch (GLib.Error e) {
                warning (e.message);
            }
        } else {
            appstream_comp_id = "";
        }
    }

#if HAS_PLANK
    private void plank_menuitem_activate () {
        if (plank_client == null || !plank_client.is_connected)
            return;

        if (docked)
            plank_client.remove_item (desktop_uri);
        else
            plank_client.add_item (desktop_uri);
    }
#endif
}
