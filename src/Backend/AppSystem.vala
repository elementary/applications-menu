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

        private Zeitgeist.Log log;
        private Zeitgeist.Index zg_index;
        private RelevancyService rl_service;

        private PtrArray zg_templates;

        construct {

            log = new Zeitgeist.Log ();
            zg_index = new Zeitgeist.Index ();

            rl_service = new RelevancyService ();

            populate_zg_templates ();

        }

        private void populate_zg_templates () {

            zg_templates = new PtrArray.sized (1);
            var ev = new Zeitgeist.Event.full (ZG_ACCESS_EVENT, ZG_USER_ACTIVITY, 
                                               "", new Subject.full ("application://*", 
                                                                     "", "", "", "", "", ""));
            zg_templates.add ((ev as Object).ref ());

        }

        public ArrayList<TreeDirectory> get_categories () {

            var apps_tree = GMenu.Tree.lookup ("pantheon-applications.menu", TreeFlags.INCLUDE_NODISPLAY);
            var root_tree = apps_tree.get_root_directory ();            

            if (categories == null) {
                categories = new ArrayList<TreeDirectory> ();

                foreach (TreeItem item in root_tree.get_contents ()) {
                    if (item.get_type () == TreeItemType.DIRECTORY)
                        if (((TreeDirectory) item).get_is_nodisplay () == false)
                            categories.add ((TreeDirectory) item);
                }
            }

            return categories;

        }

        public async ArrayList<App> get_apps_by_category (TreeDirectory category) {

            Idle.add_full (Priority.HIGH_IDLE, get_apps_by_category.callback);
            yield;
            
            var app_list = new ArrayList<App> ();

            foreach (TreeItem item in category.get_contents ()) {
                App app;
                switch (item.get_type ()) {
                    case TreeItemType.DIRECTORY:
                        app_list.add_all (yield get_apps_by_category ((TreeDirectory) item));
                        break;
                    case TreeItemType.ENTRY:
                        if (is_entry ((TreeEntry) item)) {
                            app = new App ((TreeEntry) item);
                            if (app_list.contains (app) == false) {
                                app_list.add (app);
                            }
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

        public async HashMap<string, ArrayList<App>> get_apps () {

            Idle.add (get_apps.callback, Priority.HIGH);
            yield;            

            if (apps == null) {

                apps = new HashMap<string, ArrayList<App>> ();
                
                foreach (TreeDirectory cat in categories) {
                    apps.set (cat.get_menu_id (), yield get_apps_by_category (cat));
                }

            }

            return apps;

        }

        private int sort_apps (App a, App b) {

            return (int) (a.popularity*100 - b.popularity*100);

        }

        public SList<App> get_sorted_apps () {

            var sorted_apps = new SList<App> ();

            foreach (ArrayList<App> category in apps.values) {
                foreach (App app in category) {
                    app.popularity = rl_service.get_app_popularity (app.desktop_id);
                    sorted_apps.append (app);
                }
            }
            
            sorted_apps.sort_with_data (sort_apps);
            sorted_apps.reverse ();
            return sorted_apps;

        }

    }

}
