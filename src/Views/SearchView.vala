/*
 * Copyright (c) 2011-2015 elementary LLC. (http://elementary.io)
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

namespace Slingshot.Widgets {

    public class SearchView : Gtk.ScrolledWindow {
        const int MAX_RESULTS = 10;

        public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);
        public signal void app_launched ();

        private class CycleListBox : Gtk.ListBox {
            public override void move_cursor (Gtk.MovementStep step, int count) {
                unowned Gtk.ListBoxRow selected = get_selected_row ();

                if (step != Gtk.MovementStep.DISPLAY_LINES || selected == null) {
                    base.move_cursor (step, count);
                    return;
                }

                uint n_children = get_children ().length ();

                int current = selected.get_index ();
                int target = current + count;

                if (target < 0) {
                    target = (int)n_children + count;
                } else if (target >= n_children) {
                    target = count - 1;
                }

                unowned Gtk.ListBoxRow? target_row = get_row_at_index (target);
                if (target_row != null) {
                    select_row (target_row);
                    target_row.grab_focus ();
                }
            }
        }

        private Granite.Widgets.AlertView alert_view;
        private CycleListBox list_box;
        Gee.HashMap<SearchItem.ResultType, uint> limitator;

        private bool dragging = false;
        private string? drag_uri = null;

        public SearchView () {

        }

        construct {
            hscrollbar_policy = Gtk.PolicyType.NEVER;

            alert_view = new Granite.Widgets.AlertView ("", _("Try changing search terms."), "edit-find-symbolic");
            alert_view.show_all ();

            // list box
            limitator = new Gee.HashMap<SearchItem.ResultType, uint> ();
            list_box = new CycleListBox ();
            list_box.activate_on_single_click = true;
            list_box.set_sort_func ((row1, row2) => update_sort (row1, row2));
            list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) update_header);
            list_box.set_placeholder (alert_view);
            list_box.set_selection_mode (Gtk.SelectionMode.BROWSE);
            list_box.row_activated.connect ((row) => {
                Idle.add (() => {
                    var search_item = row as SearchItem;
                    if (!dragging) {
                        switch (search_item.result_type) {
                            case SearchItem.ResultType.APP_ACTIONS:
                            case SearchItem.ResultType.LINK:
                            case SearchItem.ResultType.SETTINGS:
                                search_item.app.match.execute (null);    
                                break;
                            default:
                                search_item.app.launch ();
                                break;
                        }

                        app_launched ();
                    }

                    return false;
                });
            });

            // Drag support
            Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
            Gtk.drag_source_set (list_box, Gdk.ModifierType.BUTTON1_MASK, {dnd}, Gdk.DragAction.COPY);

            list_box.motion_notify_event.connect ((event) => {
                if (!dragging) {
                    list_box.select_row (list_box.get_row_at_y ((int)event.y));
                }
                return false;
            });

            list_box.drag_begin.connect ( (ctx) => {
                var sr = list_box.get_selected_rows ();
                if (sr.length () > 0) {
                    dragging = true;

                    var di = (SearchItem)(sr.first ().data);
                    drag_uri = di.app_uri;
                    if (drag_uri != null) {
                        Gtk.drag_set_icon_gicon (ctx, di.icon.gicon, 16, 16);
                    }

                    app_launched ();
                }
            });

            list_box.drag_end.connect ( () => {
                if (drag_uri != null) {
                    app_launched (); /* This causes indicator to close */
                }
                dragging = false;
                drag_uri = null;
            });

            list_box.drag_data_get.connect ( (ctx, sel, info, time) => {
                if (drag_uri != null) {
                    sel.set_uris ({drag_uri});
                }
            });

            add (list_box);
        }

        public void set_results (Gee.List<Synapse.Match> matches, string search_term) {
            clear ();
            if (matches.size > 0) {
                foreach (var match in matches) {
                    Backend.App app = new Backend.App.from_synapse_match (match);
                    SearchItem.ResultType result_type = (SearchItem.ResultType) match.match_type;
                    if (match is Synapse.DesktopFilePlugin.ActionMatch) {
                        result_type = SearchItem.ResultType.APP_ACTIONS;
                    } else if (match is Synapse.SwitchboardPlugin.SwitchboardObject) {
                        result_type = SearchItem.ResultType.SETTINGS;
                    } else if (match.match_type == Synapse.MatchType.GENERIC_URI) {
                        var uri = (match as Synapse.UriMatch).uri;
                        if (uri.has_prefix ("http://") || uri.has_prefix ("ftp://") || uri.has_prefix ("https://")) {
                            result_type = SearchItem.ResultType.INTERNET;
                        }
                    } else if (match is Synapse.LinkPlugin.Result) {
                        result_type = SearchItem.ResultType.INTERNET;
                    }

                    if (result_type == SearchItem.ResultType.UNKNOWN) {
                        var actions = Backend.SynapseSearch.find_actions_for_match (match);
                        foreach (var action in actions) {
                            app = new Backend.App.from_synapse_match (action, match);
                            create_item (app, search_term, (SearchItem.ResultType) app.match.match_type);
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

        private void create_item (Backend.App app, string search_term, SearchItem.ResultType result_type) {
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

            list_box.add (search_item);
            search_item.show_all ();
        }

        public void clear () {
            limitator.clear ();
            list_box.get_children ().foreach ((child) => {
                child.destroy ();
            });
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
        private void update_header (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
            var item = row as SearchItem;
            if (before != null && ((SearchItem) before).result_type == item.result_type) {
                row.set_header (null);
                return;
            }

            string label;
            switch (item.result_type) {
                case SearchItem.ResultType.TEXT:
                    label = _("Text");
                    break;
                case SearchItem.ResultType.APPLICATION:
                    label = _("Applications");
                    break;
                case SearchItem.ResultType.GENERIC_URI:
                    label = _("Files");
                    break;
                case SearchItem.ResultType.LINK:
                case SearchItem.ResultType.ACTION:
                    label = _("Actions");
                    break;
                case SearchItem.ResultType.SEARCH:
                    label = _("Search");
                    break;
                case SearchItem.ResultType.CONTACT:
                    label = _("Contacts");
                    break;
                case SearchItem.ResultType.INTERNET:
                    label = _("Internet");
                    break;
                case SearchItem.ResultType.SETTINGS:
                    label = _("Settings");
                    break;
                case SearchItem.ResultType.APP_ACTIONS:
                    label = _("Application Actions");
                    break;
                default:
                    label = _("Other");
                    break;
            }

            var header = new Gtk.Label (label);
            header.margin_start = 6;
            ((Gtk.Misc) header).xalign = 0;
            header.get_style_context ().add_class ("h4");
            row.set_header (header);
        }

    }

}
