// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Maxwell Barvian
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


namespace Slingshot.Widgets {

    public class Indicators : Gtk.HBox {

        // Animation constants
        const int FPS = 60;
        private int animation_duration;
        private int animation_frames; // total number of frames
        private int current_frame = 1;
        private uint animation_loop_id = 0;
        private bool animation_active = false;

        // Signals
        public signal void child_activated ();

        // Properties
        public new GLib.List<Gtk.Widget> children;
        public int active = -1;
        private int old_active = -1;

        public Indicators () {

            this.homogeneous = false;
            this.spacing = 0;

        }

        public void append (string thelabel) {
            var indicator = new Gtk.EventBox();
            indicator.set_visible_window (false);

            var label = new Gtk.Label(thelabel);
            Gdk.Color white;
            Gdk.Color.parse("#FFFFFF", out white);
            label.modify_fg (Gtk.StateType.NORMAL, white);
            var font = new Pango.FontDescription ();
            font.set_size (9500);
            font.set_weight (Pango.Weight.HEAVY);
            label.modify_font (font);

            // make sure the child widget is added with padding
            indicator.add (Utils.set_padding (label, 5, 15, 5, 15)); 
            this.children.append(indicator);

            this.draw.connect(draw_background);
            indicator.button_release_event.connect( () => {

                this.set_active(this.children.index(indicator));

                return true;

            } );

            this.pack_start(indicator, false, false, 0);

        }

        public void set_active_no_signal (int index) {

            if (index <= ((int)this.children.length - 1)) { // make sure the requested active item is in the children list
                this.old_active = this.active;
                this.active = index;
                this.change_focus ();
            }

        }

        public void set_active (int index) {
            this.set_active_no_signal (index);
            this.child_activated (); // send signal
        }

        public void change_focus () {
            //make sure no other animation is running, if so kill it with fire
            if(animation_active){
                GLib.Source.remove(animation_loop_id);
                end_animation();
            }

            // definie animation_duration, base is 250 millisecionds for which 50 ms is added for each item to span
            this.animation_duration = 240;
            int difference = (this.old_active - this.active).abs ();
            this.animation_duration += (int) (Math.pow(difference, 0.5) * 80);


            this.animation_frames = (int)((double) animation_duration / 1000 * FPS);

            // initial conditions for animation.
            this.current_frame = 0;
            this.animation_active = true;

            this.animation_loop_id = GLib.Timeout.add (((int)(1000 / this.FPS)), () => {
				if (this.current_frame >= this.animation_frames) {
				    end_animation();
					return false; // stop animation
				}

                this.current_frame++;
				this.queue_draw ();
				return true;
			});
        }

        private void end_animation(){
            animation_active = false;
            current_frame = 0;
        }

        protected bool draw_background (Cairo.Context context) {
            
            Gtk.Allocation size;
            get_allocation (out size);

            double d = (double) this.animation_frames;
            double t = (double) this.current_frame;

            double progress;

            // easeOutQuint algorithm - aka - start normal end slow
            progress = ((t=t/d-1)*t*t*t*t + 1);

            // Get allocations of old rectangle
            Gtk.Allocation size_old, size_new;
            this.get_children ().nth_data (this.old_active).get_allocation(out size_old);

            // Get allocations for the new rectangle
            this.get_children ().nth_data (this.active).get_allocation(out size_new);

            // Move and make a new rectangle, according to progress
            double x = size_old.x + (size_new.x - (double) size_old.x) * progress;
            double width = size_old.width + (size_new.width - (double) size_old.width) * progress;

            context.set_source_rgba (0.0, 0.0, 0.0, 0.70);
            double offset = 0.0;
            double radius = 3.0;
            context.move_to (x + radius, 0.0 + offset);
		    context.arc (x + width - radius - offset, 0.0 + radius + offset, radius, Math.PI * 1.5, Math.PI * 2);
		    context.arc (x + width - radius - offset, 0.0 + size.height - radius - offset, radius, 0, Math.PI * 0.5);
		    context.arc (x + radius + offset, 0.0 + size.height - radius - offset, radius, Math.PI * 0.5, Math.PI);
		    context.arc (x + radius + offset, 0.0 + radius + offset, radius, Math.PI, Math.PI * 1.5);
            context.fill ();

            return false;
        }
    }
}

