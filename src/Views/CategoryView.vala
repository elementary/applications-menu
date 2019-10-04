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

public class Slingshot.Widgets.CategoryView : Gtk.EventBox {
    public SlingshotView view { get; construct; }

    public Sidebar category_switcher;

    public Gee.HashMap<int, string> category_ids = new Gee.HashMap<int, string> ();

    private AppListBox listbox;

    public CategoryView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        set_visible_window (false);
        hexpand = true;

        category_switcher = new Sidebar ();

        var scrolled_category = new Gtk.ScrolledWindow (null, null);
        scrolled_category.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled_category.add (category_switcher);

        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        listbox = new AppListBox ();
        listbox.expand = true;

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        var container = new Gtk.Grid ();
        container.hexpand = true;
        container.add (scrolled_category);
        container.add (separator);
        container.add (listbox_scrolled);

        add (container);

        category_switcher.selection_changed.connect ((nth) => {
            show_filtered_apps (category_ids[nth]);
        });

        listbox.row_activated.connect ((row) => {
            Idle.add (() => {
                if (!listbox.dragging) {
                    ((AppListRow) row).launch ();
                    view.close_indicator ();
                }

                return false;
            });
        });

        listbox.button_press_event.connect ((event) => {
            if (event.button != Gdk.BUTTON_SECONDARY) {
                return Gdk.EVENT_PROPAGATE;
            }

            var selected_row = (AppListRow) listbox.get_selected_row ();

            var menu = new Slingshot.AppContextMenu (selected_row.app_id, selected_row.desktop_path);
            menu.app_launched.connect (() => {
                view.close_indicator ();
            });

            if (menu.get_children () != null) {
                menu.popup_at_pointer (event);
                return Gdk.EVENT_STOP;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.key_press_event.connect (on_key_press);
        category_switcher.key_press_event.connect (on_key_press);

        setup_sidebar ();
    }

    public void page_down () {
        category_switcher.selected++;
        focus_select_first_row ();
    }

    public void page_up () {
        if (category_switcher.selected != 0) {
            category_switcher.selected--;
            focus_select_first_row ();
        }
    }

    private void focus_select_first_row () {
        var first_row = listbox.get_row_at_index (0);
        first_row.grab_focus ();
        listbox.select_row (first_row);
    }

    public void setup_sidebar () {
        var old_selected = category_switcher.selected;
        category_ids.clear ();
        category_switcher.clear ();

        // Fill the sidebar
        int n = 0;
        foreach (string cat_name in view.apps.keys) {
            if (cat_name == "switchboard")
                continue;

            category_ids.set (n, cat_name);
            category_switcher.add_category (GLib.dgettext ("gnome-menus-3.0", cat_name).dup ());
            n++;
        }

        category_switcher.show_all ();
        category_switcher.selected = old_selected;
    }

    public void show_filtered_apps (string category) {
        foreach (unowned Gtk.Widget child in listbox.get_children ()) {
            child.destroy ();
        }

        foreach (Backend.App app in view.apps[category]) {
            listbox.add (new AppListRow (app.desktop_id, app.desktop_path));
        }

        listbox.show_all ();
    }

    private bool on_key_press (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Page_Up:
            case Gdk.Key.KP_Page_Up:
                page_up ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Page_Down:
            case Gdk.Key.KP_Page_Down:
                page_down ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Home:
                category_switcher.selected = 0;
                focus_select_first_row ();
                break;
            case Gdk.Key.End:
                category_switcher.selected = category_switcher.cat_size - 1;
                focus_select_first_row ();
                break;
        }

        return Gdk.EVENT_PROPAGATE;
    }
}
