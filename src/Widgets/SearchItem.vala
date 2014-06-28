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

        const int ICON_SIZE = 32;

        public Backend.App app { get; construct; }

        private Gtk.Label name_label;
        private Gtk.Image icon;

        private Cancellable? cancellable = null;

        public signal bool launch_app ();

        public SearchItem (Backend.App app, string search_term = "") {
            Object (app: app);

            get_style_context ().add_class ("app");
            get_style_context ().add_class ("search-item");

            var markup = Backend.SynapseSearch.markup_string_with_search (app.name, search_term);

            name_label = new Gtk.Label (markup);
            name_label.set_ellipsize (Pango.EllipsizeMode.END);
            name_label.use_markup = true;
            name_label.xalign = 0.0f;

            icon = new Gtk.Image.from_pixbuf (app.load_icon (ICON_SIZE));

            // load a favicon if we're an internet page
            var uri_match = app.match as Synapse.UriMatch;
            if (uri_match != null && uri_match.uri.has_prefix ("http")) {
                cancellable = new Cancellable ();
                Backend.SynapseSearch.get_favicon_for_match.begin (uri_match,
                    ICON_SIZE, cancellable, (obj, res) => {

                    var pixbuf = Backend.SynapseSearch.get_favicon_for_match.end (res);
                    if (pixbuf != null)
                        icon.set_from_pixbuf (pixbuf);
                });
            }

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.pack_start (icon, false);
            box.pack_start (name_label, true);
            box.margin_left = 12;
            box.margin_top = box.margin_bottom = 3;

            add (box);

            launch_app.connect (app.launch);
        }

        public override void destroy () {

            base.destroy ();

            if (cancellable != null)
                cancellable.cancel ();
        }
    }

}
