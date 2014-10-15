// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//                2013-2014 Akshay Shekher
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

errordomain IconError {
    NOT_FOUND
}

public class Slingshot.Backend.App : Object {

    public enum AppType {
        APP,
        COMMAND,
        SYNAPSE
    }

    public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);

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
    public AppType app_type { get; private set; default = AppType.APP; }

    public Synapse.Match? match { get; private set; default = null; }
    public Synapse.Match? target { get; private set; default = null; }

    public signal void icon_changed ();
    public signal void launched (App app);

    // seconds to wait before retrying icon check
    private const int RECHECK_TIMEOUT = 2;
    private bool check_icon_again = true;

    private LoadableIcon loadable_icon = null;

    public App (GMenu.TreeEntry entry) {
        app_type = AppType.APP;

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
            icon = get_loadable_icon ();
        } else {
            icon_name = "application-default-icon";
        }
        if (icon == null) {
            update_icon ();

            Slingshot.icon_theme.changed.connect (update_icon);
        }
    }

    public App.from_command (string command) {
        app_type = AppType.COMMAND;

        name = command;
        description = _("Run this command…");
        exec = command;
        desktop_id = command;
        icon_name = "system-run";

        update_icon ();

    }

    public App.from_synapse_match (Synapse.Match match, Synapse.Match? target = null) {

        app_type = AppType.SYNAPSE;

        name = match.title;
        description = match.description;
        icon_name = match.icon_name;

        this.match = match;
        this.target = target;

        update_icon ();

    }

    ~App () {
        Slingshot.icon_theme.changed.disconnect (update_icon);
    }

    public void update_icon () {
        icon = load_icon (Slingshot.settings.icon_size);

        icon_changed ();
    }

    private delegate void IconLoadFallback ();

    private class IconLoadFallbackMethod {
        public unowned IconLoadFallback load_icon;

        public IconLoadFallbackMethod (IconLoadFallback fallback) {
            load_icon = fallback;
        }
    }

    public Gdk.Pixbuf? load_icon (int size) {
        if (app_type == AppType.SYNAPSE) {
            try {
                // for contacts we can load the thumbnail because we expect it to be
                // the avatar. For other types it'd be ridiculously small.
                if (match.match_type == Synapse.MatchType.CONTACT && match.has_thumbnail) {
                    return new Gdk.Pixbuf.from_file_at_scale (match.thumbnail_path, size, size, true);
                }

                var icon = Icon.new_for_string (icon_name);
                var info = Gtk.IconTheme.get_default ().lookup_by_gicon (icon,
                    size, Gtk.IconLookupFlags.FORCE_SIZE);

                if (info == null)
                    throw new IconError.NOT_FOUND ("Not found");

                return info.load_icon ();
            } catch (Error e) {
                warning ("Failed to load icon: %s\n", e.message);
            }

            try {
                return Slingshot.icon_theme.load_icon ("application-default-icon",
                    size, Gtk.IconLookupFlags.FORCE_SIZE);
            } catch (Error e) {
                critical (e.message);
            }
        }

        Gdk.Pixbuf icon = null;
        var flags = Gtk.IconLookupFlags.FORCE_SIZE;

        if (loadable_icon != null)
            return get_loadable_icon ();

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

    public Gdk.Pixbuf? get_loadable_icon () {
        Gdk.Pixbuf? tmp_loadable_icon;
        try {
            var icon_stream = loadable_icon.load (0, null, null);
            tmp_loadable_icon = new Gdk.Pixbuf.from_stream_at_scale (icon_stream, Slingshot.settings.icon_size,
                                                                     Slingshot.settings.icon_size, true, null);
        } catch (Error e) {
            tmp_loadable_icon = null;
        }
        return tmp_loadable_icon;
    }

    public bool launch () {
        try {
            switch (app_type) {
                case AppType.COMMAND:
                    debug (@"Launching command: $name");
                    Process.spawn_command_line_async (exec);
                    break;
                case AppType.APP:
                    launched (this); // Emit launched signal
                    new DesktopAppInfo (desktop_id).launch (null, null);
                    debug (@"Launching application: $name");
                    break;
                case AppType.SYNAPSE:
                    if (match.match_type == Synapse.MatchType.SEARCH) {
                        start_search (match as Synapse.SearchMatch, target);
                        return false;
                    } else {
                        if (target == null)
                            Backend.SynapseSearch.find_actions_for_match (match).get (0).execute_with_target (match);
                        else
                            match.execute_with_target (target);
                    }
                    break;
            }
        } catch (Error e) {
            warning ("Failed to launch %s: %s", name, exec);
        }

        return true;
    }

}