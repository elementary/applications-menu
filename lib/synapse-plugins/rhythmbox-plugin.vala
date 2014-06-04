/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
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
  [DBus (name = "org.gnome.Rhythmbox.Shell")]
  interface RhythmboxShell : Object {
      public const string UNIQUE_NAME = "org.gnome.Rhythmbox";
      public const string OBJECT_PATH = "/org/gnome/Rhythmbox/Shell";
      
      [DBus (name = "addToQueue")]
      public abstract void add_to_queue (string uri) throws IOError;
      /*
      [DBus (name = "clearQueue")]
      public abstract void clear_queue () throws IOError;
      */
      [DBus (name = "loadURI")]
      public abstract void load_uri (string uri, bool b) throws IOError;
      
  }

  [DBus (name = "org.gnome.Rhythmbox.Player")]
  interface RhythmboxPlayer : Object {
      public const string UNIQUE_NAME = "org.gnome.Rhythmbox";
      public const string OBJECT_PATH = "/org/gnome/Rhythmbox/Player";
      
      [DBus (name = "getPlaying")]
      public abstract bool get_playing () throws IOError;
      [DBus (name = "next")]
      public abstract void next () throws IOError;
      [DBus (name = "previous")]
      public abstract void previous () throws IOError;
      [DBus (name = "playPause")]
      public abstract void play_pause (bool b) throws IOError;
  }
  
  public class RhythmboxActions: Object, Activatable, ItemProvider, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      actions = new Gee.ArrayList<RhythmboxAction> ();
      matches = new Gee.ArrayList<RhythmboxControlMatch> ();
      
      actions.add (new PlayNow());
      actions.add (new AddToPlaylist());
      
      matches.add (new Play ());
      matches.add (new Pause ());
      matches.add (new Previous ());
      matches.add (new Next ());
    }

    public void deactivate ()
    {
      
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (RhythmboxActions),
        "Rhythmbox",
        _ ("Control Rhythmbox and add items to playlists."),
        "rhythmbox",
        register_plugin,
        DBusService.get_default ().name_is_activatable (RhythmboxPlayer.UNIQUE_NAME),
        _ ("Rhythmbox is not installed")
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private abstract class RhythmboxAction: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; }
      
      public abstract bool valid_for_match (Match match);
      // stupid Vala...
      public abstract void execute_internal (Match? match);
      public void execute (Match? match)
      {
        execute_internal (match);
      }
      public virtual int get_relevancy ()
      {
        bool rb_running = DBusService.get_default ().name_has_owner (
          RhythmboxPlayer.UNIQUE_NAME);
        return rb_running ? default_relevancy + Match.Score.INCREMENT_LARGE : default_relevancy;
      }
    }
    
    private abstract class RhythmboxControlMatch: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public void execute (Match? match)
      {
        this.do_action ();
      }

      public abstract void do_action ();
      
      public virtual bool action_available ()
      {
        return DBusService.get_default ().name_has_owner (
          RhythmboxPlayer.UNIQUE_NAME);
      }
    }

    /* MATCHES of Type.ACTION */
    private class Play: RhythmboxControlMatch
    {
      public Play ()
      {
        Object (title: _ ("Play"),
                description: _ ("Start playback in Rhythmbox"),
                icon_name: "media-playback-start", has_thumbnail: false,
                match_type: MatchType.ACTION);
      }

      public override void do_action ()
      {
        try
        {
          bool player_opened = DBusService.get_default ().name_has_owner (RhythmboxPlayer.UNIQUE_NAME);
          RhythmboxPlayer player = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxPlayer.UNIQUE_NAME,
                                           RhythmboxPlayer.OBJECT_PATH);

          player.play_pause (true);
          if (!player_opened)
          {
            /* Try to play 10 times = 5 seconds waiting for RB to start */
            int i = 0;
            Timeout.add (500, () =>
            {
              ++i;
              try
              {
                if (i <= 10 && !player.get_playing ())
                {
                  player.play_pause (true);
                  return true;
                }
              }
              catch (Error err) { }
              return false;
            });
          }
        }
        catch (IOError e)
        {
          Utils.Logger.warning (this, "Rythmbox is not available.\n%s", e.message);
        }
      }

      public override bool action_available ()
      {
        return true;
      }
    }
    private class Pause: Play
    {
      public Pause ()
      {
        Object (title: _ ("Pause"),
                description: _ ("Pause playback in Rhythmbox"),
                icon_name: "media-playback-pause", has_thumbnail: false,
                match_type: MatchType.ACTION);
      }

      public override bool action_available ()
      {
        return DBusService.get_default ().name_has_owner (
          RhythmboxPlayer.UNIQUE_NAME);
      }
    }
    private class Next: RhythmboxControlMatch
    {
      public Next ()
      {
        Object (title: _ ("Next"),
                description: _ ("Plays the next song in Rhythmbox's playlist"),
                icon_name: "media-skip-forward", has_thumbnail: false,
                match_type: MatchType.ACTION);
      }

      public override void do_action ()
      {
        try {
          RhythmboxPlayer player = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxPlayer.UNIQUE_NAME,
                                           RhythmboxPlayer.OBJECT_PATH);

          player.next ();
        } catch (IOError e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }
    }
    private class Previous: RhythmboxControlMatch
    {
      public Previous ()
      {
        Object (title: _ ("Previous"),
                description: _ ("Plays the previous song in Rhythmbox's playlist"),
                icon_name: "media-skip-backward", has_thumbnail: false,
                match_type: MatchType.ACTION);
      }

      public override void do_action ()
      {
        try {
          RhythmboxPlayer player = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxPlayer.UNIQUE_NAME,
                                           RhythmboxPlayer.OBJECT_PATH);

          player.previous ();
          player.previous ();
        } catch (IOError e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }
    }
    /* ACTIONS FOR MP3s */
    private class AddToPlaylist: RhythmboxAction
    {
      public AddToPlaylist ()
      {
        Object (title: _ ("Enqueue in Rhythmbox"),
                description: _ ("Add the song to Rhythmbox playlist"),
                icon_name: "media-playback-start", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.AVERAGE);
      }

      public override void execute_internal (Match? match)
      {
        return_if_fail (match.match_type == MatchType.GENERIC_URI);
        UriMatch uri = match as UriMatch;
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0);
        try {
          RhythmboxShell shell = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxShell.UNIQUE_NAME,
                                           RhythmboxShell.OBJECT_PATH);

          RhythmboxPlayer player = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxPlayer.UNIQUE_NAME,
                                           RhythmboxPlayer.OBJECT_PATH);

          shell.add_to_queue (uri.uri);
          if (!player.get_playing())
            player.play_pause (true);
        } catch (IOError e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            UriMatch uri = match as UriMatch;
            if ((uri.file_type & QueryFlags.AUDIO) != 0)
              return true;
            else
              return false;
          default:
            return false;
        }
      }
    }
    private class PlayNow: RhythmboxAction
    {
      public PlayNow ()
      {
        Object (title: _ ("Play in Rhythmbox"),
                description: _ ("Clears the current playlist and plays the song"),
                icon_name: "media-playback-start", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.ABOVE_AVERAGE);
      }

      public override void execute_internal (Match? match)
      {
        return_if_fail (match.match_type == MatchType.GENERIC_URI);
        UriMatch uri = match as UriMatch;
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0);
        try {
          RhythmboxShell shell = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxShell.UNIQUE_NAME,
                                           RhythmboxShell.OBJECT_PATH);

          RhythmboxPlayer player = Bus.get_proxy_sync (BusType.SESSION,
                                           RhythmboxPlayer.UNIQUE_NAME,
                                           RhythmboxPlayer.OBJECT_PATH);
          if (!player.get_playing())
            player.play_pause (true);
          shell.load_uri (uri.uri, true);
        } catch (IOError e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            UriMatch uri = match as UriMatch;
            if ((uri.file_type & QueryFlags.AUDIO) != 0)
              return true;
            else
              return false;
          default:
            return false;
        }
      }
    }
    private Gee.List<RhythmboxAction> actions;
    private Gee.List<RhythmboxControlMatch> matches;

    construct
    {
    }
    
    public async ResultSet? search (Query q) throws SearchError
    {
      // we only search for actions
      if (!(QueryFlags.ACTIONS in q.query_type)) return null;

      var result = new ResultSet ();
      
      var matchers = Query.get_matchers_for_query (q.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var action in matches)
      {
        if (!action.action_available ()) continue;
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            result.add (action, matcher.value - Match.Score.INCREMENT_SMALL);
            break;
          }
        }
      }

      q.check_cancellable ();

      return result;
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
            results.add (action, action.get_relevancy ());
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
