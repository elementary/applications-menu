// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2014 Tom Beckmann <tomjonabc@gmail.com>
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

namespace Slingshot.Widgets
{
	public class LargeSearchEntry : Gtk.Box {
		const int ICON_SIZE = 24;

		public signal void search_changed ();

		public string text {
			get {
				return widget.text;
			}
			set {
				widget.text = value;
			}
		}

		public Gtk.Entry widget { get; private set; }

		public LargeSearchEntry ()
		{
			Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 4);

			var find_pixbuf = Gtk.IconTheme.get_default ().load_icon ("edit-find-symbolic", ICON_SIZE, 0);
			var clear_pixbuf = Gtk.IconTheme.get_default ().load_icon ("edit-clear-symbolic", ICON_SIZE, 0);

			var clear_box = new Gtk.Button ();
			clear_box.add (new Gtk.Image.from_pixbuf (clear_pixbuf));
			clear_box.relief = Gtk.ReliefStyle.NONE;
			clear_box.clicked.connect (() => text = "" );

			widget = new Gtk.Entry ();
			widget.get_style_context ().add_class ("search-entry-large");

			pack_start (new Gtk.Image.from_pixbuf (find_pixbuf), false);
			pack_start (widget);
			pack_start (clear_box, false);

			widget.changed.connect (() => search_changed ());
		}

	}
}

