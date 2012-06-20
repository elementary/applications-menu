// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011-2012 Giulio Collura
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
        private string icon_name;
        private Label name_label;
        private Label desc_label;

        public bool in_box = false;
        public int icon_size = 64;
        public signal void launch_app ();

        public SearchItem (Backend.App app) {
            
            get_style_context ().add_class ("app");            

            icon = app.icon;
            icon_name = app.icon_name;

            name_label = new Label ("<b><span size=\"larger\">" + fix (app.name) + "</span></b>");
            name_label.set_ellipsize (Pango.EllipsizeMode.END);
            name_label.use_markup = true;
            name_label.xalign = 0.0f;
            
            desc_label = new Label (fix (app.description));
            desc_label.set_ellipsize (Pango.EllipsizeMode.END);
            desc_label.xalign = 0.0f;

            var vbox = new VBox (false, 0);
            vbox.pack_start (name_label, false, true, 0);
            vbox.pack_start (desc_label, false, true, 0);

            add (Utils.set_padding (vbox, 5, 0, 0, 78));

            this.launch_app.connect (app.launch);

        }

        protected override bool draw (Cairo.Context cr) {

            Allocation size;
            get_allocation (out size);

            base.draw (cr);

            Pixbuf scaled_icon = null;
            try {
                scaled_icon = Slingshot.icon_theme.load_icon (icon_name, icon_size,
                                                        Gtk.IconLookupFlags.FORCE_SIZE);
            } catch (Error e) {
                try {
                    scaled_icon = new Gdk.Pixbuf.from_file_at_scale (icon_name, icon_size, icon_size, false);
                } catch (Error e) {
	            	try {
                        scaled_icon = Slingshot.icon_theme.load_icon ("application-default-icon", icon_size,
                                                               Gtk.IconLookupFlags.FORCE_SIZE);
	        	    } catch (Error e) {
                        scaled_icon = Slingshot.icon_theme.load_icon ("gtk-missing-image", icon_size,
                                                               Gtk.IconLookupFlags.FORCE_SIZE);
	            	}
                }
            }
            
            height_request = icon_size + 10;

            // Draw icon
            cairo_set_source_pixbuf (cr, scaled_icon, 74 - icon_size, 5);
            cr.paint ();

            return true;

        }
        
        private string fix (string text) {
            return text.replace ("&", "&amp;").replace ("<", "&lt;").replace (">", "&gt;");
        }
    }

}
