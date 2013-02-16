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

using Gtk;
using Gee;

using Slingshot.Backend;

namespace Slingshot.Widgets {

    public class CategoryView : EventBox {

        private Gtk.Grid container;
        public Sidebar category_switcher;
        public VSeparator separator;
        public Widgets.Grid app_view;
        private Layout layout;
        public Switcher switcher;
        private SlingshotView view;
        private Label empty_cat_label;

        private Gtk.Grid page_switcher;

        private const string ALL_APPLICATIONS = _("All Applications");
        private const string NEW_FILTER = _("Create a new Filter");
        private int current_position = 0;
        private bool from_category = false;

        public HashMap<int, string> category_ids = new HashMap<int, string> ();

        public CategoryView (SlingshotView parent) {

            view = parent;

            set_visible_window (false);
            setup_ui ();
            setup_sidebar ();
            connect_events ();

            set_size_request (view.columns*130 + 17, view.view_height);

        }

        private void setup_ui () {
            container = new Gtk.Grid ();
            separator = new VSeparator ();

            layout = new Layout (null, null);

            app_view = new Widgets.Grid (view.rows, view.columns - 1);
            layout.put (app_view, 0, 0);
            layout.put (empty_cat_label, view.columns*130, view.rows * 130 / 2);
            layout.set_hexpand (true);
            layout.set_vexpand (true);

            // Create the page switcher
            switcher = new Switcher ();

            // A bottom widget to keep the page switcher center
            page_switcher = new Gtk.Grid ();
            var bottom_separator1 = new Label (""); // A fake label
            bottom_separator1.set_hexpand(true);
            var bottom_separator2 = new Label (""); // A fake label
            bottom_separator2.set_hexpand(true);
            page_switcher.attach (bottom_separator1, 0, 0, 1, 1);
            page_switcher.attach (switcher, 1, 0, 1, 1);
            page_switcher.attach (bottom_separator2, 2, 0, 1, 1);

            container.attach (separator, 1, 0, 1, 2);
            container.attach (layout, 2, 0, 1, 1);

            add (container);

        }

        public void setup_sidebar () {

            if (category_switcher != null)
                category_switcher.destroy ();

            category_switcher = new Sidebar ();
            category_switcher.can_focus = false;

            // Fill the sidebar
            int n = 0;

            foreach (string cat_name in view.apps.keys) {
                category_ids.set (n, cat_name);
                category_switcher.add_category (GLib.dgettext ("gnome-menus-3.0", cat_name).dup ());
                n++;
            }

            container.attach (category_switcher, 0, 0, 1, 2);
            category_switcher.selection_changed.connect ((name, nth) => {

                view.reset_category_focus ();
                string category = category_ids.get (nth);
                show_filtered_apps (category);
            });
            category_switcher.selected = 0; //Must be after everything else

            category_switcher.show_all ();
        }

        private void connect_events () {

            layout.scroll_event.connect ((event) => {
                switch (event.direction.to_string ()) {
                    case "GDK_SCROLL_UP":
                    case "GDK_SCROLL_LEFT":
                        switcher.set_active (switcher.active - 1);
                        break;
                    case "GDK_SCROLL_DOWN":
                    case "GDK_SCROLL_RIGHT":
                        switcher.set_active (switcher.active + 1);
                        break;
                }
                return false;
            });

            app_view.new_page.connect ((page) => {
                
                if (switcher.size == 0)
                    switcher.append ("1");
                switcher.append (page);

                /* Prevents pages from changing */
                from_category = true;
            });

            switcher.active_changed.connect (() => {
                if (from_category || switcher.active - switcher.old_active == 0) {
                    from_category = false;
                    return;
                }

                move_page (switcher.active - switcher.old_active);
                view.searchbar.grab_focus (); // this is because otherwise focus isn't the current page
            });
        }

        private void add_app (App app) {

            var app_entry = new AppEntry (app);
            app_entry.app_launched.connect (() => view.hide ());
            app_view.append (app_entry);
            app_entry.show_all ();

        }

        public void show_filtered_apps (string category) {

            switcher.clear_children ();
            app_view.clear ();
            
            layout.move (empty_cat_label, view.columns*130, view.rows*130 / 2);
            foreach (App app in view.apps[category])
	            add_app (app);
            
            switcher.set_active (0);

            layout.move (app_view, 0, 0);
            current_position = 0;

        }

        public void move_page (int step) {
        
            debug ("Moving: step = " + step.to_string ());
        
            if (step == 0)
                return;
            if (step < 0 && current_position >= 0) //Left border
                return;
            if (step > 0 && (-current_position) >= ((app_view.get_n_pages () - 1) * app_view.get_page_columns () * 130)) //Right border
                return;
            
            int count = 0;
            int increment = -step*130*(view.columns-1)/10;
            Timeout.add (30/(view.columns-1), () => {

                if (count >= 10) {
                    current_position += -step*130*(view.columns-1) - 10*increment; //We adjust to end of the page
                    layout.move (app_view, current_position, 0);
                    return false;
                }
                    
                current_position += increment;
                layout.move (app_view, current_position, 0);
                count++;
                return true;
                
            }, Priority.DEFAULT_IDLE);
        }

        public void show_page_switcher (bool show) {

            if (page_switcher.get_parent () == null)
                container.attach (page_switcher, 2, 1, 1, 1);

            if (show) {
                page_switcher.show_all ();
                view.bottom.hide ();
            }
            else
                page_switcher.hide ();
                
            view.searchbar.grab_focus ();

        }

    }

}

