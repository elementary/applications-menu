/*
* Copyright (c) 2019 Ranfdev <ranfdev@gmail.com>
*               2019 elementary LLC.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Ranfdev <ranfdev@gmail.com>
*/

namespace Synapse {
    public class WindowSwitcherPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (typeof (WindowSwitcherPlugin),
                                                                    "Window switcher",
                                                                    _("Search and open active windows"),
                                                                    "switcher",
                                                                    register_plugin);
        }

        static construct {
            register_plugin ();
        }


        public signal void load_complete ();

        public class WindowMatch: Object, Match {
          public string title { get; construct set; }
          public string description { get; set; default = "";}
          public string icon_name { get; construct set; }
          public bool has_thumbnail { get; construct set; }
          public string thumbnail_path { get; construct set; }
          public MatchType match_type { get; construct set; default = MatchType.WINDOW; }

          public WindowMatch(string new_title, string new_icon_name) {
            title = new_title; 
            icon_name = new_icon_name; 
          }

          public void execute(Match? match) {
            var w_match = (WindowMatch) match;
          }
        }
        public bool handles_query (Query q) {
          return true;
        }

        public async ResultSet? search (Query q) throws SearchError {
          unowned List<Wnck.Window> windows = Wnck.Screen.get_default().get_windows();
          var results = new ResultSet();
          foreach (var window in windows) {
            var match = new WindowMatch(
              window.get_name(), 
              window.get_icon_name()
            );
            results.add(match, Match.Score.HIGHEST);
          }
          return results;
        }
    }
}
