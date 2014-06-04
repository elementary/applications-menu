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

using Zeitgeist;

namespace Synapse
{
  public class ZeitgeistRelated: Object, Activatable, ActionProvider
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

    private class RelatedItem: Object, SearchProvider, Match, SearchMatch
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
        ResultSet? results = yield plugin.find_related (q, search_source);
        dest_result_set.add_all (results);

        return dest_result_set.get_sorted_list ();
      }

      private unowned ZeitgeistRelated plugin;

      public RelatedItem (ZeitgeistRelated plugin)
      {
        Object (match_type: MatchType.SEARCH,
                has_thumbnail: false,
                icon_name: "search",
                title: _ ("Find related"),
                description: _ ("Find resources related to this result"));
        this.plugin = plugin;
      }
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (ZeitgeistRelated),
        _ ("Related files"),
        _ ("Finds files related to other search results using Zeitgeist."),
        "search",
        register_plugin,
        DBusService.get_default ().name_is_activatable ("org.gnome.zeitgeist.Engine"),
        _ ("Zeitgeist is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    RelatedItem action;
    Zeitgeist.Log zg_log;

    construct
    {
      action = new RelatedItem (this);
      zg_log = new Zeitgeist.Log ();
    }

    public async ResultSet? find_related (Query q, Match m) throws SearchError
    {
      Event e;
      Subject s;
      if (!(m is UriMatch) && !(m is ApplicationMatch)) return null;

      GenericArray<Event> templates = new GenericArray<Event> ();
      PtrArray event_templates = new PtrArray ();
      PtrArray result_templates = new PtrArray ();

      if (m is UriMatch)
      {
        var um = m as UriMatch;
        Utils.Logger.debug (this, "searching for items related to %s", um.uri);

        s = new Subject ();
        s.set_uri (um.uri);
        e = new Event ();
        e.add_subject (s);
      }
      else if (m is ApplicationMatch)
      {
        string app_id;
        var app_info = (m as ApplicationMatch).app_info;
        if (app_info != null)
        {
          app_id = app_info.get_id () ?? "";
          if (app_id == "" && app_info is DesktopAppInfo)
          {
            app_id = (app_info as DesktopAppInfo).get_filename () ?? "";
            app_id = Path.get_basename (app_id);
          }
        }
        else
        {
          app_id = Path.get_basename ((m as ApplicationMatch).filename);
        }

        if (app_id == null || app_id == "")
        {
          Utils.Logger.warning (this, "Unable to extract application id!");
          return null;
        }

        app_id = "application://" + app_id;
        Utils.Logger.debug (this, "searching for items related to %s", app_id);

        e = new Event ();
        e.set_actor (app_id);
      }
      else return null;

      templates.add (e);
      event_templates.add (e);

      try
      {
        string[] uris;
        int64 end = Zeitgeist.Timestamp.now ();
        int64 start = end - Zeitgeist.Timestamp.WEEK * 8;
        uris = yield zg_log.find_related_uris (new TimeRange (start, end),
            (owned) event_templates, (owned) result_templates,
            StorageState.ANY, q.max_results, ResultType.MOST_RECENT_EVENTS,
            q.cancellable);

        if (uris == null || uris.length == 0)
        {
          q.check_cancellable ();
          return null;
        }

        templates = new GenericArray<Event> ();
        event_templates = new PtrArray ();

        foreach (unowned string uri in uris)
        {
          s = new Subject ();
          s.set_uri (uri);
          e = new Event ();
          e.add_subject (s);

          event_templates.add (e);
          templates.add (e);
        }

        var rs = yield zg_log.find_events (new TimeRange.anytime (),
                                           (owned) event_templates,
                                           StorageState.ANY,
                                           q.max_results,
                                           ResultType.MOST_RECENT_SUBJECTS,
                                           q.cancellable);

        ResultSet results = new ResultSet ();
        yield ZeitgeistPlugin.process_results ("", rs, q.cancellable, results,
                                               false, false);

        return results;
      }
      catch (Error err)
      {
        Utils.Logger.warning (this, "%s", err.message);
      }

      q.check_cancellable ();

      return null;
    }

    public ResultSet? find_for_match (ref Query q, Match match)
    {
      /*
      var our_results = QueryFlags.APPLICATIONS | QueryFlags.AUDIO
        | QueryFlags.DOCUMENTS | QueryFlags.IMAGES | QueryFlags.UNCATEGORIZED
        | QueryFlags.VIDEO | QueryFlags.PLACES;
      */

      if (q.query_type == QueryFlags.ACTIONS) return null;
      if (match.match_type != MatchType.GENERIC_URI
        && match.match_type != MatchType.APPLICATION) return null;

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
