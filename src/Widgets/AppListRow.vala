/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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
 * Boston, MA 02110-1301 USA.
 */

public class Slingshot.AppListRow : Gtk.ListBoxRow {
    public Backend.App app {get; construct; }
    public string app_id { get { return app.desktop_id; }}
    public int popularity { get { return app.popularity; }}
    public string desktop_path { get { return app.desktop_path; }}
    public string display_name { get; private set; }
    public Icon icon { get { return app_info.get_icon (); }}
    private GLib.DesktopAppInfo app_info;

    public AppListRow (Backend.App app) {
        Object (
            app: app
        );
    }

    construct {
        app_info = new GLib.DesktopAppInfo (app_id);
        var icon = app_info.get_icon ();
        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (icon == null || theme.lookup_by_gicon (icon, 32, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        var image = new Gtk.Image ();
        image.gicon = icon;
        image.pixel_size = 32;

        display_name = app_info.get_display_name ();
        var name_label = new Gtk.Label (display_name);
        name_label.set_ellipsize (Pango.EllipsizeMode.END);
        name_label.xalign = 0;

        tooltip_text = app_info.get_description ();

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (image);
        grid.add (name_label);
        grid.margin = 6;
        grid.margin_start = 18;

        add (grid);
    }

    public void launch () {
        try {
            app_info.launch (null, null);
        } catch (Error error) {
            critical (error.message);
        }
    }
}
