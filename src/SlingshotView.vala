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

namespace Slingshot {

    public enum Modality {
        NORMAL_VIEW = 0,
        CATEGORY_VIEW = 1,
        SEARCH_VIEW
    }

#if HAS_PLANK_0_11
    public class SlingshotView : Gtk.Grid, Plank.UnityClient {
#else
    public class SlingshotView : Gtk.Grid {
#endif
        // Widgets
        public Gtk.SearchEntry search_entry;
        public Gtk.Stack stack;
        public Granite.Widgets.ModeButton view_selector;
        private Gtk.Revealer view_selector_revealer;

        // Views
        private Widgets.Grid grid_view;
        private Widgets.SearchView search_view;
        private Widgets.CategoryView category_view;

        public Gtk.Grid top;
        public Gtk.Grid container;
        public Gtk.Stack main_stack;
        public Gtk.Box content_area;
        private Gtk.EventBox event_box;

        public Backend.AppSystem app_system;
        private Gee.ArrayList<GMenu.TreeDirectory> categories;
        public Gee.HashMap<string, Gee.ArrayList<Backend.App>> apps;

        private Modality modality;

        private Backend.SynapseSearch synapse;

        // Sizes
        public int columns {
            get {
                return grid_view.get_page_columns ();
            }
        }
        public int rows {
            get {
                return grid_view.get_page_rows ();
            }
        }

        private int default_columns;
        private int default_rows;

        private int primary_monitor = 0;

        Gdk.Screen screen;

        public signal void close_indicator ();

        public SlingshotView () {
            // Have the window in the right place
            read_settings (true);

            Slingshot.icon_theme = Gtk.IconTheme.get_default ();

            app_system = new Backend.AppSystem ();
            synapse = new Backend.SynapseSearch ();

            categories = app_system.get_categories ();
            apps = app_system.get_apps ();

            screen = get_screen ();

            primary_monitor = screen.get_primary_monitor ();
            Gdk.Rectangle geometry;
            screen.get_monitor_geometry (primary_monitor, out geometry);
            if (Slingshot.settings.screen_resolution != @"$(geometry.width)x$(geometry.height)")
                setup_size ();

            height_request = calculate_grid_height () + Pixels.BOTTOM_SPACE;
            setup_ui ();

            connect_signals ();
            debug ("Apps loaded");
        }

        public int calculate_grid_height () {
            return (int) (default_rows * Pixels.ITEM_SIZE +
                         (default_rows - 1) * Pixels.ROW_SPACING);
        }

        public int calculate_grid_width () {
            return (int) default_columns * Pixels.ITEM_SIZE + 24;
        }

        private void setup_size () {
            debug ("In setup_size ()");
            primary_monitor = screen.get_primary_monitor ();
            Gdk.Rectangle geometry;
            screen.get_monitor_geometry (primary_monitor, out geometry);
            Slingshot.settings.screen_resolution = @"$(geometry.width)x$(geometry.height)";
            default_columns = 5;
            default_rows = 3;
            while ((calculate_grid_width () >= 2 * geometry.width / 3)) {
                default_columns--;
            }

            while ((calculate_grid_height () >= 2 * geometry.height / 3)) {
                default_rows--;
            }

            if (Slingshot.settings.columns != default_columns) {
                Slingshot.settings.columns = default_columns;
            }
            if (Slingshot.settings.rows != default_rows)
                Slingshot.settings.rows = default_rows;
        }

        private void setup_ui () {

            debug ("In setup_ui ()");

            // Create the base container
            container = new Gtk.Grid ();
            container.row_spacing = 12;
            container.margin_top = 12;

            // Add top bar
            top = new Gtk.Grid ();
            top.orientation = Gtk.Orientation.HORIZONTAL;
            top.margin_start = 6;
            top.margin_end = 6;

            view_selector = new Granite.Widgets.ModeButton ();
            view_selector.margin_end = 6;
            view_selector.margin_start = 6;
            view_selector_revealer = new Gtk.Revealer ();
            view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
            view_selector_revealer.add (view_selector);

            var image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
            image.tooltip_text = _("View as Grid");
            view_selector.append (image);

            image = new Gtk.Image.from_icon_name ("view-filter-symbolic", Gtk.IconSize.MENU);
            image.tooltip_text = _("View by Category");
            view_selector.append (image);

            if (Slingshot.settings.use_category)
                view_selector.selected = 1;
            else
                view_selector.selected = 0;

            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Apps");
            search_entry.hexpand = true;
            search_entry.margin_start = 6;
            search_entry.margin_end = 6;

            top.add (view_selector_revealer);
            top.add (search_entry);

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // Create the "NORMAL_VIEW"
            grid_view = new Widgets.Grid (default_rows, default_columns);
            stack.add_named (grid_view, "normal");

            // Create the "CATEGORY_VIEW"
            category_view = new Widgets.CategoryView (this);
            stack.add_named (category_view, "category");

            // Create the "SEARCH_VIEW"
            search_view = new Widgets.SearchView ();
            search_view.start_search.connect ((match, target) => {
                search.begin (search_entry.text, match, target);
            });

            stack.add_named (search_view, "search");

            container.attach (top, 0, 0, 1, 1);
            container.attach (stack, 0, 1, 1, 1);

            event_box = new Gtk.EventBox ();
            event_box.add (container);
            event_box.add_events (Gdk.EventMask.SCROLL_MASK);

            // Add the container to the dialog's content area

            this.add (event_box);

            if (Slingshot.settings.use_category)
                set_modality (Modality.CATEGORY_VIEW);
            else
                set_modality (Modality.NORMAL_VIEW);
            debug ("Ui setup completed");
        }

        private void connect_signals () {
            this.focus_in_event.connect (() => {
                search_entry.grab_focus ();
                return false;
            });

            event_box.key_press_event.connect (on_event_box_key_press);
            search_entry.key_press_event.connect (on_search_view_key_press);
            search_entry.key_press_event.connect_after (on_key_press);

            // Showing a menu reverts the effect of the grab_device function.
            search_entry.search_changed.connect (() => {
                if (modality != Modality.SEARCH_VIEW)
                    set_modality (Modality.SEARCH_VIEW);
                search.begin (search_entry.text);
            });

            search_entry.grab_focus ();
            search_entry.activate.connect (search_entry_activated);

            // FIXME: signals chain up is not supported
            search_view.app_launched.connect (() => { close_indicator (); });

            // This function must be after creating the page switcher
            populate_grid_view ();

            view_selector.mode_changed.connect (() => {

                set_modality ((Modality) view_selector.selected);
            });

            // Auto-update settings when changed
            Slingshot.settings.changed["rows"].connect ( () => {read_settings (false, false, true);});
            Slingshot.settings.changed["columns"].connect ( () => {read_settings (false, true, false);});

            // Auto-update applications grid
            app_system.changed.connect (() => {

                categories = app_system.get_categories ();
                apps = app_system.get_apps ();

                populate_grid_view ();
                category_view.setup_sidebar ();
            });

            // position on the right monitor when settings changed
            screen.size_changed.connect (() => {
                Gdk.Rectangle geometry;
                screen.get_monitor_geometry (screen.get_primary_monitor (), out geometry);
                if (Slingshot.settings.screen_resolution != @"$(geometry.width)x$(geometry.height)") {
                    setup_size ();
                }
            });
        }

#if HAS_PLANK_0_11
        public void update_launcher_entry (string sender_name, GLib.Variant parameters, bool is_retry = false) {
            if (!is_retry) {
                // Wait to let further update requests come in to catch the case where one application
                // sends out multiple LauncherEntry-updates with different application-uris, e.g. Nautilus
                Idle.add (() => {
                    update_launcher_entry (sender_name, parameters, true);
                    return false;
                });

                return;
            }

            string app_uri;
            VariantIter prop_iter;
            parameters.get ("(sa{sv})", out app_uri, out prop_iter);

            foreach (var app in app_system.get_apps_by_name ()) {
                if (app_uri == "application://" + app.desktop_id) {
                    app.perform_unity_update (sender_name, prop_iter);
                }
            }
        }

        public void remove_launcher_entry (string sender_name) {
            foreach (var app in app_system.get_apps_by_name ()) {
                app.remove_launcher_entry (sender_name);
            }
        }
#endif

        private void change_view_mode (string key) {
            switch (key) {
                case "1": // Normal view
                    view_selector.selected = 0;
                    break;
                default: // Category view
                    view_selector.selected = 1;
                    break;
            }
        }

        private void search_entry_activated () {
            if (modality == Modality.SEARCH_VIEW) {
                search_view.activate_selection ();
            }
        }

        /* These keys do not work if connect_after used; the rest of the key events
         * are dealt with after the default handler in order that CJK input methods
         * work properly */  
        public bool on_search_view_key_press (Gdk.EventKey event) {
            var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");

            switch (key) {
                case "1":
                case "2":
                    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                        change_view_mode (key);
                        return true;
                    }

                    break;

                case "F4":
                    if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                        close_indicator ();
                        return true;
                    }

                    break;

                case "Escape":
                    if (search_entry.text.length > 0) {
                        search_entry.text = "";
                    } else {
                        close_indicator ();
                    }

                    return true;

                default:
                    break;
            }

            return false;
        }

        public bool on_event_box_key_press (Gdk.EventKey event) {
            if (!on_search_view_key_press (event)) {
                return on_key_press (event);
            } else {
                return true;
            }
        }

        public bool on_key_press (Gdk.EventKey event) {
            var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");
            switch (key) {
                case "Enter": // "KP_Enter"
                case "Return":
                case "KP_Enter":
                    return false;

                case "Alt_L":
                case "Alt_R":
                    break;

                case "0":
                case "1":
                case "2":
                case "3":
                case "4":
                case "5":
                case "6":
                case "7":
                case "8":
                case "9":
                    int page = int.parse (key);

                    if (event.state != Gdk.ModifierType.MOD1_MASK)
                        return false;

                    if (modality == Modality.NORMAL_VIEW) {
                        if (page < 0 || page == 9)
                            grid_view.go_to_last ();
                        else
                            grid_view.go_to_number (page);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (page < 0 || page == 9)
                            category_view.app_view.go_to_last ();
                        else
                            category_view.app_view.go_to_number (page);
                    } else {
                        return false;
                    }
                    search_entry.grab_focus ();
                    break;

                case "Tab":
                    if (modality == Modality.NORMAL_VIEW) {
                        view_selector.selected = (int) Modality.CATEGORY_VIEW;
                        category_view.app_view.top_left_focus ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        view_selector.selected = (int) Modality.NORMAL_VIEW;
                        grid_view.top_left_focus ();
                    }
                    break;

                case "Left":
                    if (modality != Modality.NORMAL_VIEW && modality != Modality.CATEGORY_VIEW)
                        return false;

                    if (get_style_context ().direction == Gtk.TextDirection.LTR) {
                        move_left (event);
                    } else {
                        move_right (event);
                    }

                    break;
                case "Right":
                    if (modality != Modality.NORMAL_VIEW && modality != Modality.CATEGORY_VIEW)
                        return false;

                    if (get_style_context ().direction == Gtk.TextDirection.LTR) {
                        move_right (event);
                    } else {
                        move_left (event);
                    }

                    break;
                case "Up":
                    if (modality == Modality.NORMAL_VIEW) {
                            normal_move_focus (0, -1);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Up
                            if (category_view.category_switcher.selected != 0) {
                                category_view.category_switcher.selected--;
                                category_view.app_view.top_left_focus ();
                            }
                        } else if (search_entry.has_focus) {
                            category_view.category_switcher.selected--;
                        } else {
                          category_move_focus (0, -1);
                        }
                    } else if (modality == Modality.SEARCH_VIEW) {
                        return false;
                    }
                    break;

                case "Down":
                    if (modality == Modality.NORMAL_VIEW) {
                        if (search_entry.has_focus) {
                            grid_view.top_left_focus ();
                        } else {
                            normal_move_focus (0, +1);
                        }
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Down
                            category_view.category_switcher.selected++;
                            category_view.app_view.top_left_focus ();
                        } else if (search_entry.has_focus) {
                            category_view.category_switcher.selected++;
                        } else { // the user has already selected an AppEntry
                            category_move_focus (0, +1);
                        }
                    } else if (modality == Modality.SEARCH_VIEW) {
                        return false;
                    }
                    break;

                case "Page_Up":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_previous ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected--;
                        category_view.app_view.top_left_focus ();
                    }
                    break;

                case "Page_Down":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_next ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected++;
                        category_view.app_view.top_left_focus ();
                    }
                    break;

                case "BackSpace":
                    if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Delete
                        search_entry.text = "";
                    } else if (search_entry.has_focus) {
                        return false;
                    } else {
                        search_entry.grab_focus ();
                        search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                        return false;
                    }
                    break;

                case "Home":
                    if (search_entry.text.length > 0) {
                        return false;
                    }

                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_number (1);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected = 0;
                        category_view.app_view.top_left_focus ();
                    }
                    break;

                case "End":
                    if (search_entry.text.length > 0) {
                        return false;
                    }

                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_last ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected = category_view.category_switcher.cat_size - 1;
                        category_view.app_view.top_left_focus ();
                    }
                    break;

                case "v":
                case "V":
                    if ((event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) != 0) {
                        search_entry.paste_clipboard ();
                    } else {
                        return false;
                    }
                    break;

                default:
                    if (!search_entry.has_focus) {
                        search_entry.grab_focus ();
                        search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                        search_entry.key_press_event (event);
                    }
                    return false;

            }

            return true;
        }

        public override bool scroll_event (Gdk.EventScroll scroll_event) {
            print ("Direction: %s\n", scroll_event.direction.to_string ());
            print ("Device input souce: %s\n", scroll_event.device.get_source ().to_string ());

            if (scroll_event.direction != Gdk.ScrollDirection.DOWN &&
                scroll_event.direction != Gdk.ScrollDirection.UP &&
                (grid_view.stack.transition_running || category_view.app_view.stack.transition_running)) {
                return false;
            }

            switch (scroll_event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_LEFT":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_previous ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.app_view.go_to_previous ();
                    }
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_next ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.app_view.go_to_next ();
                    }
                    break;

            }

            return false;
        }

        public void show_slingshot () {
            search_entry.text = "";

/* TODO
            set_focus (null);
*/

            search_entry.grab_focus ();
            // This is needed in order to not animate if the previous view was the search view.
            view_selector_revealer.transition_type = Gtk.RevealerTransitionType.NONE;
            stack.transition_type = Gtk.StackTransitionType.NONE;
            set_modality ((Modality) view_selector.selected);
            view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        }

        /*
         * Moves the current view to the left (undependent of the TextDirection).
         */
        private void move_left (Gdk.EventKey event) {
            if (modality == Modality.NORMAL_VIEW) {
                if (event.state == Gdk.ModifierType.SHIFT_MASK) {// Shift + Left
                    grid_view.go_to_previous ();
                } else {
                    normal_move_focus (-1, 0);
                }
            } else if (modality == Modality.CATEGORY_VIEW) {
                if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Left
                    category_view.app_view.go_to_previous ();
                else if (!search_entry.has_focus) {//the user has already selected an AppEntry
                    category_move_focus (-1, 0);
                }
            }
        }

        /*
         * Moves the current view to the right (undependent of the TextDirection).
         */
        private void move_right (Gdk.EventKey event) {
            if (modality == Modality.NORMAL_VIEW) {
                if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                    grid_view.go_to_next ();
                else
                    normal_move_focus (+1, 0);
            } else if (modality == Modality.CATEGORY_VIEW) {
                if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                    category_view.app_view.go_to_next ();
                else if (search_entry.has_focus) // there's no AppEntry selected, the user is switching category
                    category_view.app_view.top_left_focus ();
                else //the user has already selected an AppEntry
                    category_move_focus (+1, 0);
            }
        }

        private void set_modality (Modality new_modality) {
            modality = new_modality;

            switch (modality) {
                case Modality.NORMAL_VIEW:

                    if (Slingshot.settings.use_category)
                        Slingshot.settings.use_category = false;
                    view_selector_revealer.set_reveal_child (true);
                    stack.set_visible_child_name ("normal");

                    search_entry.grab_focus ();
                    break;

                case Modality.CATEGORY_VIEW:

                    if (!Slingshot.settings.use_category)
                        Slingshot.settings.use_category = true;
                    view_selector_revealer.set_reveal_child (true);
                    stack.set_visible_child_name ("category");

                    search_entry.grab_focus ();
                    break;

                case Modality.SEARCH_VIEW:
                    view_selector_revealer.set_reveal_child (false);
                    stack.set_visible_child_name ("search");
                    break;

            }
        }

        private async void search (string text, Synapse.SearchMatch? search_match = null,
            Synapse.Match? target = null) {

            var stripped = text.strip ();

            if (stripped == "") {
                // this code was making problems when selecting the currently searched text
                // and immediately replacing it. In that case two async searches would be
                // started and both requested switching from and to search view, which would
                // result in a Gtk error and the first letter of the new search not being
                // picked up. If we add an idle and recheck that the entry is indeed still
                // empty before switching, this problem is gone.
                Idle.add (() => {
                    if (search_entry.text.strip () == "")
                        set_modality ((Modality) view_selector.selected);
                    return false;
                });
                return;
            }

            if (modality != Modality.SEARCH_VIEW)
                set_modality (Modality.SEARCH_VIEW);

            Gee.List<Synapse.Match> matches;

            if (search_match != null) {
                search_match.search_source = target;
                matches = yield synapse.search (text, search_match);
            } else {
                matches = yield synapse.search (text);
            }

            Idle.add (() => {
                search_view.set_results (matches, text);
                return false;
            });

        }

        public void populate_grid_view () {
            grid_view.clear ();
            foreach (Backend.App app in app_system.get_apps_by_name ()) {
                var app_entry = new Widgets.AppEntry (app);
                app_entry.app_launched.connect (() => close_indicator ());
                grid_view.append (app_entry);
                app_entry.show_all ();
            }

            stack.set_visible_child_name ("normal");
        }

        private void read_settings (bool first_start = false, bool check_columns = true, bool check_rows = true) {
            if (check_columns) {
                if (Slingshot.settings.columns > 3)
                    default_columns = Slingshot.settings.columns;
                else
                    default_columns = Slingshot.settings.columns = 4;
            }

            if (check_rows) {
                if (Slingshot.settings.rows > 1)
                    default_rows = Slingshot.settings.rows;
                else
                    default_rows = Slingshot.settings.rows = 2;
            }

            if (!first_start) {
                grid_view.resize (default_rows, default_columns);
                populate_grid_view ();
                height_request = calculate_grid_height () + Pixels.BOTTOM_SPACE;

                category_view.app_view.resize (default_rows, default_columns);
                category_view.show_filtered_apps (category_view.category_ids.get (category_view.category_switcher.selected));
            }
        }

        private void normal_move_focus (int delta_column, int delta_row) {
            if (grid_view.set_focus_relative (delta_column, delta_row)) {
                return;
            }

            if (delta_column < 0 || delta_row < 0) {
                search_entry.grab_focus ();
            }
        }

        private void category_move_focus (int delta_column, int delta_row) {
            if (category_view.app_view.set_focus_relative (delta_column, delta_row)) {
                return;
            }

            if (delta_row < 0 && category_view.category_switcher.selected > 0) {
                category_view.category_switcher.selected--;
                category_view.app_view.top_left_focus ();
            } else if (delta_row > 0) {
                category_view.category_switcher.selected++;
                category_view.app_view.top_left_focus ();
            } else if (delta_column < 0 || delta_row < 0) {
                search_entry.grab_focus ();
            }
        }
    }
}
