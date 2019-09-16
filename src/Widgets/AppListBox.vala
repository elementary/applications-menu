/*
 * Copyright 2011-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Giulio Collura
 */

public class Slingshot.AppListBox : Gtk.ListBox {
    public override void move_cursor (Gtk.MovementStep step, int count) {
        unowned Gtk.ListBoxRow selected = get_selected_row ();

        if (step != Gtk.MovementStep.DISPLAY_LINES || selected == null) {
            base.move_cursor (step, count);
            return;
        }

        uint n_children = get_children ().length ();

        int current = selected.get_index ();
        int target = current + count;

        if (target < 0) {
            target = (int) n_children + count;
        } else if (target >= n_children) {
            target = count - 1;
        }

        unowned Gtk.ListBoxRow? target_row = get_row_at_index (target);
        if (target_row != null) {
            select_row (target_row);
            target_row.grab_focus ();
        }
    }
}
