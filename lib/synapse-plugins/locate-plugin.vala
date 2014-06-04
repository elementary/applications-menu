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
  public class LocatePlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class MatchObject: Object, Match, UriMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for FileMatch
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }

      public MatchObject (string? thumbnail_path, string? icon)
      {
        Object (match_type: MatchType.GENERIC_URI,
                has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");
      }
    }

    private class LocateItem: Object, SearchProvider, Match, SearchMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public int default_relevancy { get; set; default = Match.Score.INCREMENT_SMALL; }
      // for SearchMatch interface
      public Match search_source { get; set; }
      public async Gee.List<Match> search (string query,
                                           QueryFlags flags,
                                           ResultSet? dest_result_set,
                                           Cancellable? cancellable = null) throws SearchError
      {
        var q = Query (0, query, flags);
        q.cancellable = cancellable;
        ResultSet? results = yield plugin.locate (q);
        dest_result_set.add_all (results);

        return dest_result_set.get_sorted_list ();
      }

      private unowned LocatePlugin plugin;

      public LocateItem (LocatePlugin plugin)
      {
        Object (match_type: MatchType.SEARCH,
                has_thumbnail: false,
                icon_name: "search",
                title: _ ("Locate"),
                description: _ ("Locate files with this name on the filesystem"));
        this.plugin = plugin;
      }
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (LocatePlugin),
        _ ("Locate"),
        _ ("Runs locate command to find files on the filesystem."),
        "search",
        register_plugin,
        Environment.find_program_in_path ("locate") != null,
        _ ("Unable to find \"locate\" binary")
      );
    }

    static construct
    {
      register_plugin ();
    }

    LocateItem action;

    construct
    {
      action = new LocateItem (this);
    }

    public bool handles_unknown ()
    {
      return true;
    }

    public async ResultSet? locate (Query q) throws SearchError
    {
      var our_results = QueryFlags.AUDIO | QueryFlags.DOCUMENTS
        | QueryFlags.IMAGES | QueryFlags.UNCATEGORIZED | QueryFlags.VIDEO;

      var common_flags = q.query_type & our_results;
      // strip query
      q.query_string = q.query_string.strip ();
      // ignore short searches
      if (common_flags == 0 || q.query_string.length <= 1) return null;

      q.check_cancellable ();

      q.max_results = 256;
      string regex = Regex.escape_string (q.query_string);
      // FIXME: split pattern into words and search using --regexp?
      string[] argv = {"locate", "-i", "-l", "%u".printf (q.max_results),
                       "*%s*".printf (regex.replace (" ", "*"))};

      Gee.Set<string> uris = new Gee.HashSet<string> ();

      try
      {
        Pid pid;
        int read_fd;

        // FIXME: fork on every letter... yey!
        Process.spawn_async_with_pipes (null, argv, null,
                                        SpawnFlags.SEARCH_PATH,
                                        null, out pid, null, out read_fd);

        UnixInputStream read_stream = new UnixInputStream (read_fd, true);
        DataInputStream locate_output = new DataInputStream (read_stream);
        string? line = null;

        Regex filter_re = new Regex ("/\\."); // hidden file/directory
        do
        {
          line = yield locate_output.read_line_async (Priority.DEFAULT_IDLE, q.cancellable);
          if (line != null)
          {
            if (filter_re.match (line)) continue;
            var file = File.new_for_path (line);
            uris.add (file.get_uri ());
          }
        } while (line != null);
      }
      catch (Error err)
      {
        if (!q.is_cancelled ()) warning ("%s", err.message);
      }

      q.check_cancellable ();

      var result = new ResultSet ();

      foreach (string s in uris)
      {
        var fi = new Utils.FileInfo (s, typeof (MatchObject));
        yield fi.initialize ();
        if (fi.match_obj != null && fi.file_type in q.query_type)
        {
          int relevancy = Match.Score.INCREMENT_SMALL; // FIXME: relevancy
          if (fi.uri.has_prefix ("file:///home/")) relevancy += Match.Score.INCREMENT_MINOR;
          result.add (fi.match_obj, relevancy);
        }
        q.check_cancellable ();
      }

      return result;
    }

    public ResultSet? find_for_match (ref Query q, Match match)
    {
      var our_results = QueryFlags.AUDIO | QueryFlags.DOCUMENTS
        | QueryFlags.IMAGES | QueryFlags.UNCATEGORIZED | QueryFlags.VIDEO;

      var common_flags = q.query_type & our_results;
      // ignore short searches
      if (common_flags == 0 || match.match_type != MatchType.UNKNOWN) return null;

      // strip query
      q.query_string = q.query_string.strip ();
      bool query_empty = q.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        results.add (action, action.default_relevancy);
      }
      else
      {
        var matchers = Query.get_matchers_for_query (q.query_string, 0,
          RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            results.add (action, matcher.value);
            break;
          }
        }
      }

      return results;
    }
  }
}
