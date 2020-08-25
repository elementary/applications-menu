/*
 * Copyright 2020 elementary, Inc. (https://elementary.io)
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
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Slingshot.Widgets.QuickActionsView : Gtk.Grid {
    public signal void configure ();

    public SlingshotView view { get; construct; }
    private Gtk.ListBox listbox;

    public QuickActionsView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        var quick_actions_label = new Gtk.Label (_("Quick Actions").up ()) {
            halign = Gtk.Align.START
        };
        quick_actions_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        var quick_action_add_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON) {
            halign = Gtk.Align.END
        };
        quick_action_add_button.clicked.connect (() => configure ());

        attach (quick_actions_label, 0, 0);
        attach (quick_action_add_button, 1, 0);

        var empty_quicklist_label = new Gtk.Label (_("No Quick Actions…")) {
            visible = true
        };
        empty_quicklist_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        empty_quicklist_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        listbox = new Gtk.ListBox () {
            margin = 12
        };
        listbox.expand = true;
        listbox.selection_mode = Gtk.SelectionMode.BROWSE;
        listbox.set_placeholder (empty_quicklist_label);

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        attach (listbox_scrolled, 0, 1, 2, 2);

        var settings = new Settings ("io.elementary.desktop.wingpanel.applications-menu");
        var app_actions = settings.get_strv ("app-actions");
        foreach (var app in view.app_system.get_apps_by_name ()) {
            foreach (var action in app.actions) {
                foreach (var app_action in app_actions) {
                    var tokens = app_action.split (":", 2);
                    if (app.desktop_id == tokens[0] && action.action == tokens[1]) {
                        var action_button = new Gtk.Button.with_label (action.name) {
                            image = new Gtk.Image.from_gicon (action.icon, Gtk.IconSize.BUTTON),
                            always_show_image = true,
                            margin_bottom = 12,
                            xalign = 0
                        };

                        action_button.clicked.connect (() => {
                            app.launch_action (action.action);
                            view.close_indicator ();
                        });

                        listbox.add (action_button);
                    }
                }
            }
        }

        listbox.show_all ();

        this.margin_start = this.margin_end = 12;
    }
}
