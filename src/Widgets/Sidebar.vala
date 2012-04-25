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

        private TreeStore store;
            
        private TreeIter bookmarks_iter;
        private TreeIter category_iter;
        private TreeIter entry_iter;

        private int cat_size {
            get {
                return store.iter_n_children (category_iter);
            }
        }
        private int book_size {
            get {
                return store.iter_n_children (bookmarks_iter);
            }
        }
        
        private int _selected;
        public int selected {
            get {
                return _selected;
            }
            set {
                if (0 <= value < (cat_size + book_size)) {
                    select_nth (value);
                    _selected = value;
                }
            }
        }

        private enum Columns {
            INT,
            TEXT,
            N_COLUMNS
        }

        public signal void selection_changed (string entry_name, int nth);

        public Sidebar () {

            store = new TreeStore (Columns.N_COLUMNS, typeof (int), typeof (string));
            set_model (store);

            set_headers_visible (false);
            set_show_expanders (false);
            set_level_indentation (8);

            set_size_request (145, -1);
            get_style_context ().add_class ("sidebar");

            var cell = new CellRendererText ();
            cell.wrap_mode = Pango.WrapMode.WORD;
            cell.wrap_width = 110;
            cell.xpad = 17;

            insert_column_with_attributes (-1, "Filters", cell, "markup", Columns.TEXT);

            store.append (out bookmarks_iter, null);
            store.set (bookmarks_iter, Columns.TEXT, _("<b>Bookmarks</b>"));

            store.append (out category_iter, null);
            store.set (category_iter, Columns.TEXT, _("<b>Categories</b>"));

            get_selection ().set_mode (SelectionMode.SINGLE);
            get_selection ().changed.connect (selection_change);

        }

        public void add_category (string entry_name) {

            store.append (out entry_iter, category_iter);
            store.set (entry_iter, Columns.INT, book_size + cat_size - 1, Columns.TEXT, entry_name, -1);
            
            expand_all ();

        }

        public void add_bookmark (string entry_name) {

            store.append (out entry_iter, bookmarks_iter);
            store.set (entry_iter, Columns.INT, book_size - 1, Columns.TEXT, entry_name, -1);
            
            expand_all ();

        }

        public void selection_change () {

            TreeModel model;
            TreeIter sel_iter;
            string name;
            int nth;

            if (get_selection ().get_selected (out model, out sel_iter)) {
                store.get (sel_iter, Columns.INT, out nth, Columns.TEXT, out name);
                /** 
                 * Check if sel_iter is category or bookmark entry.
                 * If it is, select the previous selected entry.
                 */
                if (sel_iter == category_iter || sel_iter == bookmarks_iter) {
                    selected = _selected;
                } else {
                    _selected = nth;
                    selection_changed (name, nth);
                }
            }

        }

        public bool select_nth (int nth) {

            TreeIter iter;

            /**
             * If the nth value to select is inside the fist iter,
             * then check if it is minor than bookmark iter size
             * If greater, it must be inside the category iter or
             * outside any iter.
             */
            if (nth < book_size)
                store.iter_nth_child (out iter, bookmarks_iter, nth);
            else if (nth < (cat_size + book_size))
                store.iter_nth_child (out iter, category_iter, nth - book_size);
            else
                return false;

            get_selection ().select_iter (iter);
            return true;

        }

        protected override bool scroll_event (Gdk.EventScroll event) {

            switch (event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_LEFT":
                    selected--;
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    selected++;
                    break;

            }

            return false;

        }

    }

}
