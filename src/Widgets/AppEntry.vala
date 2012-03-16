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
        public string desktop_path;

        public signal void app_launched ();

        private double alpha = 1.0;
        private bool   dragging = false; //prevent launching
        
        public AppEntry (Backend.App app) {
            TargetEntry dnd = {"text/uri-list", 0, 0};
            Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd}, 
                Gdk.DragAction.COPY);
            
            app_paintable = true;
			set_visual (get_screen ().get_rgba_visual());
            set_size_request (130, 130);
            desktop_id = app.desktop_id;
            desktop_path = app.desktop_path;
            
            app_name = app.name;
            tooltip_text = app.description;
            exec_name = app.exec;
            icon_size = Slingshot.settings.icon_size;
            icon = app.icon;

            get_style_context ().add_class ("app");

            var grid = new Gtk.Grid ();
            grid.attach (new Gtk.Image.from_pixbuf (icon), 0, 0, 1, 1);
            var label = new Gtk.EventBox ();
            label.set_visible_window (false);
            var layout = create_pango_layout (app_name);
            layout.set_ellipsize(Pango.EllipsizeMode.END);
            layout.set_width (Pango.units_from_double (130));
            label.draw.connect ( (cr) => {
                Gtk.render_layout (get_style_context (), cr, 0, 0, layout);
                return true;
            });
            layout.set_alignment (Pango.Alignment.CENTER);
            label.hexpand = true;
            Pango.Rectangle extents;
            layout.get_extents (null, out extents);
            label.height_request = (int) Pango.units_to_double (extents.height);
            grid.attach (label, 0, 1, 1, 1);
            add (grid);
            
            this.button_release_event.connect (() => {
                if (!this.dragging){
                    app.launch ();
                    app_launched ();
                }
                return true;
            });
            
            this.drag_begin.connect ( (ctx) => {
                this.dragging = true;
                Gtk.drag_set_icon_pixbuf (ctx, icon, 0, 0);
            });
            this.drag_end.connect ( () => {
                this.dragging = false;
            });
            this.drag_data_get.connect ( (ctx, sel, info, time) => {
                sel.set_uris ({File.new_for_path (desktop_path).get_uri ()});
            });
            
            app.icon_changed.connect (queue_draw);

        }
    }

}
