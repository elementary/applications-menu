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

public class AppListRow : Gtk.ListBoxRow {
    public string app_id { get; construct; }

    private GLib.DesktopAppInfo app_info;

    public AppListRow (string app_id) {
        Object (app_id: app_id);
    }

    construct {
        app_info = new GLib.DesktopAppInfo (app_id);

        var icon = new Gtk.Image ();
        icon.gicon = app_info.get_icon ();
        icon.pixel_size = 32;

        var name_label = new Gtk.Label (app_info.get_display_name ());
        name_label.set_ellipsize (Pango.EllipsizeMode.END);
        name_label.use_markup = true;
        name_label.xalign = 0;

        tooltip_text = app_info.get_description ();

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (icon);
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
