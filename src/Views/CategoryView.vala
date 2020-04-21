/*
 * Copyright 2019-2020 elementary, Inc. (https://elementary.io)
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
    public signal void search_focus_request ();

    public SlingshotView view { get; construct; }

    public Gee.HashMap<int, string> category_ids = new Gee.HashMap<int, string> ();

    private bool dragging = false;
    private string? drag_uri = null;
    private NavListBox category_switcher;
    private NavListBox listbox;

    private const Gtk.TargetEntry DND = { "text/uri-list", 0, 0 };

    public CategoryView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        set_visible_window (false);
        hexpand = true;

        category_switcher = new NavListBox ();
        category_switcher.selection_mode = Gtk.SelectionMode.BROWSE;
        category_switcher.set_sort_func ((Gtk.ListBoxSortFunc) category_sort_func);
        category_switcher.width_request = 120;

        unowned Gtk.StyleContext category_switcher_style_context = category_switcher.get_style_context ();
        category_switcher_style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
        category_switcher_style_context.add_class (Gtk.STYLE_CLASS_VIEW);

        setup_sidebar ();

        var scrolled_category = new Gtk.ScrolledWindow (null, null);
        scrolled_category.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled_category.add (category_switcher);

        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        listbox = new NavListBox ();
        listbox.expand = true;
        listbox.selection_mode = Gtk.SelectionMode.BROWSE;

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        var container = new Gtk.Grid ();
        container.hexpand = true;
        container.add (scrolled_category);
        container.add (separator);
        container.add (listbox_scrolled);

        add (container);

        show_filtered_apps (category_ids[0]);
        category_switcher.row_selected.connect ((row) => {
            show_filtered_apps (category_ids[row.get_index ()]);
        });

        category_switcher.search_focus_request.connect (() => {
            search_focus_request ();
        });

        listbox.row_activated.connect ((row) => {
            Idle.add (() => {
                if (!dragging) {
                    ((AppListRow) row).launch ();
                    view.close_indicator ();
                }

                return false;
            });
        });

        listbox.button_press_event.connect ((event) => {
            if (event.button == Gdk.BUTTON_SECONDARY) {
                return create_context_menu (event);
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Menu) {
                return create_context_menu (event);
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.key_press_event.connect (on_key_press);
        category_switcher.key_press_event.connect (on_key_press);

        Gtk.drag_source_set (listbox, Gdk.ModifierType.BUTTON1_MASK, {DND}, Gdk.DragAction.COPY);

        listbox.motion_notify_event.connect ((event) => {
            if (!dragging) {
                listbox.select_row (listbox.get_row_at_y ((int) event.y));
            }

            return Gdk.EVENT_PROPAGATE;
        });

        listbox.drag_begin.connect ((ctx) => {
            var selected_row = listbox.get_selected_row ();
            if (selected_row != null) {
                dragging = true;

                var drag_item = (AppListRow) selected_row;
                drag_uri = "file://" + drag_item.desktop_path;
                if (drag_uri != null) {
                    Gtk.drag_set_icon_gicon (ctx, drag_item.app_info.get_icon (), 32, 32);
                }

                view.close_indicator ();
            }
        });

        listbox.drag_end.connect (() => {
            if (drag_uri != null) {
                view.close_indicator ();
            }

            dragging = false;
            drag_uri = null;
        });

        listbox.drag_data_get.connect ((ctx, sel, info, time) => {
            if (drag_uri != null) {
                sel.set_uris ({drag_uri});
            }
        });

        listbox.search_focus_request.connect (() => {
            search_focus_request ();
        });
    }

    private static int category_sort_func (CategoryRow row1, CategoryRow row2) {
        return row1.cat_name.collate (row2.cat_name);
    }

    private bool create_context_menu (Gdk.Event event) {
        var selected_row = (AppListRow) listbox.get_selected_row ();

        var menu = new Slingshot.AppContextMenu (selected_row.app_id, selected_row.desktop_path);
        menu.app_launched.connect (() => {
            view.close_indicator ();
        });

        if (menu.get_children () != null) {
            if (event.type == Gdk.EventType.KEY_PRESS) {
                menu.popup_at_widget (selected_row, Gdk.Gravity.CENTER, Gdk.Gravity.CENTER, event);
                return Gdk.EVENT_STOP;
            } else if (event.type == Gdk.EventType.BUTTON_PRESS) {
                menu.popup_at_pointer (event);
                return Gdk.EVENT_STOP;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public void page_down () {
        category_switcher.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1);
        focus_select_first_row ();
    }

    public void page_up () {
        category_switcher.move_cursor (Gtk.MovementStep.DISPLAY_LINES, -1);
        focus_select_first_row ();
    }

    private void focus_select_first_row () {
        var first_row = listbox.get_row_at_index (0);
        first_row.grab_focus ();
        listbox.select_row (first_row);
    }

    public void setup_sidebar () {
        category_ids.clear ();

        foreach (unowned Gtk.Widget child in category_switcher.get_children ()) {
            child.destroy ();
        }

        // Fill the sidebar
        int n = 0;
        foreach (string cat_name in view.apps.keys) {
            if (cat_name == "switchboard") {
                continue;
            }

            category_ids.set (n, cat_name);

            var row = new CategoryRow (cat_name);

            category_switcher.add (row);

            n++;
        }

        category_switcher.show_all ();
        category_switcher.select_row (category_switcher.get_row_at_index (0));
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
                category_switcher.move_cursor (Gtk.MovementStep.PAGES, -1);
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.End:
                category_switcher.move_cursor (Gtk.MovementStep.PAGES, 1);
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.KP_Up:
            case Gdk.Key.Up:
                if (event.state == Gdk.ModifierType.SHIFT_MASK) {
                    page_up ();
                    return Gdk.EVENT_STOP;
                }

                break;
            case Gdk.Key.KP_Down:
            case Gdk.Key.Down:
                if (event.state == Gdk.ModifierType.SHIFT_MASK) {
                    page_down ();
                    return Gdk.EVENT_STOP;
                }
                break;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private class CategoryRow : Gtk.ListBoxRow {
        public string cat_name { get; construct; }

        public CategoryRow (string cat_name) {
            Object (cat_name: cat_name);
        }

        construct {
            var label = new Gtk.Label (GLib.dgettext ("gnome-menus-3.0", cat_name).dup ());
            label.halign = Gtk.Align.START;
            label.margin_start = 3;

            add (label);
        }
    }

    private class NavListBox : Gtk.ListBox {
        public signal void search_focus_request ();

        public override void move_cursor (Gtk.MovementStep step, int count) {
            unowned Gtk.ListBoxRow selected = get_selected_row ();
            if (
                selected != null &&
                selected == get_row_at_index (0) &&
                step == DISPLAY_LINES &&
                count == -1
            ) {
                search_focus_request ();
            } else {
                base.move_cursor (step, count);
            }
        }
    }
}
