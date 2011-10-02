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

    public enum Modality {
        NORMAL_VIEW = 0,
        CATEGORY_VIEW = 1,
        SEARCH_VIEW
    }

    public class SlingshotView : Gtk.Window, Gtk.Buildable {

        // Widgets
        public SearchBar searchbar;
        public Layout view_manager = null;
        public Switcher page_switcher;
        public ModeButton view_selector;
        public HBox bottom;

        // Views
        public Widgets.Grid grid_view;
        public SearchView search_view;
        public CategoryView category_view;

        private VBox container;

        public AppSystem app_system;
        private ArrayList<TreeDirectory> categories;
        public HashMap<string, ArrayList<App>> apps;
        private ArrayList<App> filtered;

        private int current_position = 0;
        private int search_view_position = 0;
        private Modality modality;

        // Sizes
        public int columns {
            get {
                return grid_view.get_page_columns ();
            }
        }
        public int rows {
            get {
                return grid_view.get_page_rows ();
            }
        }
        private int default_columns;
        private int default_rows;

        // Background color
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
            read_settings (true);
            set_size_request (default_columns * 130 + 50, default_rows * 140 + 160);

            set_visual (get_screen ().get_rgba_visual());
            get_style_context ().add_provider_for_screen (get_screen (), Slingshot.style_provider, 600);
            Slingshot.icon_theme = IconTheme.get_default ();

            app_system = new AppSystem ();

            categories = app_system.get_categories ();
            apps = app_system.get_apps ();
            setup_ui ();
            connect_signals ();
            if (!app.silent)
                show_all ();

            debug ("Apps loaded");

            filtered = new ArrayList<App> ();

        }

        private void setup_ui () {

            debug ("In setup_ui ()");

            // Create the base container
            container = new VBox (false, 0);

            // Add top bar
            var top = new HBox (false, 10);

            view_selector = new ModeButton ();
            view_selector.append (new Image.from_icon_name ("slingshot-view-list-icons-symbolic", IconSize.MENU));
            view_selector.append (new Image.from_icon_name ("slingshot-view-list-filter-symbolic", IconSize.MENU));
            view_selector.selected = 0;

            searchbar = new SearchBar ("");
            searchbar.width_request = 250;

            if (Slingshot.settings.show_category_filter) {
                top.pack_start (view_selector, false, false, 0);
            }
            top.pack_end (searchbar, false, false, 0);

            // Create the layout which works like view_manager
            view_manager = new Layout (null, null);

            // Get the current size of the view
            int width, height;
            get_size (out width, out height);

            // Create the "NORMAL_VIEW"
            grid_view = new Widgets.Grid (default_rows, default_columns);
            view_manager.put (grid_view, 0, 0);

            // Create the "SEARCH_VIEW"
            search_view = new SearchView (this);
            foreach (ArrayList<App> app_list in apps.values) {
                search_view.add_apps (app_list);
            }
            view_manager.put (search_view, -columns*130, 0);

            // Create the "CATEGORY_VIEW"
            category_view = new CategoryView (this);
            view_manager.put (category_view, -columns*130, 0);

            // Create the page switcher
            page_switcher = new Switcher ();

            // A bottom widget to keep the page switcher center
            bottom = new HBox (false, 0);
            bottom.pack_start (new Label (""), true, true, 0); // A fake label
            bottom.pack_start (page_switcher, false, false, 10);
            bottom.pack_start (new Label (""), true, true, 0); // A fake label

            container.pack_start (top, false, true, 15);
            container.pack_start (Utils.set_padding (view_manager, 0, 10, 24, 10), true, true, 0);
            container.pack_start (Utils.set_padding (bottom, 0, 9, 15, 9), false, false, 0);
            this.add (Utils.set_padding (container, 15, 15, 1, 15));

            set_modality (Modality.NORMAL_VIEW);
            debug ("Ui setup completed");

        }

        private void connect_signals () {

            this.focus_out_event.connect (() => {
                this.hide_slingshot();
                return false;
            });

            this.focus_in_event.connect (() => {
                searchbar.grab_focus ();
                return false;
            });

            view_manager.draw.connect (this.draw_background);

            searchbar.changed.connect_after (this.search);
            searchbar.grab_focus ();

            search_view.app_launched.connect (hide_slingshot);

            // This function must be after creating the page switcher
            grid_view.new_page.connect (page_switcher.append);
            populate_grid_view ();

            page_switcher.active_changed.connect (() => {

                if (page_switcher.active > page_switcher.old_active)
                    this.page_right (page_switcher.active - page_switcher.old_active);
                else
                    this.page_left (page_switcher.old_active - page_switcher.active);

            });

            view_selector.mode_changed.connect (() => {

                set_modality ((Modality) view_selector.selected);

            });

            // Auto-update settings when changed
            Slingshot.settings.changed.connect (() => read_settings ());

            // Auto-update applications grid
            app_system.changed.connect (() => {

                categories = app_system.get_categories ();
                apps = app_system.get_apps ();

                populate_grid_view ();
            });

        }

        protected override bool draw (Context cr) {

            Allocation size;
            get_allocation (out size);

            // Some (configurable?) values
            double radius = 7.0;
            double offset = 2.0;

            cr.set_antialias (Antialias.SUBPIXEL);

            cr.move_to (0 + radius, 15 + offset);
            // Create the little rounded triangle
            cr.line_to (20.0, 15.0 + offset);
            //cr.line_to (30.0, 0.0 + offset);
            cr.arc (35.0, 0.0 + offset + radius, radius - 2.0, -2.0 * Math.PI / 2.7, -7.0 * Math.PI / 3.2);
            cr.line_to (50.0, 15.0 + offset);
            // Create the rounded square
            cr.arc (0 + size.width - radius - offset, 15.0 + radius + offset,
                         radius, Math.PI * 1.5, Math.PI * 2);
            cr.arc (0 + size.width - radius - offset, 0 + size.height - radius - offset,
                         radius, 0, Math.PI * 0.5);
            cr.arc (0 + radius + offset, 0 + size.height - radius - offset,
                         radius, Math.PI * 0.5, Math.PI);
            cr.arc (0 + radius + offset, 15 + radius + offset, radius, Math.PI, Math.PI * 1.5);
            cr.close_path ();

            pick_background_color (cr);

            cr.clip_preserve ();
            cr.paint ();

            // Paint a little white border
            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.set_line_width (1.0);
            cr.stroke ();

            return base.draw (cr);

        }

        public bool draw_background (Widget widget, Context cr) {

            Allocation size;
            widget.get_allocation (out size);

            cr.rectangle (0, 0, size.width, size.height);

            pick_background_color (cr);

            cr.fill_preserve ();

            return false;

        }

        private void pick_background_color (Context cr) {

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
                case BackgroundColor.ORANGE:
                    cr.set_source_rgba (0.4, 0.2, 0.1, 0.9);
                    break;
                case BackgroundColor.GOLD:
                    cr.set_source_rgba (0.5, 0.4, 0.0, 0.9);
                    break;
                case BackgroundColor.VIOLET:
                    cr.set_source_rgba (0.2, 0.1, 0.2, 0.9);
                    break;
            }

        }

        public override bool key_press_event (Gdk.EventKey event) {

            switch (Gdk.keyval_name (event.keyval)) {

                case "Escape":
                    hide_slingshot ();
                    return true;

                case "Return":
                    if (modality == Modality.SEARCH_VIEW) {
                        search_view.launch_first ();
                        hide_slingshot ();
                    }
                    return true;

                case "Alt":
                    break;

                case "1":
                case "KP_1":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (0);
                    else
                        return base.key_press_event (event);
                    break;

                case "2":
                case "KP_2":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (1);
                    else
                        return base.key_press_event (event);
                    break;

                case "3":
                case "KP_3":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (2);
                    else
                        return base.key_press_event (event);
                    break;

                case "4":
                case "KP_4":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (3);
                    else
                        return base.key_press_event (event);
                    break;

                case "5":
                case "KP_5":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (4);
                    else
                        return base.key_press_event (event);
                    break;

                case "6":
                case "KP_6":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (5);
                    else
                        return base.key_press_event (event);
                    break;

                case "7":
                case "KP_7":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (6);
                    else
                        return base.key_press_event (event);
                    break;

                case "8":
                case "KP_8":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (7);
                    else
                        return base.key_press_event (event);
                    break;

                case "9":
                case "KP_9":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (8);
                    else
                        return base.key_press_event (event);
                    break;

                case "0":
                case "KP_0":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (9);
                    else
                        return base.key_press_event (event);
                    break;

                case "Down":
                    break;

                default:
                    if (!searchbar.has_focus)
                        searchbar.grab_focus ();
                    return base.key_press_event (event);

            }

            return true;

        }

        public override bool scroll_event (EventScroll event) {

            switch (event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_LEFT":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (page_switcher.active - 1);
                    else if (modality == Modality.SEARCH_VIEW)
                        search_view_up ();
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (page_switcher.active + 1);
                    else if (modality == Modality.SEARCH_VIEW)
                        search_view_down ();
                    break;

            }

            return false;

        }

        public void hide_slingshot () {
            
            // Show the first page
            searchbar.text = "";

            hide ();

            // grab_remove ((Widget) this);
			// get_current_event_device ().ungrab (Gdk.CURRENT_TIME);

        }

        public void show_slingshot () {

            show_all ();
            set_modality ((Modality) view_selector.selected);

            searchbar.grab_focus ();
            //Utils.present_window (this);

        }

        private void page_left (int step = 1) {

            // Avoid unexpected behavior
            if (modality != Modality.NORMAL_VIEW)
                return;

            if (current_position < 0) {
                int count = 0;
                int val = columns*130*step / 10;
                Timeout.add (20 / step, () => {

                    if (count >= columns*130*step) {
                        count = 0;
                        return false;
                    }
                    view_manager.move (grid_view, current_position + val, 0);
                    current_position += val;
                    count += val;
                    return true;

                });
            }

        }

        private void page_right (int step = 1) {

            // Avoid unexpected behavior
            if (modality != Modality.NORMAL_VIEW)
                return;            

            if ((- current_position) < (grid_view.n_columns*130)) {
                int count = 0;
                int val = columns*130*step / 10;
                Timeout.add (20 / step, () => {

                    if (count >= columns*130*step) {
                        count = 0;
                        return false;
                    }
                    view_manager.move (grid_view, current_position - val, 0);
                    current_position -= val;
                    count += val;
                    return true;
                    
                });
            }

        }

        private void search_view_down () {

            if (search_view.apps_showed < default_rows * 3)
                return;

            if ((search_view_position) > -(search_view.apps_showed*48)) {
                view_manager.move (search_view, 0, search_view_position - 2*48);
                search_view_position -= 2*48;
            }

        }

        private void search_view_up () {

            if (search_view_position < 0) {
                view_manager.move (search_view, 0, search_view_position + 2*48);
                search_view_position += 2*48;
            }

        }

        private void set_modality (Modality new_modality) {

            modality = new_modality;

            switch (modality) {
                case Modality.NORMAL_VIEW:
                    view_manager.move (search_view, -130*columns, 0);
                    view_manager.move (category_view, 130*columns, 0);
                    bottom.show_all ();
                    view_selector.show_all ();
                    view_selector.selected = 0;
                    view_manager.move (grid_view, 0, 0);
                    current_position = 0;
                    page_switcher.set_active (0);
                    return;

                case Modality.CATEGORY_VIEW:
                    view_selector.show_all ();
                    view_selector.selected = 1;
                    bottom.hide ();
                    view_manager.move (grid_view, columns*130, 0);
                    view_manager.move (search_view, -columns*130, 0);
                    view_manager.move (category_view, 0, 0);
                    return;

                case Modality.SEARCH_VIEW:
                    view_selector.hide ();
                    bottom.hide (); // Hide the switcher
                    view_manager.move (grid_view, columns*130, 0); // Move the grid_view away
                    view_manager.move (category_view, columns*130, 0);
                    view_manager.move (search_view, 0, 0); // Show the searchview
                    return;
            
            }

        }

        private void search () {

            //Idle.add_full (Priority.HIGH_IDLE, get_apps_by_category.callback);
            //yield;

            var text = searchbar.text.down ().strip ();

            if (text == "") {
                set_modality ((Modality) view_selector.selected);
                return;
            }
            
            if (modality != Modality.SEARCH_VIEW)
                set_modality (Modality.SEARCH_VIEW);
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

        public void populate_grid_view () {

            page_switcher.clear_children ();
            grid_view.clear ();

            page_switcher.append ("1");
            page_switcher.set_active (0);

            foreach (App app in app_system.get_apps_by_name ()) {

                var app_entry = new AppEntry (app);

                app_entry.app_launched.connect (hide_slingshot);
                grid_view.append (app_entry);
                app_entry.show_all ();

            }

            current_position = 0;

        }

        private void read_settings (bool first_start = false) {

            if (first_start) {
                default_columns = Slingshot.settings.columns;
                default_rows = Slingshot.settings.rows;
            }

            bg_color = Slingshot.settings.background_color;
            this.queue_draw ();
            if (view_manager != null)
                view_manager.queue_draw ();

        }

    }

}
