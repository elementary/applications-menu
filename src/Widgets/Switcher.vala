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
using Cairo;

namespace Slingshot.Widgets {

    public class Switcher : HBox {

        public signal void active_changed (int active);

        public new List<Button> children;
        public int active = -1;
        public int old_active = -1;

        private CssProvider style_provider;

        public Switcher () {

            homogeneous = false;
            spacing = 2;
            
            app_paintable = true;
			set_visual (get_screen ().get_rgba_visual());

            style_provider = new CssProvider ();

            try {
                style_provider.load_from_path (Build.PKGDATADIR + "/style/default.css");
            } catch (Error e) {
                warning ("Could not add css provider. Some widgets won't look as intended. %s", e.message);
            }

            can_focus = true;

            get_style_context ().add_provider (style_provider, 600);
            get_style_context ().add_class ("switcher");

        }

        public void append (string label) {

            var button = new Button.with_label (label);
            button.get_style_context ().add_provider (style_provider, 600);
            button.name = "switcher-button";
            button.width_request = 10;

            children.append (button);

            button.clicked.connect (() => {

                int select = children.index (button);
                set_active (select);

            });

            add (button);

        }
        
        public void set_active (int new_active) {

            if (new_active >= children.length ())
                return;

            if (active >= 0)
                children.nth_data (active).set_state (StateType.NORMAL);

            old_active = active;
            active = new_active;
            active_changed (new_active);
            children.nth_data (active).set_state (StateType.SELECTED);

        }

        public void clear_children () {

            foreach (Button button in children) {
                remove (button);
                children.remove (button);
            }

            old_active = -1;
            active = -1;

        }
    }
}
