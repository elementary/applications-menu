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

    public class AppEntry : Button {

        public Label app_label;
        private Pixbuf icon;
        private VBox layout;

        public string exec_name;
        public string app_name;
        public string desktop_id;
        public int icon_size;

        public signal void app_launched ();

        public AppEntry (Backend.App app) {
            
            app_paintable = true;
			set_visual (get_screen ().get_rgba_visual());
            set_size_request (130, 130);
            
            app_name = app.name;
            tooltip_text = app.description;
            exec_name = app.exec;
            icon_size = Slingshot.settings.icon_size;
            icon = app.icon;

            get_style_context ().add_provider (Slingshot.style_provider, 600);
            get_style_context ().add_class ("app");

            app_label = new Label (Utils.truncate_text (app_name, icon_size));
            app_label.halign = Align.CENTER;
            app_label.justify = Justification.CENTER;
            app_label.set_line_wrap (true); // Need a smarter way
            app_label.get_style_context ().add_provider (Slingshot.style_provider, 600);
            app_label.get_style_context ().add_class ("app-name");

            if (app_label.get_allocated_width () >= 120)
                app_label.wrap_mode = Pango.WrapMode.CHAR;

            layout = new VBox (false, 0);

            layout.pack_end (app_label, false, true, 0);

            add (Utils.set_padding (layout, 10, 10, 10, 10));

            this.button_release_event.connect (() => {
                app.launch ();
                app_launched ();
                return true;
            });

            app.icon_changed.connect (queue_draw);

        }

        protected override bool draw (Context cr) {

            Allocation size;
            get_allocation (out size);

            base.draw (cr);

            // Draw icon
            Gdk.cairo_set_source_pixbuf (cr, icon, (icon.width - size.width) / -2.0, 10);
            cr.paint ();

            return true;

        }

    }

}
