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

    public int selected {
        get {
            return get_selected_row ().get_index ();
        }
        set {
            select_row (get_row_at_y (value));
        }
    }

    construct {
        hexpand = true;
        selection_mode = Gtk.SelectionMode.SINGLE;
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);

        row_selected.connect ((row) => {
            selection_changed (row.get_index ());
        });

    }

    public void add_category (string entry_name) {
        var label = new Gtk.Label (entry_name);
        label.halign = Gtk.Align.START;

        add (label);
    }

    public void clear () {
        foreach (unowned Gtk.Widget child in get_children ()) {
            child.destroy ();
        }
    }

    public void select_end () {
        int count = 0;
        foreach (unowned Gtk.Widget child in get_children ()) {
            count++;
        }
        select_row (get_row_at_y (count));
    }

    protected override bool scroll_event (Gdk.EventScroll event) {
        switch (event.direction.to_string ()) {
            case "GDK_SCROLL_UP":
            case "GDK_SCROLL_LEFT":
                select_row (get_row_at_y (get_selected_row ().get_index () - 1));
                break;
            case "GDK_SCROLL_DOWN":
            case "GDK_SCROLL_RIGHT":
                select_row (get_row_at_y (get_selected_row ().get_index () + 1));
                break;

        }

        return false;
    }
}
