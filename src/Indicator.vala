/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2011-2012 Giulio Collura
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

public class Slingshot.Indicator : Wingpanel.Indicator {
    private const string KEYBINDING_SCHEMA = "io.elementary.desktop.wm.keybindings";
    private const string GALA_BEHAVIOR_SCHEMA = "io.elementary.desktop.wm.behavior";
    private const string DOCK_SCHEMA = "io.elementary.dock";

    private DBusService? dbus_service = null;
    private Gtk.Grid? indicator_grid = null;
    private SlingshotView? view = null;

    private static GLib.Settings? keybinding_settings;
    private static GLib.Settings? gala_behavior_settings;
    private static GLib.Settings? dock_settings;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.APP_LAUNCHER);
    }

    static construct {
        if (SettingsSchemaSource.get_default ().lookup (KEYBINDING_SCHEMA, true) != null) {
            keybinding_settings = new GLib.Settings (KEYBINDING_SCHEMA);
        }

        if (SettingsSchemaSource.get_default ().lookup (GALA_BEHAVIOR_SCHEMA, true) != null) {
            gala_behavior_settings = new GLib.Settings (GALA_BEHAVIOR_SCHEMA);
        }

        if (SettingsSchemaSource.get_default ().lookup (DOCK_SCHEMA, true) != null) {
            dock_settings = new GLib.Settings (DOCK_SCHEMA);
        }
    }

    construct {
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/desktop/wingpanel/applications-menu/icons");
    }

    private void on_close_indicator () {
        close ();
    }

    public override Gtk.Widget? get_widget () {
        if (view == null) {
            view = new SlingshotView ();

            unowned var unity_client = Unity.get_default ();
            unity_client.add_client (view);

            view.close_indicator.connect (on_close_indicator);

            if (dbus_service == null) {
                dbus_service = new DBusService (view);
            }

            if (dock_settings != null) {
                dock_settings.changed.connect ((key) => {
                    if (key == "launchers") {
                        view.update (dock_settings.get_strv ("launchers"));
                    }
                });
            }
        }

        // Wait for AppSystem to initialize
        Idle.add (() => {
            view.update (dock_settings != null ? dock_settings.get_strv ("launchers") : null);
            return Source.REMOVE;
        });

        return view;
    }

    public override Gtk.Widget get_display_widget () {
        if (indicator_grid == null) {
            var indicator_label = new Gtk.Label (_("Applications"));
            indicator_label.vexpand = true;

            var indicator_icon = new Gtk.Image.from_icon_name ("system-search-symbolic", Gtk.IconSize.MENU);

            indicator_grid = new Gtk.Grid ();
            indicator_grid.attach (indicator_icon, 0, 0, 1, 1);
            indicator_grid.attach (indicator_label, 1, 0, 1, 1);
            update_tooltip ();

            if (keybinding_settings != null) {
                keybinding_settings.changed.connect ((key) => {
                    if (key == "panel-main-menu") {
                        update_tooltip ();
                    }
                });
            }

            if (gala_behavior_settings != null) {
                gala_behavior_settings.changed.connect ((key) => {
                    if (key == "overlay-action") {
                        update_tooltip ();
                    }
                });
            }
        }

        visible = true;

        return indicator_grid;
    }

    public override void opened () {
        if (view != null) {
            view.show_slingshot ();
        }
    }

    public override void closed () {
        // TODO: Do we need to do anything here?
    }

    private void update_tooltip () {
        string[] accels = {};

        if (keybinding_settings != null && indicator_grid != null) {
            var raw_accels = keybinding_settings.get_strv ("panel-main-menu");
            foreach (unowned string raw_accel in raw_accels) {
                if (raw_accel != "") accels += raw_accel;
            }
        }

        if (gala_behavior_settings != null) {
            if ("wingpanel" in gala_behavior_settings.get_string ("overlay-action")) {
                accels += "<Super>";
            }
        }

        indicator_grid.tooltip_markup = Granite.markup_accel_tooltip (accels, _("Open and search apps"));
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Slingshot");
    if (server_type == Wingpanel.IndicatorManager.ServerType.GREETER) {
        return null;
    }
    var indicator = new Slingshot.Indicator ();
    return indicator;
}
