// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
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

public class Slingshot.Widgets.CategoryView : Gtk.EventBox {
    public SlingshotView view { get; construct; }

    public Sidebar category_switcher;

    public Gee.HashMap<int, string> category_ids = new Gee.HashMap<int, string> ();

    private bool dragging = false;
    private string? drag_uri = null;
    private Gtk.ListBox listbox;

    public CategoryView (SlingshotView view) {
        Object (view: view);
    }

    construct {
        set_visible_window (false);
        hexpand = true;

        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        category_switcher = new Sidebar ();

        var scrolled_category = new Gtk.ScrolledWindow (null, null);
        scrolled_category.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled_category.add (category_switcher);

        listbox = new Gtk.ListBox ();
        listbox.expand = true;

        var listbox_scrolled = new Gtk.ScrolledWindow (null, null);
        listbox_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        listbox_scrolled.add (listbox);

        var container = new Gtk.Grid ();
        container.hexpand = true;
        container.orientation = Gtk.Orientation.HORIZONTAL;
        container.add (scrolled_category);
        container.add (separator);
        container.add (listbox_scrolled);
        add (container);

        category_switcher.selection_changed.connect ((name, nth) => {
            show_filtered_apps (category_ids[nth]);
        });


        listbox.row_activated.connect ((row) => {
            Idle.add (() => {
                if (!dragging) {
                    ((SearchItem) row).app.launch ();
                    view.close_indicator ();
                }

                return false;
            });
        });

        Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (listbox, Gdk.ModifierType.BUTTON1_MASK, {dnd}, Gdk.DragAction.COPY);

        listbox.motion_notify_event.connect ((event) => {
            if (!dragging) {
                listbox.select_row (listbox.get_row_at_y ((int)event.y));
            }
            return false;
        });

        listbox.drag_begin.connect ((ctx) => {
            var selected_row = listbox.get_selected_row ();
            if (selected_row != null) {
                dragging = true;

                var drag_item = (SearchItem) selected_row;

                drag_uri = "file://" + drag_item.app.desktop_path;
                if (drag_uri != null) {
                    Gtk.drag_set_icon_gicon (ctx, drag_item.icon.gicon, 32, 32);
                }

                view.close_indicator ();
            }
        });

        listbox.drag_end.connect (() => {
            if (drag_uri != null) {
                view.close_indicator ();
            }
            dragging = false;
            drag_uri = null;
        });

        listbox.drag_data_get.connect ((ctx, sel, info, time) => {
            if (drag_uri != null) {
                sel.set_uris ({drag_uri});
            }
        });

        setup_sidebar ();
    }

    public void setup_sidebar () {
        var old_selected = category_switcher.selected;
        category_ids.clear ();
        category_switcher.clear ();
        // Fill the sidebar
        int n = 0;
        foreach (string cat_name in view.apps.keys) {
            if (cat_name == "switchboard")
                continue;

            category_ids.set (n, cat_name);
            category_switcher.add_category (GLib.dgettext ("gnome-menus-3.0", cat_name).dup ());
            n++;
        }

        category_switcher.show_all ();

        int minimum_width;
        category_switcher.get_preferred_width (out minimum_width, null);

        // Because of the different sizes of the column widget, we need to calculate if it will fit.
        int removing_columns = (int)((double)minimum_width / (double)Pixels.ITEM_SIZE);
        if (minimum_width % Pixels.ITEM_SIZE != 0)
            removing_columns++;

        category_switcher.selected = old_selected;
    }

    public void show_filtered_apps (string category) {
        foreach (unowned Gtk.Widget child in listbox.get_children ()) {
            child.destroy ();
        }

        foreach (Backend.App app in view.apps[category]) {
            listbox.add (new SearchItem (app));
        }

        listbox.show_all ();
    }
}
