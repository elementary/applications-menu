/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.Grid : Gtk.Box {
    private const int PAGE_ROWS = 3;
    private const int PAGE_COLUMNS = 5;
    private const int MAX_APPS_IN_PAGE = (PAGE_ROWS * PAGE_COLUMNS);

    private Hdy.Carousel paginator;
    private Gtk.EventControllerKey key_controller;

    private uint _focused_column = 1;
    public uint focused_column {
        set {
            var target_column = value.clamp (1, PAGE_COLUMNS);
            var target = get_widget_at (target_column, _focused_row);
            if (target != null && target is Widgets.AppButton) {
                _focused_column = target_column;
                target.grab_focus ();
            }
        }

        get {
            return _focused_column;
        }
    }

    private uint _focused_row = 1;
    public uint focused_row {
        set {
            var target_row = value.clamp (1, PAGE_ROWS);
            var target = get_widget_at (_focused_column, target_row);
            if (target != null && target is Widgets.AppButton) {
                _focused_row = target_row;
                target.grab_focus ();
            }
        }

        get {
            return _focused_row;
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

        can_focus = true;
        focus_in_event.connect_after (() => {
            refocus ();
            return Gdk.EVENT_STOP;
        });

        key_controller = new Gtk.EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_press);
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (unowned var child in paginator.get_children ()) {
            paginator.remove (child);
        }

        var apps = app_system.get_apps_by_name ();
        var num_apps = apps.length ();

        // e.g. Number of pages needed to show 33 apps is 3; 2 pages with fully apps and 1 additional page
        var num_pages = (int) Math.ceil ((double) num_apps / MAX_APPS_IN_PAGE);

        for (uint page_idx = 0; page_idx < num_pages; page_idx++) {
            // Number of total apps populated after dealing with this page
            // clamp is used to handle last page correctly; has no effect for other pages
            var num_apps_populated = ((page_idx + 1) * MAX_APPS_IN_PAGE).clamp (1, num_apps);

            // Number of apps in this page, in range of 1 to MAX_APPS_IN_PAGE
            // Subtract 1 before calculating modulo and finally adds 1 to prevent the result becomes 0
            var num_apps_in_page = ((num_apps_populated - 1) % MAX_APPS_IN_PAGE) + 1;

            populate_page (apps.nth (page_idx * MAX_APPS_IN_PAGE), num_apps_in_page);
        }

        show_all ();
        // Show first page after populating the carousel
        set_page (0);
    }

    private void populate_page (SList<Backend.App> apps, uint num_apps) {
        var grid = add_new_grid ();

        for (var row = 0; row < PAGE_ROWS; row++) {
            for (var column = 0; column < PAGE_COLUMNS; column++) {
                Gtk.Widget widget_to_attach;

                var app_idx = (row * PAGE_COLUMNS) + column;
                if (app_idx < num_apps) {
                    unowned var app = apps.nth_data (app_idx);

                    var app_button = new Widgets.AppButton (app);
                    app_button.app_launched.connect (() => ((Gtk.Popover) get_ancestor (typeof (Gtk.Popover))).popdown ());

                    widget_to_attach = app_button;
                } else {
                    // Fake grid in case there are not enough apps to fill the page
                    widget_to_attach = new Gtk.Grid ();
                }

                grid.attach (widget_to_attach, column, row);
            }
        }
    }

    private Gtk.Grid add_new_grid () {
        var grid = new Gtk.Grid () {
            hexpand = true,
            vexpand = true,
            row_homogeneous = true,
            column_homogeneous = true,
            margin_start = 12,
            margin_end = 12,
            row_spacing = 24,
            column_spacing = 0
        };

        paginator.add (grid);

        return grid;
    }

    private Gtk.Widget? get_widget_at (uint col, uint row) {
        if (col < 1 || col > PAGE_COLUMNS || row < 1 || row > PAGE_ROWS) {
            return null;
        } else {
            var grid = (Gtk.Grid) paginator.get_children ().nth_data ((int) paginator.get_position ());
            return grid.get_child_at ((int) col - 1, (int) row - 1);
        }
    }

    // Refocus an AppButton after a focus out or page change
    private void refocus () {
        focused_row = focused_row;
        focused_column = focused_column;
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
                    move_left (state);
                } else {
                    move_right (state);
                }

                return Gdk.EVENT_STOP;

            case Gdk.Key.Right:
            case Gdk.Key.KP_Right:
                if (get_default_direction () == LTR) {
                    move_right (state);
                } else {
                    move_left (state);
                }

                return Gdk.EVENT_STOP;

            case Gdk.Key.Up:
            case Gdk.Key.KP_Up:
                if (_focused_row == 1) {
                    break;
                } else {
                    focused_row--;
                    return Gdk.EVENT_STOP;
                }

            case Gdk.Key.Down:
            case Gdk.Key.KP_Down:
                focused_row++;
                return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private void move_left (Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            previous_page ();
        } else if (focused_column == 1 && paginator.get_position () > 0) {
            previous_page ();
            focused_column = PAGE_COLUMNS;
        } else {
            focused_column--;
        }
    }

    private void move_right (Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            next_page ();
        } else if (focused_column == PAGE_COLUMNS && paginator.get_position () < paginator.n_pages - 1) {
            next_page ();
            focused_column = 1;
        } else {
            focused_column++;
        }
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
