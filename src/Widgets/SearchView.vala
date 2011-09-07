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

    public class SearchView : VBox {

        private Gee.HashMap<App, SearchItem> items;

        public int active = -1;
        public int apps_showed = 0;

        public signal void app_launched ();

        public SearchView () {

            can_focus = true;
            homogeneous = false;

            app_paintable = true;
            set_visual (get_screen ().get_rgba_visual ());

            items = new Gee.HashMap<App, SearchItem> ();

        }

        public void add_apps (Gee.ArrayList<App> apps) {

            foreach (App app in apps) {
                var search_item = new SearchItem (app);

                search_item.button_release_event.connect (() => {
                    app.launch ();
                    app_launched ();
                    return true;
                });
                
                items[app] = search_item;
            }

        }

        public void show_app (App app) {

            if (!(items[app].in_box)) {
                pack_start (items[app], true, true, 0);
                items[app].in_box = true;
            }

            items[app].show_all ();
            apps_showed++;

        }

        public void hide_app (App app) {

            items[app].hide ();
            apps_showed--;

        }

        public void hide_all () {

            foreach (SearchItem app in items.values) {
                app.hide ();
                if (app.in_box) {
                    remove (app);
                    app.in_box = false;
                }
            }
            apps_showed = 0;
        }

    }

}
