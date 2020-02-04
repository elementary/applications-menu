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

public class Slingshot.Widgets.Sidebar : Gtk.TreeView {
    public signal void selection_changed (int nth);

    public int cat_size {
        get {
            return store.iter_n_children (null);
        }
    }

    private int _selected = 0;
    public int selected {
        get {
            return _selected;
        }
        set {
            if (value >= 0 && value < cat_size) {
                select_nth (value);
                _selected = value;
            }
        }
    }

    private Gtk.TreeStore store;
    private Gtk.TreeIter entry_iter;

    private enum Columns {
        INT,
        TEXT,
        N_COLUMNS
    }

    construct {
        store = new Gtk.TreeStore (Columns.N_COLUMNS, typeof (int), typeof (string));
        store.set_sort_column_id (1, Gtk.SortType.ASCENDING);
        set_model (store);

        enable_search = false;
        headers_visible = false;
        show_expanders = false;
        level_indentation = 8;

        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);

        var cell = new Gtk.CellRendererText ();
        cell.xpad = Pixels.PADDING;

        insert_column_with_attributes (-1, "Filters", cell, "markup", Columns.TEXT);

        unowned Gtk.TreeSelection selection = get_selection ();
        selection.set_mode (Gtk.SelectionMode.SINGLE);
        selection.changed.connect (selection_change);
    }

    public void add_category (string entry_name) {
        store.append (out entry_iter, null);
        store.set (entry_iter, Columns.INT, cat_size - 1, Columns.TEXT, Markup.escape_text (entry_name), -1);
        expand_all ();
    }

    public void clear () {
        store.clear ();
    }

    private void selection_change () {
        Gtk.TreeModel model;
        Gtk.TreeIter sel_iter;
        int nth;

        if (get_selection ().get_selected (out model, out sel_iter)) {
            store.get (sel_iter, Columns.INT, out nth);
            _selected = nth;
            selection_changed (nth);
        }

    }

    private bool select_nth (int nth) {
        Gtk.TreeIter iter;

        if (nth < cat_size) {
            store.iter_nth_child (out iter, null, nth);
        } else {
            return false;
        }

        get_selection ().select_iter (iter);

        return true;
    }
}
