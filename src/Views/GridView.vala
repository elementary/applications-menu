/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.Grid : Gtk.Box {
    public signal void app_launched ();

    private const int PAGE_ROWS = 3;
    private const int PAGE_COLUMNS = 5;

    private Hdy.Carousel paginator;
    private Gtk.EventControllerKey key_controller;

    private int focused_column {
        get {
            var flowbox = (Gtk.FlowBox) paginator.get_children ().nth_data ((int) paginator.get_position ());
            var selected_child = flowbox.get_selected_children ().nth_data (0);

            for (int i = 0; i < PAGE_ROWS * PAGE_COLUMNS; i++) {
                if (flowbox.get_child_at_index (i) == selected_child) {
                    return i % PAGE_COLUMNS + 1;
                }
            }

            return -1;
        }
    }

    construct {
        paginator = new Hdy.Carousel () {
            hexpand = true,
            vexpand = true
        };

        var page_switcher = new Widgets.Switcher () {
            carousel = paginator,
            halign = CENTER
        };

        orientation = VERTICAL;
        spacing = 24;
        margin_bottom = 12;
        add (paginator);
        add (page_switcher);

        focus_in_event.connect_after (() => {
            refocus ();
            return Gdk.EVENT_PROPAGATE;
        });

        key_controller = new Gtk.EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_press);

        paginator.page_changed.connect (refocus);
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (unowned var child in paginator.get_children ()) {
            paginator.remove (child);
        }

        var grid = add_new_grid ();
        // Where to insert new app button
        var next_grid_index = 0;
        foreach (Backend.App app in app_system.get_apps_by_name ()) {
            var app_button = new Widgets.AppButton (app);
            app_button.app_launched.connect (() => app_launched ());

            if (next_grid_index == PAGE_ROWS * PAGE_COLUMNS) {
                grid = add_new_grid ();
                next_grid_index = 0;
            }

            grid.add (app_button);
            next_grid_index++;
        }

        // Empty children in case there are not enough apps to fill a single page
        while (next_grid_index < PAGE_ROWS * PAGE_COLUMNS) {
            grid.add (new Gtk.FlowBoxChild () { can_focus = false });
            next_grid_index++;
        }

        show_all ();
        // Show first page after populating the carousel
        set_page (0);
    }

    private Gtk.FlowBox add_new_grid () {
        var flowbox = new Gtk.FlowBox () {
            hexpand = true,
            vexpand = true,
            homogeneous = true,
            margin_start = 12,
            margin_end = 12,
            min_children_per_line = PAGE_COLUMNS,
            max_children_per_line = PAGE_COLUMNS,
            row_spacing = 24,
            column_spacing = 0
        };

        flowbox.child_activated.connect ((child) => {
            ((AppButton) child).launch_app ();
        });

        paginator.add (flowbox);
        return flowbox;
    }

    // focus the child with the same coords on the new page
    private void refocus () {

    }

    private bool on_key_press (uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Home:
            case Gdk.Key.KP_Home:
                set_page (0);
                return Gdk.EVENT_STOP;

            case Gdk.Key.Left:
            case Gdk.Key.KP_Left:
                if (get_default_direction () == LTR) {
                    return move_left (state);
                } else {
                    return move_right (state);
                }

            case Gdk.Key.Right:
            case Gdk.Key.KP_Right:
                if (get_default_direction () == LTR) {
                    return move_right (state);
                } else {
                    return move_left (state);
                }
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private bool move_left (Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            previous_page ();
            return Gdk.EVENT_STOP;
        }

        if (paginator.get_position () > 0 && focused_column == 1) {
            previous_page ();
            move_focus (LEFT);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private bool move_right (Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            next_page ();
            return Gdk.EVENT_STOP;
        }

        if (paginator.get_position () < paginator.n_pages - 1 && focused_column == PAGE_COLUMNS) {
            next_page ();
            move_focus (RIGHT);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public void next_page () {
        set_page ((int) paginator.get_position () + 1);
    }

    public void previous_page () {
        set_page ((int) paginator.get_position () - 1);
    }

    public void last_page () {
        set_page (paginator.n_pages);
    }

    public void set_page (uint pos) {
        var grid = paginator.get_children ().nth_data (pos);
        if (grid == null) {
            return;
        }

        paginator.scroll_to (grid);
        refocus ();
    }
}
