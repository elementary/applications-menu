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
using Gee;

using Slingshot.Backend;

namespace Slingshot.Widgets {

    public class CategoryView : EventBox {

        private HBox container;
        private Sidebar category_switcher;
        private Widgets.Grid app_view;
        private Layout layout;
        private SlingshotView view;

        private const string ALL_APPLICATIONS = _("All Applications");
        private const string MOST_USED_APPS = _("Most used apps");
        private int current_position = 0;

        public CategoryView (SlingshotView parent) {

            view = parent;

            set_visible_window (false);
            setup_ui ();
            connect_events ();
            category_switcher.select_first ();

            set_size_request (view.columns*130, view.rows * 130 + 190);

        }

        private void setup_ui () {

            container = new HBox (false, 0);

            category_switcher = new Sidebar ();
            category_switcher.can_focus = false;
            //category_switcher.add_category (ALL_APPLICATIONS); 
            foreach (string cat_name in view.apps.keys) {
                category_switcher.add_category (cat_name);
            }
            category_switcher.add_bookmark (MOST_USED_APPS);

            layout = new Layout (null, null);

            app_view = new Widgets.Grid (view.rows, view.columns - 1);
            layout.put (app_view, 0, 0);

            container.pack_start (category_switcher, false, false, 0);
            container.pack_end (layout, true, true, 0);

            add (container);

        }

        private void connect_events () { 

            category_switcher.selection_changed.connect ((category) => {

                if (category == ALL_APPLICATIONS)
                    show_all_apps ();
                else if (category in view.apps.keys || category == MOST_USED_APPS)
                    show_filtered_apps (category);
                else
                    return;

            });

            category_switcher.draw.connect (view.draw_background);
            layout.draw.connect (view.draw_background);

            layout.scroll_event.connect ((event) => {
                switch (event.direction.to_string ()) {
                    case "GDK_SCROLL_UP":
                    case "GDK_SCROLL_LEFT":
                        page_left ();
                        break;
                    case "GDK_SCROLL_DOWN":
                    case "GDK_SCROLL_RIGHT":
                        page_right ();
                        break;
                }
                return false;
            });

        }

        private void add_app (App app) {

            var app_entry = new AppEntry (app);
            app_entry.app_launched.connect (view.hide_slingshot);
            app_view.append (app_entry);
            app_entry.show_all ();

        }

        private void show_all_apps () {

            app_view.clear ();

            foreach (App app in view.app_system.get_apps_by_name ())
                add_app (app);

            layout.move (app_view, 0, 0);
            current_position = 0;

        }

        private void show_filtered_apps (string category) {

            app_view.clear ();

            if (category == MOST_USED_APPS) {

                var apps = view.app_system.get_apps_by_popularity ();
                for (int i = 0; i < 12; i++)
                    add_app (apps.nth_data (i));

            } else {
    
                foreach (App app in view.apps[category])
                    add_app (app);

            }

            layout.move (app_view, 0, 0);
            current_position = 0;

        }

        private void page_left () {

            int columns = app_view.get_page_columns ();

            if (current_position < 0) {

                layout.move (app_view, current_position + columns*130, 0);
                current_position += columns*130;

            }
            
        }

        private void page_right () {

            int columns = app_view.get_page_columns ();
            int pages = app_view.get_n_pages ();
            
            if ((- current_position) < (columns*(pages - 1)*130)) {

                layout.move (app_view, current_position - columns*130, 0);
                current_position -= columns*130;
                    
            }

        }

    }

}
