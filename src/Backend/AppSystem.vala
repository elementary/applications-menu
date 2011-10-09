// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Slingshot Developers
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

using GLib;
using GMenu;
using Gee;
using Zeitgeist;

namespace Slingshot.Backend {

    public class AppSystem : Object {

        private ArrayList<TreeDirectory> categories = null;
        private HashMap<string, ArrayList<App>> apps = null;
        private GMenu.Tree apps_menu = null;

        private RelevancyService rl_service;

        public signal void changed ();
        private bool index_changed = false;

        construct {

            rl_service = new RelevancyService ();

            apps_menu = GMenu.Tree.lookup ("pantheon-applications.menu", TreeFlags.INCLUDE_NODISPLAY);
            apps_menu.add_monitor ((menu) => {

                debug ("Apps menu tree changed. Updating..");
                index_changed = true;
                update_app_system ();
                changed ();
                
            });

            update_app_system ();

        }

        private void update_app_system () {

            rl_service.refresh_popularity ();

            update_categories_index ();
            update_apps ();

        }

        private void update_categories_index () {

            var root_tree = apps_menu.get_root_directory ();            

            if (categories == null || index_changed) {
                categories = new ArrayList<TreeDirectory> ();

                foreach (TreeItem item in root_tree.get_contents ()) {
                    if (item.get_type () == TreeItemType.DIRECTORY)
                        if (((TreeDirectory) item).get_is_nodisplay () == false)
                            categories.add ((TreeDirectory) item);
                }
            }

        }

        private void update_apps () {

            if (index_changed) {
                apps.clear ();
                apps = null;
                index_changed = false;
            }

            if (apps == null) {

                apps = new HashMap<string, ArrayList<App>> ();
                
                foreach (TreeDirectory cat in categories) {
                    apps.set (cat.get_menu_id (), get_apps_by_category (cat));
                }

            }

        }

        public ArrayList<TreeDirectory> get_categories () {

            return categories;

        }

        public ArrayList<App> get_apps_by_category (TreeDirectory category) {

            var app_list = new ArrayList<App> ();

            foreach (TreeItem item in category.get_contents ()) {
                App app;
                switch (item.get_type ()) {
                    case TreeItemType.DIRECTORY:
                        app_list.add_all (get_apps_by_category ((TreeDirectory) item));
                        break;
                    case TreeItemType.ENTRY:
                        if (is_entry ((TreeEntry) item)) {
                            app = new App ((TreeEntry) item);
                            if (app_list.contains (app) == false)
                                app_list.add (app);
                            else
                                debug (@"App already present: $(app.name)");
                        }
                        break;
                }
            }
            return app_list;

        }

        private bool is_entry (TreeEntry entry) {

            if (entry.get_launch_in_terminal () == false 
                && entry.get_is_nodisplay () == false) {
                return true;
            } else {
                return false;
            }

        }

        public HashMap<string, ArrayList<App>> get_apps () {

            return apps;

        }

        public SList<App> get_apps_by_popularity () {

            var sorted_apps = new SList<App> ();

            foreach (ArrayList<App> category in apps.values) {
                foreach (App app in category) {
                    app.popularity = rl_service.get_app_popularity (app.desktop_id);
                    sorted_apps.insert_sorted_with_data (app, Utils.sort_apps_by_popularity);
                }
            }
            
            return sorted_apps;

        }

        public SList<App> get_apps_by_name () {

            var sorted_apps = new SList<App> ();

            foreach (ArrayList<App> category in apps.values) {
                foreach (App app in category) {
                    sorted_apps.insert_sorted_with_data (app, Utils.sort_apps_by_name);
                }
            }

            return sorted_apps;

        }

    }

}
