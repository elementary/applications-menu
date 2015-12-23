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
    public string[] keywords { get; private set;}
    public Icon icon { get; private set; default = new ThemedIcon ("application-default-icon"); }
    public double popularity { get; set; }
    public double relevancy { get; set; }
    public string desktop_path { get; private set; }
    public string categories { get; private set; }
    public string generic_name { get; private set; default = ""; }
    public AppType app_type { get; private set; default = AppType.APP; }

    public Synapse.Match? match { get; private set; default = null; }
    public Synapse.Match? target { get; private set; default = null; }
    public Gee.ArrayList<string> actions { get; private set; default = null; }
    public Gee.HashMap<string, string> actions_map { get; private set; default = null; }

    public signal void launched (App app);

    // for FDO Desktop Actions
    // see http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html#extra-actions
    private const string DESKTOP_ACTION_KEY = "Actions";
    private const string DESKTOP_ACTION_GROUP_NAME = "Desktop Action %s";
    // for the Unity static quicklists
    // see https://wiki.edubuntu.org/Unity/LauncherAPI#Static_Quicklist_entries
    private const string UNITY_QUICKLISTS_KEY = "X-Ayatana-Desktop-Shortcuts";
    private const string UNITY_QUICKLISTS_SHORTCUT_GROUP_NAME = "%s Shortcut Group";
    private const string UNITY_QUICKLISTS_TARGET_KEY = "TargetEnvironment";
    private const string UNITY_QUICKLISTS_TARGET_VALUE = "Unity";
    private const string[] SUPPORTED_GETTEXT_DOMAINS_KEYS = {"X-Ubuntu-Gettext-Domain", "X-GNOME-Gettext-Domain"};

    public App (GMenu.TreeEntry entry) {
        app_type = AppType.APP;

        unowned GLib.DesktopAppInfo info = entry.get_app_info ();
        name = info.get_display_name ();
        description = info.get_description () ?? name;
        exec = info.get_commandline ();
        desktop_id = entry.get_desktop_file_id ();
        desktop_path = entry.get_desktop_file_path ();
#if HAVE_UNITY
        keywords = Unity.AppInfoManager.get_default ().get_keywords (desktop_id);
#endif
        categories = info.get_categories ();
        generic_name = info.get_generic_name ();
        var desktop_icon = info.get_icon ();
        if (desktop_icon != null) {
            icon = desktop_icon;
        }

        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (theme.lookup_by_gicon (icon, 64, Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }
    }

    public App.from_command (string command) {
        app_type = AppType.COMMAND;

        name = command;
        description = _("Run this command…");
        exec = command;
        desktop_id = command;
        icon = new ThemedIcon ("system-run");
    }

    public App.from_synapse_match (Synapse.Match match, Synapse.Match? target = null) {
        app_type = AppType.SYNAPSE;

        name = match.title;
        description = match.description;
        if (match.match_type == Synapse.MatchType.CONTACT && match.has_thumbnail) {
            var file = File.new_for_path (match.thumbnail_path);
            icon = new FileIcon (file);
        } else if (match.icon_name != null) {
            icon = new ThemedIcon (match.icon_name);
        }

        weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
        if (theme.lookup_by_gicon (icon, 64, Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        this.match = match;
        this.target = target;
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

    // Quicklist code from Plank
    public void init_actions () throws KeyFileError  {
        actions = new Gee.ArrayList<string> ();
        actions_map = new Gee.HashMap<string, string> ();

        // get FDO Desktop Actions
        // see http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html#extra-actions
        // get the Unity static quicklists
        // see https://wiki.edubuntu.org/Unity/LauncherAPI#Static Quicklist entries
        KeyFile file;
        try {
            file = new KeyFile ();
            file.load_from_file (desktop_path, 0);
        } catch (Error e) {
            critical ("%s: %s", desktop_path, e.message);
        }

        string? textdomain = null;
        foreach (var domain_key in SUPPORTED_GETTEXT_DOMAINS_KEYS)
            if (file.has_key (KeyFileDesktop.GROUP, domain_key)) {
                textdomain = file.get_string (KeyFileDesktop.GROUP, domain_key);
                break;
            }
        if (actions != null && actions_map != null) {
            actions.clear ();
            actions_map.clear ();
            string[] keys = {DESKTOP_ACTION_KEY, UNITY_QUICKLISTS_KEY};

            foreach (var key in keys) {
                if (!file.has_key (KeyFileDesktop.GROUP, key))
                    continue;

                foreach (var action in file.get_string_list (KeyFileDesktop.GROUP, key)) {
                    var group = DESKTOP_ACTION_GROUP_NAME.printf (action);
                    if (!file.has_group (group)) {
                        group = UNITY_QUICKLISTS_SHORTCUT_GROUP_NAME.printf (action);
                        if (!file.has_group (group))
                            continue;
                    }

                    // check for TargetEnvironment
                    if (file.has_key (group, UNITY_QUICKLISTS_TARGET_KEY)) {
                        var target = file.get_string (group, UNITY_QUICKLISTS_TARGET_KEY);
                        if (target != UNITY_QUICKLISTS_TARGET_VALUE)
                            continue;
                    }

                    // check for OnlyShowIn
                    if (file.has_key (group, KeyFileDesktop.KEY_ONLY_SHOW_IN)) {
                        var found = false;

                        foreach (var s in file.get_string_list (group, KeyFileDesktop.KEY_ONLY_SHOW_IN))
                            if (s == UNITY_QUICKLISTS_TARGET_VALUE) {
                                found = true;
                                break;
                            }

                        if (!found)
                            continue;
                    }

                    var action_name = file.get_locale_string (group, KeyFileDesktop.KEY_NAME);

                    var action_icon = "";
                    if (file.has_key (group, KeyFileDesktop.KEY_ICON))
                        action_icon = file.get_locale_string (group, KeyFileDesktop.KEY_ICON);

                    var action_exec = "";
                    if (file.has_key (group, KeyFileDesktop.KEY_EXEC))
                        action_exec = file.get_string (group, KeyFileDesktop.KEY_EXEC);

                    // apply given gettext-domain if available
                    if (textdomain != null)
                        action_name = GLib.dgettext (textdomain, action_name).dup ();

                    actions.add (action_name);
                    actions_map.set (action_name, "%s;;%s".printf (action_exec, action_icon));
                }
            }
        }
    }
}
