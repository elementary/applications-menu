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
    private const string KEYBINDING_SCHEMA = "org.gnome.desktop.wm.keybindings";

    private DBusService? dbus_service = null;
    private Gtk.Grid? indicator_grid = null;
    private SlingshotView? view = null;

    private static GLib.Settings? keybinding_settings;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.APP_LAUNCHER,
        display_name: _("Slingshot"),
        description:_("The app-menu indicator"));
    }

    static construct {
        if (SettingsSchemaSource.get_default ().lookup (KEYBINDING_SCHEMA, true) != null) {
            keybinding_settings = new GLib.Settings (KEYBINDING_SCHEMA);
        }
    }

    construct {
        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/desktop/wingpanel/applications-menu/icons");
    }

    private void on_close_indicator () {
        close ();
    }

    public override Gtk.Widget? get_widget () {
        if (view == null) {
            view = new SlingshotView ();

#if HAS_PLANK
            unowned Plank.Unity client = Plank.Unity.get_default ();
            client.add_client (view);
#endif

            view.close_indicator.connect (on_close_indicator);

            if (dbus_service == null) {
                dbus_service = new DBusService (view);
            }
        }

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
        }

        visible = true;

        return indicator_grid;
    }

    public override void opened () {
        if (view != null)
            view.show_slingshot ();
    }

    public override void closed () {
        // TODO: Do we need to do anyhting here?
    }

    private void update_tooltip () {
        string[] accels = {};

        if (keybinding_settings != null && indicator_grid != null) {
            var raw_accels = keybinding_settings.get_strv ("panel-main-menu");
            foreach (string raw_accel in raw_accels) {
                if (raw_accel != "") accels += raw_accel;
            }
        }

        indicator_grid.tooltip_markup = Granite.markup_accel_tooltip (accels, _("Open and search apps"));
    }
}

public Wingpanel.Indicator get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Slingshot");
    if (server_type == Wingpanel.IndicatorManager.ServerType.GREETER){
        return null;
    }
    var indicator = new Slingshot.Indicator ();
    return indicator;
}
