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
using Gdk;

namespace Slingshot.Widgets {

    public class ComboBox : Button {

        private Menu menu;

        public signal void item_clicked (string name);

        public ComboBox () {

            menu = new Menu ();

            this.button_release_event.connect (() => {
                menu.popup (null, null, null, 1, 0);
                return false;
            });

        }

        public Menu get_menu () {

            return menu;

        }

        public void append (string name) {

            var item = new MenuItem.with_label (name);
            menu.append (item);

            item.activate.connect (() => {
                this.label = name;
                item_clicked (name);
            });

        }

    }

}
