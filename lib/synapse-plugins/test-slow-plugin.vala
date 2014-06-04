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
  public class TestSlowPlugin: Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class TestResult: Object, Match
    {
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }
      public MatchType match_type { get; construct set; }
      
      public TestResult (string query)
      {
        Object (title: "Test result for " + query.strip (),
                description: "by TestSlowPlugin",
                icon_name: "unknown", has_thumbnail: false,
                match_type: MatchType.UNKNOWN);
      }
    }
    
    public async ResultSet? search (Query q) throws SearchError
    {
      Idle.add (search.callback);
      yield;

      q.check_cancellable ();

      Timeout.add (2000, search.callback);
      yield;

      q.check_cancellable ();

      Utils.Logger.debug (this, "finished search for \"%s\"", q.query_string);

      var rs = new ResultSet ();
      rs.add (new TestResult (q.query_string), 0);

      return rs;
    }
  }
}
