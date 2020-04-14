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

public class Slingshot.Widgets.Sidebar : Gtk.ListBox {
    public signal void selection_changed (int nth);

    construct {
        selection_mode = Gtk.SelectionMode.SINGLE;
        width_request = 120;

        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
        style_context.add_class (Gtk.STYLE_CLASS_VIEW);

        row_selected.connect ((row) => {
            selection_changed (row.get_index ());
        });
    }

    public void add_category (string entry_name) {
        var label = new Gtk.Label (entry_name);
        label.halign = Gtk.Align.START;
        label.margin_start = 3;

        add (label);
    }

    public void clear () {
        foreach (unowned Gtk.Widget child in get_children ()) {
            child.destroy ();
        }
    }
}
