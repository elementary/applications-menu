/*
 * Copyright (C) 2011 Michal Hruby <michal.mhr@gmail.com>
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
  // There are two basic plugin interfaces - ItemProvider and ActionProvider
  //
  // Plugins implementing ItemProvider have the ability to add items as a result for particular search query.
  // ActionProvider plugins on the other hand define actions that can be performed on items returned
  // by other ItemProviders ie. a "Home directory" is an item that gets added by a particular ItemProvider plugin
  // as a possible match when user searches for "home". ActionProvider will inspect this item, see that it's a file URI,
  // and will add an action for the item, for example "Open".
  //
  // Please note that for example a "Pause" action (for a music player), is still implemented by an ItemProvider and
  // it gets matched to the default "Run" action.
  //
  // Also note that a plugin can implement both of these interfaces if it's necessary.
  public class HelloWorldPlugin : Object, Activatable, ItemProvider
  {
    // a mandatory property
    public bool enabled { get; set; default = true; }

    // this method is called when a plugin is enabled
    // use it to initialize your plugin
    public void activate ()
    {
    }

    // this method is called when a plugin is disabled
    // use it to free the resources you're using
    public void deactivate ()
    {
    }

    // register your plugin in the UI
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (HelloWorldPlugin),
        _ ("Hello world"), // plugin title
        _ ("An example plugin."), // description
        "system-run", // icon name
        register_plugin, // reference to this function
        Environment.find_program_in_path ("ls") != null, // true if user's system has all required components which the plugin needs
        _ ("ls is not installed") // error message
      );
    }

    static construct
    {
      // register the plugin when the class is constructed
      register_plugin ();
    }

    // an optional method to improve the speed of searches, 
    // if you return false here, the search method won't be called
    // for this query
    public bool handles_query (Query query)
    {
      // we will only search in the "Actions" category (that includes "All" as well)
      return (QueryFlags.ACTIONS in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      if (query.query_string.has_prefix ("hello"))
      {
        // if the user searches for "hello" + anything, we'll add our result
        var results = new ResultSet ();
        results.add (new WorldMatch (), Match.Score.AVERAGE);

        // make sure this method is called before returning any results
        query.check_cancellable ();
        return results;
      }

      // make sure this method is called before returning any results
      query.check_cancellable ();
      return null;
    }

    // define our Match object
    private class WorldMatch : Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public WorldMatch ()
      {
        Object (match_type: MatchType.UNKNOWN,
                title: "HelloWorld",
                description: "Result from HelloWorldPlugin",
                has_thumbnail: false, icon_name: "system-run");
      }
    }
  }
}
