/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Slingshot.Backend {

    public errordomain SearchError {
        SEARCH_CANCELLED,
        UNKNOWN_ERROR
    }
  
    public interface SearchProvider : Object {

        public abstract async Gee.List<Match> search (string query,
                                                      QueryFlags flags,
                                                      ResultSet? dest_result_set,
                                                      Cancellable? cancellable = null) throws SearchError;
    }

    // don't move into a class, gir doesn't like it
    [CCode (has_target = false)]
    public delegate void PluginRegisterFunc ();

    public class DataSink : Object, SearchProvider {
  
        private Gee.Set<ItemProvider> item_plugins;
        private Gee.Set<ActionProvider> action_plugins;
        private uint query_id;
        // data sink will keep reference to the name cache, so others will get this
        // instance on call to get_default()
        private DBusService dbus_name_cache;
        private DesktopFileService desktop_file_service;
        private PluginRegistry registry;
        private RelevancyService relevancy_service;
        private VolumeService volume_service;
        private Type[] plugin_types;

        construct {

            item_plugins = new Gee.HashSet<ItemProvider> ();
            action_plugins = new Gee.HashSet<ActionProvider> ();
            plugin_types = {};
            query_id = 0;

            var cfg = ConfigService.get_default ();
            config = (DataSinkConfiguration)
                     cfg.get_config ("data-sink", "global", typeof (DataSinkConfiguration));

            // oh well, yea we need a few singletons
            registry = PluginRegistry.get_default ();
            relevancy_service = RelevancyService.get_default ();
            volume_service = VolumeService.get_default ();

            initialize_caches ();
            register_static_plugin (typeof (CommonActions));
        }


        public DataSink () {
        }

        ~DataSink () {
            debug ("DataSink died...");
        }


        private async void initialize_caches () {

            int initialized_components = 0;
            int NUM_COMPONENTS = 2;

            dbus_name_cache = DBusService.get_default ();
            ulong sid1 = dbus_name_cache.initialization_done.connect (() => {

                    initialized_components++;
                    if (initialized_components >= NUM_COMPONENTS) {
                        initialize_caches.callback ();
                    }
                    });

            desktop_file_service = DesktopFileService.get_default ();
            desktop_file_service.reload_done.connect (this.check_plugins);
            ulong sid2 = desktop_file_service.initialization_done.connect (() => {

                    initialized_components++;
                    if (initialized_components >= NUM_COMPONENTS) {
                        initialize_caches.callback ();
                    }

                    });

            yield;
            SignalHandler.disconnect (dbus_name_cache, sid1);
            SignalHandler.disconnect (desktop_file_service, sid2);

            Idle.add (() => { this.load_plugins (); return false; });
        }

        public bool has_empty_handlers { get; set; default = false; }
        public bool has_unknown_handlers { get; set; default = false; }

        [Signal (detailed = true)]
            public signal void search_done (ResultSet rs, uint query_id);

        public async Gee.List<Match> search (string query,
                QueryFlags flags,
                ResultSet? dest_result_set,
                Cancellable? cancellable = null) throws SearchError
        {
            // wait for our initialization
            while (!plugins_loaded)
            {
                Timeout.add (100, search.callback);
                yield;
                if (cancellable != null && cancellable.is_cancelled ())
                {
                    throw new SearchError.SEARCH_CANCELLED ("Cancelled");
                }
            }
            var q = Query (query_id++, query, flags);
            string query_stripped = query.strip ();

            var cancellables = new GLib.List<Cancellable> ();

            var current_result_set = dest_result_set ?? new ResultSet ();
            int search_size = item_plugins.size;
            // FIXME: this is probably useless, if async method finishes immediately,
            // it'll call complete_in_idle
            bool waiting = false;

            foreach (var data_plugin in item_plugins)
            {
                bool skip = !data_plugin.enabled ||
                    (query == "" && !data_plugin.handles_empty_query ()) ||
                    !data_plugin.handles_query (q);
                if (skip)
                {
                    search_size--;
                    continue;
                }
                // we need to pass separate cancellable to each plugin, because we're
                // running them in parallel
                var c = new Cancellable ();
                cancellables.prepend (c);
                q.cancellable = c;
                // magic comes here
                data_plugin.search.begin (q, (src_obj, res) =>
                        {
                        var plugin = src_obj as ItemProvider;
                        try
                        {
                        var results = plugin.search.end (res);
                        this.search_done[plugin.get_type ().name ()] (results, q.query_id);
                        current_result_set.add_all (results);
                        }
                        catch (SearchError err)
                        {
                        if (!(err is SearchError.SEARCH_CANCELLED))
                        {
                        warning ("%s returned error: %s",
                            plugin.get_type ().name (), err.message);
                        }
                        }

                        if (--search_size == 0 && waiting) search.callback ();
                        });
            }
            cancellables.reverse ();

            if (cancellable != null)
            {
                CancellableFix.connect (cancellable, () =>
                        {
                        foreach (var c in cancellables) c.cancel ();
                        });
            }

            waiting = true;
            if (search_size > 0) yield;

            if (cancellable != null && cancellable.is_cancelled ())
            {
                throw new SearchError.SEARCH_CANCELLED ("Cancelled");
            }

            if (has_unknown_handlers && query_stripped != "")
            {
                var unknown_match = new DefaultMatch (query);
                bool add_to_rs = false;
                if (QueryFlags.ACTIONS in flags || QueryFlags.TEXT in flags)
                {
                    // FIXME: maybe we should also check here if there are any matches
                    add_to_rs = true;
                }
                else
                {
                    // check whether any of the actions support this category
                    var unknown_match_actions = find_actions_for_unknown_match (unknown_match, flags);
                    if (unknown_match_actions.size > 0) add_to_rs = true;
                }

                if (add_to_rs) current_result_set.add (unknown_match, 0);
            }

            return current_result_set.get_sorted_list ();
        }

        protected Gee.List<Match> find_actions_for_unknown_match (Match match,
                QueryFlags flags)
        {
            var rs = new ResultSet ();
            var q = Query (0, "", flags);
            foreach (var action_plugin in action_plugins)
            {
                if (!action_plugin.enabled) continue;
                if (!action_plugin.handles_unknown ()) continue;
                rs.add_all (action_plugin.find_for_match (q, match));
            }

            return rs.get_sorted_list ();
        }

        public Gee.List<Match> find_actions_for_match (Match match, string? query,
                QueryFlags flags)
        {
            var rs = new ResultSet ();
            var q = Query (0, query ?? "", flags);
            foreach (var action_plugin in action_plugins)
            {
                if (!action_plugin.enabled) continue;
                rs.add_all (action_plugin.find_for_match (q, match));
            }

            return rs.get_sorted_list ();
        }
    }
}
