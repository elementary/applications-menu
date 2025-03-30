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

    private Gtk.Revealer current_grid;
    private Gee.HashMap<uint, Gtk.Revealer> grids;
    //private Gtk.Stack stack;
    // private Gtk.Revealer revealer;
    private Page page;

    private uint _focused_column = 1;
    public uint focused_column {
        set {
            var target_column = value.clamp (1, page.columns);
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
            var target_row = value.clamp (1, page.rows);
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

    private uint _current_grid_key = 0;
    public uint current_grid_key {
        get {
            return _current_grid_key;
        }

        set {
            // Clamp to valid values for keyboard navigation
            _current_grid_key = value.clamp (1, grids.size);
            var grid = grids.@get (_current_grid_key);
            if (grid == null) {
                return;
            }

            add (grid);
            remove (current_grid);
            show_all ();
            current_grid.reveal_child = false;
            grid.reveal_child = true;
            current_grid = grid;
            refocus ();
        }
    }

    construct {
        page.rows = 3;
        page.columns = 5;

        //  stack = new Gtk.Stack ();
        //  stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        //  stack.transition_duration = 300;
        //  switcher = new Gtk.StackSwitcher () {
        //      stack = stack
        //  };

        grids = new Gee.HashMap<uint, Gtk.Revealer> (null, null);
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 24;
        margin_bottom = 12;
        //  add (stack);
        //  add (switcher);

        can_focus = true;
        focus_in_event.connect_after (() => {
            refocus ();
            return Gdk.EVENT_STOP;
        });
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (var grid in get_children ()) {
            ((Gtk.Revealer)grid).get_child ().destroy ();
            grid.destroy ();
        }

        grids.clear ();
        _current_grid_key = 0; // Avoids clamp
        add_new_grid (); // Increments current_grid_key to 1

        // Where to insert new app button
        var next_row_index = 0;
        var next_col_index = 0;

        foreach (Backend.App app in app_system.get_apps_by_name ()) {
            var app_button = new Widgets.AppButton (app);
            app_button.app_launched.connect (() => app_launched ());

            if (next_col_index == page.columns) {
                next_col_index = 0;
                next_row_index++;
            }

            if (next_row_index == page.rows) {
                add_new_grid ();
                next_row_index = 0;
                next_col_index = 0;
            }

            ((Gtk.Grid)current_grid.get_child ()).attach (app_button, (int)next_col_index, (int)next_row_index);
            next_col_index++;
        }

        show_all ();
        // Show first page after populating the carousel
        current_grid_key = 1;
    }

    private void add_new_grid () {
        var grid = new Gtk.Grid () {
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
                grid.attach (new Gtk.Grid (), column, row, 1, 1);
            }
        }

        current_grid = new Gtk.Revealer ();
        current_grid.transition_duration = 500;
        current_grid.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        current_grid.child = grid;
        current_grid.reveal_child = false;
        // add (current_grid);
        current_grid_key = current_grid_key + 1;
        grids.set (current_grid_key, current_grid);
    }


    private Gtk.Widget? get_widget_at (uint col, uint row) {
        if (col < 1 || col > page.columns || row < 1 || row > page.rows) {
            return null;
        } else {
            return ((Gtk.Grid)current_grid.get_child ()).get_child_at ((int)col - 1, (int)row - 1);
        }
    }

    // Refocus an AppButton after a focus out or page change
    private void refocus () {
        focused_row = focused_row;
        focused_column = focused_column;
    }

    public void go_to_next () {
        current_grid_key++;
    }

    public void go_to_previous () {
        current_grid_key--;
    }

    public void go_to_last () {
        current_grid_key = grids.size;
    }

    public void go_to_number (int number) {
        current_grid_key = number;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.Home:
            case Gdk.Key.KP_Home:
                current_grid_key = 1;
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
            current_grid_key--;
        } else if (focused_column == 1 && current_grid_key > 1) {
            current_grid_key--;
            focused_column = page.columns;
        } else {
            focused_column--;
        }
    }

    private void move_right (Gdk.EventKey event) {
        if ((event.state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            current_grid_key++;
        } else if (focused_column == page.columns && current_grid_key < grids.size) {
            current_grid_key++;
            focused_column = 1;
        } else {
            focused_column++;
        }
    }
}
