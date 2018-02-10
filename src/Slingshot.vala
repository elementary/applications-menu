// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Slingshot.Slingshot : Wingpanel.Indicator {
    private const string KEYBINDING_SCHEMA = "org.gnome.desktop.wm.keybindings";

    private SlingshotView? view = null;

    private Gtk.Grid? indicator_grid = null;

    public static Settings settings { get; private set; default = null; }
    public static Gtk.IconTheme icon_theme { get; set; default = null; }

    private DBusService? dbus_service = null;

    private static GLib.Settings? keybinding_settings;

    public Slingshot () {
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
        default_theme.add_resource_path ("/org/pantheon/slingshot/icons");
    }

    void on_close_indicator () {
        close ();
    }

    public override Gtk.Widget? get_widget () {
        if (view == null) {
            keybinding_settings.changed.connect ((key) => {
                if (key == "panel-main-menu") {
                    update_tooltip ();
                }
            });

            settings = new Settings ();

            view = new SlingshotView ();

#if HAS_PLANK_0_11
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
        if (keybinding_settings == null) {
            return;
        }

        string[] accels = keybinding_settings.get_strv ("panel-main-menu");
        if (accels.length > 0) {
            string shortcut = accel_to_string (accels[0]);
            indicator_grid.tooltip_text = (_("Open and search apps (%s)").printf (shortcut));
        }
    }

    private static string accel_to_string (string accel) {
        string[] keys = parse_accelerator (accel);
        return string.joinv (_(" + "), keys);
    }

    private static string[] parse_accelerator (string accel) {
        uint accel_key;
        Gdk.ModifierType accel_mods;
        Gtk.accelerator_parse (accel, out accel_key, out accel_mods);

        string[] arr = {};
        if (Gdk.ModifierType.SUPER_MASK in accel_mods) {
            arr += _("⌘");
        }

        if (Gdk.ModifierType.SHIFT_MASK in accel_mods) {
            arr += _("Shift");
        }

        if (Gdk.ModifierType.CONTROL_MASK in accel_mods) {
            arr += _("Ctrl");
        }

        if (Gdk.ModifierType.MOD1_MASK in accel_mods) {
            arr += _("Alt");
        }

        string? key = Gdk.keyval_name (accel_key);
        if (key != null) {
            arr += key;
        }

        return arr;
    }    
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating Slingshot");
    var indicator = new Slingshot.Slingshot ();
    return indicator;
}

