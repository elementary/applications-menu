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

    public class App : Button {

        public Image app_icon;
        public Label app_label;
        private VBox layout;

        public string exec_name;
        public string app_name;
        public string desktop_id;

        private CssProvider style_provider;

        public App (GMenu.TreeEntry entry) {
            
            app_paintable = true;
			set_visual (get_screen ().get_rgba_visual());
            
            app_name = entry.get_display_name ();
            tooltip_text = entry.get_comment ();
            exec_name = entry.get_exec ();
            desktop_id = entry.get_desktop_file_id ();

            style_provider = new CssProvider ();

            try {
                style_provider.load_from_path (Build.PKGDATADIR + "/style/default.css");
            } catch (Error e) {
                warning ("Could not add css provider. Some widgets won't look as intended. %s", e.message);
            }

            can_focus = true;

            get_style_context ().add_provider (style_provider, 600);
            get_style_context ().add_class ("app");

            app_icon = new Image.from_icon_name (entry.get_icon (), IconSize.DIALOG);
            app_icon.pixel_size = Slingshot.settings.icon_size;
            app_icon.get_style_context ().add_provider (style_provider, 600);
            app_icon.get_style_context ().add_class ("app-icon");

            app_label = new Label (app_name);
            app_label.halign = Align.CENTER;
            app_label.set_line_wrap (true); // Need a smarter way
            app_label.get_style_context ().add_provider (style_provider, 600);
            app_label.name = "app-name";

            layout = new VBox (false, 5);

            layout.pack_start (app_icon, false, true, 0);
            layout.pack_end (app_label, false, true, 0);

            add (Utils.set_padding (layout, 10, 10, 10, 10));

        }

        public void launch () {

            try {
                new DesktopAppInfo (desktop_id).launch (null, null);
            } catch (Error e) {
                warning ("Failed to launch %s: %s", app_name, exec_name);
            }

        }

    }

}
