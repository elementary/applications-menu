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

        GMenu.Tree apps_tree;
        HashTable entry_to_app;

        construct {

            apps_tree = GMenu.Tree.lookup ("applications.menu", TreeFlags.INCLUDE_NODISPLAY);

        }

        public static void lookup_app (string id) {

        }

        public static List get_all () {

            ArrayList<App> apps = new ArrayList<App> ();

        }

    }

}
