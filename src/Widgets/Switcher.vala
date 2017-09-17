// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//  Copyright (C) 2014 Corentin Noël <tintou@mailoo.org>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Slingshot.Widgets.Switcher : Gtk.Grid {
    private bool has_enough_children {
        get {
            return get_children ().length () > 1;
        }
    }

    private Gtk.Stack stack;
    public signal void on_stack_changed ();

    construct {
        halign = Gtk.Align.CENTER;
        orientation = Gtk.Orientation.HORIZONTAL;
        column_spacing = 3;
        can_focus = false;
        show_all ();
    }

    public void set_stack (Gtk.Stack stack) {
        if (this.stack != null) {
            get_children ().foreach ((child) => {
                child.destroy ();
            });
        }

        this.stack = stack;
        foreach (var child in stack.get_children ()) {
            add_child (child);
        }

        stack.add.connect_after (add_child);
    }

    private void add_child (Gtk.Widget widget) {
        var button = new PageChecker (widget);
        add (button);
    }

    public override void show () {
        base.show ();
        if (!has_enough_children) {
            hide ();
        }
    }

    public override void show_all () {
        base.show_all ();
        if (!has_enough_children) {
            hide ();
        }
    }
}
