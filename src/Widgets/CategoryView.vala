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

    private Gtk.Grid container;
    public Sidebar category_switcher;
    public Gtk.Separator separator;
    public Widgets.Grid app_view;
    private SlingshotView view;

    private Gtk.Grid page_switcher;

    private const string ALL_APPLICATIONS = _("All Applications");
    private const string NEW_FILTER = _("Create a new Filter");
    private const string SWITCHBOARD_CATEGORY = "switchboard";

    private int current_position = 0;

    public Gee.HashMap<int, string> category_ids = new Gee.HashMap<int, string> ();

    public CategoryView (SlingshotView parent) {

        view = parent;

        set_visible_window (false);
        setup_ui ();
        setup_sidebar ();
        connect_events ();

        set_size_request (view.columns*130 + 17, view.view_height);

    }

    private void setup_ui () {
        container = new Gtk.Grid ();
        separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        app_view = new Widgets.Grid (view.rows, view.columns - 1);
        app_view.margin_left = 5;

        container.attach (separator, 1, 0, 1, 2);
        container.attach (app_view, 2, 0, 1, 1);

        add (container);

    }

    public void setup_sidebar () {

        if (category_switcher != null)
            category_switcher.destroy ();

        category_switcher = new Sidebar ();
        category_switcher.can_focus = false;

        // Fill the sidebar
        int n = 0;

        foreach (string cat_name in view.apps.keys) {
            if (cat_name == SWITCHBOARD_CATEGORY)
                continue;

            category_ids.set (n, cat_name);
            category_switcher.add_category (GLib.dgettext ("gnome-menus-3.0", cat_name).dup ());
            n++;
        }

        container.attach (category_switcher, 0, 0, 1, 2);
        category_switcher.selection_changed.connect ((name, nth) => {

            view.reset_category_focus ();
            string category = category_ids.get (nth);
            show_filtered_apps (category);
        });

        category_switcher.show_all ();
    }

    private void connect_events () {

        category_switcher.selected = 0; //Must be after everything else
    }

    private void add_app (Backend.App app) {

        var app_entry = new AppEntry (app);
        app_entry.app_launched.connect (() => view.hide ());
        app_view.append (app_entry);
        app_view.show_all ();

    }

    public void show_filtered_apps (string category) {

        app_view.clear ();
        foreach (Backend.App app in view.apps[category])
            add_app (app);

        current_position = 0;

    }

    public void show_page_switcher (bool show) {

        if (page_switcher.get_parent () == null)
            container.attach (page_switcher, 2, 1, 1, 1);

        if (show) {
            page_switcher.show_all ();
        }
        else
            page_switcher.hide ();

        view.search_entry.grab_focus ();

    }

}