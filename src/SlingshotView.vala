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
        public Layout pages = null;
        public Switcher page_switcher;
        public HBox bottom;

        public SearchView search_view;

        private VBox container;

        private AppSystem app_system;
        private ArrayList<TreeDirectory> categories;
        private HashMap<string, ArrayList<App>> apps;
        private ArrayList<App> filtered;

        private int current_position = 0;
        private int search_view_position = 0;
        private const string ALL_APPLICATIONS = _("All Applications");

        private BackgroundColor bg_color;

        public SlingshotView (Slingshot app) {

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

            app_system = new AppSystem ();

            categories = app_system.get_categories ();
            app_system.get_apps.begin ((obj, res) => {
                apps = app_system.get_apps.end (res);
                setup_ui ();
                connect_signals ();
                if (!app.silent)
                    show_all ();
            });
            debug ("Apps loaded");

            filtered = new ArrayList<App> ();

        }

        private void setup_ui () {

            debug ("In setup_ui ()");

            // Create the base container
            container = new VBox (false, 0);

            // Add top bar
            var top = new HBox (false, 10);

            category_switcher = new ComboBoxText ();
            category_switcher.get_style_context ().add_provider (Slingshot.style_provider, 600);
            category_switcher.get_style_context ().add_class ("category-switcher");
            category_switcher.append (ALL_APPLICATIONS, ALL_APPLICATIONS); 
            category_switcher.active = 0;
            foreach (string cat_name in apps.keys) {
                category_switcher.append (cat_name, cat_name);
            }

            searchbar = new SearchBar ("");
            searchbar.width_request = 250;

            if (Slingshot.settings.show_category_filter) {
                top.pack_start (category_switcher, false, false, 0);
            }
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

            // A bottom widget to keep the page switcher center
            bottom = new HBox (false, 0);
            bottom.pack_start (new Label (""), true, true, 0); // A fake label 
            bottom.pack_start (page_switcher, false, false, 10);
            bottom.pack_start (new Label (""), true, true, 0); // A fake label
            
            // This function must be after creating the page switcher
            grid.new_page.connect (page_switcher.append);
            populate_grid.begin ();

            search_view = new SearchView ();
            foreach (ArrayList<App> app_list in apps.values) {
                search_view.add_apps (app_list);
            }
            pages.put (search_view, -5*130, 0);

            container.pack_start (top, false, true, 15);
            container.pack_start (Utils.set_padding (pages, 0, 9, 24, 9), true, true, 0);
            container.pack_start (Utils.set_padding (bottom, 0, 9, 15, 9), false, false, 0);
            this.add (Utils.set_padding (container, 15, 15, 1, 15));

            debug ("Ui setup completed");

        }

        private void connect_signals () {
            
            this.focus_out_event.connect ( () => {
                if (!(category_switcher.popup_shown)) {
                    this.hide_slingshot();
                }
                return false; 
            });

            this.draw.connect (this.draw_background);
            pages.draw.connect (this.draw_pages_background);
            
            searchbar.changed.connect_after (this.search);
            searchbar.grab_focus ();
            search_view.app_launched.connect (hide_slingshot);

            page_switcher.active_changed.connect (() => {

                if (page_switcher.active > page_switcher.old_active)
                    this.page_right (page_switcher.active - page_switcher.old_active);
                else
                    this.page_left (page_switcher.old_active - page_switcher.active);

            });

            category_switcher.changed.connect (() => {

                if (category_switcher.get_active_id () == ALL_APPLICATIONS)
                    populate_grid ();
                else 
                    show_filtered (apps[category_switcher.get_active_id ()]);

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

            pick_background_color (cr);

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

            pick_background_color (cr);

            cr.fill_preserve ();

            return false;

        }

        private void pick_background_color (Context cr) {

            // TODO: Add more colors

            switch (bg_color) {
                case BackgroundColor.BLACK:
                    cr.set_source_rgba (0.1, 0.1, 0.1, 0.9);
                    break;
                case BackgroundColor.GREY:
                    cr.set_source_rgba (0.3, 0.3, 0.3, 0.9);
                    break;
                case BackgroundColor.RED:
                    cr.set_source_rgba (0.2, 0.1, 0.1, 0.9);
                    break;
                case BackgroundColor.BLUE:
                    cr.set_source_rgba (0.1, 0.1, 0.2, 0.9);
                    break;
                case BackgroundColor.GREEN:
                    cr.set_source_rgba (0.1, 0.2, 0.1, 0.9);
                    break;
            }

        }

        public override bool key_press_event (Gdk.EventKey event) {

            switch (Gdk.keyval_name (event.keyval)) {

                case "Escape":
                    hide_slingshot ();
                    return true;

                case "Return":
                    if (!bottom.visible) {
                        search_view.launch_first ();
                        hide_slingshot ();
                    }
                    return true;

                case "Alt":
                    message ("Alt pressed");
                    break;

                case "1":
                case "KP_1":
                    page_switcher.set_active (0);
                    break;

                case "2":
                case "KP_2":
                    page_switcher.set_active (1);
                    break;

                case "3":
                case "KP_3":
                    page_switcher.set_active (2);
                    break;

                case "4":
                case "KP_4":
                    page_switcher.set_active (3);
                    break;

                case "5":
                case "KP_5":
                    page_switcher.set_active (4);
                    break;

                case "6":
                case "KP_6":
                    page_switcher.set_active (5);
                    break;

                case "7":
                case "KP_7":
                    page_switcher.set_active (6);
                    break;

                case "8":
                case "KP_8":
                    page_switcher.set_active (7);
                    break;

                case "9":
                case "KP_9":
                    page_switcher.set_active (8);
                    break;

                case "0":
                case "KP_0":
                    page_switcher.set_active (9);
                    break;

                case "Down":
                    break;

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
                    if (bottom.visible)
                        page_switcher.set_active (page_switcher.active - 1);
                    else
                        search_view_up ();
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (bottom.visible)
                        page_switcher.set_active (page_switcher.active + 1);
                    else
                        search_view_down ();
                    break;

            }

            return false;

        }

        public void hide_slingshot () {
            
            // Show the first page
            searchbar.text = "";

            hide ();

            grab_remove ((Widget) this);
			get_current_event_device ().ungrab (Gdk.CURRENT_TIME);

        }

        public void show_slingshot () {

            show_search_view (false);

            show_all ();
            searchbar.grab_focus ();
            //Utils.present_window (this);

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

        private void show_search_view (bool show) {

            if (show) {

                bottom.hide (); // Hide the switcher
                category_switcher.hide ();
                pages.move (grid, 5*130, 0); // Move the grid away
                pages.move (search_view, 0, 0); // Show the searchview
            
            } else {

                pages.move (search_view, -130*5, 0);
                bottom.show_all ();
                page_switcher.set_active (0);
                category_switcher.active = 0;
                category_switcher.show_all ();
                pages.move (grid, 0, 0);
                current_position = 0;
            
            }

        }

        private void search () {

            var text = searchbar.text.down ().strip ();

            if (text == "") {
                show_search_view (false);
                return;
            }

            show_search_view (true);
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

        public async void populate_grid () {

            page_switcher.clear_children ();
            grid.clear ();

            pages.move (grid, 0, 0);

            page_switcher.append ("1");
            page_switcher.set_active (0);

            foreach (App app in app_system.get_sorted_apps ()) {

                var app_entry = new AppEntry (app);
                
                app_entry.app_launched.connect (hide_slingshot);

                yield grid.append (app_entry);

                app_entry.show_all ();

            }

            current_position = 0;

        }

        public void show_filtered (ArrayList<App> app_list) {

            page_switcher.clear_children ();
            grid.clear ();

            pages.move (grid, 0, 0);
            
            page_switcher.append ("1");
            page_switcher.set_active (0);

            foreach (App app in app_list) {

                var app_entry = new AppEntry (app);
                app_entry.app_launched.connect (hide_slingshot);
                grid.append (app_entry);
                app_entry.show_all ();

            }

            current_position = 0;

        }

        private void read_settings () {

            default_width = Slingshot.settings.width;
            default_height = Slingshot.settings.height;

            bg_color = Slingshot.settings.background_color;
            this.queue_draw ();
            if (pages != null)
                pages.queue_draw ();

        }

    }

}
