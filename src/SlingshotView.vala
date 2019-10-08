/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2011-2012 Giulio Collura
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#if HAS_PLANK
public class Slingshot.SlingshotView : Gtk.Grid, Plank.UnityClient {
#else
public class Slingshot.SlingshotView : Gtk.Grid {
#endif
    public signal void close_indicator ();

    public Backend.AppSystem app_system;
    public Gee.HashMap<string, Gee.ArrayList<Backend.App>> apps;
    public Gtk.SearchEntry search_entry;
    public Gtk.Stack stack;
    public Granite.Widgets.ModeButton view_selector;

    private enum Modality {
        NORMAL_VIEW = 0,
        CATEGORY_VIEW = 1,
        SEARCH_VIEW
    }

    public const int DEFAULT_COLUMNS = 5;
    public const int DEFAULT_ROWS = 3;

    private Backend.SynapseSearch synapse;
    private Gdk.Screen screen;
    private Gtk.Revealer view_selector_revealer;
    private Modality modality;
    private Widgets.Grid grid_view;
    private Widgets.SearchView search_view;
    private Widgets.CategoryView category_view;

    private static GLib.Settings settings { get; private set; default = null; }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wingpanel.applications-menu");
    }

    construct {
        app_system = new Backend.AppSystem ();
        synapse = new Backend.SynapseSearch ();

        apps = app_system.get_apps ();

        screen = get_screen ();

        height_request = (int) (
            DEFAULT_ROWS * Pixels.ITEM_SIZE + (DEFAULT_ROWS - 1) * Pixels.ROW_SPACING
        ) + Pixels.BOTTOM_SPACE;

        var grid_image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
        grid_image.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>1"}, _("View as Grid"));

        var category_image = new Gtk.Image.from_icon_name ("view-filter-symbolic", Gtk.IconSize.MENU);
        category_image.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>2"}, _("View by Category"));

        view_selector = new Granite.Widgets.ModeButton ();
        view_selector.margin_end = 12;
        view_selector.append (grid_image);
        view_selector.append (category_image);

        view_selector_revealer = new Gtk.Revealer ();
        view_selector_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        view_selector_revealer.add (view_selector);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Apps");
        search_entry.hexpand = true;
        search_entry.secondary_icon_tooltip_markup = Granite.markup_accel_tooltip (
            {"<Ctrl>BackSpace"}, _("Clear all")
        );

        var top = new Gtk.Grid ();
        top.margin_start = 12;
        top.margin_end = 12;
        top.add (view_selector_revealer);
        top.add (search_entry);

        grid_view = new Widgets.Grid ();

        category_view = new Widgets.CategoryView (this);

        search_view = new Widgets.SearchView ();

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        stack.add_named (grid_view, "normal");
        stack.add_named (category_view, "category");
        stack.add_named (search_view, "search");

        var container = new Gtk.Grid ();
        container.row_spacing = 12;
        container.margin_top = 12;
        container.attach (top, 0, 0);
        container.attach (stack, 0, 1);

        // This function must be after creating the page switcher
        populate_grid_view ();

        var event_box = new Gtk.EventBox ();
        event_box.add (container);
        event_box.add_events (Gdk.EventMask.SCROLL_MASK);

        // Add the container to the dialog's content area
        this.add (event_box);

        if (settings.get_boolean ("use-category")) {
            view_selector.selected = 1;
            set_modality (Modality.CATEGORY_VIEW);
        } else {
            view_selector.selected = 0;
            set_modality (Modality.NORMAL_VIEW);
        }

        search_view.start_search.connect ((match, target) => {
            search.begin (search_entry.text, match, target);
        });

        focus_in_event.connect (() => {
            search_entry.grab_focus ();
            return Gdk.EVENT_PROPAGATE;
        });

        event_box.key_press_event.connect (on_event_box_key_press);
        search_entry.key_press_event.connect (on_search_view_key_press);
        search_entry.key_press_event.connect_after (on_key_press);

        // Showing a menu reverts the effect of the grab_device function.
        search_entry.search_changed.connect (() => {
            if (modality != Modality.SEARCH_VIEW) {
                set_modality (Modality.SEARCH_VIEW);
            }
            search.begin (search_entry.text);
        });

        search_entry.grab_focus ();
        search_entry.activate.connect (search_entry_activated);

        // FIXME: signals chain up is not supported
        search_view.app_launched.connect (() => {
            close_indicator ();
        });

        view_selector.mode_changed.connect (() => {
            set_modality ((Modality) view_selector.selected);
        });

        // Auto-update applications grid
        app_system.changed.connect (() => {
            apps = app_system.get_apps ();

            populate_grid_view ();
            category_view.setup_sidebar ();
        });
    }

#if HAS_PLANK
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

        if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            switch (key) {
                case "1":
                    view_selector.selected = 0;
                    return Gdk.EVENT_STOP;
                case "2":
                    view_selector.selected = 1;
                    return Gdk.EVENT_STOP;
            }
            return Gdk.EVENT_PROPAGATE;
        }

        switch (key) {
            case "F4":
                if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                    close_indicator ();
                    return Gdk.EVENT_STOP;
                }

                break;

            case "Escape":
                if (search_entry.text.length > 0) {
                    search_entry.text = "";
                } else {
                    close_indicator ();
                }

                return Gdk.EVENT_STOP;

            default:
                break;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public bool on_event_box_key_press (Gdk.EventKey event) {
        if (!on_search_view_key_press (event)) {
            return on_key_press (event);
        } else {
            return Gdk.EVENT_STOP;
        }
    }

    public bool on_key_press (Gdk.EventKey event) {
        var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");
        switch (key) {
            case "Enter": // "KP_Enter"
            case "Return":
            case "KP_Enter":
            case "Tab":
                return Gdk.EVENT_PROPAGATE;

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
                if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                    int page = int.parse (key);
                    if (modality == Modality.NORMAL_VIEW) {
                        if (page < 0 || page == 9) {
                            grid_view.go_to_last ();
                        } else {
                            grid_view.go_to_number (page);
                        }
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (page < 0 || page == 9) {
                            category_view.app_view.go_to_last ();
                        } else {
                            category_view.app_view.go_to_number (page);
                        }
                    }

                    search_entry.grab_focus ();
                    return Gdk.EVENT_STOP;
                }

                return Gdk.EVENT_PROPAGATE;
            case "Left":
                if (modality != Modality.NORMAL_VIEW && modality != Modality.CATEGORY_VIEW)
                    return Gdk.EVENT_PROPAGATE;

                if (get_style_context ().direction == Gtk.TextDirection.LTR) {
                    move_left (event);
                } else {
                    move_right (event);
                }

                break;
            case "Right":
                if (modality != Modality.NORMAL_VIEW && modality != Modality.CATEGORY_VIEW)
                    return Gdk.EVENT_PROPAGATE;

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
                        category_view.page_up ();
                    } else if (search_entry.has_focus) {
                        category_view.category_switcher.selected--;
                    } else {
                      category_move_focus (0, -1);
                    }
                } else if (modality == Modality.SEARCH_VIEW) {
                    return Gdk.EVENT_PROPAGATE;
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
                        category_view.page_down ();
                    } else if (search_entry.has_focus) {
                        category_view.category_switcher.selected++;
                    } else { // the user has already selected an AppButton
                        category_move_focus (0, +1);
                    }
                } else if (modality == Modality.SEARCH_VIEW) {
                    return Gdk.EVENT_PROPAGATE;
                }
                break;

            case "Page_Up":
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_previous ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.page_up ();
                }
                break;

            case "Page_Down":
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_next ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.page_down ();
                }
                break;

            case "BackSpace":
                if (!search_entry.has_focus) {
                    search_entry.grab_focus ();
                    search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                }
                return Gdk.EVENT_PROPAGATE;
            case "Home":
                if (search_entry.text.length > 0) {
                    return Gdk.EVENT_PROPAGATE;
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
                    return Gdk.EVENT_PROPAGATE;
                }

                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_last ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.category_switcher.selected = category_view.category_switcher.cat_size - 1;
                    category_view.app_view.top_left_focus ();
                }
                break;
            default:
                if (!search_entry.has_focus) {
                    search_entry.grab_focus ();
                    search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                    search_entry.key_press_event (event);
                }
                return Gdk.EVENT_PROPAGATE;

        }

        return Gdk.EVENT_STOP;
    }

    public override bool scroll_event (Gdk.EventScroll scroll_event) {
        unowned Gdk.Device? device = scroll_event.get_source_device ();

        if ((device == null ||
            (device.input_source != Gdk.InputSource.MOUSE && device.input_source != Gdk.InputSource.KEYBOARD)) &&
            (grid_view.transition_running || category_view.app_view.transition_running)) {
            return Gdk.EVENT_PROPAGATE;
        }

        switch (scroll_event.direction) {
            case Gdk.ScrollDirection.UP:
            case Gdk.ScrollDirection.LEFT:
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_previous ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.app_view.go_to_previous ();
                }
                break;
            case Gdk.ScrollDirection.DOWN:
            case Gdk.ScrollDirection.RIGHT:
                if (modality == Modality.NORMAL_VIEW) {
                    grid_view.go_to_next ();
                } else if (modality == Modality.CATEGORY_VIEW) {
                    category_view.app_view.go_to_next ();
                }
                break;
        }

        return Gdk.EVENT_PROPAGATE;
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
            else if (!search_entry.has_focus) {//the user has already selected an AppButton
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
            else if (search_entry.has_focus) // there's no AppButton selected, the user is switching category
                category_view.app_view.top_left_focus ();
            else //the user has already selected an AppButton
                category_move_focus (+1, 0);
        }
    }

    private void set_modality (Modality new_modality) {
        modality = new_modality;

        switch (modality) {
            case Modality.NORMAL_VIEW:
                if (settings.get_boolean ("use-category")) {
                    settings.set_boolean ("use-category", false);
                }

                view_selector_revealer.set_reveal_child (true);
                stack.set_visible_child_name ("normal");

                search_entry.grab_focus ();
                break;

            case Modality.CATEGORY_VIEW:
                if (!settings.get_boolean ("use-category")) {
                    settings.set_boolean ("use-category", true);
                }

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
            var app_button = new Widgets.AppButton (app);
            app_button.app_launched.connect (() => close_indicator ());
            grid_view.append (app_button);
        }

        grid_view.show_all ();
    }

    private void normal_move_focus (int delta_column, int delta_row) {
        if (grid_view.set_focus_relative (delta_column, delta_row)) {
            return;
        }

        int pages = grid_view.get_n_pages ();
        int current = grid_view.get_current_page ();
        int columns = grid_view.get_page_columns ();

        if (delta_column > 0 && current < pages && grid_view.set_focus ((pages - 1) * columns, 0)) {
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
