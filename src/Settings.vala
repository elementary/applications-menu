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

namespace Slingshot {
    GLib.Settings settings;

    public class Settings {

        public int columns {
            get {return settings.get_int ("columns");}
            set {settings.set_int ("columns", value);}
        }
        public int rows {
            get {return settings.get_int ("rows");}
            set {settings.set_int ("rows", value);}
        }
        public int icon_size {
            get {return settings.get_int ("icon-size");}
            set {settings.set_int ("icon-size", value);}
        }
        public bool show_category_filter {
            get {return settings.get_boolean ("show-category-filter");}
            set {settings.set_boolean ("show-category-filter", value);}
        }
        public bool open_on_mouse {
            get {return settings.get_boolean ("open-on-mouse");}
            set {settings.set_boolean ("open-on-mouse", value);}
        }
        public bool use_category {
            get {return settings.get_boolean ("use-category");}
            set {settings.set_boolean ("use-category", value);}
        }
        public string screen_resolution {
            get {return (settings.get_string ("screen-resolution").to_string ());} //to_string () is required to avoid ownership problems
            set {settings.set_string ("screen-resolution", value);}
        }

        public Settings () {
              settings = new GLib.Settings ("org.pantheon.slingshot");
        }

    }

}
