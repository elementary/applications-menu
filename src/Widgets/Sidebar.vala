// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Giulio Collura
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

using Gtk;

namespace Slingshot.Widgets {

    public class Sidebar : TreeView {

        TreeStore store;
            
        TreeIter bookmarks_iter;
        TreeIter category_iter;
        TreeIter entry_iter;

        public signal void selection_changed (string entry_name);

        public Sidebar () {

            store = new TreeStore (1, typeof (string));
            set_model (store);

            set_headers_visible (false);
            set_show_expanders(false);
            set_level_indentation (5);
            set_size_request (130, -1);
            get_style_context ().add_class ("sidebar");

            insert_column_with_attributes (-1, "Filters", new CellRendererText (), "markup", 0);

            store.append (out category_iter, null);
            store.set (category_iter, 0, _("<b>Categories</b>"));

            store.append (out bookmarks_iter, null);
            store.set (bookmarks_iter, 0, _("<b>Bookmarks</b>"));

            get_selection ().set_mode (SelectionMode.SINGLE);
            get_selection ().changed.connect (selection_change);

        }

        public void add_category (string entry_name) {

            store.append (out entry_iter, category_iter);
            store.set (entry_iter, 0, entry_name, -1);
            
            expand_all ();

        }

        public void add_bookmark (string entry_name) {

            store.append (out entry_iter, bookmarks_iter);
            store.set (entry_iter, 0, entry_name, -1);
            
            expand_all ();

        }

        public void selection_change () {

            TreeModel model;
            TreeIter sel_iter;
            string name;

            if (get_selection ().get_selected (out model, out sel_iter)) {
                store.get (sel_iter, 0, out name);
                selection_changed (name);
            }

        }

        public void select_first () {

            TreeIter iter;

            // Select first item by default
            store.iter_nth_child (out iter, category_iter, 0);
            get_selection ().select_iter (iter);

        }

    }

}
