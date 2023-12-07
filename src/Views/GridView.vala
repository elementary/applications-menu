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

public class Slingshot.Widgets.Grid : Gtk.Grid {
    public signal void app_launched ();

    private struct Page {
        public uint rows;
        public uint columns;
    }

    private Gtk.Grid current_grid;
    private Gee.HashMap<uint, Gtk.Grid> grids;
    private Hdy.Carousel paginator;
    private Page page;

    private uint _focused_column = 1;
    public uint focused_column {
        set {
            var target_column = value.clamp (1, page.columns);
            var target = get_widget_at (target_column, _focused_row);
            if (target != null && target is Widgets.AppButton) {
                _focused_column = target_column;
                target.grab_focus ();
                warning ("focus column %u", _focused_column);
            }
        }

        get {
            return _focused_column;
        }
    }

    private uint _focused_row = 1;
    public uint focused_row {
        set {
            var target_row = value.clamp (1, page.rows);
            var target = get_widget_at (_focused_column, target_row);
            if (target != null && target is Widgets.AppButton) {
                _focused_row = target_row;
                target.grab_focus ();
                warning ("focus row %u", _focused_row);
            }
        }

        get {
            return _focused_row;
        }
    }

    private uint _current_page_number = 0;
    public uint current_page_number {
        get {
            return _current_page_number;
        }

        set {
            _current_page_number = value.clamp (0, paginator.n_pages);
            var grid = grids.@get (_current_page_number);
            if (grid == null) {
                return;
            }

            paginator.scroll_to (grid);
            current_grid = grid;
            refocus ();
        }
    }

    construct {
        page.rows = 3;
        page.columns = 5;

        paginator = new Hdy.Carousel ();
        paginator.expand = true;

        var page_switcher = new Widgets.Switcher ();
        page_switcher.set_paginator (paginator);

        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 24;
        margin_bottom = 12;
        add (paginator);
        add (page_switcher);

        grids = new Gee.HashMap<uint, Gtk.Grid> (null, null);

        can_focus = true;
        focus_in_event.connect_after (() => {
            refocus ();
            return Gdk.EVENT_STOP;
        });
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (Gtk.Grid grid in grids.values) {
            grid.destroy ();
        }

        grids.clear ();
        current_page_number = 0;
        var row_index = 0;
        var col_index = 0;
        add_new_grid (); // Increments current_page_number


        foreach (Backend.App app in app_system.get_apps_by_name ()) {
            var app_button = new Widgets.AppButton (app);
            app_button.app_launched.connect (() => app_launched ());

            if (col_index == page.columns) {
                col_index = 0;
                row_index++;
            }

            if (row_index == page.rows) {
                add_new_grid ();
                row_index = 0;
                col_index = 0;
            }

            current_grid.attach (app_button, (int)col_index, (int)row_index);
            col_index++;
        }

        show_all ();
        // Show first page after populating the carousel
        current_page_number = 1;
    }

    private void add_new_grid () {
        current_grid = new Gtk.Grid () {
            expand = true,
            row_homogeneous = true,
            column_homogeneous = true,
            margin_start = 12,
            margin_end = 12,
            row_spacing = 24,
            column_spacing = 0
        };

        // Fake grids in case there are not enough apps to fill the grid
        for (var row = 0; row < page.rows; row++) {
            for (var column = 0; column < page.columns; column++) {
                current_grid.attach (new Gtk.Grid (), column, row, 1, 1);
            }
        }

        paginator.add (current_grid);
        current_page_number = current_page_number + 1;
        grids.set (current_page_number, current_grid);
    }


    private Gtk.Widget? get_widget_at (uint col, uint row) {
        if (col < 1 || col > page.columns || row < 1 || row > page.rows) {
            return null;
        } else {
            return current_grid.get_child_at ((int)col - 1, (int)row - 1);
        }
    }

    // Refocus an AppButton after a focus out or page change
    private void refocus () {
        focused_row = focused_row;
        focused_column = focused_column;
    }

    public void go_to_next () {
        current_page_number++;
    }

    public void go_to_previous () {
        current_page_number--;
    }

    public void go_to_last () {
        current_page_number = paginator.n_pages;
    }

    public void go_to_number (int number) {
        current_page_number = number;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Home:
            case Gdk.Key.KP_Home:
                current_page_number = 1;
                return Gdk.EVENT_STOP;

            case Gdk.Key.Left:
            case Gdk.Key.KP_Left:
                if (get_style_context ().direction == Gtk.TextDirection.LTR) {
                    move_left (event);
                } else {
                    move_right (event);
                }

                return Gdk.EVENT_STOP;

            case Gdk.Key.Right:
            case Gdk.Key.KP_Right:
                if (get_style_context ().direction == Gtk.TextDirection.LTR) {
                    move_right (event);
                } else {
                    move_left (event);
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

    private void move_left (Gdk.EventKey event) {
        if ((event.state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            current_page_number--;
        } else if (focused_column == 1 && current_page_number > 1) {
            current_page_number--;
            focused_column = page.columns;
        } else {
            focused_column--;
        }
    }

    private void move_right (Gdk.EventKey event) {
        if ((event.state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            current_page_number++;
        } else if (focused_column == page.columns && current_page_number < paginator.n_pages {
            current_page_number++;
            focused_column = 1;
        } else {
            focused_column++;
        }
    }
}
