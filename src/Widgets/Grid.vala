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

    struct Page {
        public uint rows;
        public uint columns;
        public uint number;
    }

    public class Grid : Table {

        public signal void new_page (string page_num);

        private uint current_row = 0;
        private uint current_col = 0;
        private Page page;

        public Grid (int rows, int columns) {
            
            // Grid properties
            this.homogeneous = true;

            row_spacing = 20;
            column_spacing = 0;

            page.rows = rows;
            page.columns = columns;
            page.number = 1;

        }

        public async void append (Widget widget) {

            update_position ();

            var col = current_col + page.columns * (page.number - 1);

            this.attach (widget, col, col + 1,
                         current_row, current_row + 1, AttachOptions.EXPAND, AttachOptions.EXPAND,
                         0, 0);
            current_col++;

        }

        private void update_position () {

            if (current_col == page.columns) {
                current_col = 0;
                current_row++;
            }

            if (current_row == page.rows) {
                page.number++;
                new_page (page.number.to_string ());
                current_row = 0;
            }

        }

        public void clear () {

            foreach (Widget widget in get_children ()) {
                if (widget.get_parent () != null)                
                    remove (widget);
                widget.destroy ();
            }

            current_row = 0;
            current_col = 0;
            page.number = 1;
            n_rows = page.rows;
            n_columns = page.columns;

        }

        public int get_page_columns () {

            return (int) page.columns;

        }

        public int get_page_rows () {

            return (int) page.rows;

        }

        public int get_n_pages () {

            return (int) page.number;

        }

        public void fade_all_out () {

            foreach (Widget widget in get_children ()) {
            }

        }

        public void fade_all_in () {

            foreach (Widget widget in get_children ()) {
            }

        }

    }

}
