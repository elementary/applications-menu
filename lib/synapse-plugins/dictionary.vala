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
  public class DictionaryPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class Define: Object, Match
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
            "gnome-dictionary \"%s\"".printf (match.title),
            "gnome-dictionary", 0);
          ai.launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public Define ()
      {
        Object (title: _ ("Define"),
                description: _ ("Look up definition in dictionary"),
                has_thumbnail: false, icon_name: "accessories-dictionary");
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (DictionaryPlugin),
        "Dictionary",
        _ ("Look up definitions of words."),
        "accessories-dictionary",
        register_plugin,
        Environment.find_program_in_path ("gnome-dictionary") != null,
        _ ("Gnome Dictionary is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Define action;
    private bool has_dictionary;

    construct
    {
      action = new Define ();
      has_dictionary =
        Environment.find_program_in_path ("gnome-dictionary") != null;
    }
    
    public bool handles_unknown ()
    {
      return has_dictionary;
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      if (!has_dictionary || match.match_type != MatchType.UNKNOWN ||
          !(QueryFlags.ACTIONS in query.query_type))
      {
        return null;
      }

      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        results.add (action, action.default_relevancy);
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
