// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Maxwell Barvian
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

namespace Slingshot.Backend {

    public class AppMonitor : GLib.Object {

        public File system_applications;
        public File user_applications;

        public FileMonitor system_monitor;
        public FileMonitor user_monitor;

        public signal void changed (File file, File? other_file, FileMonitorEvent event_type);

        public void trigger_changed (File file, File? other_file, FileMonitorEvent event_type) {
            this.changed (file, other_file, event_type);
        }

        construct {
        
            this.system_applications = File.new_for_path ("/usr/share/applications");
            this.user_applications = File.new_for_path (Environment.get_user_data_dir() + "/applications");
            try {
                this.system_monitor = this.system_applications.monitor_directory(FileMonitorFlags.NONE);
                this.system_monitor.changed.connect (this.trigger_changed);
            } catch (Error e) {
                warning ("Error: " + e.message + "\n");
            }
            try {
                this.user_monitor = this.user_applications.monitor_directory(GLib.FileMonitorFlags.NONE);
                this.user_monitor.changed.connect (this.trigger_changed);
            } catch (Error e) {
                warning ("Error: " + e.message + "\n");
            }

        }

    }

}
