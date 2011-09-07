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

namespace Slingshot.Backend {

    public class AppSystem : Object {

        public static ArrayList<TreeDirectory> get_categories () {

            var apps_tree = GMenu.Tree.lookup ("gnome-applications.menu", TreeFlags.INCLUDE_NODISPLAY);
            var root_tree = apps_tree.get_root_directory ();            

            var category_entries = new ArrayList<TreeDirectory> ();

            foreach (TreeItem item in root_tree.get_contents ()) {
                if (item.get_type () == TreeItemType.DIRECTORY)
                    if (((TreeDirectory) item).get_is_nodisplay () == false)
                        category_entries.add ((TreeDirectory) item);
            }

            return category_entries;

        }

        public static ArrayList<App> get_apps (TreeDirectory category) {

            var apps = new ArrayList<App> ();

            foreach (TreeItem item in category.get_contents ()) {
                App app;
                switch (item.get_type ()) {
                    case TreeItemType.DIRECTORY:
                        apps.add_all (get_apps ((TreeDirectory) item));
                        break;
                    case TreeItemType.ENTRY:
                        if (is_entry ((TreeEntry) item)) {
                            app = new App ((TreeEntry) item);
                            if (apps.contains (app) == false) {
                                apps.add (app);
                            }
                        }
                        break;
                }
            }
            return apps;

        }

        private static bool is_entry (TreeEntry entry) {

            if (entry.get_launch_in_terminal () == false 
                && entry.get_is_nodisplay () == false) {
                return true;
            } else {
                return false;
            }

        }

    }

}
