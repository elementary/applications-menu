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

    public class SearchItem : Button {

        private Pixbuf icon;
        private Label app_label;

        public bool in_box = false;
        public int icon_size = 64;
        public signal void launch_app ();

        public SearchItem (Backend.App app) {
            
            app_paintable = true;
			set_visual (get_screen ().get_rgba_visual());

            set_size_request (130*5, 58);

            get_style_context ().add_provider (Slingshot.style_provider, 600);
            get_style_context ().add_class ("app");            

            icon = app.icon;

            app_label = new Label (@"<b><span size=\"larger\">$(app.name)</span></b>\n" +
                                    @"$(Utils.truncate_text (app.description, 200))");
            app_label.use_markup = true;
            app_label.xalign = 0.0f;

            app_label.get_style_context ().add_provider (Slingshot.style_provider, 600);
            app_label.get_style_context ().add_class ("app-name");

            var vbox = new VBox (false, 3);
            vbox.pack_start (app_label, false, true, 0);

            add (Utils.set_padding (vbox, 5, 0, 0, 78));

            this.launch_app.connect (app.launch);

        }

        protected override bool draw (Cairo.Context cr) {

            Allocation size;
            get_allocation (out size);

            base.draw (cr);

            var scaled_icon = icon.scale_simple (icon_size, icon_size, Gdk.InterpType.BILINEAR);
            height_request = icon_size + 10;

            // Draw icon
            cairo_set_source_pixbuf (cr, scaled_icon, 10.0, 5);
            cr.paint ();

            return true;

        }

    }

}
