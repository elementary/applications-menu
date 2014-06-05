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

namespace Slingshot.Widgets {

    public class SearchItem : Gtk.Button {

		const int ICON_SIZE = 22;

        public Backend.App app { get; construct; }

        private Gdk.Pixbuf icon;
        private string icon_name;
        private Gtk.Label name_label;
        // private Gtk.Label desc_label;

        public signal bool launch_app ();

        public SearchItem (Backend.App app) {
            Object (app: app);

            get_style_context ().add_class ("app");

            icon = app.icon;
            icon_name = app.icon_name;

            name_label = new Gtk.Label (fix (app.name));
            name_label.set_ellipsize (Pango.EllipsizeMode.END);
            name_label.use_markup = true;
            name_label.xalign = 0.0f;

            /*desc_label = new Gtk.Label (fix (app.description));
            desc_label.set_ellipsize (Pango.EllipsizeMode.END);
            desc_label.xalign = 0.0f;*/

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
			box.pack_start (new Gtk.Image.from_pixbuf (app.load_icon (ICON_SIZE)), false);
            box.pack_start (name_label, true);

            add (box);

            launch_app.connect (app.launch);
        }

        protected override bool draw (Cairo.Context cr) {
            Gtk.Allocation size;
            get_allocation (out size);

            return base.draw (cr);
        }

        private string fix (string text) {
            return text.replace ("&", "&amp;").replace ("<", "&lt;").replace (">", "&gt;");
        }
    }

}
