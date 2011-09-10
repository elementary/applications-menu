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

using Granite.Services;

namespace Slingshot {

    public enum BackgroundColor {

        BLACK = 0,
        GREY = 1,
        RED = 2,
        BLUE = 3,
        GREEN = 4

    }

    public class Settings : Granite.Services.Settings {

        public int width { get; set; }
        public int height { get; set; }
        public int icon_size { get; set; }
        public bool show_category_filter { get; set; }
        public BackgroundColor background_color { get; set; }

        public Settings () {
            base ("desktop.pantheon.slingshot");
        }

    }

}
