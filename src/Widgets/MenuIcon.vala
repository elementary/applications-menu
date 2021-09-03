/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
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
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Torikulhabib <torik.habib@gamail.com>
 *
 */

private class MenuIcon : Gtk.MenuItem {
    public string menu_image { get; set; }
    public string menu_label { get; set; }

    construct {
        var label = new Gtk.Label (null) {
            xalign = 0
        };

        var image_menu = new Gtk.Image ();

        var grid = new Gtk.Grid ();
        grid.add (image_menu);
        grid.add (label);
        add (grid);

        notify["menu-image"].connect (()=>{
            image_menu.set_from_gicon (new ThemedIcon (menu_image), Gtk.IconSize.BUTTON);
        });

        notify["menu-label"].connect (()=>{
            label.label = menu_label;
        });
    }
}
