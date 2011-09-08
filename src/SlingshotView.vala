// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Giulio Collura
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

using Gtk;
using Gdk;
using Gee;
using Cairo;
using Granite.Widgets;
using GMenu;

using Slingshot.Widgets;
using Slingshot.Backend;

namespace Slingshot {

    public class SlingshotView : Gtk.Window, Gtk.Buildable {

        public ComboBoxText category_switcher;
        public SearchBar searchbar;
        public Widgets.Grid grid;
        public Layout pages;
        public Switcher page_switcher;
        public VBox grid_n_pages;

        public SearchView search_view;

        private VBox container;

        private ArrayList<TreeDirectory> categories;
        private HashMap<string, ArrayList<App>> apps;
        private ArrayList<App> filtered;

        private int current_position = 0;
        private int search_view_position = 0;

        public SlingshotView () {

            // Window properties
            this.title = "Slingshot";
            this.skip_pager_hint = true;
            this.skip_taskbar_hint = true;
            this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
            this.set_keep_above (true);
            this.decorated = false;

            // No time to have slingshot resizable.
            this.resizable = false;
            this.app_paintable = true;

            // Have the window in the right place
            this.move (5, 27); 
            set_size_request (700, 580);
            read_settings ();

            set_visual (get_screen ().get_rgba_visual());
            get_style_context ().add_provider (Slingshot.style_provider, 600);
            Slingshot.icon_theme = IconTheme.get_default ();

            categories = AppSystem.get_categories ();
            apps = new HashMap<string, ArrayList<App>> ();

            foreach (TreeDirectory cat in categories) {
                apps.set (cat.get_name (), AppSystem.get_apps (cat));
            }
            debug ("Apps loaded");

            filtered = new ArrayList<App> ();

            setup_ui ();
            connect_signals ();

        }

        private void setup_ui () {
            
            // Create the base container
            container = new VBox (false, 0);

            // Add top bar
            var top = new HBox (false, 10);

            searchbar = new SearchBar ("");
            searchbar.width_request = 250;
            top.pack_end (searchbar, false, false, 0);
            
            // Get the current size of the view
            int width, height;
            get_size (out width, out height);
            
            // Make icon grid and populate
            grid = new Widgets.Grid (height / 180, width / 128);

            // Create the layout which works like pages
            pages = new Layout (null, null);
            pages.put (grid, 0, 0);
            pages.get_style_context ().add_provider (Slingshot.style_provider, 600);

            // Create the page switcher
            page_switcher = new Switcher ();
            
            // This function must be after creating the page switcher
            grid.new_page.connect (page_switcher.append);
            populate_grid ();

            // This vbox is absolutely useless
            grid_n_pages = new VBox (false, 0);
            grid_n_pages.pack_start (Utils.set_padding (pages, 0, 9, 24, 9), true, true, 0);
            grid_n_pages.pack_start (Utils.set_padding (page_switcher, 0, 100, 15, 100), false, true, 0);

            search_view = new SearchView ();
            foreach (ArrayList<App> app_list in apps.values) {
                search_view.add_apps (app_list);
            }
            pages.put (search_view, -5*130, 0);

            container.pack_start (top, false, true, 15);
            container.pack_start (grid_n_pages, true, true, 0);
            this.add (Utils.set_padding (container, 15, 15, 1, 15));

            debug ("Ui setup completed");

        }

        private void connect_signals () {
            
            this.focus_out_event.connect ( () => {
                this.hide_slingshot(); 
                return false; 
            });

            this.draw.connect (this.draw_background);
            pages.draw.connect (this.draw_pages_background);
            
            searchbar.changed.connect_after (this.search);
            search_view.app_launched.connect (hide_slingshot);

            page_switcher.active_changed.connect (() => {

                if (page_switcher.active > page_switcher.old_active)
                    this.page_right (page_switcher.active - page_switcher.old_active);
                else
                    this.page_left (page_switcher.old_active - page_switcher.active);

            });

            // Auto-update settings when changed
            Slingshot.settings.changed.connect (read_settings);

        }

        private bool draw_background (Context cr) {

            Allocation size;
            get_allocation (out size);
            
            // Some (configurable?) values
            double radius = 6.0;
            double offset = 2.0;

            cr.set_antialias (Antialias.SUBPIXEL);

            cr.move_to (0 + radius, 15 + offset);
            // Create the little rounded triangle
            cr.line_to (20.0, 15.0 + offset);
            //cr.line_to (30.0, 0.0 + offset);
            cr.arc (35.0, 0.0 + offset + radius, radius - 1.0, -2.0 * Math.PI / 2.7, -7.0 * Math.PI / 3.2);
            cr.line_to (50.0, 15.0 + offset);
            // Create the rounded square
            cr.arc (0 + size.width - radius - offset, 15.0 + radius + offset, 
                         radius, Math.PI * 1.5, Math.PI * 2);
            cr.arc (0 + size.width - radius - offset, 0 + size.height - radius - offset, 
                         radius, 0, Math.PI * 0.5);
            cr.arc (0 + radius + offset, 0 + size.height - radius - offset, 
                         radius, Math.PI * 0.5, Math.PI);
            cr.arc (0 + radius + offset, 15 + radius + offset, radius, Math.PI, Math.PI * 1.5);

            cr.set_source_rgba (0.1, 0.1, 0.1, 0.9);
            cr.fill_preserve ();

            // Paint a little white border
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.set_line_width (1.5);
            cr.stroke ();

            return false;

        }

        private bool draw_pages_background (Widget widget, Context cr) {

            Allocation size;
            widget.get_allocation (out size);

            cr.rectangle (0, 0, size.width, size.height);

            cr.set_source_rgba (0.1, 0.1, 0.1, 0.9);
            cr.fill_preserve ();

            return false;

        }

        public override bool key_press_event (Gdk.EventKey event) {

            switch (Gdk.keyval_name (event.keyval)) {

                case "Escape":
                    hide_slingshot ();
                    return true;

                default:
                    if (!searchbar.has_focus)
                        searchbar.grab_focus ();
                    break;

            }

            base.key_press_event (event);
            return false;

        }

        public override bool scroll_event (EventScroll event) {

            switch (event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_LEFT":
                    if (page_switcher.visible)
                        page_switcher.set_active (page_switcher.active - 1);
                    else
                        search_view_up ();
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (page_switcher.visible)
                        page_switcher.set_active (page_switcher.active + 1);
                    else
                        search_view_down ();
                    break;

            }

            return false;

        }

        public void hide_slingshot () {
            
            // Show the first page
            page_switcher.set_active (0);
            current_position = 0;
            searchbar.text = "";

            hide ();

        }

        public void show_slingshot () {

            page_switcher.set_active (0);
            searchbar.text = "";

            deiconify ();
            show_all ();
            searchbar.grab_focus ();

        }

        private void page_left (int step = 1) {

            if (current_position < 0) {
                pages.move (grid, current_position + 5*130*step, 0);
                current_position += 5*130*step;
            }

        }

        private void page_right (int step = 1) {

            if ((- current_position) < ((grid.n_columns - 5.8)*130)) {
                pages.move (grid, current_position - 5*130*step, 0);
                current_position -= 5*130*step;
            }

        }

        private void search_view_down () {

            if (search_view.apps_showed < 7)
                return;

            if ((search_view_position) > -(search_view.apps_showed*64)) {
                pages.move (search_view, 0, search_view_position - 2*74);
                search_view_position -= 2*74;
            }

        }

        private void search_view_up () {

            if (search_view_position < 0) {
                pages.move (search_view, 0, search_view_position + 2*74);
                search_view_position += 2*74;
            }

        }

        private void search () {

            var text = searchbar.text.down ().strip ();

            if (text == "") {
                pages.move (search_view, -130*5, 0);
                page_switcher.show_all ();
                page_switcher.set_active (0);
                pages.move (grid, 0, 0);
                return;
            }

            page_switcher.hide (); // Hide the switcher
            pages.move (grid, 5*130, 0); // Move the grid away
            pages.move (search_view, 0, 0); // Show the searchview
            search_view_position = 0;
            search_view.hide_all ();
            filtered.clear ();

            // There should be a real search engine, which can sort application
            foreach (ArrayList<App> entries in apps.values) {
                foreach (App app in entries) {
                    
                    if (text in app.name.down () ||
                        text in app.exec.down () ||
                        text in app.description.down ())
                        filtered.add (app);
                    else
                        filtered.remove (app);

                }
            }

            filtered.sort ();
            if (filtered.size > 20) {
                foreach (App app in filtered[0:20])
                    search_view.show_app (app);
            } else {
                foreach (App app in filtered)
                    search_view.show_app (app);
            }

            if (filtered.size != 1)
                search_view.add_command (text);

        }

        public void populate_grid () {

            page_switcher.append ("1");

            foreach (ArrayList<App> entries in apps.values) {
                foreach (App app in entries) {

                    var app_entry = new AppEntry (app);
                    
                    app_entry.app_launched.connect (hide_slingshot);

                    grid.append (app_entry);

                    app_entry.show_all ();

                }
            }

            debug ("Grid filled");

            page_switcher.set_active (0);

        }

        private void read_settings () {

            default_width = Slingshot.settings.width;
            default_height = Slingshot.settings.height;

        }

    }

}
