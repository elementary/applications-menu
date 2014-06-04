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
  public class SelectionPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    private Gtk.Clipboard clipboard;
    private SelectedTextItem item;

    public void activate ()
    {
      item = new SelectedTextItem ();
      clipboard = Gtk.Clipboard.get (Gdk.SELECTION_PRIMARY);
      clipboard.owner_change.connect (this.cb_owner_change);
    }

    public void deactivate ()
    {
      clipboard.owner_change.disconnect (this.cb_owner_change);
    }
    
    bool cb_changed = true;
    
    private void cb_owner_change ()
    {
      cb_changed = true;
    }

    // register your plugin in the UI
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (SelectionPlugin),
        _ ("Selection"), // plugin title
        _ ("Provides actions for currently selected text."), // description
        "edit-select-all", // icon name
        register_plugin // reference to this function
      );
    }

    static construct
    {
      // register the plugin when the class is constructed
      register_plugin ();
    }
    
    private class SelectedTextItem : Object, Match, TextMatch
    {
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public TextOrigin text_origin { get; set; }
      
      public SelectedTextItem ()
      {
        Object (title: _("Selected text"),
                description : "",
                icon_name: "edit-select-all",
                has_thumbnail: false,
                match_type: MatchType.TEXT,
                text_origin: TextOrigin.CLIPBOARD);
      }

      protected string get_text ()
      {
        return content;
      }
      
      private string? content = null;

      public void update_content (owned string content)
      {
        this.content = content;
        string chugged = content.chug ();
        string shortened = chugged.substring (0, int.min ((int)chugged.length, 100));
        description = shortened.replace ("\n", " ");
      }
    }

    public bool handles_query (Query query)
    {
      // we will only search in the "Actions" category
      return (QueryFlags.ACTIONS in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      var matchers = Query.get_matchers_for_query (query.query_string,
                                                   MatcherFlags.NO_FUZZY | MatcherFlags.NO_PARTIAL,
                                                   RegexCompileFlags.CASELESS);
      int relevancy = 0;
      foreach (var matcher in matchers)
      {
        if (matcher.key.match (item.title))
        {
          relevancy = matcher.value;
          break;
        }
      }
      
      if (relevancy == 0) return null;
      string? cb_text = null;
      
      if (cb_changed)
      {
        clipboard.request_text ((cb, text) =>
        {
          cb_text = text;
          search.callback ();
        });
      }
      else
      {
        cb_text = "";
        Idle.add (search.callback);
      }
      yield;

      query.check_cancellable ();

      if (cb_text != null)
      {
        if (cb_changed)
        {
          item.update_content ((owned) cb_text);
          cb_changed = false;
        }
        var results = new ResultSet ();
        results.add (item, relevancy);

        query.check_cancellable ();
        return results;
      }

      // make sure this method is called before returning any results
      query.check_cancellable ();
      return null;
    }
  }
}
