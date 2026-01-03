/*
 * Copyright 2026 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

public class Slingshot.Widgets.FavoritesSidebar : Gtk.Box {
    public signal void app_launched ();

    private Gtk.ListBox favorites_list;
    private Gtk.Button session_button;
    private AppMenu.PowerStrip powerstrip;
    private Budgie.Popover? session_popover = null;
    private Backend.FavoritesManager favorites_manager;
    private Backend.AppSystem app_system;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        width_request = 64;

        favorites_manager = Backend.FavoritesManager.get_default ();

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled.vexpand = true;

        favorites_list = new Gtk.ListBox ();
        favorites_list.selection_mode = Gtk.SelectionMode.NONE;
        favorites_list.get_style_context ().add_class ("favorites-list");

        scrolled.add (favorites_list);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        // Session button with icon (like Windows Start button power icon)
        session_button = new Gtk.Button ();
        session_button.relief = Gtk.ReliefStyle.NONE;
        session_button.halign = Gtk.Align.CENTER;
        session_button.valign = Gtk.Align.CENTER;
        session_button.margin = 6;

        var session_icon = new Gtk.Image.from_icon_name ("system-shutdown-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        session_icon.pixel_size = 24;
        session_button.add (session_icon);
        session_button.tooltip_text = _("Power Options");

        var session_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        session_box.pack_start (session_button, false, false, 0);

        pack_start (scrolled, true, true, 0);
        pack_start (separator, false, false, 0);
        pack_start (session_box, false, false, 0);

        // Create powerstrip for session popover
        powerstrip = new AppMenu.PowerStrip (Gtk.Orientation.VERTICAL);
        powerstrip.invoke_action.connect (() => {
            if (session_popover != null) {
                session_popover.hide ();
            }
            app_launched ();
        });

        // Setup popover
        session_popover = new Budgie.Popover (session_button);
        session_popover.add (powerstrip);
        powerstrip.show_all ();

        session_button.clicked.connect (() => {
            if (session_popover.get_visible ()) {
                session_popover.hide ();
            } else {
                session_popover.show_all ();
            }
        });

        favorites_list.row_activated.connect ((row) => {
            var fav_row = row as FavoriteRow;
            if (fav_row != null) {
                fav_row.launch ();
                app_launched ();
            }
        });

        favorites_manager.favorites_changed.connect (() => {
            populate_favorites ();
        });

        this.show_all();
    }

    public void set_app_system (Backend.AppSystem system) {
        app_system = system;
        populate_favorites ();
    }

    public void validate_and_populate () {
        favorites_manager.validate_favorites ();
        populate_favorites ();
    }

    private void populate_favorites () {
        favorites_list.foreach ((widget) => {
            widget.destroy ();
        });

        if (app_system == null) return;

        var favorites = favorites_manager.get_favorites ();
        var dfs = Synapse.DesktopFileService.get_default ();

        foreach (string desktop_id in favorites) {
            var info = dfs.get_desktop_file_for_id (desktop_id);
            if (info != null && !info.is_hidden && info.is_valid) {
                var row = new FavoriteRow (desktop_id, info.filename);
                row.show_context_menu.connect ((event) => {
                    return create_context_menu (event, row);
                });
                favorites_list.add (row);
            }
        }

        favorites_list.show_all ();
    }

    private bool create_context_menu (Gdk.Event event, FavoriteRow? row) {
        if (row == null) return Gdk.EVENT_PROPAGATE;

        // Capture the desktop_id now, not in the callback
        string desktop_id_to_remove = row.desktop_id;

        // Create menu manually to avoid duplicate "Remove from Favorites"
        var menu = new Gtk.Menu ();

        // Add "Remove from Favorites" first
        var remove_item = new Gtk.MenuItem.with_label (_("Remove from Favorites"));
        remove_item.activate.connect (() => {
            favorites_manager.remove_favorite (desktop_id_to_remove);
        });
        menu.add (remove_item);

        // Get app info for additional actions
        var app_info = new DesktopAppInfo (row.desktop_id);

        // Add application-specific actions
        foreach (unowned string _action in app_info.list_actions ()) {
            string action = _action.dup ();
            var menuitem = new Gtk.MenuItem.with_mnemonic (app_info.get_action_name (action));
            menu.add (menuitem);

            menuitem.activate.connect (() => {
                app_info.launch_action (action, new AppLaunchContext ());
                app_launched ();
            });
        }

        // Only add separator if there are app actions
        if (app_info.list_actions ().length > 0) {
            var separator = new Gtk.SeparatorMenuItem ();
            menu.insert (separator, 1);  // Insert after "Remove from Favorites"
        }

        // Add GPU selection if available
        var switcheroo_control = new Slingshot.Backend.SwitcherooControl ();
        if (switcheroo_control != null && switcheroo_control.has_dual_gpu) {
            bool prefers_non_default_gpu = app_info.get_boolean ("PrefersNonDefaultGPU");
            string gpu_name = switcheroo_control.get_gpu_name (prefers_non_default_gpu);
            string label = _("Open with %s Graphics").printf (gpu_name);

            var menu_item = new Gtk.MenuItem.with_mnemonic (label);
            menu.add (menu_item);

            menu_item.activate.connect (() => {
               try {
                   var context = new AppLaunchContext ();
                   switcheroo_control.apply_gpu_environment (context, prefers_non_default_gpu);
                   app_info.launch (null, context);
                   app_launched ();
               } catch (Error e) {
                   warning ("Failed to launch %s: %s", app_info.get_name (), e.message);
               }
            });
        }

#if HAS_PLANK
        // Add Plank dock integration
        var plank_client = Plank.DBusClient.get_instance ();
        if (plank_client != null && plank_client.is_connected) {
            var desktop_uri = File.new_for_path (row.desktop_path).get_uri ();

            var plank_menuitem = new Gtk.MenuItem ();
            plank_menuitem.use_underline = true;

            bool docked = (desktop_uri in plank_client.get_persistent_applications ());
            if (docked) {
                plank_menuitem.label = _("Remove from _Dock");
            } else {
                plank_menuitem.label = _("Add to _Dock");
            }

            plank_menuitem.activate.connect (() => {
                if (docked) {
                    plank_client.remove_item (desktop_uri);
                } else {
                    plank_client.add_item (desktop_uri);
                }
            });

            menu.add (plank_menuitem);
        }
#endif

        menu.show_all ();

        if (event.type == Gdk.EventType.BUTTON_PRESS) {
            menu.popup_at_pointer (event);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private class FavoriteRow : Gtk.ListBoxRow {
        public signal bool show_context_menu (Gdk.Event event);
	public string desktop_id { get; construct; }
        public string desktop_path { get; construct; }
        private GLib.DesktopAppInfo app_info;
        private Gtk.Label? tooltip_label = null;
        private uint timeout_id = 0;

        public FavoriteRow (string desktop_id, string desktop_path) {
            Object (
                desktop_id: desktop_id,
                desktop_path: desktop_path
            );
        }

        construct {
            app_info = new GLib.DesktopAppInfo (desktop_id);

            var icon = app_info.get_icon ();
            if (icon == null) {
                icon = new ThemedIcon ("application-default-icon");
            }

            var image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.INVALID);
            image.pixel_size = 32;
            image.margin = 8;

            var event_box = new Gtk.EventBox ();
            event_box.add (image);
            event_box.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            add (event_box);

            // Create persistent tooltip label that will be shown/hidden
            tooltip_label = new Gtk.Label (null);
            tooltip_label.set_markup (
                "<b>%s</b>\n<small>%s</small>".printf (
                    Markup.escape_text (app_info.get_display_name ()),
                    Markup.escape_text (app_info.get_description () ?? "")
                )
            );
            tooltip_label.halign = Gtk.Align.START;
            tooltip_label.margin = 8;
            tooltip_label.get_style_context ().add_class ("tooltip");
            tooltip_label.get_style_context ().add_class ("background");

            // Use standard tooltip instead of popover to avoid positioning issues
            var tooltip_text = app_info.get_display_name ();
            if (app_info.get_description () != null && app_info.get_description () != "") {
                tooltip_text += "\n" + app_info.get_description ();
            }
            this.tooltip_text = tooltip_text;

            // Connect context menu directly to this row
            this.button_press_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_SECONDARY) {
                    return show_context_menu (event);
                }
                return Gdk.EVENT_PROPAGATE;
            });

            this.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Menu) {
                    return show_context_menu (event);
                }
                return Gdk.EVENT_PROPAGATE;
            });
        }

        public void launch () {
            try {
                var commandline = app_info.get_commandline ();
                string[] spawn_args = {};
                const string checkstr = "pkexec";

                if (commandline.contains (checkstr)) {
                    spawn_args = commandline.split (" ");
                }

                if (spawn_args.length >= 2 && spawn_args[0] == checkstr) {
                    string[] spawn_env = Environ.get ();
                    Pid child_pid;
                    Process.spawn_async (
                        "/",
                        spawn_args,
                        spawn_env,
                        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                        null,
                        out child_pid
                    );
                    ChildWatch.add (child_pid, (pid, status) => {
                        Process.close_pid (pid);
                    });
                } else {
                    app_info.launch (null, null);
                }
            } catch (Error error) {
                critical (error.message);
            }
        }
    }
}
