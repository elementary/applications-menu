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

    public Gtk.Stack stack { get; private set; }

    private struct Page {
        public uint rows;
        public uint columns;
        public int number;
    }

    private Gtk.FlowBox current_grid;
    private Gee.HashMap<int, Gtk.FlowBox> grids;
    private Page page;

    private uint current_row = 0;
    private uint current_col = 0;

    construct {
        page.rows = 3;
        page.columns = 5;
        page.number = 1;

        stack = new Gtk.Stack ();
        stack.expand = true;
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        var page_switcher = new Widgets.Switcher ();
        page_switcher.set_stack (stack);

        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 24;
        margin_bottom = 12;
        add (stack);
        add (page_switcher);

        grids = new Gee.HashMap<int, Gtk.FlowBox> (null, null);
        create_new_grid ();
        go_to_number (1);
    }

    public void populate (Backend.AppSystem app_system) {
        foreach (Gtk.FlowBox flowbox in grids.values) {
            flowbox.destroy ();
        }

        grids.clear ();
        current_row = 0;
        current_col = 0;
        page.number = 1;
        create_new_grid ();
        stack.set_visible_child (current_grid);

        foreach (Backend.App app in app_system.get_apps_by_name ()) {
            var app_button = new Widgets.AppButton (app);
            app_button.app_launched.connect (() => app_launched ());

            if (current_col == page.columns) {
                current_col = 0;
                current_row++;
            }

            if (current_row == page.rows) {
                page.number++;
                create_new_grid ();
                current_row = 0;
            }

            current_grid.add (app_button);
            current_col++;
            current_grid.show ();
        }

        show_all ();
    }

    private void create_new_grid () {
        current_grid = new Gtk.FlowBox ();
        current_grid.expand = true;
        current_grid.homogeneous = true;
        current_grid.margin_start = 12;
        current_grid.margin_end = 12;
        current_grid.row_spacing = 24;
        current_grid.column_spacing = 0;
        current_grid.max_children_per_line = 5;
        current_grid.min_children_per_line = 5;
        current_grid.selection_mode = Gtk.SelectionMode.NONE;

        current_grid.child_activated.connect ((child) => {
            ((Widgets.AppButton) child).launch_app ();
            app_launched ();
        });

        grids.set (page.number, current_grid);

        stack.add_titled (current_grid, page.number.to_string (), page.number.to_string ());
    }

    public int get_n_pages () {
        return (int) page.number;
    }

    private int get_current_page () {
        return int.parse (stack.get_visible_child_name ());
    }

    public void go_to_next () {
        int page_number = get_current_page () + 1;
        if (page_number <= get_n_pages ())
            stack.set_visible_child_name (page_number.to_string ());
    }

    public void go_to_previous () {
        int page_number = get_current_page () - 1;
        if (page_number > 0)
            stack.set_visible_child_name (page_number.to_string ());
    }

    public void go_to_last () {
        stack.set_visible_child_name (get_n_pages ().to_string ());
    }

    public void go_to_number (int number) {
        stack.set_visible_child_name (number.to_string ());
    }
}
