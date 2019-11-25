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

public class Slingshot.Widgets.SearchView : Gtk.ScrolledWindow {
    const int MAX_RESULTS = 10;

    public signal void start_search (Synapse.SearchMatch search_match, Synapse.Match? target);
    public signal void app_launched ();

    private Granite.Widgets.AlertView alert_view;
    private AppListBox list_box;
    Gee.HashMap<SearchItem.ResultType, uint> limitator;

    construct {
        hscrollbar_policy = Gtk.PolicyType.NEVER;

        alert_view = new Granite.Widgets.AlertView ("", _("Try changing search terms."), "edit-find-symbolic");
        alert_view.show_all ();

        // list box
        limitator = new Gee.HashMap<SearchItem.ResultType, uint> ();
        list_box = new AppListBox ();
        list_box.activate_on_single_click = true;
        list_box.set_sort_func ((row1, row2) => update_sort (row1, row2));
        list_box.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) update_header);
        list_box.set_placeholder (alert_view);

        list_box.close_request.connect (() => {
            app_launched ();
        });

        list_box.row_activated.connect ((row) => {
            Idle.add (() => {
                var search_item = row as SearchItem;
                if (!list_box.dragging) {
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
    private void update_header (SearchItem row, SearchItem? before) {
        if (before != null && before.result_type == row.result_type) {
            row.set_header (null);
            return;
        }

        var header = new Granite.HeaderLabel (row.result_type.to_string ());
        header.margin_start = 6;

        row.set_header (header);
    }
}
