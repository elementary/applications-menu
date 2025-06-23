/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 */

public class Slingshot.AppListRow : Gtk.ListBoxRow {
    public Backend.App app { get; construct; }
    public string app_id { get; construct; }
    public string desktop_path { get; construct; }
    public GLib.DesktopAppInfo app_info { get; private set; }

    public AppListRow (Backend.App app) {
        Object (
            app: app,
            app_id: app.desktop_id,
            desktop_path: app.desktop_path
        );
    }

    construct {
        app_info = new GLib.DesktopAppInfo (app_id);

        var icon = app_info.get_icon ();
        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (icon == null || theme.lookup_by_gicon (icon, 32, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        var image = new Gtk.Image () {
            gicon = icon,
            pixel_size = 32
        };

        var name_label = new Gtk.Label (app_info.get_display_name ()) {
            ellipsize = END,
            xalign = 0
        };

        tooltip_text = app_info.get_description ();

        var box = new Gtk.Box (HORIZONTAL, 12) {
            margin_top = 6,
            margin_start = 18,
            margin_end = 6,
            margin_bottom = 6
        };
        box.add (image);
        box.add (name_label);

        child = box;
    }

    public void launch () {
        try {
            app_info.launch (null, null);
        } catch (Error error) {
            critical (error.message);
        }
    }
}
