// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//  Copyright (C) 2014 Maddie May <madelynn@madelynnmay.com>
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

// A menu to be used inside of popovers for when a normal context
// menu can't be used
namespace Slingshot.Widgets {

public class PopoverMenu : Gtk.Grid {
    private int line_count = 0;
    private Gee.ArrayList<PopoverMenuItem> items = new Gee.ArrayList<PopoverMenuItem> ();

    public PopoverMenu () {
        row_homogeneous = true;
        column_homogeneous = true;
    }

    public void add_menu_item (PopoverMenuItem item) {
        line_count++;
        this.items.add (item);
        this.attach (item.child, 0, line_count, 1 , 1);
    }

    public int get_size () {
        return items.size;
    }
}

public class PopoverMenuItem : Object {
    public Gtk.Widget child = null;
    public signal void activated ();

    public PopoverMenuItem (string label, Gdk.Pixbuf? icon) {
        var button = new Gtk.Button ();
        button.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);

        var grid = new Gtk.Grid ();
        if (icon != null) {
            var image = new Gtk.Image.from_pixbuf (icon);
            image.margin_left = 2;
            image.margin_right = 2;
            image.halign = Gtk.Align.START;
            grid.attach (image, 0, 0, 1, 1);
        } else {
            var space_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            space_box.set_size_request (26, 16);
            grid.attach (space_box, 0, 0, 1, 1);
        }

        var label_widget = new Gtk.Label.with_mnemonic (label);
        label_widget.margin_right = 16;
        label_widget.justify = Gtk.Justification.LEFT;
        label_widget.set_alignment (0, 0);
        grid.attach (label_widget, 1, 0, 1, 1);

        button.add (grid);
        button.relief = Gtk.ReliefStyle.NONE;
        button.clicked.connect (on_activate);
        child = button;
    }

    private void on_activate () {
        activated ();
    }
}

// A popover that doesn't grab focus
public class NofocusPopover : Gtk.Popover {
    private Gtk.Container parent_container;
    private unowned SlingshotView view;

    private const string POPOVER_STYLESHEET = """
        .popover,
        .popover.osd,
        GtkPopover {
            border-radius: 0px;
            margin: 0px;
            text-shadow: none;
        }
    """;

    public NofocusPopover (SlingshotView view, Gtk.Container parent) {
        this.view = view;
        this.parent_container = parent;
        connect_popover_signals (parent);
        modal = false;
        parent.button_release_event.connect (hide_popover_menu);
        parent.button_press_event.connect (hide_popover_menu);
        get_style_context ().add_class (Gtk.STYLE_CLASS_MENU);
        Granite.Widgets.Utils.set_theming_for_screen (get_screen (), POPOVER_STYLESHEET,
                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public void connect_popover_signals (Gtk.Container parent) {
        foreach (Gtk.Widget child in parent.get_children ()) {
            if (child is Gtk.Container) {
                Gtk.Container container = child as Gtk.Container;
                connect_popover_signals (container);
            }

            if (child is Widgets.Switcher) {
                var switcher = child as Widgets.Switcher;
                switcher.on_stack_changed.connect (switched);
            }

            child.button_release_event.connect (hide_popover_menu);
            child.button_press_event.connect (hide_popover_menu);
        }
    }

    private void disconnect_popover_signals (Gtk.Container parent) {
        foreach (Gtk.Widget child in parent.get_children ()) {
            if (child is Gtk.Container) {
                Gtk.Container container = child as Gtk.Container;
                disconnect_popover_signals (container);
            }

            if (child is Widgets.Switcher) {
                var switcher = child as Widgets.Switcher;
                switcher.on_stack_changed.disconnect (switched);
            }
            
            child.button_release_event.disconnect (hide_popover_menu);
            child.button_press_event.disconnect (hide_popover_menu);
        }
    }

    public void switched () {
        this.hide ();
    }

    public bool hide_popover_menu (Gdk.EventButton event) {
        if (this.visible) {
            view.set_focus (null);
            view.search_entry.grab_focus ();

            this.hide ();
            // Block here to replicate context menu behavior
            return true;
        }
        // Visible can be false but the popover still thinks it's up
        // and will show when it's view is switched back to
        // in that case don't block forwarding but make sure it is
        // really hidden
        this.hide ();
        return false;
    }

    ~NofocusPopover () {
        disconnect_popover_signals (parent_container);
    }
}

} // End namespace