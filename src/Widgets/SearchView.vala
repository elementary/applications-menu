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
using Slingshot.Backend;

namespace Slingshot.Widgets {

    private class SeparatorItem : HSeparator {
        
        public bool in_box;

    }

    public class SearchView : VBox {

        private Gee.HashMap<App, SearchItem> items;
        private SeparatorItem separator;
        private SearchItem selected_app = null;

        private int _selected = 0;
        public int selected {
            get {
                return _selected;
            }
            set {
                if (value < 0 || value > get_children ().length () - 1)
                    return;

                if (value != 1) {
                    select_nth (value);
                    _selected = value;
                } else if (_selected - value > 0) {
                    /* Get a sort of direction */
                    select_nth (value - 1);
                    _selected = value - 1;
                } else {
                    select_nth (value + 1);
                    _selected = value + 1;
                }
            }
        }

        public int apps_showed = 0;

        public signal void app_launched ();

        private SlingshotView view;

        public SearchView (SlingshotView parent) {

            can_focus = true;
            homogeneous = false;

            this.view = parent;
            width_request = view.columns * 130;

            items = new Gee.HashMap<App, SearchItem> ();
            separator = new SeparatorItem ();

        }

        public void add_apps (Gee.ArrayList<App> apps) {

            foreach (App app in apps) {
                var search_item = new SearchItem (app);

                append_app (app, search_item);

            }

        }

        public void append_app (App app, SearchItem search_item) {

            search_item.button_release_event.connect (() => {
                app.launch ();
                app_launched ();
                return true;
            });
            
            items[app] = search_item;
        
        }

        public void show_app (App app) {

            if (!(app in items.keys)) {
                var search_item = new SearchItem (app);
                append_app (app, search_item);
            }

            if (apps_showed == 1) {
                show_separator ();
            }

            if (!(items[app].in_box)) {
                pack_start (items[app], true, true, 0);
                items[app].in_box = true;
                items[app].icon_size = 48;
                items[app].queue_draw ();
            }

            items[app].show_all ();
            apps_showed++;

            if (apps_showed == 1) {
                set_focus_child (items[app]);
                items[app].icon_size = 64;
                items[app].queue_draw ();
                selected = 0;
            }                

        }

        public void hide_app (App app) {

            items[app].hide ();
            apps_showed--;

        }

        public void hide_all () {

            hide_separator ();

            foreach (SearchItem app in items.values) {
                app.hide ();
                if (app.in_box) {
                    remove (app);
                    app.in_box = false;
                }
            }
            apps_showed = 0;
        }

        public void add_command (string command) {

            var app = new App.from_command (command);
            var item = new SearchItem (app);

            append_app (app, item);

            show_app (app);
        }

        private void show_separator () {

            if (!(separator.in_box)) {
                pack_start (separator, true, true, 3);
                separator.in_box = true;
            }
            separator.show_all ();

        }

        private void hide_separator () {

            separator.hide ();
            if (separator.in_box) {
                remove (separator);
                separator.in_box = false;
            }
        
        }

        private void select_nth (int index) {

            if (selected_app != null)
                selected_app.set_state (StateType.NORMAL);

            selected_app = (SearchItem) get_children ().nth_data (index);
            selected_app.set_state (StateType.PRELIGHT);

        }

        public void launch_selected () {

            selected_app.launch_app ();

        }

    }

}
