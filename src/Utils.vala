// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Slingshot Developers
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

using GLib;
using Gtk;
using Cairo;

namespace Slingshot {

    class Utils : GLib.Object {
		
	    public static Alignment set_padding (Gtk.Widget widget, int top, int right, 
                                                int bottom, int left) {

		    var alignment = new Alignment (0.0f, 0.0f, 1.0f, 1.0f);
		    alignment.top_padding = top;
		    alignment.right_padding = right;
		    alignment.bottom_padding = bottom;
		    alignment.left_padding = left;
		
		    alignment.add (widget);
		    return alignment;

	    }
		
	    public static void draw_rounded_rectangle (Cairo.Context context, double radius, 
                                                   double offset, Gtk.Allocation size) {

		    context.move_to (0 + radius, 0 + offset);
		    context.arc (0 + size.width - radius - offset, 0 + radius + offset, 
                         radius, Math.PI * 1.5, Math.PI * 2);
		    context.arc (0 + size.width - radius - offset, 0 + size.height - radius - offset, 
                         radius, 0, Math.PI * 0.5);
		    context.arc (0 + radius + offset, 0 + size.height - radius - offset, 
                         radius, Math.PI * 0.5, Math.PI);
		    context.arc (0 + radius + offset, 0 + radius + offset, radius, Math.PI, Math.PI * 1.5);
		
        }
        
        public static void truncate_text (Cairo.Context context, Gtk.Allocation size, uint padding, 
                                          string input, out string truncated, 
                                          out Cairo.TextExtents truncated_extents) {

            Cairo.TextExtents extents;
            truncated = input;
            context.text_extents (input, out extents);
            
            if (extents.width > (size.width - padding)) {
            
                while (extents.width > (size.width - padding)) {
                    truncated = truncated.slice (0, (int)truncated.length - 1);
                    context.text_extents (truncated, out extents);
                }   
                
                truncated = truncated.slice (0, (int) truncated.length - 3); // make room for ...
                truncated += "...";
            
            }
            
            context.text_extents (truncated, out truncated_extents);
            
        }

        public static string get_font_name () {

            var settings = new GLib.Settings ("org.gnome.desktop.interface");
            string font_name = settings.get_string ("font-name");

            // Return the font-name without the size
            return font_name [0:font_name.length - 2];

        }

    }	
	
}
		
