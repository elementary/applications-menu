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
        
        public static string truncate_text (string input, int icon_size) {
            
            string new_text;
            if (input.length > icon_size / 3) {
                new_text = input[0:icon_size / 3] + "...";
                return new_text;
            } else {
                return input;
            }

        }

    }	
	
}
		
