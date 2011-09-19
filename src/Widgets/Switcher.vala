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

    public class Switcher : HBox {

        public signal void active_changed (int active);

        public int active = -1;
        public int old_active = -1;

        public Switcher () {

            homogeneous = true;
            spacing = 2;

            app_paintable = true;
            set_visual (get_screen ().get_rgba_visual());

            can_focus = true;

        }

        public void append (string label) {

            var button = new ToggleButton.with_label (label);
            button.width_request = 30;
            button.can_focus = false;
            button.get_style_context ().add_class ("switcher");

            button.button_press_event.connect (() => {

                int select = get_children ().index (button);
                set_active (select);
                return true;

            });

            add (button);
            button.show_all ();

        }
        
        public void set_active (int new_active) {

            if (new_active >= get_children ().length () || active == new_active)
                return;

            if (active >= 0)
                ((ToggleButton) get_children ().nth_data (active)).set_active (false);

            old_active = active;
            active = new_active;
            active_changed (new_active);
            ((ToggleButton) get_children ().nth_data (active)).set_active (true);

        }

        public void clear_children () {

            foreach (weak Widget button in get_children ()) {
                button.hide ();
                if (button.get_parent () != null)
                    remove (button);
            }

            old_active = 0;
            active = -1;

        }
    }
}
