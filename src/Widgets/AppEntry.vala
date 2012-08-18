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
        
        private Backend.App application;
        
        public AppEntry (Backend.App app) {
            TargetEntry dnd = {"text/uri-list", 0, 0};
            Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd}, 
                Gdk.DragAction.COPY);
            
            app_paintable = true;
            set_visual (get_screen ().get_rgba_visual());
            set_size_request (130, 130);
            desktop_id = app.desktop_id;
            desktop_path = app.desktop_path;
            
            application = app;
            app_name = app.name;
            tooltip_text = app.description;
            exec_name = app.exec;
            icon_size = Slingshot.settings.icon_size;
            icon = app.icon;

            get_style_context ().add_class ("app");

            app_label = new Label (app_name);
            app_label.halign = Align.CENTER;
            app_label.justify = Justification.CENTER;
            app_label.set_line_wrap (true); // Need a smarter way
            app_label.set_single_line_mode (false);
            app_label.set_ellipsize (Pango.EllipsizeMode.END);

            layout = new VBox (false, 0);

            layout.pack_start (app_label, false, true, 0);

            add (Utils.set_padding (layout, 78, 5, 5, 5));
            
            this.released.connect (() => {
                if (!this.dragging){
                    app.launch ();
                    app_launched ();
                }
            });
            
            this.button_press_event.connect ((e) => {return e.button == 3;});
            
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

        protected override bool draw (Context cr) {


            Allocation size;
            get_allocation (out size);

            base.draw (cr);

            // Draw icon
            Gdk.cairo_set_source_pixbuf (cr, icon, (icon.width - size.width) / -2.0, 10);
            cr.paint_with_alpha (alpha);

            return true;

        }

        public void fade_out () {

            Timeout.add (20, () => {

                if (alpha <= 0.3) {
                    queue_draw ();
                    return false;
                }

                alpha -= 0.05;
                queue_draw ();
                return true;

            });

        }

        public void fade_in () {

            Timeout.add (20, () => {

                if (alpha == 1.0) {
                    queue_draw ();
                    return false;
                }
                
                alpha += 0.05;
                queue_draw ();
                return true;

            });

        }
        
        public void launch_app () {
            application.launch ();
            app_launched ();
        }
    }
}
