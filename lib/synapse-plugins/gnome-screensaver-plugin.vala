/*
 * Copyright (C) 2010 Igor S. Mandrigin <i@mandrigin.ru>
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
 * Based on plugins code by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  [DBus (name = "org.gnome.ScreenSaver")]
  public interface GnomeScreenSaver: Object
  {
    public const string UNIQUE_NAME = "org.gnome.ScreenSaver";
    public const string OBJECT_PATH = "/org/gnome/ScreenSaver";
    
    public abstract async void lock () throws IOError;
  }

  public class GnomeScreenSaverPlugin: Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class LockScreenAction: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public LockScreenAction ()
      {
        Object (match_type: MatchType.ACTION, title: _ ("Lock Screen"),
                description: _ ("Locks screen and starts screensaver."),
                icon_name: "system-lock-screen", has_thumbnail: false);
      }
      
      public void execute (Match? match)
      {
        GnomeScreenSaverPlugin.lock_screen ();
      }
    }
    
    public static void lock_screen ()
    {
      GnomeScreenSaver dbus_interface = Bus.get_proxy_sync (BusType.SESSION,
                                               GnomeScreenSaver.UNIQUE_NAME,
                                               GnomeScreenSaver.OBJECT_PATH);
      // we need the async variant cause Screensaver doesn't send the reply
      dbus_interface.lock.begin ();
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (GnomeScreenSaverPlugin),
        "Gnome screensaver plugin",
        _ ("Lock screen of your computer."),
        "system-lock-screen",
        register_plugin,
        DBusService.get_default ().name_is_activatable (GnomeScreenSaver.UNIQUE_NAME),
        _ ("Gnome Screen Saver wasn't found")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Gee.List<Match> actions;

    construct
    {
      actions = new Gee.LinkedList<Match> ();
      actions.add (new LockScreenAction ());
    }
    
    public async ResultSet? search (Query q) throws SearchError
    {
      // we only search for actions
      if (!(QueryFlags.ACTIONS in q.query_type)) return null;

      var result = new ResultSet ();

      var matchers = Query.get_matchers_for_query (q.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var action in actions)
      {
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
  }
}
