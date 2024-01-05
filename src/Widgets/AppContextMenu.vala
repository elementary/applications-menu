/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2020-2021 Justin Haygood
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

public class Slingshot.AppContextMenu : Gtk.Menu {
    public signal void app_launched ();

    public string desktop_id { get; construct; }
    public string desktop_path { get; construct; }
    private DesktopAppInfo app_info;

    private bool has_system_item = false;
    private string appstream_comp_id = "";

    private Slingshot.Backend.SwitcherooControl switcheroo_control;
    private Gtk.MenuItem uninstall_menuitem;
    private Gtk.MenuItem appcenter_menuitem;
    private Gtk.MenuItem dock_menuitem;

    private bool docked = false;

    public AppContextMenu (string desktop_id, string desktop_path) {
        Object (
            desktop_id: desktop_id,
            desktop_path: desktop_path
        );
    }

    construct {
        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();

        app_info = new DesktopAppInfo (desktop_id);

        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var menuitem = new Gtk.MenuItem.with_mnemonic (app_info.get_action_name (action));
            add (menuitem);

            menuitem.activate.connect ((target) => {
                var context = target.get_display ().get_app_launch_context ();
                context.set_timestamp (Gtk.get_current_event_time ());
                app_info.launch_action (action, context);
                app_launched ();
            });
        }

        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            string gpu_name = switcheroo_control.get_gpu_name (prefers_non_default_gpu);

            string label = _("Open with %s Graphics").printf (gpu_name);

            var menu_item = new Gtk.MenuItem.with_mnemonic (label);
            add (menu_item);

            menu_item.activate.connect ((target) => {
               try {
                   var context = target.get_display ().get_app_launch_context ();
                   context.set_timestamp (Gtk.get_current_event_time ());
                   switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);
                   app_info.launch (null, context);
                   app_launched ();
               } catch (Error e) {
                   warning ("Failed to launch %s: %s", name, e.message);
               }

            });
        }

        if (Environment.find_program_in_path ("io.elementary.dock") != null) {
            if (get_children ().length () > 0) {
                add (new Gtk.SeparatorMenuItem ());
            }

            has_system_item = true;

            dock_menuitem = new Gtk.MenuItem () {
                label = _("Add to _Dock"),
                sensitive = false,
                use_underline = true
            };
            dock_menuitem.activate.connect (dock_menuitem_activate);

            add (dock_menuitem );

            var dock = Backend.Dock.get_default ();
            dock.notify["dbus"].connect (() => on_dock_dbus_changed.begin (dock));
            on_dock_dbus_changed.begin (dock);
        }

        if (Environment.find_program_in_path ("io.elementary.appcenter") != null) {
            if (!has_system_item && get_children ().length () > 0) {
                add (new Gtk.SeparatorMenuItem ());
            }

            uninstall_menuitem = new Gtk.MenuItem.with_label (_("Uninstall")) {
                sensitive = false
            };
            uninstall_menuitem.activate.connect (uninstall_menuitem_activate);

            appcenter_menuitem = new Gtk.MenuItem.with_label (_("View in AppCenter")) {
                sensitive = false
            };
            appcenter_menuitem.activate.connect (open_in_appcenter);

            add (uninstall_menuitem);
            add (appcenter_menuitem);

            var appcenter = Backend.AppCenter.get_default ();
            appcenter.notify["dbus"].connect (() => on_appcenter_dbus_changed.begin (appcenter));
            on_appcenter_dbus_changed.begin (appcenter);
        }

        show_all ();
    }

    private void uninstall_menuitem_activate () {
        var appcenter = Backend.AppCenter.get_default ();
        if (appcenter.dbus == null || appstream_comp_id == "") {
            return;
        }

        app_launched ();

        appcenter.dbus.uninstall.begin (appstream_comp_id, (obj, res) => {
            try {
                appcenter.dbus.uninstall.end (res);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        });
    }

    private void open_in_appcenter () {
        AppInfo.launch_default_for_uri_async.begin ("appstream://" + appstream_comp_id, null, null, (obj, res) => {
            try {
                AppInfo.launch_default_for_uri_async.end (res);
            } catch (Error error) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Unable to open %s in AppCenter".printf (app_info.get_display_name ()),
                    "",
                    "dialog-error",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (error.message);
                message_dialog.run ();
                message_dialog.destroy ();
            } finally {
                app_launched ();
            }
        });
    }

    private async void on_appcenter_dbus_changed (Backend.AppCenter appcenter) {
        if (appcenter.dbus != null) {
            try {
                appstream_comp_id = yield appcenter.dbus.get_component_from_desktop_id (desktop_id);
            } catch (GLib.Error e) {
                appstream_comp_id = "";
                warning (e.message);
            }
        } else {
            appstream_comp_id = "";
        }

        uninstall_menuitem.sensitive = appstream_comp_id != "";
        appcenter_menuitem.sensitive = appstream_comp_id != "";
    }

    private async void on_dock_dbus_changed (Backend.Dock dock) {
        if (dock.dbus != null) {
            dock_menuitem.sensitive = true;

            try {
                docked = desktop_id in dock.dbus.list_launchers ();
                if (docked) {
                    dock_menuitem.label = _("Remove from _Dock");
                } else {
                    dock_menuitem.label = _("Add to _Dock");
                }
            } catch (GLib.Error e) {
                critical (e.message);
            }
        }
    }

    private void dock_menuitem_activate () {
        var dock = Backend.Dock.get_default ();
        if (dock.dbus == null) {
            return;
        }

        try {
            if (docked) {
                dock.dbus.remove_launcher (desktop_id);
            } else {
                dock.dbus.add_launcher (desktop_id);
            }
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }
}
