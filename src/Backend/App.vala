/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2013-2014 Akshay Shekher
 *           2011-2012 Giulio Collura
 *           2020-2021 Justin Haygood
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

public class Slingshot.Backend.App : Object {
    public signal void launched (App app);
    public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);

    public enum AppType {
        APP,
        COMMAND,
        SYNAPSE
    }

    public const string ACTION_GROUP_PREFIX = "app-actions";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string APP_ACTION = "action.%s";
    private const string PINNED_ACTION = "pinned";
    private const string SWITCHEROO_ACTION = "switcheroo";
    private const string UNINSTALL_ACTION = "uninstall";
    private const string VIEW_ACTION = "view-in-appcenter";

    public SimpleActionGroup action_group { get; private set; }
    public string name { get; construct set; }
    public string description { get; private set; default = ""; }
    public string desktop_id { get; construct set; }
    public string exec { get; private set; }
    public string[] keywords { get; private set;}
    public Icon icon { get; private set; default = new ThemedIcon ("application-default-icon"); }
    public double popularity { get; set; }
    public string desktop_path { get; private set; }
    public string categories { get; private set; }
    public string generic_name { get; private set; default = ""; }
    public bool prefers_default_gpu { get; private set; default = false; }
    public AppType app_type { get; private set; default = AppType.APP; }

    private string? unity_sender_name = null;
    public bool count_visible { get; private set; default = false; }
    public int64 current_count { get; private set; default = 0; }

    public Synapse.Match? match { get; private set; default = null; }
    public Synapse.Match? target { get; private set; default = null; }

    private Slingshot.Backend.SwitcherooControl switcheroo_control;
    private GLib.Menu? menu_model = null;
    private GLib.SimpleAction? pinned_action = null;
    private GLib.SimpleAction uninstall_action;
    private GLib.SimpleAction view_action;

    private bool has_system_item = false;
    private string appstream_comp_id = "";

    construct {
        switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
    }

    public App (GLib.DesktopAppInfo info) {

        app_type = AppType.APP;

        name = info.get_display_name ();
        description = info.get_description () ?? name;
        exec = info.get_commandline ();
        desktop_id = info.get_id ();
        desktop_path = info.get_filename ();
        keywords = info.get_keywords ();
        categories = info.get_categories ();
        generic_name = info.get_generic_name ();
        prefers_default_gpu = !info.get_boolean ("PrefersNonDefaultGPU");

        var desktop_icon = info.get_icon ();
        if (desktop_icon != null) {
            icon = desktop_icon;
        }
    }

    public App.from_command (string command) {
        app_type = AppType.COMMAND;

        name = command;
        description = _("Run this command…");
        exec = command;
        desktop_id = command;
        icon = new ThemedIcon ("system-run");
    }

    public App.from_synapse_match (Synapse.Match match, Synapse.Match? target = null) {
        app_type = AppType.SYNAPSE;

        name = match.title;
        description = match.description;

        if (match.match_type == Synapse.MatchType.CONTACT && match.has_thumbnail) {
            var file = File.new_for_path (match.thumbnail_path);
            icon = new FileIcon (file);
        } else if (match.icon_name != null) {
            icon = new ThemedIcon (match.icon_name);
        }

        if (match is Synapse.ApplicationMatch) {

            var app_match = (Synapse.ApplicationMatch) match;

            var app_info = app_match.app_info;

            this.desktop_id = app_info.get_id ();

            if (app_info is DesktopAppInfo) {
                var desktop_app_info = (DesktopAppInfo) app_info;
                this.desktop_path = desktop_app_info.get_filename ();
                this.prefers_default_gpu = !desktop_app_info.get_boolean ("PrefersNonDefaultGPU");
            }
        }

        this.match = match;
        this.target = target;
    }

    public bool launch () {
        try {
            switch (app_type) {
                case AppType.COMMAND:
                    debug (@"Launching command: $name");
                    Process.spawn_command_line_async (exec);
                    break;
                case AppType.APP:
                    launched (this); // Emit launched signal

                    var context = Gdk.Display.get_default ().get_app_launch_context ();
                    context.set_timestamp (Gtk.get_current_event_time ());
                    switcheroo_control.apply_gpu_environment (context, prefers_default_gpu);

                    new DesktopAppInfo (desktop_id).launch (null, context);

                    debug (@"Launching application: $name");
                    break;
                case AppType.SYNAPSE:
                    if (match.match_type == Synapse.MatchType.SEARCH) {
                        start_search (match as Synapse.SearchMatch, target);
                        return false;
                    } else {
                        if (target == null)
                            Backend.SynapseSearch.find_actions_for_match (match).get (0).execute_with_target (match);
                        else
                            match.execute_with_target (target);
                    }
                    break;
            }
        } catch (Error e) {
            warning ("Failed to launch %s: %s", name, exec);
        }

        return true;
    }

    public void perform_unity_update (string sender_name, VariantIter prop_iter) {
        unity_sender_name = sender_name;

        string prop_key;
        Variant prop_value;
        while (prop_iter.next ("{sv}", out prop_key, out prop_value)) {
            if (prop_key == "count") {
                current_count = prop_value.get_int64 ();
            } else if (prop_key == "count-visible") {
                count_visible = prop_value.get_boolean ();
            }
        }
    }

    public void remove_launcher_entry (string sender_name) {
        if (unity_sender_name == sender_name) {
            unity_sender_name = null;
            count_visible = false;
            current_count = 0;
        }
    }

    public GLib.Menu get_menu_model () {
        if (menu_model != null) {
            return menu_model;
        }

        var actions_section = new GLib.Menu ();
        var shell_section = new GLib.Menu ();

        action_group = new SimpleActionGroup ();

        var app_info = new DesktopAppInfo (desktop_id);
        foreach (unowned var action in app_info.list_actions ()) {
            var simple_action = new SimpleAction (APP_ACTION.printf (action), null);
            simple_action.activate.connect (() => {
                var context = Gdk.Display.get_default ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);

                app_info.launch_action (action, context);
                launched (this);
            });
            action_group.add_action (simple_action);

            actions_section.append (
                app_info.get_action_name (action),
                ACTION_PREFIX + APP_ACTION.printf (action)
            );
        }

        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");

            var switcheroo_action = new SimpleAction (SWITCHEROO_ACTION, null);
            switcheroo_action.activate.connect (() => {
                try {
                    var context = Gdk.Display.get_default ().get_app_launch_context ();
                    context.set_timestamp (Gdk.CURRENT_TIME);

                    switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);

                    app_info.launch (null, context);
                    launched (this);
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

            shell_section.append (
                _("Keep in _Dock"),
                ACTION_PREFIX + PINNED_ACTION
            );

            var dock = Backend.Dock.get_default ();
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

        menu_model = new GLib.Menu ();
        menu_model.append_section (null, actions_section);
        menu_model.append_section (null, shell_section);

        return menu_model;
    }

    private void action_uninstall () {
        var appcenter = Backend.AppCenter.get_default ();
        if (appcenter.dbus == null || appstream_comp_id == "") {
            return;
        }

        launched (this);

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
                var app_info = new DesktopAppInfo (desktop_id);
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Unable to open %s in AppCenter".printf (app_info.get_display_name ()),
                    "",
                    "dialog-error",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (error.message);
                message_dialog.response.connect (message_dialog.destroy);
                message_dialog.present ();
            } finally {
                launched (this);
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
        if (pinned_action != null) {
            pinned_action.set_enabled (dock.dbus != null);
        }

        if (dock.dbus == null) {
            return;
        }

        if (pinned_action == null) {
            try {
                pinned_action = new SimpleAction.stateful (
                    PINNED_ACTION,
                    null,
                    new Variant.boolean (desktop_id in dock.dbus.list_launchers ())
                );
                pinned_action.change_state.connect (pinned_action_change_state);

                action_group.add_action (pinned_action);
            } catch (Error e) {
                critical ("Unable to create pinned launcher action: %s", e.message);
            }
        } else {
            try {
                pinned_action.change_state (new Variant.boolean (desktop_id in dock.dbus.list_launchers ()));
            } catch (GLib.Error e) {
                critical ("Unable to update pinned launcher action state: %s", e.message);
            }
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
            critical ("Unable to change pinned launcher: %s", e.message);
        }
    }
}
