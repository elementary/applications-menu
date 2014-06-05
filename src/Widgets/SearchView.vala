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

    public class SearchView : Gtk.ScrolledWindow {
		const int CONTEXT_WIDTH = 200;

		public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);

        private Gee.HashMap<Backend.App, SearchItem> items;
        private SearchItem selected_app = null;
		private Gtk.Box main_box;

		private Gtk.Revealer revealer;
		private Gtk.Box context_box;
		private Gtk.Fixed context_fixed;

		private bool in_context_view = false;

        private int _selected = 0;
        public int selected {
            get {
                return _selected;
            }
            set {
				_selected = value;
				var max_index = (int)main_box.get_children ().length () - 1;

				// cycle
                if (_selected < 0)
					_selected = max_index;
				else if (_selected > max_index)
					_selected = 0;

				select_nth (main_box, _selected);

				if (in_context_view)
					toggle_context (false);
            }
        }

        private int _context_selected = 0;
        public int context_selected {
            get {
                return _context_selected;
            }
            set {
				_context_selected = value;
				var max_index = (int)context_box.get_children ().length () - 1;

				// cycle
                if (_context_selected < 0)
					_context_selected = max_index;
				else if (_context_selected > max_index)
					_context_selected = 0;

				select_nth (context_box, _context_selected);
            }
        }

        public signal void app_launched ();

        private SlingshotView view;

        public SearchView (SlingshotView parent) {
            view = parent;

            items = new Gee.HashMap<Backend.App, SearchItem> ();

			main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

			context_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
			context_box.width_request = CONTEXT_WIDTH;
			context_fixed = new Gtk.Fixed ();
			context_fixed.put (context_box, 0, 0);

			revealer = new Gtk.Revealer ();
			revealer.transition_duration = 400;
			revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
			revealer.width_request = CONTEXT_WIDTH;
			revealer.no_show_all = true;
			revealer.add (context_fixed);

			var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			box.pack_start (main_box, true);
			box.pack_start (revealer, false);

            add_with_viewport (box);
        }

        public void show_app (Backend.App app) {

			var search_item = new SearchItem (app);
			app.start_search.connect ((search, target) => start_search (search, target));
            search_item.button_release_event.connect (() => {
                app.launch ();
                app_launched ();
                return true;
            });

			main_box.pack_start (search_item, false, false);
			search_item.show_all ();

            items[app] = search_item;

        }

		public void toggle_context (bool show) {
			var prev_y = vadjustment.value;

			if (show && in_context_view == false) {
				in_context_view = true;

				foreach (var child in context_box.get_children ())
					context_box.remove (child);

				var actions = Backend.SynapseSearch.find_actions_for_match (selected_app.app.match);
				foreach (var action in actions) {
					var app = new Backend.App.from_synapse_match (action, selected_app.app.match);
					app.start_search.connect ((search, target) => start_search (search, target));
					context_box.pack_start (new SearchItem (app));
				}
				context_fixed.show_all ();

				revealer.show ();
				revealer.set_reveal_child (true);

				Gtk.Allocation alloc;
				selected_app.get_allocation (out alloc);

				context_fixed.move (context_box, 0, alloc.y);

				context_selected = 0;
			} else {
				in_context_view = false;

				revealer.set_reveal_child (false);
				revealer.hide ();

				// trigger update of selection
				selected = selected;
			}

			vadjustment.value = prev_y;
		}

        public void clear () {
			if (in_context_view)
				toggle_context (false);

			foreach (var child in main_box.get_children ())
				main_box.remove (child);
        }

		public void down ()
		{
			if (in_context_view)
				context_selected ++;
			else
				selected++;
		}

		public void up ()
		{
			if (in_context_view)
				context_selected--;
			else
				selected--;
		}

        private void select_nth (Gtk.Box box, int index) {

            if (selected_app != null)
				//&& !(box == context_box && selected_app.get_parent () == main_box))
                selected_app.unset_state_flags (Gtk.StateFlags.PRELIGHT);

            selected_app = (SearchItem) box.get_children ().nth_data (index);
            selected_app.set_state_flags (Gtk.StateFlags.PRELIGHT, false);

			Gtk.Allocation alloc;
			selected_app.get_allocation (out alloc);

			vadjustment.value = double.max (alloc.y - vadjustment.page_size / 2, 0);
        }

		/**
		 * Launch selected app
		 *
		 * @return indicates whether slingshot should now be hidden
		 */
        public bool launch_selected () {

            return selected_app.launch_app ();

        }

    }

}
