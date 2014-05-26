// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
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

public class Slingshot.Backend.App : Object {

    public string name { get; construct set; }
    public string description { get; private set; default = ""; }
    public string desktop_id { get; construct set; }
    public string exec { get; private set; }
    public string icon_name { get; private set; default = ""; }
    public string[] keywords { get; private set;}
    public Gdk.Pixbuf? icon { get; private set; default = null; }
    public double popularity { get; set; }
    public double relevancy { get; set; }
    public string desktop_path { get; private set; }
    public string categories { get; private set; }
    public string generic_name { get; private set; default = ""; }

    private bool is_command = false;
    private LoadableIcon? loadable_icon = null;

    public signal void icon_changed ();
    public signal void launched (App app);

    // seconds to wait before retrying icon check
    private const int RECHECK_TIMEOUT = 2;
    private bool check_icon_again = true;

    public App (GMenu.TreeEntry entry) {
        unowned GLib.DesktopAppInfo info = entry.get_app_info ();
        name = info.get_display_name ().dup ();
        description = info.get_description ().dup () ?? name;
        exec = info.get_commandline ().dup ();
        desktop_id = entry.get_desktop_file_id ();
        desktop_path = entry.get_desktop_file_path ();
#if HAVE_UNITY
        keywords = Unity.AppInfoManager.get_default ().get_keywords (desktop_id);
#endif
        categories = info.get_categories ();
        generic_name = info.get_generic_name ();

        if (info.get_icon () is ThemedIcon) {
            icon_name = (info.get_icon () as ThemedIcon).get_names ()[0].dup ();
        } else if (info.get_icon () is LoadableIcon) {
            loadable_icon = info.get_icon () as LoadableIcon;
        } else {
            icon_name = "application-default-icon";
        }

        update_icon ();

        Slingshot.icon_theme.changed.connect (update_icon);
    }

    public App.from_command (string command) {

        name = command;
        description = _("Run this command...");
        exec = command;
        desktop_id = command;
        icon_name = "system-run";

        is_command = true;

        update_icon ();

    }

    public void update_icon () {
        if (loadable_icon != null) {
            try {
                var ios = loadable_icon.load (0, null, null);
                icon = new Gdk.Pixbuf.from_stream_at_scale (ios, Slingshot.settings.icon_size,
                                                            Slingshot.settings.icon_size, true, null);
            } catch (Error e) {
                icon_name = "application-default-icon";
            }
        } else {
            icon = load_icon (Slingshot.settings.icon_size);
        }

        icon_changed ();
    }

    private delegate void IconLoadFallback ();

    private class IconLoadFallbackMethod {
        public unowned IconLoadFallback load_icon;

        public IconLoadFallbackMethod (IconLoadFallback fallback) {
            load_icon = fallback;
        }
    }

    public Gdk.Pixbuf load_icon (int size) {
        var flags = Gtk.IconLookupFlags.FORCE_SIZE;

        IconLoadFallbackMethod[] fallbacks = {
            new IconLoadFallbackMethod (() => {
                try {
                    icon = Slingshot.icon_theme.load_icon (icon_name, size, flags);
                } catch (Error e) {
                    warning ("Could not load icon. Falling back to method 2");
                }
            }),

            new IconLoadFallbackMethod (() => {
                // Since the best method didn't work retry after some time
                if (check_icon_again) {
                    // only recheck once
                    check_icon_again = false;

                    Timeout.add_seconds (RECHECK_TIMEOUT, () => {
                        Slingshot.icon_theme.rescan_if_needed ();
                        update_icon ();
                        return false;
                    });
                }
            }),

            new IconLoadFallbackMethod (() => {
                try {
                    if (icon_name.last_index_of (".") > 0) {
                        var name = icon_name[0:icon_name.last_index_of (".")];
                        icon = Slingshot.icon_theme.load_icon (name, size, flags);
                    }
                } catch (Error e) {
                    warning ("Could not load icon. Falling back to method 3");
                }
            }),

            new IconLoadFallbackMethod (() => {
                try {
                    icon = new Gdk.Pixbuf.from_file_at_scale (icon_name, size, size, false);
                } catch (Error e) {
                    warning ("Could not load icon. Falling back to method 4");
                }
            }),

            new IconLoadFallbackMethod (() => {
                try {
                    icon = Slingshot.icon_theme.load_icon ("application-default-icon", size, flags);
                 } catch (Error e) {
                     warning ("Could not load icon. Falling back to method 5");
                 }
            }),

            new IconLoadFallbackMethod (() => {
                 try {
                    icon = Slingshot.icon_theme.load_icon ("gtk-missing-image", size, flags);
                 } catch (Error e) {
                    error ("Could not find a fallback icon to load");
                 }
            })
        };
        foreach (IconLoadFallbackMethod fallback in fallbacks) {
            fallback.load_icon ();
            if (icon != null)
                break;
        }

        return icon;
    }

    public void launch () {
        try {
            if (is_command) {
                debug (@"Launching command: $name");
                Process.spawn_command_line_async (exec);
            } else {
                launched (this); // Emit launched signal
                new DesktopAppInfo (desktop_id).launch (null, null);
                debug (@"Launching application: $name");
            }
        } catch (Error e) {
            warning ("Failed to launch %s: %s", name, exec);
        }
    }

}
