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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

namespace Synapse
{
  public class FileOpPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private abstract class FileAction: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public int default_relevancy { get; set; }
      public bool notify_match { get; set; default = true; }

      public abstract bool valid_for_match (Match match);
      public virtual int get_relevancy_for_match (Match match)
      {
        return default_relevancy;
      }
      
      public virtual void execute_with_target (Match? source, Match? target = null)
      {
        if (target == null) execute (source);
        else Utils.Logger.error (this, "execute () is not implemented");
      }
      
      public virtual bool needs_target () {
        return false;
      }
      
      public virtual QueryFlags target_flags ()
      {
        return QueryFlags.ALL;
      }
    }
    
    private class RenameTo: FileAction
    {
      public RenameTo ()
      {
        Object (title: _ ("Rename to"),
                description: _ ("Rename the file to..."),
                icon_name: "stock_save-as", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.AVERAGE);
      }
      
      public override void execute_with_target (Match? source, Match? target = null)
      {
        if (target == null) return; // not possible
        
        UriMatch uri_match = source as UriMatch;
        if (uri_match == null) return; // not possible
        
        File f;
        f = File.new_for_uri (uri_match.uri);
        if (!f.query_exists ())
        {
          Utils.Logger.warning (this, _("File \"%s\"does not exist."), uri_match.uri);
          return;
        }
        string newpath = Path.build_filename (Path.get_dirname (f.get_path ()), target.title);
        var f2 = File.new_for_path (newpath);
        Utils.Logger.debug (this, "Moving \"%s\" to \"%s\"", f.get_path (), newpath);
        bool done = false;
        try {
          done = f.move (f2, GLib.FileCopyFlags.OVERWRITE);
        }catch (GLib.Error err) {}
        if (!done)
        {
          Utils.Logger.warning (this, _("Cannot move \"%s\" to \"%s\""), f.get_path (), newpath);
        }
      }
      
      public override bool needs_target () {
        return true;
      }
      
      public override QueryFlags target_flags ()
      {
        return QueryFlags.TEXT;
      }
      
      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            UriMatch um = match as UriMatch;
            return (um.file_type & QueryFlags.FILES) != 0;
          default:
            return false;
        }
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (FileOpPlugin),
        _ ("File Operations"),
        _ ("Copy, Cut, Paste and Delete files"),
        "stock_copy",
        register_plugin
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private Gee.List<FileAction> actions;

    construct
    {
      actions = new Gee.ArrayList<FileAction> ();

      actions.add (new RenameTo ());
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();
      
      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (action.valid_for_match (match))
          {
            results.add (action, action.get_relevancy_for_match (match));
          }
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var action in actions)
        {
          if (!action.valid_for_match (match)) continue;
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (action.title))
            {
              results.add (action, matcher.value);
              break;
            }
          }
        }
      }

      return results;
    }
  }
}
