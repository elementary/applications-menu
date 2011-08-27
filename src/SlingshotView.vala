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
using Gee;
using Cairo;
using Granite.Widgets;

using Slingshot.Widgets;

namespace Slingshot {

    public class SlingshotView : CompositedWindow {

        public EventBox wrapper;
        public Switcher category_switcher;
        public SearchBar searchbar;
        public Widgets.Grid grid;

        public SlingshotView () {

            set_size_request (660, 570);
            read_settings ();

            // Window properties
            this.title = "Slingshot"; // Do I need this?
            this.skip_pager_hint = true;
            this.skip_taskbar_hint = true;
            this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
            this.set_keep_above (true);
            this.resizable = false;
            this.app_paintable = true;

            // Have the window in the right place
            this.move (5, 0); 

            setup_ui ();
            connect_signals ();

        }

        private void setup_ui () {
            
            // Add container wrapper
            wrapper = new EventBox ();
            wrapper.set_visible_window (false);

            // Add container
            var container = new VBox (false, 15);
            wrapper.add (container);

            // Add top bar
            var top = new HBox (false, 10);

            // Category Switcher widget
            category_switcher = new Switcher ();
            for (int i = 0; i < 5; i++)
                category_switcher.append (@"All Apps $i");
            category_switcher.set_active (0);


            searchbar = new SearchBar (_("Start typing to search"));
            
            top.pack_start (category_switcher, true, true, 15);
            top.pack_start (searchbar, false, true, 0);

            container.pack_start (top, false, true, 15);

            // Get the current size of the view
            int width, height;
            get_size (out width, out height);
            
            // Make icon grid and populate
            grid = new Widgets.Grid (height / 180, width / 128);
            container.pack_start (Utils.set_padding (grid, 0, 18, 0, 18), true, true, 0);

            for (int r = 0; r < this.grid.n_rows; r++) {

                for (int c = 0; c < this.grid.n_columns; c++) {

                    var item = new App ();

                    this.grid.attach (item, c, c + 1, r, r + 1, Gtk.AttachOptions.EXPAND, Gtk.AttachOptions.EXPAND, 0, 0);

                }
            }
            

            this.add (Utils.set_padding (wrapper, 15, 15, 15, 15));

            this.show_all ();

        }

        private void connect_signals () {
            
            this.focus_out_event.connect ( () => {
                this.hide_slingshot(); 
                Gtk.main_quit ();
                return false; 
            });
            this.draw.connect (this.draw_background);
            searchbar.changed.connect (this.search);

            // Auto-update settings when changed
            Slingshot.settings.changed.connect (read_settings);

        }

        private bool draw_background (Context cr) {

            Allocation size;
            get_allocation (out size);
            
            // Some (configurable?) values
            double radius = 6.0;
            double offset = 2.0;

            cr.set_antialias (Antialias.SUBPIXEL);

		    cr.move_to (0 + radius, 15 + offset);
            // Create the little triangle
            cr.line_to (20.0, 15.0 + offset);
            cr.line_to (35.0, 0.0 + offset);
            cr.line_to (50.0, 15.0 + offset);
            // Create the rounded square
		    cr.arc (0 + size.width - radius - offset, 15.0 + radius + offset, 
                         radius, Math.PI * 1.5, Math.PI * 2);
		    cr.arc (0 + size.width - radius - offset, 0 + size.height - radius - offset, 
                         radius, 0, Math.PI * 0.5);
		    cr.arc (0 + radius + offset, 0 + size.height - radius - offset, 
                         radius, Math.PI * 0.5, Math.PI);
		    cr.arc (0 + radius + offset, 15 + radius + offset, radius, Math.PI, Math.PI * 1.5);

            cr.set_source_rgba (0.1, 0.1, 0.1, 0.95);
            cr.fill_preserve ();

            // Add a little vertical gradient
            /*var linear_stroke = new Cairo.Pattern.linear (0, 0, 0, size.height);
	        linear_stroke.add_color_stop_rgba (0.0,  1.0, 1.0, 1.0, 0.0);
	        linear_stroke.add_color_stop_rgba (0.5,  1.0, 1.0, 1.0, 0.0);
	        linear_stroke.add_color_stop_rgba (1.0,  0.9, 0.9, 0.9, 0.2);
            cr.set_source (linear_stroke);
            cr.fill_preserve ();
            */ // I don't like it anymore

            // Paint a little lighter border
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.set_line_width (1.0);
            cr.stroke ();

            return false;

        }


        public override bool key_press_event (Gdk.EventKey event) {

            switch (Gdk.keyval_name (event.keyval)) {

                case "Escape":
                    hide_slingshot ();
                    return true;

                default:
                    if (!searchbar.has_focus)
                        searchbar.grab_focus ();
                    break;

            }

            base.key_press_event (event);
            return false;

        }

        private void hide_slingshot () {

            iconify ();

        }

        private void search () {

            message ("Performing searching...");

        }

        private void read_settings () {

            default_width = Slingshot.settings.width;
            default_height = Slingshot.settings.height;

        }

    }

}
