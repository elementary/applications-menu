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

    public class Searchbar : Gtk.HBox {
        
        // Constants
        const int WIDTH = 230;
        const int HEIGHT = 24;
        
        // Signals
        public signal void changed ();
        
        public string text {
            owned get {
                string current_text = this.buffer.text;
                return (current_text == this.hint_string && this.is_hinted) ? "" : current_text;
            }
            set {
                this.buffer.text = value;
                if (this.buffer.text == "") {
                    this.hint ();
                } else {
                    this.reset_font ();
                    this.label.label = this.buffer.text; 
                    this.label.select_region (-1, -1);
                    this.clear_icon.visible = true;
                }
            }
        }
        
        private Gtk.TextBuffer buffer;
        public Gtk.Label label;
        public Gtk.Image search_icon;
        private Gtk.Image clear_icon;
        public string hint_string;
        private bool is_hinted = true; // protects against bug where get_text () will return "" if the user happens to type in the hint string
        

        public Searchbar (string hint) {
            this.hint_string = hint;
            this.buffer = new Gtk.TextBuffer (null);
            this.buffer.text = this.hint_string;
            
            // HBox properties
            this.homogeneous = false;
            this.can_focus = true;
            this.set_size_request (this.WIDTH, this.HEIGHT);
        
            // Wrapper 
            var wrapper = new Gtk.HBox (false, 3);
            this.add (wrapper);
            
            // Pack gtk-find icon
            var search_icon_wrapper = new Gtk.EventBox ();
            search_icon_wrapper.set_visible_window (false);
            this.search_icon = new Gtk.Image.from_stock("gtk-find", Gtk.IconSize.MENU);
            search_icon_wrapper.add (this.search_icon);
            search_icon_wrapper.button_release_event.connect ( () => {return true;});
            wrapper.pack_start (search_icon_wrapper, false, true, 3);
            
            // Label properties
            this.label = new Gtk.Label (this.buffer.text);
            this.label.set_ellipsize (Pango.EllipsizeMode.START);
            this.label.set_alignment(0.0f, 0.5f);
            this.label.selectable = true;
            this.label.can_focus = false;
            this.label.set_single_line_mode (true);
            
            wrapper.pack_start (this.label);
            
            // Clear icon
            var clear_icon_wrapper = new Gtk.EventBox ();
            clear_icon_wrapper.set_visible_window (false);
            var stock_item = Gtk.StockItem ();
            stock_item.stock_id = "edit-clear-symbolic";
            stock_item.label = null;
            stock_item.modifier = 0;
            stock_item.keyval = 0;
            stock_item.translation_domain = Gtk.Stock.CLEAR;
            var factory = new Gtk.IconFactory ();
            var icon_set = new Gtk.IconSet ();
            var icon_source = new Gtk.IconSource ();
            icon_source.set_icon_name (Gtk.Stock.CLEAR);
            icon_set.add_source (icon_source);
            icon_source.set_icon_name ("edit-clear-symbolic");
            icon_set.add_source (icon_source);
            factory.add ("edit-clear-symbolic", icon_set);
            Gtk.Stock.add ({stock_item});
            factory.add_default ();
            this.clear_icon = new Gtk.Image.from_stock("edit-clear-symbolic", Gtk.IconSize.MENU);
            
            clear_icon_wrapper.add (this.clear_icon);
            clear_icon_wrapper.button_release_event.connect ( () => { this.hint (); return true; });
            wrapper.pack_end (clear_icon_wrapper, false, true, 3);
            
            // Connect signals and callbacks
            this.buffer.changed.connect (on_changed);
            this.draw.connect (this.draw_background);
            this.realize.connect (() => {
				this.hint (); // hint it
			});
        
        }
        
        public void hint () {
            this.buffer.text = "";
            this.label.label = this.hint_string;
            this.grey_out ();
            this.clear_icon.visible = false;
        }

        public void unhint () {
            this.text = "";
            this.reset_font ();
        }
        
        
        private void grey_out () {
            var color = Gdk.Color ();
            Gdk.Color.parse ("#a0a0a0", out color);
            this.label.modify_fg (Gtk.StateType.NORMAL, color);
            this.label.modify_font (Pango.FontDescription.from_string ("italic"));
            this.is_hinted = true;
        }
        
        private void reset_font () {
        
            var color = Gdk.Color ();
            Gdk.Color.parse ("#444", out color);
            this.label.modify_fg (Gtk.StateType.NORMAL, color);
            this.label.modify_font (Pango.FontDescription.from_string ("normal"));
            this.is_hinted = false;
        
        }
        
        private void on_changed () {
            // Send changed signal
            this.changed ();
        }
        
        private bool draw_background (Cairo.Context context) {

            Gtk.Allocation size;
            get_allocation (out size);

            // Background
            Utils.draw_rounded_rectangle (context, 3.0, 0.5, size);

            // Draw background gradient
            var linear_fill = new Cairo.Pattern.linear (0, 0, 0, 0 + size.height);
	        linear_fill.add_color_stop_rgb (0.0,  0.85, 0.85, 0.85);
	        linear_fill.add_color_stop_rgb (15.25,  1.0, 1.0, 1.0);
	        linear_fill.add_color_stop_rgb (1.0,  1.0, 1.0, 1.0);
            context.set_source (linear_fill);
            context.fill_preserve ();
            
            // Draw outside black stroke
            context.set_source_rgba (0.1, 0.1, 0.1, 1.0);
            context.set_line_width (1.0);
            context.stroke ();


            return false;
        }
        
    }
}
