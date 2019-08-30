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
    public Widgets.Grid app_view;

    private int current_position = 0;

    public Gee.HashMap<int, string> category_ids = new Gee.HashMap<int, string> ();

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

        app_view = new Widgets.Grid (view.rows, view.columns - 1);

        var container = new Gtk.Grid ();
        container.hexpand = true;
        container.orientation = Gtk.Orientation.HORIZONTAL;
        container.add (scrolled_category);
        container.add (separator);
        container.add (app_view);
        add (container);

        category_switcher.selection_changed.connect ((name, nth) => {
            show_filtered_apps (category_ids[nth]);
        });

        setup_sidebar ();
    }

    public void setup_sidebar () {
        var old_selected = category_switcher.selected;
        category_ids.clear ();
        category_switcher.clear ();
        app_view.set_size_request (-1, -1);
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

        int columns = view.columns - removing_columns;
        app_view.resize (view.rows, columns);

        category_switcher.selected = old_selected;
    }

    public void show_filtered_apps (string category) {
        app_view.clear ();
        foreach (Backend.App app in view.apps[category]) {
            var app_entry = new AppButton (app);
            app_entry.app_launched.connect (() => view.close_indicator ());
            app_view.append (app_entry);
            app_view.show_all ();
        }

        current_position = 0;
    }
}
