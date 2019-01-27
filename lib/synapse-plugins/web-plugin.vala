/*
 * Copyright (c) 2019 elementary LLC.
 *               2019 Matthew Olenik <olenikm@gmail.com>
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
 * Authored by: Matthew Olenik <olenikm@gmail.com>
 */

public class Synapse.WebPlugin: Object, Activatable, ItemProvider {

    class SearchEngine {
        public string url_template;
        public string description_template;
    }

    public class Result : Object, Match {
        // From Match interface
        public string title { get; construct set; }
        public string description { get; set; }
        public string icon_name { get; construct set; }
        public bool has_thumbnail { get; construct set; }
        public string thumbnail_path { get; construct set; }
        public MatchType match_type { get; construct set; }

        AppInfo? browser;
        string search_url;  // Final URL to be launched in the browser
        bool web_search_enabled;
        const string DEFAULT_ENGINE_ID = "duckduckgo";
        const string CUSTOM_ENGINE_ID = "custom";

        public Result (string search) {
            browser = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
            if (browser == null) {
                return;
            }
            web_search_enabled = gsettings.get_boolean ("web-search-enabled");
            if (!web_search_enabled) {
                return;
            }

            var engine_id = gsettings.get_string ("web-search-engine-id");
            if (!search_engines.has_key (engine_id) && engine_id != CUSTOM_ENGINE_ID) {
                /* This block should not be reached unless the setting have been tampered with. */
                warning ("Invalid search engine found in gsettings, reverting to default");
                engine_id = DEFAULT_ENGINE_ID;
                gsettings.set_string ("web-search-engine-id", engine_id);
            }

            var custom_url = gsettings.get_string ("web-search-custom-url");
            var url_template = engine_id == CUSTOM_ENGINE_ID ? custom_url : search_engines[engine_id].url_template;
            var description_template = get_description_template (engine_id, custom_url);
            search_url = url_template.replace ("{query}", Uri.escape_string (search));

            title = description_template.printf (search);
            icon_name = browser.get_icon ().to_string ();
            description = _("Search the web");
            has_thumbnail = false;
            match_type = MatchType.ACTION;
        }

        public void execute (Match? match) {
            if (!web_search_enabled || browser == null) {
                return;
            }
            if (!url_regex.match (search_url)) {
                show_error (_("The custom search URL is invalid, please reconfigure it in System Settings."));
                return;
            }
            try {
                var list = new List<string> ();
                list.append (search_url);
                if (!browser.launch_uris (list, null)) {
                    show_error (null);
                    return;
                }
            } catch (Error e) {
                show_error (e.message);
                return;
            }
        }

        /* Given an engine_id, find the correct description phrasing template.
         * This is the string in that UI that looks like "Search for %s on searchengine.com"
         */
        string get_description_template (string engine_id, string custom_url) {
            /* For custom search, rather than having the user bother to enter an ID/name for the search engine,
               simply use the domain name of the provider.
             */
            if (engine_id == CUSTOM_ENGINE_ID) {
                var url_template = custom_url;
                var fqdn = get_name_from_url (url_template);
                // TRANSLATORS: This is the first part of the phrase "Search for %s on searchengine.com"
                var custom_description = _("Search for %s on");
                return custom_description + " " + fqdn;
            }
            return search_engines[engine_id].description_template;
        }

        /* There should rarely be a failure opening an https link, but if there is,
         * surface the error to the user in a MessageDialog.
         */
        void show_error (string? message) {
            var error_message = _("Failed to launch web search");
            var error_text = error_message.printf (search_url, browser.get_name ());
            warning (error_text);
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Web Search Failed"),
                error_text,
                "dialog-error");
            if (message != null) {
                /* Widen dialog when showing error details */
                dialog.primary_label.max_width_chars = 60;
                dialog.primary_label.width_chars = 60;
                dialog.show_error_details (message);
            }
            dialog.run ();
            dialog.destroy ();
        }
    }

    public bool enabled { get; set; default = true; }
    public void activate () { }
    public void deactivate () { }

    static Regex url_regex;                                   // Regex for extracting FQDN portion of URL
    static Gee.HashMap<string, SearchEngine> search_engines;  // Mapping of search engine metadata
    static Settings gsettings;

    public bool handles_query (Query query) {
        return QueryFlags.TEXT in query.query_type;
    }

    public async ResultSet? search (Query query) throws SearchError {
        if (query.query_string.char_count () < 2) {
            return null;
        }
        ResultSet results = new ResultSet ();
        Result search_result = new Result (query.query_string);
        results.add (search_result, Match.Score.BELOW_AVERAGE);
        return results;
    }

    /* Gets an inferred name for a search engine at a given URL */
    static string get_name_from_url (string url) {
        var parts = url_regex.split (url);
        if (parts.length > 2) {
            /* Return FQDN */
            return parts[2];
        }
        /* If no FQDN match found, just return the input.
         * This should only happen if using a custom URL that is invalid.
         */
        return url;
    }

    static construct {
        gsettings = new GLib.Settings ("io.elementary.desktop.wingpanel.applications-menu");

        try {
            /* First capture group is protocol, second is FQDN */
            url_regex = new Regex ("""(\w+:\/\/)([^/:]+)""");
        } catch (RegexError e) {
            error (e.message);
        }

        search_engines = new Gee.HashMap<string, SearchEngine?> ();
        search_engines["google"] = new SearchEngine () {
            url_template = _("https://www.google.com/search?q={query}"),
            description_template = _("Search the web for %s with Google")
        };
        search_engines["bing"] = new SearchEngine () {
            url_template = _("https://www.bing.com/search?q={query}"),
            description_template = _("Search the web for %s with Bing")
        };
        search_engines["duckduckgo"] = new SearchEngine () {
            url_template = _("https://duckduckgo.com/?q={query}"),
            description_template = _("Search the web for %s with DuckDuckGo")
        };
        search_engines["yahoo"] = new SearchEngine () {
            url_template = _("https://search.yahoo.com/search?p={query}"),
            description_template = _("Search the web for %s with Yahoo!")
        };
        search_engines["yandex"] = new SearchEngine () {
            url_template = _("https://yandex.com/search/?text={query}"),
            description_template = _("Search the web for %s with Yandex")
        };
        search_engines["baidu"] = new SearchEngine () {
            url_template = _("https://www.baidu.com/s?wd={query}"),
            description_template = _("Search the web for %s with Baidu")
        };

        register_plugin ();
    }

    static void register_plugin () {
        DataSink.PluginRegistry.get_default ().register_plugin (
            typeof (WebPlugin),
            _("Web"),
            _("Search the web"),
            "web-browser",
            register_plugin);
    }
}
