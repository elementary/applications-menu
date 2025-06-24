/*
 * Copyright 2011-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Giulio Collura
 */

// The first entries of ResultType enum must match those of Synapse.MatchType so that a cast from
// Synapse.MatchType to ResultType is valid.
public enum Slingshot.Widgets.ResultType {
    UNKNOWN = 0,
    TEXT,
    CALCULATION,
    APPLICATION,
    BOOKMARK,
    GENERIC_URI,
    ACTION,
    SEARCH,
    APP_ACTIONS, // Extra entries from here
    CONTACT,
    INTERNET,
    SETTINGS,
    LINK;

    public unowned string to_string () {
        switch (this) {
            case TEXT:
                return _("Text");
            case CALCULATION:
                return _("Calculation");
            case APPLICATION:
                return _("Applications");
            case GENERIC_URI:
                return _("Files");
            case LINK:
            case ACTION:
                return _("Actions");
            case SEARCH:
                return _("Search");
            case CONTACT:
                return _("Contacts");
            case INTERNET:
                return _("Internet");
            case SETTINGS:
                return _("Settings");
            case APP_ACTIONS:
                return _("Application Actions");
            case BOOKMARK:
                return _("Bookmarks");
            default:
                return _("Other");
        }
    }
}

public class Slingshot.Widgets.SearchView : Granite.Bin {

    const int MAX_RESULTS = 10;

    public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);
    public signal void app_launched ();

    private Granite.Placeholder alert_view;
    private Gtk.ListBox list_box;
    Gee.HashMap<ResultType, uint> limitator;
    private string? drag_uri = null;

    construct {
        alert_view = new Granite.Placeholder ("") {
            icon = new ThemedIcon ("edit-find-symbolic"),
            description = _("Try changing search terms.")
        };

        // list box
        limitator = new Gee.HashMap<ResultType, uint> ();

        // const Gtk.TargetEntry DND = {"text/uri-list", 0, 0};
        // Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {DND}, Gdk.DragAction.COPY);

        list_box = new Gtk.ListBox () {
            activate_on_single_click = true,
            selection_mode = BROWSE
        };
        list_box.set_sort_func ((row1, row2) => update_sort (row1, row2));
        list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) update_header);
        list_box.set_placeholder (alert_view);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = list_box,
            hscrollbar_policy = NEVER
        };

        child = scrolled_window;

        // list_box.drag_begin.connect ((ctx) => {
        //     var selected_row = list_box.get_selected_row ();
        //     if (selected_row != null) {

        //         var drag_item = (Slingshot.Widgets.SearchItem) selected_row;
        //         drag_uri = drag_item.app_uri;
        //         if (drag_uri != null) {
        //             Gtk.drag_set_icon_gicon (ctx, drag_item.image.gicon, 32, 32);
        //         }

        // list_box.drag_end.connect (() => {
        //     if (drag_uri != null) {
        //         app_launched ();
        //     }

        //     drag_uri = null;
        // });

        // list_box.drag_data_get.connect ((ctx, sel, info, time) => {
        //     if (drag_uri != null) {
        //         sel.set_uris ({drag_uri});
        //     }
        // });

        list_box.move_cursor.connect (move_cursor);

        list_box.row_activated.connect ((row) => {
            Idle.add (() => {
                var search_item = row as SearchItem;
                switch (search_item.result_type) {
                    case ResultType.APP_ACTIONS:
                    case ResultType.LINK:
                    case ResultType.SETTINGS:
                    case ResultType.BOOKMARK:
                        search_item.app.match.execute (null);
                        break;
                    default:
                        search_item.app.launch ();
                        break;
                }

                app_launched ();

                return false;
            });
        });

        var click_controller = new Gtk.GestureClick () {
            button = 0,
            exclusive = true
        };
        click_controller.pressed.connect ((n_press, x, y) => {
            var search_item = (SearchItem) list_box.get_selected_row ();

            var sequence = click_controller.get_current_sequence ();
            var event = click_controller.get_last_event (sequence);

            if (event.triggers_context_menu ()) {
                var context_menu = search_item.create_context_menu ();
                if (context_menu != null) {
                    Utils.menu_popup_at_pointer (context_menu, x, y);
                }

                click_controller.set_state (CLAIMED);
                click_controller.reset ();
            }
        });

        var menu_key_controller = new Gtk.EventControllerKey ();
        menu_key_controller.key_released.connect ((keyval, keycode, state) => {
            var search_item = (SearchItem) list_box.get_selected_row ();

            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            switch (keyval) {
                case Gdk.Key.F10:
                    if (mods == Gdk.ModifierType.SHIFT_MASK) {
                        var context_menu = search_item.create_context_menu ();
                        if (context_menu != null) {
                            Utils.menu_popup_on_keypress (context_menu);
                        }
                    }
                    break;
                case Gdk.Key.Menu:
                case Gdk.Key.MenuKB:
                    var context_menu = search_item.create_context_menu ();
                    if (context_menu != null) {
                        Utils.menu_popup_on_keypress (context_menu);
                    }
                    break;
                default:
                    return;
            }
        });

        list_box.add_controller (click_controller);
        list_box.add_controller (menu_key_controller);
    }

    private void move_cursor (Gtk.MovementStep step, int count) {
        unowned var selected = list_box.get_selected_row ();
        if (step != DISPLAY_LINES || selected == null) {
            return;
        }

        // Move up to the searchbar
        if (selected == list_box.get_row_at_index (0) && count == -1) {
            move_focus (TAB_BACKWARD);
            return;
        }

        // Wrap to the searchbar
        if (list_box.get_row_at_index (selected.get_index () + count) == null) {
            list_box.select_row (list_box.get_row_at_index (0));
            move_focus (TAB_FORWARD);
        }
    }

    public void set_results (Gee.List<Synapse.Match> matches, string search_term) {
        clear ();
        if (matches.size > 0) {
            foreach (var match in matches) {
                Backend.App app = new Backend.App.from_synapse_match (match);
                ResultType result_type = (ResultType) match.match_type;
                if (match is Synapse.DesktopFilePlugin.ActionMatch) {
                    result_type = ResultType.APP_ACTIONS;
                } else if (match is Synapse.SwitchboardObject) {
                    result_type = ResultType.SETTINGS;
                } else if (match is Synapse.LinkPlugin.Result) {
                    result_type = ResultType.INTERNET;
                } else if (match is Synapse.FileBookmarkPlugin.Result) {
                    result_type = ResultType.BOOKMARK;
                }

                if (result_type == ResultType.UNKNOWN) {
                    var actions = Backend.SynapseSearch.find_actions_for_match (match);
                    foreach (var action in actions) {
                        app = new Backend.App.from_synapse_match (action, match);
                        create_item (app, search_term, (ResultType) app.match.match_type);
                    }

                    continue;
                }

                create_item (app, search_term, result_type);
            }

        } else {
            alert_view.title = _("No Results for “%s”").printf (search_term);
        }


        weak Gtk.ListBoxRow? first = list_box.get_row_at_index (0);
        if (first != null) {
            list_box.select_row (first);
        }
    }

    private void create_item (Backend.App app, string search_term, ResultType result_type) {
        if (limitator.has_key (result_type)) {
            var amount = limitator.get (result_type);
            if (amount >= MAX_RESULTS) {
                return;
            } else {
                limitator.set (result_type, amount + 1);
            }
        } else {
            limitator.set (result_type, 1);
        }

        var search_item = new SearchItem (app, search_term, result_type);
        app.start_search.connect ((search, target) => start_search (search, target));

        app.launched.connect (() => app_launched ());

        list_box.append (search_item);
    }

    public void clear () {
        limitator.clear ();
        list_box.remove_all ();
    }

    public void activate_selection () {
        var selection = list_box.get_selected_row ();
        if (selection != null) {
            list_box.row_activated (selection);
        }
    }

    private int update_sort (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var item1 = row1 as SearchItem;
        var item2 = row2 as SearchItem;
        if (item1.result_type != item2.result_type) {
            return item1.result_type - item2.result_type;
        }

        return 0;
    }

    [CCode (instance_pos = -1)]
    private void update_header (SearchItem row, SearchItem? before) {
        if (before != null && before.result_type == row.result_type) {
            row.set_header (null);
            return;
        }

        var header = new Granite.HeaderLabel (row.result_type.to_string ());

        row.set_header (header);
    }
}
