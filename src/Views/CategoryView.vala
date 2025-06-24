/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.CategoryView : Granite.Bin {
    public SlingshotView view { get; construct; }

    private Gtk.ListBox category_switcher;
    private Gtk.ListBox listbox;

    public CategoryView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        hexpand = true;

        category_switcher = new Gtk.ListBox () {
            selection_mode = BROWSE,
            width_request = 120
        };
        category_switcher.set_sort_func ((Gtk.ListBoxSortFunc) category_sort_func);

        var scrolled_category = new Gtk.ScrolledWindow () {
            child = category_switcher,
            hscrollbar_policy = NEVER
        };
        scrolled_category.add_css_class (Granite.STYLE_CLASS_SIDEBAR);

        var separator = new Gtk.Separator (VERTICAL);

        listbox = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true,
            selection_mode = BROWSE
        };
        listbox.set_filter_func ((Gtk.ListBoxFilterFunc) filter_function);

        var listbox_scrolled = new Gtk.ScrolledWindow () {
            child = listbox,
            hscrollbar_policy = NEVER
        };

        var container = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true
        };
        container.append (scrolled_category);
        container.append (listbox_scrolled);

        child = container;

        category_switcher.move_cursor.connect (move_cursor);

        category_switcher.row_selected.connect (() => {
            listbox.invalidate_filter ();
        });

        listbox.move_cursor.connect (move_cursor);

        listbox.row_activated.connect ((row) => {
            Idle.add (() => {
                ((AppListRow) row).launch ();
                view.close_indicator ();

                return false;
            });
        });

        var click_controller = new Gtk.GestureClick () {
            button = 0,
            exclusive = true
        };
        click_controller.pressed.connect ((n_press, x, y) => {
            var sequence = click_controller.get_current_sequence ();
            var event = click_controller.get_last_event (sequence);

            if (event.triggers_context_menu ()) {
                var context_menu = ((AppListRow) listbox.get_row_at_y ((int) y)).app.get_context_menu (this);
                context_menu.halign = START;

                Utils.menu_popup_at_pointer (context_menu, x, y);

                click_controller.set_state (CLAIMED);
                click_controller.reset ();
            }
        });

        var listbox_key_controller = new Gtk.EventControllerKey ();
        listbox_key_controller.key_pressed.connect (on_key_press);
        listbox_key_controller.key_released.connect ((keyval, keycode, state) => {
            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            switch (keyval) {
                case Gdk.Key.F10:
                    if (mods == Gdk.ModifierType.SHIFT_MASK) {
                        var selected_row = (AppListRow) listbox.get_selected_row ();
                        Utils.menu_popup_on_keypress (selected_row.app.get_context_menu (selected_row));
                    }
                    break;
                case Gdk.Key.Menu:
                case Gdk.Key.MenuKB:
                    var selected_row = (AppListRow) listbox.get_selected_row ();
                    Utils.menu_popup_on_keypress (selected_row.app.get_context_menu (selected_row));
                    break;
                default:
                    return;
            }
        });

        var drag_source = new Gtk.DragSource () {
            actions = COPY
        };
        drag_source.prepare.connect ((x, y) => {
            var drag_item = (AppListRow) listbox.get_row_at_y ((int) y);
            if (drag_item == null) {
                return null;
            }

            drag_source.set_icon (
                Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).lookup_by_gicon (
                    drag_item.app_info.get_icon (),
                    32,
                    scale_factor,
                    get_direction (),
                    PRELOAD
                ), 0, 0
            );

            return new Gdk.ContentProvider.union ({
                new Gdk.ContentProvider.for_value ("file://" + drag_item.desktop_path)
            });
        });
        drag_source.drag_begin.connect ((drag_source, drag) => {
            view.close_indicator ();
        });

        listbox.add_controller (click_controller);
        listbox.add_controller (drag_source);
        listbox.add_controller (listbox_key_controller);

        var category_switcher_key_controller = new Gtk.EventControllerKey ();
        category_switcher_key_controller.key_pressed.connect (on_key_press);

        category_switcher.add_controller (category_switcher_key_controller);

        setup_sidebar ();
    }

    private static int category_sort_func (CategoryRow row1, CategoryRow row2) {
        return row1.cat_name.collate (row2.cat_name);
    }

    public void page_down () {
        category_switcher.move_cursor (DISPLAY_LINES, 1, false, true);
        focus_select_first_row ();
    }

    public void page_up () {
        category_switcher.move_cursor (DISPLAY_LINES, -1, false, true);
        focus_select_first_row ();
    }

    private void focus_select_first_row () {
        unowned Gtk.ListBoxRow? first_row = listbox.get_row_at_index (0);
        if (first_row != null) {
            first_row.grab_focus ();
            listbox.select_row (first_row);
        }
    }

    public void setup_sidebar () {
        CategoryRow? old_selected = (CategoryRow) category_switcher.get_selected_row ();

        category_switcher.remove_all ();
        listbox.remove_all ();

        foreach (unowned Backend.App app in view.app_system.get_apps_by_name ()) {
            listbox.append (new AppListRow (app));
        }

        // Fill the sidebar
        unowned Gtk.ListBoxRow? new_selected = null;
        foreach (string cat_name in view.app_system.apps.keys) {
            if (cat_name == "switchboard") {
                continue;
            }

            var row = new CategoryRow (cat_name);
            category_switcher.append (row);
            if (old_selected != null && old_selected.cat_name == cat_name) {
                new_selected = row;
            }
        }

        category_switcher.select_row (new_selected ?? category_switcher.get_row_at_index (0));
    }

    [CCode (instance_pos = -1)]
    private bool filter_function (AppListRow row) {
        unowned CategoryRow category_row = (CategoryRow) category_switcher.get_selected_row ();
        if (category_row != null) {
            foreach (Backend.App app in view.app_system.apps[category_row.cat_name]) {
                if (row.app_id == app.desktop_id) {
                    return true;
                }
            }
        }

        return false;
    }

    private bool on_key_press (uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Page_Up:
            case Gdk.Key.KP_Page_Up:
                page_up ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Page_Down:
            case Gdk.Key.KP_Page_Down:
                page_down ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.Home:
                category_switcher.move_cursor (PAGES, -1, false, true);;
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.End:
                category_switcher.move_cursor (PAGES, 1, false, true);;
                focus_select_first_row ();
                return Gdk.EVENT_STOP;
            case Gdk.Key.KP_Up:
            case Gdk.Key.Up:
                if (state == Gdk.ModifierType.SHIFT_MASK) {
                    page_up ();
                    return Gdk.EVENT_STOP;
                }

                break;
            case Gdk.Key.KP_Down:
            case Gdk.Key.Down:
                if (state == Gdk.ModifierType.SHIFT_MASK) {
                    page_down ();
                    return Gdk.EVENT_STOP;
                }
                break;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private void move_cursor (Gtk.ListBox list_box, Gtk.MovementStep step, int count, bool extend, bool modify) {
        unowned var selected = list_box.get_selected_row ();
        if (step != DISPLAY_LINES || selected == null) {
            return;
        }

        // Move up to the searchbar
        if (selected == list_box.get_row_at_index (0) && count == -1) {
            move_focus (TAB_BACKWARD);
            return;
        }
    }

    private class CategoryRow : Gtk.ListBoxRow {
        public string cat_name { get; construct; }

        public CategoryRow (string cat_name) {
            Object (cat_name: cat_name);
        }

        construct {
            var label = new Gtk.Label (cat_name) {
                halign = START,
                margin_start = 3
            };

            child = label;
        }
    }
}
