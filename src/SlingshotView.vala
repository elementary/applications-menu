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

using Slingshot.Widgets;

namespace Slingshot {

    public class SlingshotView : CompositedWindow {

        private Pixbuf background;

        public EventBox wrapper;
        public EventBox lefttop_widget;
        public Searchbar searchbar;
        public GLib.List<AppIcon> children = new GLib.List<AppIcon> ();
        public Widgets.Grid grid;

        public Indicators pages;
        private int total_pages;

        public ArrayList<HashMap<string, string>> apps = new ArrayList<HashMap<string, string>> ();
        public HashMap<string, Pixbuf> icons = new HashMap<string, Pixbuf> ();
        public ArrayList<HashMap<string, string>> filtered = new ArrayList<HashMap<string, string>> ();

        private Backend.AppMonitor monitor;

        private int icon_size = 64;

        public SlingshotView () {

            try {
                background = new Pixbuf.from_file (Build.PKGDATADIR + "/style/images/background.png");
            } catch {
                error (_("Could not load background, please check your installation."));
            }

            set_size_request (661, 568);

            // Window properties
            this.title = "Slingshot";
            this.skip_pager_hint = true;
            this.skip_taskbar_hint = true;
            this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
            this.set_keep_above (true);

            setup_ui ();
            connect_signals ();

            refresh_apps ();

        }

        private void setup_ui () {
            
            // Add container wrapper
            wrapper = new EventBox ();
            wrapper.set_visible_window (false);

            // Add container
            var container = new VBox (false, 15);
            wrapper.add (container);

            // Add top bar
            var top = new HBox (false, 10);

            // Fake placeholder widget
            lefttop_widget = new EventBox ();
            lefttop_widget.set_visible_window (false);

            searchbar = new Searchbar (_("Start typing to search"));
            
            top.pack_start (lefttop_widget, true, true, 15);
            top.pack_start (searchbar, false, true, 15);

            container.pack_start (top, false, true, 15);
            
            // Make icon grid and populate
            grid = new Widgets.Grid (3, 5);
            container.pack_start (grid, true, true, 0);

            //this.populate_grid ();
            //update_grid (apps);
            //this.update_pages (this.apps);
            
            // Add pages
            this.pages = new Indicators ();
            this.pages.child_activated.connect ( () => { this.update_grid (this.filtered); } );

            var pages_wrapper = new Gtk.HBox (false, 0);
            pages_wrapper.set_size_request (-1, 30);
            pages_wrapper.pack_start (pages, true, false, 0);
            container.pack_start (pages_wrapper, false, true, 15);

            // Find number of pages and populate
            this.update_pages (this.apps);
            if (this.total_pages >  1) {
                pages_wrapper.pack_start (this.pages, true, false, 0);
                for (int p = 1; p <= this.total_pages; p++) {
                    this.pages.append (p.to_string ());
                }
            }
            this.pages.set_active (0);

            this.add (Utils.set_padding (wrapper, 15, 15, 15, 15));

        }

        private void connect_signals () {
            
            this.focus_out_event.connect ( () => {
                this.hide_slingshot(); 
                Gtk.main_quit ();
                return false; 
            });
            this.draw.connect (this.draw_background);
            searchbar.changed.connect (this.search);            

        }

        private bool draw_background (Context cr) {

            cairo_set_source_pixbuf (cr, background, 0, 0);
            cr.paint ();

            return false;

        }


        public override bool key_press_event (Gdk.EventKey event) {

            switch (Gdk.keyval_name (event.keyval)) {

                case "Escape":
                    hide_slingshot ();
                    return true;

                case "BackSpace":
                    int len = (int) this.searchbar.text.length;
                    if (len > 0) {
                        this.searchbar.text = this.searchbar.text.slice (0,len - 1);
                        this.searchbar.changed ();
                    }
                return true;
                
                default:
                    this.searchbar.text = this.searchbar.text + event.str;
                    this.searchbar.changed ();
                    break;

            }

            base.key_press_event (event);
            return false;

        }

        private void hide_slingshot () {

            iconify ();

        }

        private void search () {

            var text = searchbar.text.down ();

            message ("Performing searching... %s", text);

        }

        private void populate_grid () {

            for (int r = 0; r < this.grid.n_rows; r++) {

                for (int c = 0; c < this.grid.n_columns; c++) {

                    var item = new AppIcon (this.icon_size);
                    this.children.append (item);

                    item.button_press_event.connect ( () => { item.grab_focus (); return true; } );
                    item.enter_notify_event.connect ( () => { item.grab_focus (); return true; } );
                    item.leave_notify_event.connect ( () => { this.searchbar.grab_focus (); return true; } );
                    item.button_release_event.connect ( () => {

                        try {
                            new GLib.DesktopAppInfo.from_filename (this.filtered.get((int) (this.children.index(item) + (5 * this.grid.n_columns * this.grid.n_rows)))["desktop_file"]).launch (null, null);
                            this.hide_slingshot();
                        } catch (GLib.Error e) {
                            stdout.printf("Error! Load application: " + e.message);
                        }

                        return true;

                    });

                    this.grid.attach (item, c, c + 1, r, r + 1, Gtk.AttachOptions.EXPAND, Gtk.AttachOptions.EXPAND, 0, 0);

                }
            }

        }

        private void update_grid (Gee.ArrayList<Gee.HashMap<string, string>> apps) {

            int item_iter = (int)(6 * this.grid.n_columns * this.grid.n_rows);
            for (int r = 0; r < this.grid.n_rows; r++) {

                for (int c = 0; c < this.grid.n_columns; c++) {

                    int table_pos = c + (r * (int)this.grid.n_columns); // position in table right now

                    var item = this.children.nth_data(table_pos);
                    if (item_iter < apps.size) {
                        var current_item = apps.get(item_iter);

                        // Update app
                        if (current_item["description"] == null || current_item["description"] == "") {
                            //item.change_app (icons[current_item["command"]], current_item["name"], current_item["name"]);
                        } else {
                            //item.change_app (icons[current_item["command"]], current_item["name"], current_item["name"] + ":\n" + current_item["description"]);
                        }
                        item.visible = true;

                    } else { // fill with a blank one
                        item.visible = false;
                    }

                    item_iter++;

                }
            }

            // Update number of pages
            this.update_pages (apps);

            // Grab first one's focus
            this.children.nth_data (0).grab_focus ();
        }

        public void refresh_apps () {
            print("Refreshing applications list\n");
            Backend.GMenuEntries.enumerate_apps (Backend.GMenuEntries.get_all (), this.icons, this.icon_size, out this.apps);
        }

        private void update_pages (Gee.ArrayList<Gee.HashMap<string, string>> apps) {
            // Find current number of pages and update count
            var num_pages = (int) (apps.size / (this.grid.n_columns * this.grid.n_rows));
            (double) apps.size % (double) (this.grid.n_columns * this.grid.n_rows) > 0 ? this.total_pages = num_pages + 1 : this.total_pages = num_pages;

            // Update pages
            if (this.total_pages > 1) {
                this.pages.visible = true;
                for (int p = 1; p <= this.pages.children.length (); p++) {
                    p > this.total_pages ? this.pages.children.nth_data (p - 1).visible = false : this.pages.children.nth_data (p - 1).visible = true;
                }
            } else {
                this.pages.visible = false;
            }

        }
    }

}
