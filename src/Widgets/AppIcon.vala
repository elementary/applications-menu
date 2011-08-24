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

    public class AppIcon : EventBox {

        private Pixbuf icon;
        private string label;
        private VBox wrapper;

        string font_name;
        int icon_size;

        const int FPS = 24;
        const int DURATION = 400;
        const int RUN_LENGTH = (int)(DURATION/FPS); // total number of frames
        private int current_frame = 1; // run length, in frames

        public AppIcon (int size) {

            this.icon_size = size;

            // EventBox properties
            set_visible_window (false);
            can_focus = true;
            set_size_request (icon_size + 30, icon_size + 30);

            // VBox properties
            wrapper = new VBox (false, 0);
            wrapper.draw.connect (draw_icon);
            add (wrapper);

            this.draw.connect (draw_background);

            this.focus_in_event.connect ( () => {
                this.focus_in ();
                return true;
            });
            this.focus_out_event.connect ( () => {
                this.focus_out ();
                return true;
            });

            font_name = Utils.get_font_name ();

        }

        public void change_app (string new_name, string new_tooltip) {

            this.icon = new Pixbuf.from_file ("/usr/share/icons/hicolor/64x64/apps/beatbox.svg");
            this.label = new_name;
            this.set_tooltip_text (new_tooltip);

            wrapper.queue_draw ();

        }

        public new void focus_in () {

            GLib.Timeout.add (((int)(1000/this.FPS)), () => {
                if (this.current_frame >= this.RUN_LENGTH || !this.has_focus) {
                    current_frame = 1;
                    return false; // stop animation
                }
                queue_draw ();
                this.current_frame++;
                return true;
            });

        }

        public new void focus_out () {

            GLib.Timeout.add (((int)(1000/this.FPS)), () => {
                if (this.current_frame >= this.RUN_LENGTH || this.has_focus) {
                    current_frame = 1;
                    return false; // stop animation
                }
                queue_draw ();
                this.current_frame++;
                return true;
            });

        }

        private bool draw_icon (Cairo.Context context) {

            Allocation size;
            get_allocation (out size);

            // Draw icon
            cairo_set_source_pixbuf (context, this.icon, (this.icon.width - size.width) / -2.0, 4.0);
            context.paint ();

            // Truncate Text
            TextExtents extents;
            context.select_font_face (font_name, FontSlant.NORMAL, FontWeight.NORMAL);
            context.set_font_size (12.0);
            Utils.truncate_text (context, size, 10, label, out label, out extents);

            // Draw text shadow
            context.move_to ((size.width/2 - extents.width/2) + 1, size.height - 9);
            context.set_source_rgba (0.0, 0.0, 0.0, 0.8);
            context.show_text (label);

            // Draw normal text
            context.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            context.move_to (size.width/2 - extents.width/2, 0 + size.height - 10);
            context.show_text (label);

            return false;

        }

        private bool draw_background (Cairo.Context context) {

            Allocation size;
            get_allocation (out size);

            double progress;
            if (current_frame > 0) {
                progress = (double) RUN_LENGTH/(double) current_frame;
            } else {
                progress = 1;
            }

            if (has_focus) {

                var linear_gradient = new Pattern.linear (0, 0, 0, 0 + size.height);
                linear_gradient.add_color_stop_rgba (0.0, 0.1, 0.1, 0.1, 0.5);
                linear_gradient.add_color_stop_rgba (0.5, 0.1, 0.1, 0.1, 0.7);
                linear_gradient.add_color_stop_rgba (0.0, 0.1, 0.1, 0.1, 0.9);

                context.set_source (linear_gradient);
                Utils.draw_rounded_rectangle (context, 4.0, 0.8, size);
                context.fill_preserve ();

                context.set_source_rgba (33.1, 83.1, 83.1, 0.3);
                context.set_line_width (1.0);
                context.stroke ();

            }  else  {
                if (this.current_frame > 1) {
                    var linear_gradient = new Pattern.linear (0, 0, 0, 0 + size.height);
                    linear_gradient.add_color_stop_rgba (0.0, 0.1, 0.1, 0.1, 0.0);
                    linear_gradient.add_color_stop_rgba (0.5, 0.1, 0.1, 0.1, 0.25 - 0.25/progress);
                    linear_gradient.add_color_stop_rgba (0.0, 0.1, 0.1, 0.1, 0.4 - 0.4/progress);

                    context.set_source (linear_gradient);
                    Utils.draw_rounded_rectangle (context, 4.0, 0.8, size);
                    context.fill ();
                }
            }

            return false;

        }

    }

}
