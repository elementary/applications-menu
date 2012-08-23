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

namespace Slingshot.Backend {

    public class App : Object {

        public string name { get; construct set; }
        public string description { get; private set; default = ""; }
        public string desktop_id { get; construct set; }
        public string exec { get; private set; }
        public string icon_name { get; private set; default = ""; }
        public string[] keywords { get; private set;}
        public Gdk.Pixbuf icon { get; private set; }
        public double popularity { get; set; }
        public double relevancy { get; set; }
        public string desktop_path { get; private set; }

        private bool is_command = false;

        public signal void icon_changed ();
        public signal void launched (App app);

        public App (GMenu.TreeEntry entry) {

            name = entry.get_display_name ();
            description = entry.get_comment () ?? name;
            exec = entry.get_exec ();
            desktop_id = entry.get_desktop_file_id ();
            icon_name = entry.get_icon () ?? "application-default-icon";
            desktop_path = entry.get_desktop_file_path ();
            keywords = Unity.AppInfoManager.get_default ().get_keywords (desktop_id);

            update_icon ();
            Slingshot.icon_theme.changed.connect (update_icon);

        }

        public App.from_command (string command) {

            name = command;
            description = _("Run this command...");
            exec = command;
            desktop_id = command;
            icon_name = "system-run";

            is_command = true;

            update_icon ();

        }

        public void update_icon () {

            try {
                icon = Slingshot.icon_theme.load_icon (icon_name, Slingshot.settings.icon_size,
                                                        Gtk.IconLookupFlags.FORCE_SIZE);
            } catch (Error e) {
                try {
                    if (icon_name.last_index_of (".") > 0)
                        icon = Slingshot.icon_theme.load_icon (icon_name[0:icon_name.last_index_of (".")],
                                                               Slingshot.settings.icon_size, Gtk.IconLookupFlags.FORCE_SIZE);
                    else
                        throw new IOError.NOT_FOUND ("Requested image could not be found.");
                        
                } catch (Error e) {
                    try {
                        icon = new Gdk.Pixbuf.from_file_at_scale (icon_name, Slingshot.settings.icon_size,
                                                                  Slingshot.settings.icon_size, false);
                    } catch (Error e) {
                        try {
                            icon = Slingshot.icon_theme.load_icon ("application-default-icon", Slingshot.settings.icon_size,
                                                                   Gtk.IconLookupFlags.FORCE_SIZE);
                        } catch (Error e) {
                            icon = Slingshot.icon_theme.load_icon ("gtk-missing-image", Slingshot.settings.icon_size,
                                                                   Gtk.IconLookupFlags.FORCE_SIZE);
                        }
                    }
                }
            }

            icon_changed ();

        }

        public void launch () {

            try {
                if (is_command) {
                    debug (@"Launching command: $name");
                    Process.spawn_command_line_async (exec);
                } else {
                    launched (this); // Emit launched signal
                    new DesktopAppInfo (desktop_id).launch (null, null);
                    debug (@"Launching application: $name");
                }
            } catch (Error e) {
                warning ("Failed to launch %s: %s", name, exec);
            }

        }

    }

}
