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

/* 
 * This plugin keeps a cache of file names for directories that are commonly
 * used. 
 */

namespace Synapse
{
  public class HybridSearchPlugin: Object, Activatable, ItemProvider
  {
    public unowned DataSink data_sink { get; construct; }
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

    private class DirectoryInfo
    {
      public string path;
      public TimeVal last_update;
      public Gee.Map<unowned string, Utils.FileInfo?> files;

      public DirectoryInfo (string path)
      {
        this.files = new Gee.HashMap<unowned string, Utils.FileInfo?> ();
        this.path = path;
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (HybridSearchPlugin),
        "Hybrid Search",
        _ ("Improve results returned by the Zeitgeist plugin by looking " +
        "for similar files on the filesystem."),
        "search",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    construct
    {
      directory_hits = new Gee.HashMap<string, int> ();
      directory_contents = new Gee.HashMap<string, Utils.FileInfo?> ();

      analyze_recent_documents ();
    }
    
    private bool initialization_done = false;

    protected override void constructed ()
    {
      data_sink.search_done["SynapseZeitgeistPlugin"].connect (this.zg_plugin_search_done);
    }

    private const string RECENT_XML_NAME = "recently-used.xbel";
    private const int MAX_RECENT_DIRS = 10;

    private async void analyze_recent_documents ()
    {
      var recent = File.new_for_path (Path.build_filename (
        Environment.get_home_dir (), "." + RECENT_XML_NAME, null));

      try
      {
        uint8[] file_contents;
        string contents;
        size_t len;

        bool load_ok;

        try
        {
          load_ok = yield recent.load_contents_async (null,
                                                      out file_contents, null);
        }
        catch (GLib.Error load_error)
        {
          load_ok = false;
        }

        // try again in datadir
        if (!load_ok)
        {
          recent = File.new_for_path (Path.build_filename (
            Environment.get_user_data_dir (), RECENT_XML_NAME, null));
          load_ok = yield recent.load_contents_async (null,
                                                      out file_contents, null);
        }

        if (load_ok)
        {
          contents = (string) file_contents;
          len = file_contents.length;

          // load all uris from recently-used bookmark file
          var bf = new BookmarkFile ();
          bf.load_from_data (contents, len);
          string[] uris = bf.get_uris ();

          // make a <string, int> map of directory occurences for the uris
          Gee.Map<string, int> dir_hits = new Gee.HashMap<string, int> ();

          foreach (unowned string uri in uris)
          {
            var f = File.new_for_uri (uri);
            File? parent = f.get_parent ();
            if (parent == null) continue;
            string? parent_path = parent.get_path ();
            if (parent_path == null) continue;
            dir_hits[parent_path] = dir_hits[parent_path]+1;
          }

          // sort the map according to hits
          Gee.List<Gee.Map.Entry<string, int>> sorted_dirs = new Gee.ArrayList<Gee.Map.Entry<string, int>> ();
          sorted_dirs.add_all (dir_hits.entries);
          sorted_dirs.sort ((a, b) =>
          {
            unowned Gee.Map.Entry<string, int> e1 =
              (Gee.Map.Entry<string, int>) a;
            unowned Gee.Map.Entry<string, int> e2 = 
              (Gee.Map.Entry<string, int>) b;
            return e2.value - e1.value;
          });

          // pick first MAX_RECENT_DIRS items and scan those
          Gee.List<string> directories = new Gee.ArrayList<string> ();
          for (int i=0;
               i<sorted_dirs.size && directories.size<MAX_RECENT_DIRS; i++)
          {
            string dir_path = sorted_dirs[i].key;
            if (dir_path.has_prefix ("/tmp")) continue;
            var dir_f = File.new_for_path (dir_path);
            if (dir_f.is_native ())
            {
              bool exists;
              exists = yield Utils.query_exists_async (dir_f);
              if (exists) directories.add (dir_path);
            }
          }

          yield process_directories (directories);

          int z = 0;
          foreach (var x in directory_contents.entries)
          {
            z += x.value.files.size;
          }
          Utils.Logger.log (this, "keeps in cache now %d file names", z);
        }
      }
      catch (Error err)
      {
        Utils.Logger.warning (this, "Unable to parse %s", recent.get_path ());
      }

      initialization_done = true;
    }

    public signal void zeitgeist_search_complete (ResultSet? rs, uint query_id);
    
    private void zg_plugin_search_done (ResultSet? rs, uint query_id)
    {
      zeitgeist_search_complete (rs, query_id);
    }

    Gee.Map<string, int> directory_hits;
    int hit_level = 0;
    int current_level_uris = 0;

    private async void process_uris (Gee.Collection<string> uris)
    {
      Gee.Set<string> dirs = new Gee.HashSet<string> ();

      foreach (var uri in uris)
      {
        var f = File.new_for_uri (uri);
        try
        {
          if (f.is_native ())
          {
            var fi = yield f.query_info_async (FileAttribute.STANDARD_TYPE,
                                               0, 0, null);
            if (fi.get_file_type () == FileType.REGULAR)
            {
              string? parent_path = f.get_parent ().get_path ();
              if (parent_path != null) dirs.add (parent_path);
            }
          }
        }
        catch (Error err)
        {
          continue;
        }
      }

      int q_len = current_query == null ? 1 : (int) current_query.length;
      foreach (var dir in dirs)
      {
        if (directory_hits.has_key (dir))
        {
          int hit_count = directory_hits[dir];
          directory_hits[dir] = hit_count + q_len;
        }
        else
        {
          directory_hits[dir] = q_len;
        }
      }
    }

    private Gee.List<string> get_most_likely_dirs ()
    {
      int MAX_ITEMS = 2;
      var result = new Gee.ArrayList<string> ();

      if (directory_hits.size <= MAX_ITEMS)
      {
        // too few results, use all we have
        foreach (var dir in directory_hits.keys) result.add (dir);
      }
      else
      {
        var sort_array = new Gee.ArrayList<Gee.Map.Entry<unowned string, int>> ();
        int min_hit = int.MAX;
        foreach (var entry in directory_hits.entries)
        {
          if (entry.value < min_hit) min_hit = entry.value;
        }
        foreach (var entry in directory_hits.entries)
        {
          if (entry.value > min_hit) sort_array.add (entry);
        }
        sort_array.sort ((a, b) =>
        {
          unowned Gee.Map.Entry<unowned string, int> e1 =
            (Gee.Map.Entry<unowned string, int>) a;
          unowned Gee.Map.Entry<unowned string, int> e2 =
            (Gee.Map.Entry<unowned string, int>) b;
          return e2.value - e1.value;
        });

        int count = 0;
        foreach (var entry in sort_array)
        {
          result.add (entry.key);
          if (count++ >= MAX_ITEMS-1) break;
        }
      }

      return result;
    }

    Gee.Map<string, DirectoryInfo> directory_contents;

    private void process_directory_contents (DirectoryInfo di,
                                             File directory,
                                             List<GLib.FileInfo> files)
    {
      di.last_update = TimeVal ();
      foreach (var f in files)
      {
        unowned string name = f.get_name ();
        // ignore common binary files
        if (name.has_suffix (".o") || name.has_suffix (".lo") ||
            name.has_suffix (".mo") || name.has_suffix (".gmo"))
        {
          continue;
        }
        var child = directory.get_child (name);
        var file_info = new Utils.FileInfo (child.get_uri (), typeof (MatchObject));
        di.files[file_info.uri] = file_info;
      }
    }

    private async void update_directory_contents (GLib.File directory,
                                                  DirectoryInfo di) throws Error
    {
      Utils.Logger.debug (this, "Scanning %s", directory.get_path ());
      var enumerator = yield directory.enumerate_children_async (
        FileAttribute.STANDARD_NAME, 0, 0);
      var files = yield enumerator.next_files_async (1024, 0);

      di.files.clear ();
      process_directory_contents (di, directory, files);
    }

    private async void process_directories (Gee.Collection<string> directories)
    {
      foreach (var dir_path in directories)
      {
        var directory = File.new_for_path (dir_path);
        try
        {
          DirectoryInfo di;
          if (directory_contents.has_key (dir_path))
          {
            var cur_time = TimeVal ();
            di = directory_contents[dir_path];
            if (cur_time.tv_sec - di.last_update.tv_sec <= 5 * 60)
            {
              // info fairly fresh, continue
              continue;
            }
          }
          else
          {
            di = new DirectoryInfo (dir_path);
            directory_contents[dir_path] = di;
          }

          yield update_directory_contents (directory, di);
        }
        catch (Error err)
        {
        }
      }
    }

    private async ResultSet get_extra_results (Query q,
                                               ResultSet? original_rs,
                                               Gee.Collection<string>? dirs)
      throws SearchError
    {
      uint num_results = 0;
      bool enough_results = false;
      var results = new ResultSet ();

      // FIXME: casefold the parse_names, so we don't need CASELESS regexes
      //   but first find out if it really saves some time
      var flags = RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS;
      var matchers = Query.get_matchers_for_query (q.query_string,
                                                   MatcherFlags.NO_FUZZY | MatcherFlags.NO_PARTIAL,
                                                   flags);
      Gee.Collection<string> directories = dirs ?? directory_contents.keys;
      foreach (var directory in directories)
      {
        var di = directory_contents[directory];
        // check if we have fresh directory listing
        var dir = File.new_for_path (directory);
        try
        {
          var dir_info = yield dir.query_info_async ("time::*", 0, 0, null);
#if VALA_0_16
          var t = dir_info.get_modification_time ();
#else
          var t = TimeVal ();
          dir_info.get_modification_time (out t);
#endif
          if (t.tv_sec > di.last_update.tv_sec)
          {
            // the directory was changed, let's update
            yield update_directory_contents (dir, di);
          }
        }
        catch (Error err)
        {
          Utils.Logger.warning (this, "%s", err.message);
        }

        var rel_srv = RelevancyService.get_default ();

        // only add the uri if it matches our query
        foreach (var entry in di.files.entries)
        {
          foreach (var matcher in matchers)
          {
            Utils.FileInfo fi = entry.value;
            if (matcher.key.match (fi.parse_name))
            {
              if (original_rs == null || !original_rs.contains_uri (fi.uri))
              {
                bool done_io = false;
                if (!fi.is_initialized ())
                {
                  yield fi.initialize ();
                  done_io = true;
                }
                else if (fi.match_obj != null && fi.file_type in q.query_type)
                {
                  // make sure the file still exists (could be deleted by now)
                  bool exists = yield fi.exists ();
                  if (!exists) break;
                  done_io = true;
                }
                // file info is now initialized
                if (fi.match_obj != null && fi.file_type in q.query_type)
                {
                  //Does match only the path, use base_relevancy like ZG plugin does for non-matched
                  int base_relevancy = Match.Score.POOR + Match.Score.INCREMENT_MINOR;
                  if (matcher.key.match (fi.match_obj.title))
                  {
                    //Matches title! Great news!
                    base_relevancy = matcher.value - Match.Score.URI_PENALTY;
                  }
                  float pop = rel_srv.get_uri_popularity (fi.uri);
                  results.add (fi.match_obj, 
                    RelevancyService.compute_relevancy (base_relevancy, pop));
                  num_results++;
                }

                // the HashMap might have changed, if it did iterator.next ()
                // will fail and we'll crash
                // this here should prevent it, but it still needs more elegant fix
                if (done_io) q.check_cancellable ();
              }
              break;
            }
          }
          if (num_results >= q.max_results)
          {
            enough_results = true;
            break;
          }
        }

        q.check_cancellable ();
        if (enough_results) break;
      }

      if (directories.size == 0) q.check_cancellable ();

      Utils.Logger.debug (this, "found %d extra uris (ZG returned %d)",
        results.size, original_rs == null ? 0 : original_rs.size);

      return results;
    }

    private string? current_query = null;

    public bool handles_query (Query query)
    {
      // we search everything but ACTIONS and APPLICATIONS
      var our_results = QueryFlags.AUDIO | QueryFlags.DOCUMENTS
        | QueryFlags.IMAGES | QueryFlags.UNCATEGORIZED | QueryFlags.VIDEO;
      // FIXME: APPLICATIONS?
      var common_flags = query.query_type & our_results;

      return common_flags != 0;
    }

    public bool processing_query { get; private set; default = false; }

    private async void wait_for_processing_finished ()
    {
      while (processing_query)
      {
        ulong sig_id;
        sig_id = this.notify["processing-query"].connect (() =>
        {
          if (processing_query) return;
          wait_for_processing_finished.callback ();
        });
        yield;

        SignalHandler.disconnect (this, sig_id);
      }
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      // ignore short searches
      if (q.query_string.length <= 1) return null;

      // FIXME: what about deleting one character?
      if (current_query != null && !q.query_string.has_prefix (current_query))
      {
        hit_level = 0;
        current_level_uris = 0;
        directory_hits.clear ();
      }
      
      uint query_id = q.query_id;
      current_query = q.query_string;
      int last_level_uris = current_level_uris;
      ResultSet? original_rs = null;
      Gee.Set<string> uris = new Gee.HashSet<string> ();

      // wait for our signal or cancellable
      ulong sig_id = this.zeitgeist_search_complete.connect ((rs, q_id) =>
      {
        if (q_id != query_id) return;
        // let's mine directories ZG is aware of
        foreach (var match in rs)
        {
          unowned UriMatch uri_match = match.key as UriMatch;
          if (uri_match == null) continue;
          uris.add (uri_match.uri);
        }
        original_rs = rs;
        search.callback ();
      });
      ulong canc_sig_id = q.cancellable.connect (() =>
      {
        // who knows what thread this runs in
        SignalHandler.block (this, sig_id); // is this thread-safe?
        Idle.add (search.callback); // FIXME: this could cause issues
      });

      if (data_sink.is_plugin_enabled (Type.from_name ("SynapseZeitgeistPlugin")))
      {
        // wait for results from ZeitgeistPlugin
        yield;
      }

      SignalHandler.disconnect (this, sig_id);
      q.cancellable.disconnect (canc_sig_id);

      q.check_cancellable ();

      // make sure we've done the initial load
      while (!initialization_done)
      {
        Timeout.add (250, search.callback);
        yield;
        q.check_cancellable ();
      }

      // we need a sort-of-a-lock here to prevent updating of the file caches
      // by multiple queries at the same time
      while (processing_query)
      {
        // FIXME: the while isn't really necessary, but let's be safe
        yield wait_for_processing_finished ();
        q.check_cancellable ();
      }
      processing_query = true;

      try
      {
        // process results from the zeitgeist plugin
        current_level_uris = uris.size;
        if (current_level_uris > 0)
        {
          // extracts directories from the uris and updates directory_hits
          yield process_uris (uris);
          q.check_cancellable ();
        }
        hit_level++;

        // we weren't cancelled and we should have some directories and hits
        if (hit_level > 1 && q.query_string.length >= 3)
        {
          // we want [current_level_uris / last_level_uris > 0.66]
          if (current_level_uris * 3 > 2 * last_level_uris)
          {
            var directories = get_most_likely_dirs ();
            /*if (!directories.is_empty)
            {
              debug ("we're in level: %d and we'd crawl these dirs >\n%s",
                     hit_level, string.joinv ("; ", directories.to_array ()));
            }*/
            yield process_directories (directories);
            q.check_cancellable ();
          }
        }

        // directory contents are updated now, we can take a look if any
        // files match our query

        // FIXME: run this sooner, it doesn't need to wait for the signal
        var result = yield get_extra_results (q, original_rs, null);
        return result;
      }
      finally
      {
        processing_query = false;
      }

      return null;
    }
  }
}
