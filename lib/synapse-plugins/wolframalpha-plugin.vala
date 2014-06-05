/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>,
 *     Tom Becmann <tomjonabc@gmail.com>
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
  public class WolframAlphaPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class Request: Object, Match
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
          AppInfo.launch_default_for_uri ("https://www.wolframalpha.com/input/?i=" + (Soup.URI.encode (match.title, "+").replace (" ", "+")),
				  new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public Request ()
      {
        Object (title: _ ("WolframAlpha"),
                description: _ ("Process in WolframAlpha"),
                has_thumbnail: false, icon_name: "accessories-dictionary");
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (WolframAlphaPlugin),
        "WolframAlpha",
        _ ("Process in WolframAlpha."),
        "accessories-dictionary",
        register_plugin,
        true,
		""
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Request action;

    construct
    {
      action = new Request ();
    }
    
    public bool handles_unknown ()
    {
      return true;
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      if (!(QueryFlags.ACTIONS in query.query_type))
      {
        return null;
      }

      var results = new ResultSet ();

        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            results.add (action, Match.Score.INCREMENT_MINOR);
            break;
          }
        }

      return results;
    }
  }
}
