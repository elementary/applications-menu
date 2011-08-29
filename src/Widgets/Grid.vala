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

    public class Grid : Table {

        public signal void new_page (string page_num);

        private int current_row = 0;
        private int current_col = 0;
        private List<Widget> children;

        public Grid (int rows, int columns) {
            
            // Grid properties
            this.n_columns = columns;
            this.n_rows = rows;
            this.homogeneous = true;

            children = new List<Widget> ();

        }

        public void append (Widget widget) {

            if (current_row == n_rows) {
                current_row = 0;
                current_col++;
                if (current_col % 5 == 0)
                    new_page ((current_col / 5 + 1).to_string ());
            }

            this.attach (widget, current_col, current_col + 1,
                         current_row, current_row + 1, AttachOptions.EXPAND, AttachOptions.EXPAND,
                         0, 0);
            children.append (widget);
            current_row++;

        }

        public void clear () {

            foreach (Widget widget in children) {
                remove (widget);
                children.remove (widget);
            }

            current_row = 0;
            current_col = 0;

        }

    }

}
