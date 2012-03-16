// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Giulio Collura
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

using Gtk;
using Granite;

namespace Slingshot {

    public class Slingshot : Granite.Application {

        private SlingshotView view = null;
        public bool silent = false;

        public static Settings settings { get; private set; default = null; }
        //public static CssProvider style_provider { get; private set; default = null; }
        public static IconTheme icon_theme { get; set; default = null; }

        construct {

            build_data_dir = Build.DATADIR;
            build_pkg_data_dir = Build.PKGDATADIR;
            build_release_name = Build.RELEASE_NAME;
            build_version = Build.VERSION;
            build_version_info = Build.VERSION_INFO;
            
            program_name = "Slingshot";
		    exec_name = "slingshot";
		    app_copyright = "GPLv3";
		    app_icon = "";
		    app_launcher = "";
            app_years = "2011";
            application_id = "net.launchpad.slingshot";
		    main_url = "https://launchpad.net/slingshot";
		    bug_url = "https://bugs.launchpad.net/slingshot";
		    help_url = "https://answers.launchpad.net/slingshot";
		    translate_url = "https://translations.launchpad.net/slingshot";

		    about_authors = {"Giulio Collura <random.cpp@gmail.com>"};
		    about_artists = {"Harvey Cabaguio 'BassUltra' <harveycabaguio@gmail.com>",
                             "Daniel Foré <bunny@go-docky.com>"};
            about_translators = "Launchpad Translators";
            about_license_type = License.GPL_3_0;

        }

        public Slingshot () {

            set_flags (ApplicationFlags.HANDLES_OPEN);

            settings = new Settings ();

            DEBUG = true;

        }

        protected override void open (File[] files, string hint) {

            foreach (File file in files) {
                if (file.get_basename () == "--silent")
                    silent = true;
            }
            
            activate ();

        }

        protected override void activate () {

            if (get_windows () == null) {
                view = new SlingshotView ();
                view.set_application (this);
                if (!silent) {
                    //view.move_to_coords (0, 0);
                    view.show_slingshot ();
                }
            } else {
                if (view.visible)
                    view.hide_slingshot ();
                else
                    view.show_slingshot ();
            }
        
        }

        public static int main (string[] args) {
            GtkClutter.init (ref args);

            return new Slingshot ().run (args);

        }

    }

}
