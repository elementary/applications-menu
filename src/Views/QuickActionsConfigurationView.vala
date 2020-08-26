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

 public class Slingshot.Widgets.QuickActionsConfigurationView : Gtk.Grid {
    public signal void back ();

    public SlingshotView view { get; construct; }
    private Gtk.ListBox listbox;
    private GLib.Settings settings;
    private Gee.ArrayList<string> app_actions;

    public QuickActionsConfigurationView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        var back_button = new Gtk.Button () {
            label = _("Quick Actions"),
            halign = Gtk.Align.START
        };
        back_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);
        back_button.clicked.connect (() => back ());

        var information_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.BUTTON) {
            halign = Gtk.Align.END,
            tooltip_markup = Granite.markup_accel_tooltip (
                {},
                "<b>%s</b>\r%s".printf (
                    _("Append to Quick Actions"),
                    _("Quick Actions are actions in apps that do certain activities inside an app.")
                )
            )
        };

        attach (back_button, 0, 0);
        attach (information_button, 1, 0);

        var empty_quicklist_label = new Gtk.Label (_("No Quick Actions…")) {
            visible = true
        };
        empty_quicklist_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        empty_quicklist_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        listbox = new Gtk.ListBox () {
            margin = 12
        };
        listbox.expand = true;
        listbox.selection_mode = Gtk.SelectionMode.NONE;
        listbox.set_placeholder (empty_quicklist_label);

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        attach (listbox_scrolled, 0, 1, 2, 2);

        settings = new Settings ("io.elementary.desktop.wingpanel.applications-menu");
        app_actions = new Gee.ArrayList<string>.wrap (settings.get_strv ("app-actions"));
        foreach (var app in view.app_system.get_apps_by_name ()) {
            if (app.actions.size > 0) {
                var label_with_icon = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                    margin_bottom = 12
                };
                var icon = new Gtk.Image.from_gicon (app.icon, Gtk.IconSize.BUTTON);
                label_with_icon.pack_start (icon);
                label_with_icon.pack_start (new Gtk.Label (app.name));
                label_with_icon.show_all ();
                listbox.add (label_with_icon);
            }

            foreach (var action in app.actions) {
                var label_with_switch = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                    margin_bottom = 12
                };
                label_with_switch.pack_start (new Gtk.Label (action.name));

                var _app_action = "%s:%s".printf (app.desktop_id, action.action);

                var configured_switch = new Gtk.Switch () {
                    hexpand = true,
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.CENTER
                };
                configured_switch.state_set.connect ((state) => {
                    if (state) {
                        if (!contains_action (_app_action)) {
                            add_action (_app_action);
                        }
                    } else {
                        remove_action (_app_action);
                    }

                    configured_switch.active = state;
                    configured_switch.state = state;

                    return state;
                });

                bool active = false;
                foreach (var app_action in app_actions) {
                    var tokens = app_action.split (":", 2);
                    if (app.desktop_id == tokens[0] && action.action == tokens[1]) {
                        active = true;
                    }

                    configured_switch.active = configured_switch.state = active;
                }

                label_with_switch.pack_start (configured_switch);

                label_with_switch.show_all ();
                listbox.add (label_with_switch);
            }
        }

        listbox.show_all ();

        this.margin_start = this.margin_end = 12;
    }

    private bool contains_action (string app_action) {
        return app_actions.contains (app_action);
    }

    private void add_action (string app_action) {
        app_actions.add (app_action);

        update_settings ();
    }

    private void remove_action (string app_action) {
        app_actions.remove (app_action);

        update_settings ();
    }

    private void update_settings () {
        string[] actions = new string[app_actions.size];
        for (int i = 0; i < actions.length; i++) {
            actions[i] = app_actions[i];
        }

        settings.set_strv ("app-actions", actions);
    }
}
