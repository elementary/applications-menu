/*
* Copyright (c) 2015 Peter Arnold
*               2017 elementary LLC.
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
* Authored by: Peter Arnold
*/

namespace Synapse {
    public class SwitchboardPlugin : Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public SwitchboardPlugin() { }

        public void activate () { }

        public void deactivate () { }

        public class SwitchboardObject: Object, Match {
            // for Match interface
            public string title { get; construct set; }
            public string description { get; set; default = ""; }
            public string icon_name { get; construct set; default = ""; }
            public bool has_thumbnail { get; construct set; default = false; }
            public string thumbnail_path { get; construct set; }
            public MatchType match_type { get; construct set; }

            public string plug { get; construct set; }
            public string uri { get; construct set; }

            public SwitchboardObject (PlugInfo plug_info) {
                Object (title: plug_info.title, description: _("Open %s settings").printf (plug_info.title),
                        plug: plug_info.code_name, icon_name: plug_info.icon, match_type: MatchType.APPLICATION, uri: plug_info.uri);
            }

            public void execute (Match? match) {
                try {
                    Gtk.show_uri (null, "settings://%s".printf (uri), Gdk.CURRENT_TIME);
                } catch (Error e) {
                    warning ("Failed to show URI for %s: %s\n".printf (uri, e.message));
                }
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (typeof (SwitchboardPlugin),
                                                                    "Switchboard Search",
                                                                    _("Find switchboard plugs and open them."),
                                                                    "preferences-desktop",
                                                                    register_plugin);
        }

        static construct {
            register_plugin ();
        }
        private Gee.ArrayList<PlugInfo> plugs;

        construct {
            plugs = new Gee.ArrayList<PlugInfo> ();
            load_plugs.begin ();
        }

        public class PlugInfo : GLib.Object {
            public string title { get; construct set; }
            public string code_name { get; construct set; }
            public string icon { get; construct set; }
            public string uri { get; construct set; }
            public string[] path { get; construct set; }

            public PlugInfo (string plug_title, string code_name, string icon, string uri, string[] path = {}) {
                Object (title: plug_title, code_name: code_name, icon: icon, uri: uri, path: path);
            }
        }

        private bool loading_in_progress = false;
        public signal void load_complete ();

        private async void load_plugs () {
            loading_in_progress = true;
            Idle.add_full (Priority.LOW, load_plugs.callback);
            yield;

            var plugs_manager = Switchboard.PlugsManager.get_default ();
            foreach (var plug in plugs_manager.get_plugs ()) {
                var settings = plug.supported_settings;
                if (settings == null || settings.size <= 0) {
                    continue;
                }
                
                string uri = settings.keys.to_array ()[0];
                plugs.add (new PlugInfo (plug.display_name, plug.code_name, plug.icon, uri));
                
                // Using search to get sub settings
                var search_results = yield plug.search ("");
                foreach (var result in search_results.entries) {
                    var title = result.key;
                    var view =  result.value;
                    if (view == "") continue;
                                        
                    // get uri from plug's supported_settings
                    string? sub_uri = null;
                    foreach (var setting in settings.entries) {
                        if (setting.value == view) {
                            sub_uri = setting.key;
                            break;
                        }
                    }
                    if (sub_uri == null) continue;
                    
                    string[] path = title.split(" → ");
                    
                    plugs.add (new PlugInfo (title, "", plug.icon, sub_uri, path));
                }
            }

            // Unload all the plugs
            plugs_manager.unref ();

            loading_in_progress = false;
            load_complete ();
        }

        public async ResultSet? search (Query q) throws SearchError {
            if (loading_in_progress) {
                // wait
                ulong signal_id = this.load_complete.connect (() => {
                    search.callback ();
                });
                yield;
                SignalHandler.disconnect (this, signal_id);
            } else {
                Idle.add_full (Priority.HIGH_IDLE, search.callback);
                yield;
            }

            var result = new ResultSet ();
            MatcherFlags flags;
            if (q.query_string.length == 1) {
                flags = MatcherFlags.NO_SUBSTRING | MatcherFlags.NO_PARTIAL | MatcherFlags.NO_FUZZY;
            } else {
                flags = 0;
            }
            var matchers = Query.get_matchers_for_query (q.query_string_folded, flags);

            string stripped = q.query_string.strip ();
            if (stripped == "") {
                return null;
            }

            foreach (var plug in plugs) {
                // Retrieve the string that this plug/setting can be searched by
                string searchable_name = plug.path.length > 0 ? plug.path[plug.path.length-1] : plug.title;
                foreach (var matcher in matchers) {
                    MatchInfo info;
                    if (matcher.key.match (searchable_name.down(), 0, out info)) {
                        result.add (new SwitchboardObject (plug), Match.Score.AVERAGE + Match.Score.INCREMENT_MEDIUM);
                        break;
                    }
                }
            }
            q.check_cancellable ();

            return result;
        }
    }
}
