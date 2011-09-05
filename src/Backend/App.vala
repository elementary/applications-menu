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

namespace Slingshot.Backend {

    public class App : Object {

        public string name { get; construct set; }
        public string description { get; set; default = ""; }
        public string desktop_id { get; construct set; }
        public string exec { get; set; }
        public string icon_name { get; set; default = ""; }
        public Gdk.Pixbuf icon { get; set; }

        public App (GMenu.TreeEntry entry) {

            name = entry.get_display_name ();
            description = entry.get_comment () ?? name;
            exec = entry.get_exec ();
            desktop_id = entry.get_desktop_file_id ();
            icon_name = entry.get_icon ();
            try {
                icon = Slingshot.icon_theme.load_icon (icon_name, 64, Gtk.IconLookupFlags.FORCE_SIZE);
            } catch (Error e) {
                icon = new Gdk.Pixbuf.from_file ("/usr/share/icons/elementary/apps/64/application-default-icon.svg");
            }
        }

        public void launch () {

            try {
                new DesktopAppInfo (desktop_id).launch (null, null);
                debug (@"Launching application: $name");
            } catch (Error e) {
                warning ("Failed to launch %s: %s", name, exec);
            }
        
        }

    }

}
