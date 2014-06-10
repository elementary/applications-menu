/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
	public class UserSearchPlugin : Object, Activatable, ActionProvider
	{
		enum Browser
		{
			CHROME,
			CHROMIUM,
			FIREFOX,
			MIDORI,
			// AURORA TODO
			UNKNOWN
		}

		public bool enabled { get; set; default = true; }

		private Browser default_browser;

		public void activate ()
		{
			var default_browser_id = AppInfo.get_default_for_uri_scheme ("http").get_id ();

			if ("chromium" in default_browser_id)     default_browser = Browser.CHROMIUM;
			else if ("google" in default_browser_id)  default_browser = Browser.CHROME;
			else if ("midori" in default_browser_id)  default_browser = Browser.MIDORI;
			else if ("firefox" in default_browser_id) default_browser = Browser.FIREFOX;

			string? name = null;
			string? url = null;

			switch (default_browser) {
				case Browser.CHROMIUM:
				case Browser.CHROME:
					get_info_for_chromium_like (default_browser, out name, out url);
					break;
				case Browser.FIREFOX:
					get_info_for_firefox_like (default_browser, out name, out url);
					break;
				case Browser.MIDORI:
					get_info_for_midori (out name, out url);
					break;
			}

			// TODO replace this fallback with a gsettings key
			if (url == null) {
				name = "Google";
				url = "http://www.google.com/search?q={searchTerms}";
			}

			// if we only failed to detect the name, use a fallback
			string title;
			if (name == null)
				title = _("Search the web");
			else
				title = _("Search with %s").printf (name);

			actions = new Gee.ArrayList<SearchAction> ();
			actions.add (new SearchAction (title, url));
		}

		void get_info_for_chromium_like (Browser exact_type, out string name, out string url)
		{
			name = null;
			url = null;

			try {
				var file = FileStream.open (Path.build_filename (Environment.get_user_config_dir (), 
					default_browser == Browser.CHROME ? "google-chrome" : "chromium",
					"Default", "Preferences"), "r");

				var json_value_regex = new Regex ("\"[^\"]*: \"([^\"]*)");

				// the file is quite giant, it may have around 4k lines. The relevant part appears to be
				// located in the first 100 lines in most cases, so we go line by line instead of having
				// a proper parser go through the entire file.
				MatchInfo match;
				bool found_search_provider = false;
				string? line = null;
				while ((line = file.read_line ()) != null) {
					if (found_search_provider) {
						// we found everything, finish
						if (name != null && url != null)
							break;

						if ("\"name\":" in line) {
							json_value_regex.match (line, 0, out match);
							name = match.fetch (1);
						} else if ("\"search_url\":" in line) {
							json_value_regex.match (line, 0, out match);
							url = match.fetch (1);

							if (url != null) {
								// for google's default search, there are plenty of variables we don't need
								// to fill, so we delete them
								var clean_regex = new Regex ("{google:\\w*}");
								url = url.replace ("{google:baseURL}", "http://google.com/")
									.replace ("{inputEncoding}", "");
								url = clean_regex.replace (url, url.length, 0, "");
							}
						}

					} else if ("\"default_search_provider\": {" in line) {
						found_search_provider = true;
					}
				}
			} catch (Error e) { warning ("Loading search engine from chrome/ium failed: %s", e.message); }
		}

		void get_info_for_midori (out string name, out string url)
		{
			name = null;
			url = null;

			try {
				var config = new KeyFile ();
				config.load_from_file (Path.build_filename (Environment.get_user_config_dir (),
					"midori", "config"), 0);

				url = config.get_string ("settings", "location-entry-search");
				if (url == null)
					return;

				var engines = new KeyFile ();
				engines.load_from_file (Path.build_filename (Environment.get_user_config_dir (),
					"midori", "search"), 0);

				foreach (var group in engines.get_groups ()) {
					if (engines.get_string (group, "uri") == url) {
						name = engines.get_string (group, "name");
						break;
					}
				}

				if (name == null)
					name = new Soup.URI (url).host;

				if (!("%s" in url))
					url += "{searchTerms}";
				else
					url = url.replace ("%s", "{searchTerms}");
			} catch (Error e) { warning ("Loading search engine from midori failed: %s", e.message); }
		}

		void get_info_for_firefox_like (Browser exact_type, out string name, out string url)
		{
			name = null;
			url = null;

			try {
				// first get the default profile
				var profiles_ini = new KeyFile ();
				profiles_ini.load_from_file (Path.build_filename (Environment.get_home_dir (),
					".mozilla", "firefox", "profiles.ini"), 0);

				var profile_path = profiles_ini.get_string ("Profile0", "Path");

				// now get the name of the default search engine for that profile
				var prefs = FileStream.open (Path.build_filename (Environment.get_home_dir (),
					".mozilla", "firefox", profile_path, "prefs.js"), "r");

				var engine_name_regex = new Regex ("user_pref\\(\"browser\\.search\\.defaultenginename\", \"([^\"]*)");
				MatchInfo match;

				string? line = null;
				while ((line = prefs.read_line ()) != null) {
					if (line.has_prefix ("user_pref(\"browser.search.defaultenginename\"")) {
						engine_name_regex.match (line, 0, out match);
						name = match.fetch (1);
						break;
					}
				}

				if (name == null)
					return;

				// lastly get the info about the url for that search engine
				var parser = new Json.Parser ();
				var stream = File.new_for_path (Path.build_filename (Environment.get_home_dir (),
						".mozilla", "firefox", profile_path, "search.json")).read ();

				parser.load_from_stream (stream);

				var providers = parser.get_root ().get_object ().get_member ("directories").get_object ().get_values ();
				foreach (var provider in providers) {
					var engines = provider.get_object ().get_member ("engines").get_array ();

					foreach (var engine in engines.get_elements ()) {
						var engine_object = engine.get_object ();

						if (engine_object.get_member ("_name").get_string () == name) {
							foreach (var u in engine_object.get_member ("_urls").get_array ().get_elements ()) {
								var url_object = u.get_object ();
								if (url_object.has_member ("type")
									&& url_object.get_member ("type").get_string () == "application\\/x-suggestions+json")
									continue;

								var url_base = url_object.get_member ("template").get_string () + "?";

								foreach (var param in url_object.get_member ("params").get_array ().get_elements ()) {
									var param_object = param.get_object ();
									var key = param_object.get_member ("name").get_string ();
									var val = param_object.get_member ("value").get_string ();

									// FIXME we're skipping language keys for now. Some engines apparently use it, but
									// not many and in most cases your language is probably picked up anyway
									if ("{moz:locale}" in val)
										continue;

									url_base += key + "=" + val + "&";
								}

								url = url_base;
								break;
							}
							break;
						}

						if (url != null)
							break;
					}

					if (url != null)
						break;
				}
			} catch (Error e) { warning ("Loading search engine from firefox failed: %s", e.message); }
		}

		public void deactivate ()
		{
		}

		private class SearchAction : Object, Match
		{
			public string title { get; construct set; }
			public string description { get; set; }
			public string icon_name { get; construct set; }
			public bool has_thumbnail { get; construct set; }
			public string thumbnail_path { get; construct set; }
			public MatchType match_type { get; construct set; }

			public int default_relevancy { get; set; default = Match.Score.INCREMENT_MINOR; }
			public string query_template { get; set; default = ""; }

			public void execute (Match? match)
			{
				try {
					string what = (match is TextMatch) ?
						(match as TextMatch).get_text () : match.title;

					print ("ASKJDSD: %s\n", query_template);
					AppInfo.launch_default_for_uri (query_template.replace ("{searchTerms}", what),
						new Gdk.AppLaunchContext ());
				} catch (Error err) {
					warning ("%s", err.message);
				}
			}

			public SearchAction (string name, string url)
			{
				Object (title: name,
					description: _("Start an internet search"),
					query_template: url,
					has_thumbnail: false, icon_name: "applications-internet");
			}
		}

		static void register_plugin ()
		{
			DataSink.PluginRegistry.get_default ().register_plugin (
					typeof (OpenSearchPlugin),
					"OpenSearch",
					_ ("Search the web."),
					"applications-internet",
					register_plugin
					);
		}

		static construct
		{
			register_plugin ();
		}

		private Gee.List<SearchAction> actions;

		public bool handles_unknown ()
		{
			return true;
		}

		public ResultSet? find_for_match (ref Query query, Match match)
		{
			if (match.match_type != MatchType.UNKNOWN &&
				match.match_type != MatchType.TEXT) {
				return null;
			}

			var my_flags = QueryFlags.ACTIONS | QueryFlags.INTERNET;
			if ((query.query_type & my_flags) == 0) return null;

			bool query_empty = query.query_string == "";
			var results = new ResultSet ();

			if (query_empty) {
				foreach (var action in actions) {
					results.add (action, action.default_relevancy);
				}
			} else {
				var matchers = Query.get_matchers_for_query (query.query_string, 0,
						RegexCompileFlags.CASELESS);
				foreach (var item in actions) {
					foreach (var matcher in matchers) {
						if (matcher.key.match (item.title)) {
							results.add (item, matcher.value);
							break;
						}
					}
				}
			}

			return results;
		}
	}
}

