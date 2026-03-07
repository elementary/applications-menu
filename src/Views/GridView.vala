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

    private Hdy.Carousel paginator;
    private Page page;

    private Gtk.EventControllerKey key_controller;

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

    construct {
        page.rows = 3;
        page.columns = 5;

        paginator = new Hdy.Carousel ();
        paginator.expand = true;

        var page_switcher = new Widgets.Switcher () {
            carousel = paginator,
            halign = CENTER
        };

        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 24;
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

        paginator.page_changed.connect (refocus);
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (var child in paginator.get_children ()) {
            paginator.remove (child);
        }

        var grid = add_new_grid ();
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
                grid = add_new_grid ();
                next_row_index = 0;
                next_col_index = 0;
            }

            grid.attach (app_button, (int)next_col_index, (int)next_row_index);
            next_col_index++;
        }

        show_all ();
        // Show first page after populating the carousel
        set_page (0);
    }

    private Gtk.Grid add_new_grid () {
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

        paginator.add (grid);
        return grid;
    }


    private Gtk.Widget? get_widget_at (uint col, uint row) {
        if (col < 1 || col > page.columns || row < 1 || row > page.rows) {
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
            focused_column = page.columns;
        } else {
            focused_column--;
        }
    }

    private void move_right (Gdk.ModifierType state) {
        if ((state & Gdk.ModifierType.SHIFT_MASK) > 0) {
            next_page ();
        } else if (focused_column == page.columns && paginator.get_position () < paginator.n_pages - 1) {
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
    }
}
