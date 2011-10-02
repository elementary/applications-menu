// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Slingshot Developers
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


using Zeitgeist;

namespace Slingshot.Backend {

    public class RelevancyService : Object {

        private Zeitgeist.Log zg_log;
        private Zeitgeist.DataSourceRegistry zg_dsr;
        private Gee.Map<string, int> app_popularity;
        private bool has_datahub_gio_module = false;

        private const float MULTIPLIER = 65535.0f;

        public RelevancyService () {

            zg_log = new Zeitgeist.Log ();
            app_popularity = new Gee.HashMap<string, int> ();

            refresh_popularity ();
            check_data_sources.begin ();

            Timeout.add_seconds (60*30, refresh_popularity);

        }

        private async void check_data_sources () {

            zg_dsr = new Zeitgeist.DataSourceRegistry ();
            var ptr_arr = yield zg_dsr.get_data_sources (null);

            for (uint i=0; i < ptr_arr.len; i++) {

                unowned Zeitgeist.DataSource ds;
                ds = (Zeitgeist.DataSource) ptr_arr.index (i);
                if (ds.get_unique_id () == "com.zeitgeist-project,datahub,gio-launch-listener"
                        && ds.is_enabled ()) {

                    has_datahub_gio_module = true;
                    break;
                }
            }
        }

        public bool refresh_popularity () {

            load_application_relevancies.begin ();
            return true;

        }

        private async void load_application_relevancies () {

            Idle.add (load_application_relevancies.callback, Priority.HIGH);
            yield;

            int64 end = Zeitgeist.Timestamp.now ();
            int64 start = end - Zeitgeist.Timestamp.WEEK * 4;
            Zeitgeist.TimeRange tr = new Zeitgeist.TimeRange (start, end);

            var event = new Zeitgeist.Event ();
            event.set_interpretation ("!" + ZG_LEAVE_EVENT);
            var subject = new Zeitgeist.Subject ();
            subject.set_interpretation (NFO_SOFTWARE);
            subject.set_uri ("application://*");
            event.add_subject (subject);

            var ptr_arr = new PtrArray ();
            ptr_arr.add (event);

            Zeitgeist.ResultSet rs;

            try {

                rs = yield zg_log.find_events (tr, (owned) ptr_arr,
                        Zeitgeist.StorageState.ANY,
                        256,
                        Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                        null);

                app_popularity.clear ();
                uint size = rs.size ();
                uint index = 0;

                // Zeitgeist (0.6) doesn't have any stats API, so let's approximate

                foreach (Zeitgeist.Event e in rs) {

                    if (e.num_subjects () <= 0) continue;
                    Zeitgeist.Subject s = e.get_subject (0);

                    float power = index / (size * 2) + 0.5f; // linearly <0.5, 1.0>
                    float relevancy = 1.0f / Math.powf (index + 1, power);
                    app_popularity[s.get_uri ()] = (int)(relevancy * MULTIPLIER);
                    index++;
                }
            } catch (Error err) {
                warning ("%s", err.message);
                return;
            }
        }

        public float get_app_popularity (string desktop_id) {

            var id = "application://" + desktop_id;

            if (id in app_popularity) {
                return app_popularity[id] / MULTIPLIER;
            }

            return 0.0f;
        }

    }
}
