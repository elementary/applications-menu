namespace Slingshot.Backend {

    public class AppMonitor : GLib.Object {

        public GLib.File system_applications;
        public GLib.File user_applications;

        public GLib.FileMonitor system_monitor;
        public GLib.FileMonitor user_monitor;

        public signal void changed (GLib.File file, GLib.File? other_file, GLib.FileMonitorEvent event_type);

        public void trigger_changed (GLib.File file, GLib.File? other_file, GLib.FileMonitorEvent event_type) {
            this.changed(file, other_file, event_type);
        }

        construct {
            this.system_applications = File.new_for_path("/usr/share/applications");
            this.user_applications = File.new_for_path(GLib.Environment.get_user_data_dir() + "/applications");
            try {
                this.system_monitor = this.system_applications.monitor_directory(GLib.FileMonitorFlags.NONE);
                this.system_monitor.changed.connect(this.trigger_changed);
            } catch (GLib.Error e) {
                print("Error: "+e.message+"\n");
            }
            try {
                this.user_monitor = this.user_applications.monitor_directory(GLib.FileMonitorFlags.NONE);
                this.user_monitor.changed.connect(this.trigger_changed);
            } catch (GLib.Error e) {
                print("Error: "+e.message+"\n");
            }
        }

    }


}
