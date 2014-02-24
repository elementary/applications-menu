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

namespace Slingshot {

    public enum Modality {
        NORMAL_VIEW = 0,
        CATEGORY_VIEW = 1,
        SEARCH_VIEW
    }

    public class SlingshotView : Granite.Widgets.PopOver {

        // Widgets
        public Gtk.SearchEntry search_entry;
        public Gtk.Layout view_manager;
        public Widgets.Switcher page_switcher;
        public Granite.Widgets.ModeButton view_selector;

        // Views
        private Widgets.Grid grid_view;
        private Widgets.SearchView search_view;
        private Widgets.CategoryView category_view;

        public Gtk.Grid top;
        public Gtk.Grid center;
        public Gtk.Grid bottom;
        public Gtk.Grid container;
        public Gtk.Box content_area;
        private Gtk.EventBox event_box;

        public Backend.AppSystem app_system;
        private Gee.ArrayList<GMenu.TreeDirectory> categories;
        public Gee.HashMap<string, Gee.ArrayList<Backend.App>> apps;

        private int current_position = 0;
        private int search_view_position = 0;
        private Modality modality;
        private bool can_trigger_hotcorner = true;

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

        public int view_height {
            get {
                return (int) (rows * 130 + rows * grid_view.row_spacing + 35);
            }
        }

        private int column_focus = 0;
        private int row_focus = 0;

        private int category_column_focus = 0;
        private int category_row_focus = 0;

        public SlingshotView () {

            // Window properties
            this.title = "Slingshot";
            this.skip_pager_hint = true;
            this.skip_taskbar_hint = true;
            set_keep_above (true);

            // Have the window in the right place
            read_settings (true);

            Slingshot.icon_theme = Gtk.IconTheme.get_default ();

            app_system = new Backend.AppSystem ();

            categories = app_system.get_categories ();
            apps = app_system.get_apps ();

            if (Slingshot.settings.screen_resolution != @"$(screen.get_width ())x$(screen.get_height ())")
                setup_size ();
            height_request = default_rows * 145 + 180;
            setup_ui ();
            connect_signals ();

            debug ("Apps loaded");

        }

        private void setup_size () {

            debug ("In setup_size ()");
            Slingshot.settings.screen_resolution = @"$(screen.get_width ())x$(screen.get_height ())";
            default_columns = 5;
            default_rows = 3;
            while ((default_columns * 130 + 48 >= 2 * screen.get_width () / 3)) {
                default_columns--;
            }

            while ((default_rows * 145 + 72 >= 2 * screen.get_height () / 3)) {
                default_rows--;
            }

            if (Slingshot.settings.columns != default_columns) {
                Slingshot.settings.columns = default_columns;
            }
            if (Slingshot.settings.rows != default_rows)
                Slingshot.settings.rows = default_rows;
        }

        private void setup_ui () {

            debug ("In setup_ui ()");

            // Create the base container
            container = new Gtk.Grid ();

            // Add top bar
            top = new Gtk.Grid ();

            var top_separator = new Gtk.Label (""); // A fake label
            top_separator.set_hexpand(true);

            view_selector = new Granite.Widgets.ModeButton ();

            var image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
            image.tooltip_text = _("View as Grid");
            view_selector.append (image);

            image = new Gtk.Image.from_icon_name ("view-filter-symbolic", Gtk.IconSize.MENU);
            image.tooltip_text = _("View by Category");
            view_selector.append (image);

            if (Slingshot.settings.use_category)
                view_selector.selected = 1;
            else
                view_selector.selected = 0;

            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Apps…");
            search_entry.width_request = 250;
            search_entry.button_press_event.connect ((e) => {return e.button == 3;});

            if (Slingshot.settings.show_category_filter) {
                top.attach (view_selector, 0, 0, 1, 1);
            }
            top.attach (top_separator, 1, 0, 1, 1);
            top.attach (search_entry, 2, 0, 1, 1);

            center = new Gtk.Grid ();
            // Create the layout which works like view_manager
            view_manager = new Gtk.Layout (null, null);
            view_manager.set_size_request (default_columns * 130, default_rows * 145);
            center.attach (view_manager, 0, 0, 1, 1);

            // Create the "NORMAL_VIEW"
            grid_view = new Widgets.Grid (default_rows, default_columns);
            view_manager.put (grid_view, 0, 0);

            // Create the "SEARCH_VIEW"
            search_view = new Widgets.SearchView (this);
            foreach (Gee.ArrayList<Backend.App> app_list in apps.values) {
                search_view.add_apps (app_list);
            }
            view_manager.put (search_view, -columns * 130, 0);

            // Create the "CATEGORY_VIEW"
            category_view = new Widgets.CategoryView (this);
            view_manager.put (category_view, -columns * 130, 0);

            // Create the page switcher
            page_switcher = new Widgets.Switcher ();

            // A bottom widget to keep the page switcher center
            bottom = new Gtk.Grid ();


            var bottom_separator1 = new Gtk.Label (""); // A fake label
            bottom_separator1.set_hexpand (true);
            var bottom_separator2 = new Gtk.Label (""); // A fake label
            bottom_separator2.set_hexpand (true);
            bottom.attach (bottom_separator1, 0, 0, 1, 1); // A fake label
            bottom.attach (page_switcher, 1, 0, 1, 1);
            bottom.attach (bottom_separator2, 2, 0, 1, 1); // A fake label

            container.attach (Utils.set_padding (top, 12, 12, 12, 12), 0, 0, 1, 1);
            container.attach (Utils.set_padding (center, 0, 12, 12, 12), 0, 1, 1, 1);
            container.attach (Utils.set_padding (bottom, 0, 24, 12, 24), 0, 2, 1, 1);

            event_box = new Gtk.EventBox ();
            event_box.add (container);
            // Add the container to the dialog's content area
            content_area = get_content_area () as Gtk.Box;
            content_area.pack_start (event_box);

            if (Slingshot.settings.use_category)
                set_modality (Modality.CATEGORY_VIEW);
            else
                set_modality (Modality.NORMAL_VIEW);
            debug ("Ui setup completed");

        }

        private void grab_device () {
            var display = Gdk.Display.get_default ();
            var pointer = display.get_device_manager ().get_client_pointer ();
            var keyboard = pointer.associated_device;
            var keyboard_status = Gdk.GrabStatus.SUCCESS;

            if (keyboard != null && keyboard.input_source == Gdk.InputSource.KEYBOARD) {
                keyboard_status = keyboard.grab (get_window (), Gdk.GrabOwnership.NONE, true,
                                                 Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK,
                                                 null, Gdk.CURRENT_TIME);
            }

            var pointer_status = pointer.grab (get_window (), Gdk.GrabOwnership.NONE, true, 
                                               Gdk.EventMask.SMOOTH_SCROLL_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | 
                                               Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK,
                                               null, Gdk.CURRENT_TIME);

            if (pointer_status != Gdk.GrabStatus.SUCCESS || keyboard_status != Gdk.GrabStatus.SUCCESS)  {
                // If grab failed, retry again. Happens when "Applications" button is long held.
                Timeout.add (100, () => {
                    grab_device ();
                    return false;
                });
            }
        }

        public override bool button_press_event (Gdk.EventButton event) {
            var pointer = Gdk.Display.get_default ().get_device_manager ().get_client_pointer ();
            
            if (pointer.get_window_at_position (null, null) != get_window ()) {
                hide ();
            }
            
            return false;
        }

        public override bool map_event (Gdk.EventAny event) {
            grab_device ();

            return false;
        }

        private bool hotcorner_trigger (Gdk.EventMotion event) {
            if (can_trigger_hotcorner && event.x_root <= 0 && event.y_root <= 0) {
                Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().ungrab (event.time);
                can_trigger_hotcorner = false;
            } else if (event.x_root >= 1 || event.y_root >= 1) {
                can_trigger_hotcorner = true;
            }

            return false;
        }

        private void connect_signals () {

            this.focus_in_event.connect (() => {
                search_entry.grab_focus ();
                return false;
            });

            //view_manager.draw.connect (this.draw_background);

            event_box.key_press_event.connect (on_key_press);
            search_entry.search_changed.connect (() => this.search.begin (search_entry.text));
            search_entry.grab_focus ();

            search_entry.activate.connect (() => {
                if (modality == Modality.SEARCH_VIEW) {
                    search_view.launch_selected ();
                    hide ();
                } else {
                    if (get_focus () as Widgets.AppEntry != null) // checking the selected widget is an AppEntry
                        ((Widgets.AppEntry) get_focus ()).launch_app ();
                }
            });

            search_view.app_launched.connect (() => hide ());

            // This function must be after creating the page switcher
            grid_view.new_page.connect (page_switcher.append);
            populate_grid_view ();

            page_switcher.active_changed.connect (() => {

                move_page (page_switcher.active - page_switcher.old_active);
                search_entry.grab_focus (); //avoid focus is not on current page
            });

            view_selector.mode_changed.connect (() => {

                set_modality ((Modality) view_selector.selected);
            });

            // Auto-update settings when changed
            Slingshot.settings.changed["rows"].connect ( () => {read_settings (false, false, true);});
            Slingshot.settings.changed["columns"].connect ( () => {read_settings (false, true, false);});

            // Auto-update applications grid
            app_system.changed.connect (() => {

                categories = app_system.get_categories ();
                apps = app_system.get_apps ();

                populate_grid_view ();
                category_view.setup_sidebar ();
            });

            // position on the right monitor when settings changed
            screen.size_changed.connect (() => {
                setup_size ();
                reposition (false);
            });
            screen.monitors_changed.connect (() => {
                reposition (false);
            });

            // check for change in gala settings
            Slingshot.settings.gala_settings.changed.connect (gala_settings_changed);
            gala_settings_changed ();

            // hotcorner management
            motion_notify_event.connect (hotcorner_trigger);
        }

        private void gala_settings_changed () {
            if (Slingshot.settings.gala_settings.hotcorner_topleft == "open-launcher") {
                can_trigger_hotcorner = true;
            } else {
                can_trigger_hotcorner = false;
            }
        }
        
        private void reposition (bool show=true) {

            debug("Repositioning");

            Gdk.Rectangle monitor_dimensions, app_launcher_pos;
            screen.get_monitor_geometry (this.screen.get_primary_monitor(), out monitor_dimensions);
            app_launcher_pos = Gdk.Rectangle () { x = monitor_dimensions.x,
                                                  y = monitor_dimensions.y,
                                                  width = 100,
                                                  height = 30
                                                 };
            move_to_rect (app_launcher_pos, show);
        }

        private void change_view_mode (string key) {
            switch (key) {
                case "1": // Normal view
                    view_selector.selected = 0;
                    break;
                default: // Category view
                    view_selector.selected = 1;
                    break;
            }
        }

        /*
          Overriding the default handler results in infinite loop of error messages
          when an input method is in use (Gtk3 bug?).  Key press events are
          captured by an Event Box and passed to this function instead.

          Events not dealt with here are propagated to the search_entry by the
          usual mechanism.
        */
        public bool on_key_press (Gdk.EventKey event) {
            var key = Gdk.keyval_name (event.keyval).replace ("KP_", "");

            event.state &= (Gdk.ModifierType.SHIFT_MASK |
                            Gdk.ModifierType.MOD1_MASK |
                            Gdk.ModifierType.CONTROL_MASK);

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 &&
                (key == "1" || key == "2")) {
                change_view_mode (key);
                return true;
            }

            switch (key) {
                case "F4":
                    if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                        hide ();
                    }
                    
                    break;

                case "Escape":
                    if (search_entry.text.length > 0) {
                        search_entry.text = "";
                    } else {
                        hide ();
                    }

                    return true;

                case "Enter": // "KP_Enter"
                case "Return":
                case "KP_Enter":
                    if (modality == Modality.SEARCH_VIEW) {
                        search_view.launch_selected ();
                        hide ();
                    } else {
                        if (get_focus () as Widgets.AppEntry != null) // checking the selected widget is an AppEntry
                            ((Widgets.AppEntry)get_focus ()).launch_app ();
                    }
                    return true;


                case "Alt_L":
                case "Alt_R":
                    break;

                case "0":
                case "1":
                case "2":
                case "3":
                case "4":
                case "5":
                case "6":
                case "7":
                case "8":
                case "9":
                    int page = int.parse (key) - 1;

                    if (event.state != Gdk.ModifierType.MOD1_MASK)
                        return false;

                    if (modality == Modality.NORMAL_VIEW) {
                        if (page < 0 || page == 8)
                            page_switcher.set_active (grid_view.get_n_pages () - 1);
                        else
                            page_switcher.set_active (page);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (page < 0 || page == 8)
                            category_view.switcher.set_active (category_view.switcher.size - 1);
                        else
                            category_view.switcher.set_active (page);
                    } else {
                        return false;
                    }
                    search_entry.grab_focus ();
                    break;

                case "Tab":
                    if (modality == Modality.NORMAL_VIEW) {
                        view_selector.selected = 1;
                        var new_focus = category_view.app_view.get_child_at (category_column_focus, category_row_focus);
                        if (new_focus != null)
                            new_focus.grab_focus ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        view_selector.selected = 0;
                        var new_focus = grid_view.get_child_at (column_focus, row_focus);
                        if (new_focus != null)
                            new_focus.grab_focus ();
                    }
                    break;

                case "Left":
                    if (modality == Modality.NORMAL_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Left
                            page_switcher.set_active (page_switcher.active - 1);
                        else
                            normal_move_focus (-1, 0);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Left
                            category_view.switcher.set_active (category_view.switcher.active - 1);
                        else if (!search_entry.has_focus) {//the user has already selected an AppEntry
                            category_move_focus (-1, 0);
                        }
                    } else
                        return false;
                    break;

                case "Right":
                    if (modality == Modality.NORMAL_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                            page_switcher.set_active (page_switcher.active + 1);
                        else
                            normal_move_focus (+1, 0);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                            category_view.switcher.set_active (category_view.switcher.active + 1);
                        else if (search_entry.has_focus) // there's no AppEntry selected, the user is switching category
                            top_left_focus ();
                        else //the user has already selected an AppEntry
                            category_move_focus (+1, 0);
                    } else {
                        return false;
                    }
                    break;

                case "Up":
                    if (modality == Modality.NORMAL_VIEW) {
                            normal_move_focus (0, -1);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Up
                            if (category_view.category_switcher.selected != 0) {
                                category_view.category_switcher.selected--;
                                top_left_focus ();
                            }
                        } else if (search_entry.has_focus) {
                            category_view.category_switcher.selected--;
                        } else {
                          category_move_focus (0, -1);
                        }
                    } else if (modality == Modality.SEARCH_VIEW) {
                        search_view.selected--;
                        search_view_up ();
                    }
                    break;

                case "Down":
                    if (modality == Modality.NORMAL_VIEW) {
                            normal_move_focus (0, +1);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Down
                            category_view.category_switcher.selected++;
                            top_left_focus ();
                        } else if (search_entry.has_focus) {
                            category_view.category_switcher.selected++;
                        } else { // the user has already selected an AppEntry
                            category_move_focus (0, +1);
                        }
                    } else if (modality == Modality.SEARCH_VIEW) {
                        search_view.selected++;
                        if (search_view.selected > 7)
                            search_view_down ();
                    }
                    break;

                case "Page_Up":
                    if (modality == Modality.NORMAL_VIEW) {
                        page_switcher.set_active (page_switcher.active - 1);
                        if (page_switcher.active != 0) // we don't wanna lose focus if we don't actually change page
                            search_entry.grab_focus (); // this is because otherwise focus isn't the current page
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected--;
                        top_left_focus ();
                    }
                    break;

                case "Page_Down":
                    if (modality == Modality.NORMAL_VIEW) {
                        page_switcher.set_active (page_switcher.active + 1);
                        if (page_switcher.active != grid_view.get_n_pages () - 1) // we don't wanna lose focus if we don't actually change page
                            search_entry.grab_focus (); //this is because otherwise focus isn't the current page
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected++;
                        top_left_focus ();
                    }
                    break;

                case "BackSpace":
                    if (event.state == Gdk.ModifierType.SHIFT_MASK) { // Shift + Delete
                        search_entry.text = "";
                    } else if (search_entry.has_focus) {
                        return false;
                    } else {
                        search_entry.grab_focus ();
                        search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                        return false;
                    }
                    break;

                case "Home":
                    if (search_entry.text.length > 0) {
                        return false;
                    }

                    if (modality == Modality.NORMAL_VIEW) {
                        page_switcher.set_active (0);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected = 0;
                        top_left_focus ();
                    }
                    break;

                case "End":
                    if (search_entry.text.length > 0) {
                        return false;
                    }

                    if (modality == Modality.NORMAL_VIEW) {
                        page_switcher.set_active (grid_view.get_n_pages () - 1);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected = category_view.category_switcher.cat_size - 1;
                        top_left_focus ();
                    }
                    break;

                case "v":
                case "V":
                    if ((event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) != 0) {
                        search_entry.paste_clipboard ();
                    }
                    break;

                default:
                    if (!search_entry.has_focus) {
                        search_entry.grab_focus ();
                        search_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
                    }
                    return false;

            }

            return true;

        }

        public override bool scroll_event (Gdk.EventScroll event) {

            switch (event.direction.to_string ()) {
                case "GDK_SCROLL_UP":
                case "GDK_SCROLL_LEFT":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (page_switcher.active - 1);
                    else if (modality == Modality.SEARCH_VIEW)
                        search_view_up ();
                    else
                        category_view.switcher.set_active (category_view.switcher.active - 1);
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (modality == Modality.NORMAL_VIEW)
                        page_switcher.set_active (page_switcher.active + 1);
                    else if (modality == Modality.SEARCH_VIEW)
                        search_view_down ();
                    else
                        category_view.switcher.set_active (category_view.switcher.active + 1);
                    break;

            }

            return false;

        }

        public void show_slingshot () {

            search_entry.text = "";

            reposition ();
            show_all ();
            present ();

            set_focus(null);
            search_entry.grab_focus ();
            set_modality ((Modality) view_selector.selected);

            while (Gtk.events_pending ())
                Gtk.main_iteration ();

            var xid = Gdk.X11Window.get_xid (this.get_window ());
            var w = Wnck.Window.get (xid);
            Wnck.Screen.get_default ().force_update ();
            if (w != null)
                w.activate (Gdk.x11_get_server_time (this.get_window ()));
        }

        private void move_page (int step) {

            debug ("Moving: step = " + step.to_string ());

            if (step == 0)
                return;
            if (step < 0 && current_position >= 0) //Left border
                return;
            if (step > 0 && (-current_position) >= ((grid_view.get_n_pages () - 1) * grid_view.get_page_columns () * 130)) //Right border
                return;

            int count = 0;
            int increment = -step * 130 * columns / 10;
            Timeout.add (30 / columns, () => {

                if (count >= 10) {
                    current_position += -step * 130 * columns - 10 * increment; //We adjust to end of the page
                    view_manager.move (grid_view, current_position, 0);
                    return false;
                }

                current_position += increment;
                view_manager.move (grid_view, current_position, 0);
                count++;
                return true;

            }, Priority.DEFAULT_IDLE);
        }

        private void search_view_down () {

            if (search_view.apps_showed < default_rows * 3)
                return;

            if ((search_view_position) > -(search_view.apps_showed * 48)) {
                view_manager.move (search_view, 0, search_view_position - 2 * 38);
                search_view_position -= 2 * 38;
            }

        }

        private void search_view_up () {

            if (search_view_position < 0) {
                view_manager.move (search_view, 0, search_view_position + 2 * 38);
                search_view_position += 2 * 38;
            }

        }

        private void set_modality (Modality new_modality) {

            modality = new_modality;

            switch (modality) {
                case Modality.NORMAL_VIEW:

                    if (Slingshot.settings.use_category)
                        Slingshot.settings.use_category = false;
                    bottom.show ();
                    view_selector.show_all ();
                    page_switcher.show_all ();
                    category_view.show_page_switcher (false);
                    view_manager.move (search_view, - 130 * columns, 0);
                    view_manager.move (category_view, 130 * columns, 0);
                    view_manager.move (grid_view, current_position, 0);

                    // change the paddings/margins back to normal
                    get_content_area ().set_margin_left (PADDINGS.left + SHADOW_SIZE + 5);
                    center.set_margin_left (12);
                    top.set_margin_left (12);
                    view_manager.set_size_request (default_columns * 130, default_rows * 145);
                    break;

                case Modality.CATEGORY_VIEW:

                    if (!Slingshot.settings.use_category)
                        Slingshot.settings.use_category = true;
                    bottom.show ();
                    view_selector.show_all ();
                    page_switcher.hide ();
                    category_view.show_page_switcher (true);
                    view_manager.move (grid_view, (columns + 1) * 130, 0); // plus 1 is needed because otherwise grid_view may appear in category view
                    view_manager.move (search_view, -columns * 130, 0);
                    view_manager.move (category_view, 0, 0);

                    // remove the padding/margin on the left
                    get_content_area ().set_margin_left (PADDINGS.left + SHADOW_SIZE);
                    center.set_margin_left (0);
                    top.set_margin_left (17);
                    view_manager.set_size_request (default_columns * 130 + 17, default_rows * 145);
                    break;

                case Modality.SEARCH_VIEW:
                    view_selector.hide ();
                    bottom.hide (); // Hide the switcher
                    view_manager.move (grid_view, columns * 130, 0); // Move the grid_view away
                    view_manager.move (category_view, columns * 130, 0);
                    view_manager.move (search_view, 0, 0); // Show the searchview

                    // change the paddings/margins back to normal
                    get_content_area ().set_margin_left (PADDINGS.left + SHADOW_SIZE + 5);
                    center.set_margin_left (12);
                    top.set_margin_left (12);
                    view_manager.set_size_request (default_columns * 130, default_rows * 145);
                    break;

            }
            //search_entry.grab_focus ();

        }

        private async void search (string text) {

            var stripped = text.down ().strip ();

            if (stripped == "") {
                set_modality ((Modality) view_selector.selected);
                return;
            }

            if (modality != Modality.SEARCH_VIEW)
                set_modality (Modality.SEARCH_VIEW);
            search_view_position = 0;
            view_manager.move (search_view, 0, search_view_position);
            search_view.hide_all ();

            var filtered = yield app_system.search_results (stripped);

            foreach (Backend.App app in filtered) {
                search_view.show_app (app);
            }

            search_view.add_command (text);

        }

        public void populate_grid_view () {

            page_switcher.clear_children ();
            grid_view.clear ();

            page_switcher.append ("1");
            page_switcher.set_active (0);

            foreach (Backend.App app in app_system.get_apps_by_name ()) {

                var app_entry = new Widgets.AppEntry (app);
                app_entry.app_launched.connect (() => hide ());
                grid_view.append (app_entry);
                app_entry.show_all ();
            }

            view_manager.move (grid_view, 0, 0);
            current_position = 0;

        }

        private void read_settings (bool first_start = false, bool check_columns = true, bool check_rows = true) {

            if (check_columns) {
                if (Slingshot.settings.columns > 3)
                    default_columns = Slingshot.settings.columns;
                else
                    default_columns = Slingshot.settings.columns = 4;
            }

            if (check_rows) {
                if (Slingshot.settings.rows > 1)
                    default_rows = Slingshot.settings.rows;
                else
                    default_rows = Slingshot.settings.rows = 2;
            }

            if (!first_start) {
                grid_view.resize (default_rows, default_columns);
                populate_grid_view ();
                height_request = default_rows * 145 + 180;

                category_view.app_view.resize (default_rows, default_columns);
                category_view.set_size_request (columns * 130 + 17, view_height);
                category_view.show_filtered_apps (category_view.category_ids.get (category_view.category_switcher.selected));
            }

        }

        private void normal_move_focus (int delta_column, int delta_row) {
            if (get_focus () as Widgets.AppEntry != null) { // we check if any AppEntry has focus. If it does, we move
                var new_focus = grid_view.get_child_at (column_focus + delta_column, row_focus + delta_row); // we check if the new widget exists
                if (new_focus == null) {
                    if (delta_column <= 0)
                        return;
                    else {
                        new_focus = grid_view.get_child_at (column_focus + delta_column, 0);
                        delta_row = -row_focus; // so it's 0 at the end
                        if (new_focus == null)
                            return;
                    }
                }
                column_focus += delta_column;
                row_focus += delta_row;
                if (delta_column > 0 && column_focus % grid_view.get_page_columns () == 0 ) //check if we need to change page
                    page_switcher.set_active (page_switcher.active + 1);
                else if (delta_column < 0 && (column_focus + 1) % grid_view.get_page_columns () == 0) //check if we need to change page
                    page_switcher.set_active (page_switcher.active - 1);
                new_focus.grab_focus ();
            }
            else { // we move to the first app in the top left corner of the current page
                grid_view.get_child_at (page_switcher.active * grid_view.get_page_columns (), 0).grab_focus ();
                column_focus = page_switcher.active * grid_view.get_page_columns ();
                row_focus = 0;
            }
        }

        private void category_move_focus (int delta_column, int delta_row) {
            var new_focus = category_view.app_view.get_child_at (category_column_focus + delta_column, category_row_focus + delta_row);
            if (new_focus == null) {
                if (delta_row < 0 && category_view.category_switcher.selected != 0) {
                    category_view.category_switcher.selected--;
                    top_left_focus ();
                    return;
                }
                else if (delta_row > 0 && category_view.category_switcher.selected != category_view.category_switcher.cat_size - 1) {
                    category_view.category_switcher.selected++;
                    top_left_focus ();
                    return;
                }
                else if (delta_column > 0 && (category_column_focus + delta_column) % category_view.app_view.get_page_columns () == 0
                          && category_view.switcher.active + 1 != category_view.app_view.get_n_pages ()) {
                    category_view.switcher.set_active (category_view.switcher.active + 1);
                    top_left_focus ();
                    return;
                }
                else if (category_column_focus == 0 && delta_column < 0) {
                    search_entry.grab_focus ();
                    category_column_focus = 0;
                    category_row_focus = 0;
                    return;
                }
                else
                    return;
            }
            category_column_focus += delta_column;
            category_row_focus += delta_row;
            if (delta_column > 0 && category_column_focus % category_view.app_view.get_page_columns () == 0 ) { // check if we need to change page
                category_view.switcher.set_active (category_view.switcher.active + 1);
            }
            else if (delta_column < 0 && (category_column_focus + 1) % category_view.app_view.get_page_columns () == 0) {
                // check if we need to change page
                category_view.switcher.set_active (category_view.switcher.active - 1);
            }
            new_focus.grab_focus ();
        }

        // this method moves focus to the first AppEntry in the top left corner of the current page. Works in CategoryView only
        private void top_left_focus () {
            // this is the first column of the current page
            int first_column = category_view.switcher.active * category_view.app_view.get_page_columns ();
            category_view.app_view.get_child_at (first_column, 0).grab_focus ();
            category_column_focus = first_column;
            category_row_focus = 0;
        }

        public void reset_category_focus () {
            category_column_focus = 0;
            category_row_focus = 0;
        }
    }

}