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
//  Thanks to Synapse Developers
//

namespace Slingshot.Backend {

    public interface Match : GLib.Object {

        public enum Score {
            INCREMENT_MINOR = 2000,
            INCREMENT_SMALL = 5000,
            INCREMENT_MEDIUM = 10000,
            INCREMENT_LARGE = 20000,
            URI_PENALTY = 15000,

            POOR = 50000,
            BELOW_AVERAGE = 60000,
            AVERAGE = 70000,
            ABOVE_AVERAGE = 75000,
            GOOD = 80000,
            VERY_GOOD = 85000,
            EXCELLENT = 90000,

            HIGHEST = 100000
        }

        public abstract string title { get; construct set; }
        public abstract string description { get; set; }
        public abstract string icon_name { get; set; }
        
        public abstract AppInfo? app_info { get; set; }
        public abstract bool needs_terminal { get; set; }
        public abstract string? filename { get; construct set; }

    }

    public class AppMatch : Match, GLib.Object {

        public string title { get; construct set; }
        public string description { get; set; }
        public string icon_name { get; set; }
        
        public AppInfo? app_info { get; set; }
        public bool needs_terminal { get; set; }
        public string? filename { get; construct set; }
    
        public AppMatch (string query_string) {

            Object (title: query_string, description: "", 
                    icon_name: "unknown");

        }

    }

}
