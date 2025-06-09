/*
 * Copyright 2019-2025 elementary, Inc. (https://elementary.io)
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

public class Slingshot.AppContextMenu : Gtk.PopoverMenu {
    public signal void app_launched ();

    private const string ACTION_GROUP_PREFIX = "app-actions";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string APP_ACTION = "action.%s";
    private const string PINNED_ACTION = "pinned";
    private const string SWITCHEROO_ACTION = "switcheroo";
    private const string UNINSTALL_ACTION = "uninstall";
    private const string VIEW_ACTION = "view-in-appcenter";

    public string desktop_id { get; construct; }
    public string desktop_path { get; construct; }
    private DesktopAppInfo app_info;

    private bool has_system_item = false;
    private string appstream_comp_id = "";

    private Slingshot.Backend.SwitcherooControl switcheroo_control;
    private GLib.SimpleAction pinned_action;
    private GLib.SimpleAction uninstall_action;
    private GLib.SimpleAction view_action;

    public AppContextMenu (string desktop_id, string desktop_path) {
        Object (
            desktop_id: desktop_id,
            desktop_path: desktop_path
        );
    }

    construct {
        var action_group = new SimpleActionGroup ();

        var actions_section = new GLib.Menu ();
        var shell_section = new GLib.Menu ();

        menu_model = new GLib.Menu ();
        ((GLib.Menu) menu_model).append_section (null, actions_section);
        ((GLib.Menu) menu_model).append_section (null, shell_section);

        app_info = new DesktopAppInfo (desktop_id);
        foreach (unowned var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (APP_ACTION.printf (action), null);
            simple_action.activate.connect (() => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                app_info.launch_action (action, context);
                app_launched ();
            });
            action_group.add_action (simple_action);

            actions_section.append (
                app_info.get_action_name (action),
                ACTION_PREFIX + APP_ACTION.printf (action)
            );
        }

        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            var switcheroo_action = new SimpleAction (SWITCHEROO_ACTION, null);
            switcheroo_action.activate.connect (() => {
                try {
                    var context = Gdk.Display.get_default ().get_app_launch_context ();
                    context.set_timestamp (Gdk.CURRENT_TIME);

                    switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);

                    app_info.launch (null, context);
                    app_launched ();
                } catch (Error e) {
                    warning ("Failed to launch %s: %s", name, e.message);
                }
            });
            action_group.add_action (switcheroo_action);

            actions_section.append (
                _("Open with %s Graphics").printf (switcheroo_control.get_gpu_name (prefers_non_default_gpu)),
                ACTION_PREFIX + SWITCHEROO_ACTION
            );
        }

        if (Environment.find_program_in_path ("io.elementary.dock") != null) {
            has_system_item = true;

            var dock = Backend.Dock.get_default ();
            var pinned_variant = new Variant.boolean (false);
            try {
                pinned_variant = new Variant.boolean (desktop_id in dock.dbus.list_launchers ());
            } catch (GLib.Error e) {
                critical (e.message);
            }

            pinned_action = new SimpleAction.stateful (PINNED_ACTION, null, pinned_variant);
            pinned_action.change_state.connect (pinned_action_change_state);

            action_group.add_action (pinned_action);

            shell_section.append (
                _("Keep in _Dock"),
                ACTION_PREFIX + PINNED_ACTION
            );

            dock.notify["dbus"].connect (() => on_dock_dbus_changed (dock));
            on_dock_dbus_changed (dock);
        }

        if (Environment.find_program_in_path ("io.elementary.appcenter") != null) {
            uninstall_action = new SimpleAction (UNINSTALL_ACTION, null);
            uninstall_action.activate.connect (action_uninstall);

            view_action = new SimpleAction (VIEW_ACTION, null);
            view_action.activate.connect (open_in_appcenter);

            action_group.add_action (uninstall_action);
            action_group.add_action (view_action);

            shell_section.append (
                _("Uninstall"),
                ACTION_PREFIX + UNINSTALL_ACTION
            );

            shell_section.append (
                _("View in AppCenter"),
                ACTION_PREFIX + VIEW_ACTION
            );

            var appcenter = Backend.AppCenter.get_default ();
            appcenter.notify["dbus"].connect (() => on_appcenter_dbus_changed.begin (appcenter));
            on_appcenter_dbus_changed.begin (appcenter);
        }
    }

    private void action_uninstall () {
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

        uninstall_action.set_enabled (appstream_comp_id != "");
        view_action.set_enabled (appstream_comp_id != "");
    }

    private void on_dock_dbus_changed (Backend.Dock dock) {
        pinned_action.set_enabled (dock.dbus != null);

        if (dock.dbus == null) {
            return;
        }

        try {
            pinned_action.change_state (new Variant.boolean (desktop_id in dock.dbus.list_launchers ()));
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }

    private void pinned_action_change_state (Variant? value) {
        pinned_action.set_state (value);

        try {
            var dock = Backend.Dock.get_default ();
            if (value.get_boolean ()) {
                dock.dbus.add_launcher (desktop_id);
            } else {
                dock.dbus.remove_launcher (desktop_id);
            }
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }
}
