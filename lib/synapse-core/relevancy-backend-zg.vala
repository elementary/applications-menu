/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  private class ZeitgeistRelevancyBackend: Object, RelevancyBackend
  {
    private Zeitgeist.Log zg_log;
    private Zeitgeist.DataSourceRegistry zg_dsr;
    private Gee.Map<string, int> application_popularity;
    private Gee.Map<string, int> uri_popularity;
    private bool has_datahub_gio_module = false;

    private const float MULTIPLIER = 65535.0f;

    construct
    {
      zg_log = new Zeitgeist.Log ();
      application_popularity = new Gee.HashMap<string, int> ();
      uri_popularity = new Gee.HashMap<string, int> ();

      refresh_popularity ();
      check_data_sources.begin ();

      Timeout.add_seconds (60*30, refresh_popularity);
    }

    private async void check_data_sources ()
    {
      zg_dsr = new Zeitgeist.DataSourceRegistry ();
      try
      {
        var ptr_arr = yield zg_dsr.get_data_sources (null);

        for (uint i=0; i < ptr_arr.len; i++)
        {
          unowned Zeitgeist.DataSource ds;
          ds = (Zeitgeist.DataSource) ptr_arr.index (i);
          if (ds.get_unique_id () == "com.zeitgeist-project,datahub,gio-launch-listener"
              && ds.is_enabled ())
          {
            has_datahub_gio_module = true;
            break;
          }
        }
      }
      catch (Error err)
      {
        warning ("Unable to check Zeitgeist data sources: %s", err.message);
      }
    }

    private bool refresh_popularity ()
    {
      load_application_relevancies.begin ();
      load_uri_relevancies.begin ();
      return true;
    }

    private async void load_application_relevancies ()
    {
      Idle.add (load_application_relevancies.callback, Priority.LOW);
      yield;

      int64 end = Zeitgeist.Timestamp.now ();
      int64 start = end - Zeitgeist.Timestamp.WEEK * 4;
      Zeitgeist.TimeRange tr = new Zeitgeist.TimeRange (start, end);

      var event = new Zeitgeist.Event ();
      event.set_interpretation ("!" + Zeitgeist.ZG_LEAVE_EVENT);
      var subject = new Zeitgeist.Subject ();
      subject.set_interpretation (Zeitgeist.NFO_SOFTWARE);
      subject.set_uri ("application://*");
      event.add_subject (subject);

      var ptr_arr = new PtrArray ();
      ptr_arr.add (event);

      Zeitgeist.ResultSet rs;

      try
      {
        rs = yield zg_log.find_events (tr, (owned) ptr_arr,
                                       Zeitgeist.StorageState.ANY,
                                       256,
                                       Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                                       null);

        application_popularity.clear ();
        uint size = rs.size ();
        uint index = 0;

        // Zeitgeist (0.6) doesn't have any stats API, so let's approximate

        foreach (Zeitgeist.Event e in rs)
        {
          if (e.num_subjects () <= 0) continue;
          Zeitgeist.Subject s = e.get_subject (0);

          float power = index / (size * 2) + 0.5f; // linearly <0.5, 1.0>
          float relevancy = 1.0f / Math.powf (index + 1, power);
          application_popularity[s.get_uri ()] = (int)(relevancy * MULTIPLIER);

          index++;
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
        return;
      }
    }

    private async void load_uri_relevancies ()
    {
      Idle.add (load_uri_relevancies.callback, Priority.LOW);
      yield;

      int64 end = Zeitgeist.Timestamp.now ();
      int64 start = end - Zeitgeist.Timestamp.WEEK * 4;
      Zeitgeist.TimeRange tr = new Zeitgeist.TimeRange (start, end);

      var event = new Zeitgeist.Event ();
      event.set_interpretation ("!" + Zeitgeist.ZG_LEAVE_EVENT);
      var subject = new Zeitgeist.Subject ();
      subject.set_interpretation ("!" + Zeitgeist.NFO_SOFTWARE);
      subject.set_uri ("file://*");
      event.add_subject (subject);

      var ptr_arr = new PtrArray ();
      ptr_arr.add (event);

      Zeitgeist.ResultSet rs;
      Gee.Map<string, int> popularity_map = new Gee.HashMap<string, int> ();

      try
      {
        uint size, index;
        float power, relevancy;
        /* Get popularity for file uris */
        rs = yield zg_log.find_events (tr, (owned) ptr_arr,
                                       Zeitgeist.StorageState.ANY,
                                       256,
                                       Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                                       null);

        size = rs.size ();
        index = 0;

        // Zeitgeist (0.6) doesn't have any stats API, so let's approximate

        foreach (Zeitgeist.Event e1 in rs)
        {
          if (e1.num_subjects () <= 0) continue;
          Zeitgeist.Subject s1 = e1.get_subject (0);

          power = index / (size * 2) + 0.5f; // linearly <0.5, 1.0>
          relevancy = 1.0f / Math.powf (index + 1, power);
          popularity_map[s1.get_uri ()] = (int)(relevancy * MULTIPLIER);

          index++;
        }
        
        /* Get popularity for web uris */
        subject.set_interpretation (Zeitgeist.NFO_WEBSITE);
        subject.set_uri ("");
        ptr_arr = new PtrArray ();
        ptr_arr.add (event);

        rs = yield zg_log.find_events (tr, (owned) ptr_arr,
                                       Zeitgeist.StorageState.ANY,
                                       128,
                                       Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                                       null);

        size = rs.size ();
        index = 0;

        // Zeitgeist (0.6) doesn't have any stats API, so let's approximate

        foreach (Zeitgeist.Event e2 in rs)
        {
          if (e2.num_subjects () <= 0) continue;
          Zeitgeist.Subject s2 = e2.get_subject (0);

          power = index / (size * 2) + 0.5f; // linearly <0.5, 1.0>
          relevancy = 1.0f / Math.powf (index + 1, power);
          popularity_map[s2.get_uri ()] = (int)(relevancy * MULTIPLIER);

          index++;
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      uri_popularity = popularity_map;
    }
    
    public float get_application_popularity (string desktop_id)
    {
      if (application_popularity.has_key (desktop_id))
      {
        return application_popularity[desktop_id] / MULTIPLIER;
      }

      return 0.0f;
    }
    
    public float get_uri_popularity (string uri)
    {
      if (uri_popularity.has_key (uri))
      {
        return uri_popularity[uri] / MULTIPLIER;
      }

      return 0.0f;
    }
    
    private void reload_relevancies ()
    {
      Idle.add_full (Priority.LOW, () =>
      {
        load_application_relevancies.begin ();
        return false;
      });
    }
    
    public void application_launched (AppInfo app_info)
    {
      // FIXME: get rid of this maverick-specific workaround
      // detect if the Zeitgeist GIO module is installed
      Type zg_gio_module = Type.from_name ("GAppLaunchHandlerZeitgeist");
      // FIXME: perhaps we should check app_info.should_show?
      //   but user specifically asked to open this, so probably not
      //   otoh the gio module won't pick it up if it's not should_show
      if (zg_gio_module != 0)
      {
        Utils.Logger.debug (this, "libzg-gio-module detected, not pushing");
        reload_relevancies ();
        return;
      }

      if (has_datahub_gio_module)
      {
        reload_relevancies ();
        return;
      }

      string app_uri = null;
      if (app_info.get_id () != null)
      {
        app_uri = "application://" + app_info.get_id ();
      }
      else if (app_info is DesktopAppInfo)
      {
        string? filename = (app_info as DesktopAppInfo).get_filename ();
        if (filename == null) return;
        app_uri = "application://" + Path.get_basename (filename);
      }

      Utils.Logger.debug (this, "launched \"%s\", pushing to ZG", app_uri);
      push_app_launch (app_uri, app_info.get_display_name ());

      // and refresh
      reload_relevancies ();
    }

    private void push_app_launch (string app_uri, string? display_name)
    {
      //debug ("pushing launch event: %s [%s]", app_uri, display_name);
      var event = new Zeitgeist.Event ();
      var subject = new Zeitgeist.Subject ();

      event.set_actor ("application://synapse.desktop");
      event.set_interpretation (Zeitgeist.ZG_ACCESS_EVENT);
      event.set_manifestation (Zeitgeist.ZG_USER_ACTIVITY);
      event.add_subject (subject);

      subject.set_uri (app_uri);
      subject.set_interpretation (Zeitgeist.NFO_SOFTWARE);
      subject.set_manifestation (Zeitgeist.NFO_SOFTWARE_ITEM);
      subject.set_mimetype ("application/x-desktop");
      subject.set_text (display_name);

      zg_log.insert_events_no_reply (event, null);
    }
  }
}

