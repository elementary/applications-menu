/*
 * Copyright (C) 2013 Jan Hrdina <jan.hrdka@gmail.com>
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
namespace Synapse
{

  public class ChromiumPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }
    
    private class BookmarkMatch : Object, Match, UriMatch
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      // from UriMatch interface
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }
      
      private string? title_folded = null;
      private string? uri_folded = null;
      
      public unowned string get_title_folded ()
      {
        if (title_folded == null) title_folded = title.casefold ();
        return title_folded;
      }
      
      public unowned string get_uri_folded ()
      {
          if (uri_folded == null) uri_folded = uri.casefold ();
        return uri_folded;
      }
      
      public BookmarkMatch.with_content (string name, string url)
      {
        Object (title: name,
                description: url,
                uri: url,
                match_type: MatchType.GENERIC_URI,
                has_thumbnail: false, icon_name: "text-html");
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (ChromiumPlugin),
        _ ("Chromium Plugin"),
        _ ("Browse and open Chromium bookmarks."),
        "chromium",
        register_plugin,
        Environment.find_program_in_path ("chromium") != null,
        _ ("Chromium is not installed")
      );
    }
 
    static construct
    {
      register_plugin ();
    }
    
    private Utils.AsyncOnce<Gee.List<BookmarkMatch>> bookmarks_once;
    
    construct
    {
      bookmarks_once = new Utils.AsyncOnce<Gee.List<BookmarkMatch>> ();
    }
    
    private void full_search (Query q, ResultSet results,
                              MatcherFlags flags = 0)
    {
      // try to match against global matchers and if those fail, try also exec
      var matchers = Query.get_matchers_for_query (q.query_string_folded, flags);
      
      foreach (var bmk in bookmarks_once.get_data())
      {
        unowned string name = bmk.get_title_folded ();
        unowned string url = bmk.get_uri_folded ();
        
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (name))
          {
            results.add (bmk, matcher.value);
            break;
          }
          if (url != null && matcher.key.match (url))
          {
            results.add (bmk, matcher.value);
            break;
          }
        }
      }
    }
 
    public bool handles_query (Query query)
    {
      return (QueryFlags.INTERNET in query.query_type);
    }
 
    public async ResultSet? search (Query q) throws SearchError
    {
      var result = new ResultSet ();
      
      if (!bookmarks_once.is_initialized ())
      {
        yield parse_bookmarks ();
      }

      if (q.query_string.length == 1)
      {
        var flags = MatcherFlags.NO_SUBSTRING | MatcherFlags.NO_PARTIAL |
                    MatcherFlags.NO_FUZZY;
        full_search (q, result, flags);
      }
      else
      {
        full_search (q, result);
      }
      
      q.check_cancellable ();
      
      return result;
    }
    
    
    /* Bookmarks parsing methods */
    
    private static bool is_container (Json.Object o, string container_string) 
    {
      return o.get_string_member ("type") == container_string;
    }
    
    private static bool is_bookmark (Json.Object o)
    {
      return o.has_member ("url");
    }
    
    private static bool is_good (Json.Object o, Gee.HashSet<string> unwanted_scheme)
    {
      return !unwanted_scheme.contains (o.get_string_member ("url")
                                        .split (":", 1)[0]);
    }
    
    private async void parse_bookmarks ()
    {
      var is_locked = yield bookmarks_once.enter ();
      if (!is_locked) return;

      var bookmarks = new Gee.ArrayList<BookmarkMatch> ();
      var parser = new Json.Parser ();
      string fpath = GLib.Path.build_filename (
        Environment.get_user_config_dir (), "chromium", "Default", "Bookmarks");
      
      string CONTAINER = "folder";
      Gee.HashSet<string> UNWANTED_SCHEME = new Gee.HashSet<string> ();
      UNWANTED_SCHEME.add ("data");
      UNWANTED_SCHEME.add ("place");
      UNWANTED_SCHEME.add ("javascript");
      
      List<unowned Json.Node> folders = new List<Json.Node> ();
      
      try
      {
        File f = File.new_for_path (fpath);
        var input_stream = yield f.read_async (Priority.DEFAULT);
        yield parser.load_from_stream_async (input_stream);

        var root_object = parser.get_root ().get_object ();
        folders.concat (root_object.get_member ("roots").get_object ()
                                   .get_member ("bookmark_bar").get_object ()
                                   .get_array_member ("children").get_elements ());
        folders.concat (root_object.get_member ("roots").get_object ()
                                   .get_member ("other").get_object ()
                                   .get_array_member ("children").get_elements ());
        
        Json.Object o;
        foreach (var item in folders)
        {
          o = item.get_object ();
          if (is_bookmark (o) && is_good (o, UNWANTED_SCHEME))
          {
            bookmarks.add (new BookmarkMatch.with_content (
                o.get_string_member ("name"),
                o.get_string_member ("url")));
          }
          if (is_container (o, CONTAINER))
          {
            folders.concat(o.get_array_member ("children").get_elements ());
          }
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      bookmarks_once.leave (bookmarks);
    }
  }
}
