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
  public class DevhelpPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class Search: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; default = 0; }
      
      public void execute (Match? match)
      {
        try
        {
          AppInfo ai = AppInfo.create_from_commandline (
            "devhelp -s \"%s\"".printf (match.title),
            "devhelp", 0);
          ai.launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public Search ()
      {
        Object (title: _ ("Search in Devhelp"),
                description: _ ("Search documentation for this symbol"),
                has_thumbnail: false, icon_name: "devhelp");
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (DevhelpPlugin),
        "Devhelp",
        _ ("Search documentation using Devhelp."),
        "devhelp",
        register_plugin,
        Environment.find_program_in_path ("devhelp") != null,
        _ ("Devhelp is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Search action;
    private bool has_devhelp;

    construct
    {
      action = new Search ();
      has_devhelp =
        Environment.find_program_in_path ("devhelp") != null;

      try
      {        
        symbol_re = new Regex ("^([a-z]+_)|([A-Z]+[a-z]+[A-Z])",
                               RegexCompileFlags.OPTIMIZE);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }
    
    public bool handles_unknown ()
    {
      return has_devhelp;
    }
    
    private Regex symbol_re;

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      if (!has_devhelp || match.match_type != MatchType.UNKNOWN ||
          !(QueryFlags.ACTIONS in query.query_type))
      {
        return null;
      }

      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        int relevancy = action.default_relevancy;
        if (symbol_re.match (match.title)) relevancy += Match.Score.INCREMENT_SMALL;
        results.add (action, relevancy);
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
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
