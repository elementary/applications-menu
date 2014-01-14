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

        private Backend.App app;
        private Gdk.Pixbuf icon;
        private string icon_name;
        private Gtk.Label name_label;
        private Gtk.Label desc_label;

        public bool in_box = false;
        public int icon_size = 64;
        public signal void launch_app ();

        public SearchItem (Backend.App app) {
            this.app = app;
            get_style_context ().add_class ("app");

            icon = app.icon;
            icon_name = app.icon_name;

            name_label = new Gtk.Label ("<b><span size=\"larger\">" + fix (app.name) + "</span></b>");
            name_label.set_ellipsize (Pango.EllipsizeMode.END);
            name_label.use_markup = true;
            name_label.xalign = 0.0f;

            desc_label = new Gtk.Label (fix (app.description));
            desc_label.set_ellipsize (Pango.EllipsizeMode.END);
            desc_label.xalign = 0.0f;

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.homogeneous = false;
            vbox.pack_start (name_label, false, true, 0);
            vbox.pack_start (desc_label, false, true, 0);

            add (Utils.set_padding (vbox, 5, 0, 0, 78));

            this.launch_app.connect (app.launch);
        }

        protected override bool draw (Cairo.Context cr) {
            Gtk.Allocation size;
            get_allocation (out size);

            base.draw (cr);

            Gdk.Pixbuf scaled_icon = app.load_icon (icon_size);

            height_request = icon_size + 10;

            // Draw icon
            Gdk.cairo_set_source_pixbuf (cr, scaled_icon, 74 - icon_size, 5);
            cr.paint ();

            return true;
        }

        private string fix (string text) {
            return text.replace ("&", "&amp;").replace ("<", "&lt;").replace (">", "&gt;");
        }
    }

}