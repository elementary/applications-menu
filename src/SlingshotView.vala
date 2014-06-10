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
        public Gtk.SearchEntry dummy_search_entry;
        public Widgets.LargeSearchEntry real_search_entry;
        public Gtk.Stack stack;
        public Granite.Widgets.ModeButton view_selector;

        // Views
        private Widgets.Grid grid_view;
        private Widgets.SearchView search_view;
        private Widgets.CategoryView category_view;

        public Gtk.Grid top;
        public Gtk.Grid center;
        public Gtk.Grid container;
		public Gtk.Stack main_stack;
        public Gtk.Box content_area;
        private Gtk.EventBox event_box;

        public Backend.AppSystem app_system;
        private Gee.ArrayList<GMenu.TreeDirectory> categories;
        public Gee.HashMap<string, Gee.ArrayList<Backend.App>> apps;

        private Modality modality;
        private bool can_trigger_hotcorner = true;

		private Backend.SynapseSearch synapse;

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
			synapse = new Backend.SynapseSearch ();

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

			main_stack = new Gtk.Stack ();

			main_stack.add_named (container, "apps");

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

            dummy_search_entry = new Gtk.SearchEntry ();
            dummy_search_entry.placeholder_text = _("Search Apps…");
            dummy_search_entry.width_request = 250;
            dummy_search_entry.button_press_event.connect ((e) => {return e.button == 3;});

            if (Slingshot.settings.show_category_filter) {
                top.attach (view_selector, 0, 0, 1, 1);
            }
            top.attach (top_separator, 1, 0, 1, 1);
            top.attach (dummy_search_entry, 2, 0, 1, 1);

            center = new Gtk.Grid ();
            
            stack = new Gtk.Stack ();
            stack.set_size_request (default_columns * 130, default_rows * 145);
            center.attach (stack, 0, 0, 1, 1);

            // Create the "NORMAL_VIEW"
            var scrolled_normal = new Gtk.ScrolledWindow (null, null);
            grid_view = new Widgets.Grid (default_rows, default_columns);
            scrolled_normal.add_with_viewport (grid_view);
            stack.add_named (scrolled_normal, "normal");

            // Create the "SEARCH_VIEW"
			var search_view_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

			real_search_entry = new Widgets.LargeSearchEntry ();
			real_search_entry.margin_left = real_search_entry.margin_right = 12;

            search_view = new Widgets.SearchView (this);
			search_view.start_search.connect ((match, target) => {
				search.begin (real_search_entry.text, match, target);
			});

			search_view_container.pack_start (real_search_entry, false);
			search_view_container.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false);
			search_view_container.pack_start (search_view);

            main_stack.add_named (search_view_container, "search");

            // Create the "CATEGORY_VIEW"
            category_view = new Widgets.CategoryView (this);
            stack.add_named (category_view, "category");

            container.attach (Utils.set_padding (top, 12, 12, 12, 12), 0, 0, 1, 1);
            container.attach (Utils.set_padding (center, 0, 12, 12, 12), 0, 1, 1, 1);

            event_box = new Gtk.EventBox ();
            event_box.add (main_stack);
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

            // get_window_at_position returns null if the window belongs to another application.
            if (pointer.get_window_at_position (null, null) == null) {
                hide ();

                return true;
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
				get_current_search_entry ().grab_focus ();
                return false;
            });

            event_box.key_press_event.connect (on_key_press);
            dummy_search_entry.key_press_event.connect (search_entry_key_press);
            real_search_entry.widget.key_press_event.connect (search_entry_key_press);

            real_search_entry.search_changed.connect (() => {
				search.begin (real_search_entry.text);
			});
            dummy_search_entry.search_changed.connect (() => {
				if (modality != Modality.SEARCH_VIEW)
					set_modality (Modality.SEARCH_VIEW);
			});
            dummy_search_entry.grab_focus ();

            dummy_search_entry.activate.connect (search_entry_activated);
            real_search_entry.widget.activate.connect (search_entry_activated);

			// the focus-out event is fired as soon as the stack transition is ended
			// at which point we're able to focus the real_search_entry
			dummy_search_entry.focus_out_event.connect (() => {
				real_search_entry.text = dummy_search_entry.text;
				real_search_entry.widget.grab_focus ();
				var cursor_pos = real_search_entry.text.length;
				real_search_entry.widget.select_region (cursor_pos, cursor_pos);

				dummy_search_entry.text = "";

				return false;
			});

            search_view.app_launched.connect (() => hide ());

            // This function must be after creating the page switcher
            populate_grid_view ();

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

        // Handle super+space when the user is typing in the search entry
        private bool search_entry_key_press (Gdk.EventKey event) {
            if ((event.keyval == Gdk.Key.space) && ((event.state & Gdk.ModifierType.SUPER_MASK) != 0)) {
                hide ();
                return true;
            }

			switch (event.keyval) {
				case Gdk.Key.Left:
					search_view.toggle_context (false);
					return true;
				case Gdk.Key.Right:
					search_view.toggle_context (true);
					return true;
			}

            return false;
        }

		private void search_entry_activated () {
			if (modality == Modality.SEARCH_VIEW) {
				if (search_view.launch_selected ())
					hide ();
			} else {
				if (get_focus () as Widgets.AppEntry != null) // checking the selected widget is an AppEntry
					((Widgets.AppEntry) get_focus ()).launch_app ();
			}
		}

		public Gtk.Entry get_current_search_entry ()
		{
			return modality == Modality.SEARCH_VIEW ? real_search_entry.widget : dummy_search_entry;
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

			var search_entry = get_current_search_entry ();

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
                        if (search_view.launch_selected ())
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
                    int page = int.parse (key);

                    if (event.state != Gdk.ModifierType.MOD1_MASK)
                        return false;

                    if (modality == Modality.NORMAL_VIEW) {
                        if (page < 0 || page == 9)
                            grid_view.go_to_last ();
                        else
                            grid_view.go_to_number (page);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (page < 0 || page == 9)
                            category_view.app_view.go_to_last ();
                        else
                            category_view.app_view.go_to_number (page);
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
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) {// Shift + Left
                            grid_view.go_to_previous ();
                        } else {
                            normal_move_focus (-1, 0);
                        }
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Left
                            category_view.app_view.go_to_previous ();
                        else if (!search_entry.has_focus) {//the user has already selected an AppEntry
                            category_move_focus (-1, 0);
                        }
					} else
                        return false;
                    break;

                case "Right":
                    if (modality == Modality.NORMAL_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                            grid_view.go_to_next ();
                        else
                            normal_move_focus (+1, 0);
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        if (event.state == Gdk.ModifierType.SHIFT_MASK) // Shift + Right
                            category_view.app_view.go_to_next ();
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
                        search_view.up ();
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
                        search_view.down ();
                    }
                    break;

                case "Page_Up":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_previous ();
                    } else if (modality == Modality.CATEGORY_VIEW) {
                        category_view.category_switcher.selected--;
                        top_left_focus ();
                    }
                    break;

                case "Page_Down":
                    if (modality == Modality.NORMAL_VIEW) {
                        grid_view.go_to_next ();
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
                        grid_view.go_to_number (1);
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
                        grid_view.go_to_last ();
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
                        grid_view.go_to_previous ();
                    else if (modality == Modality.CATEGORY_VIEW)
                        category_view.app_view.go_to_previous ();
                    break;
                case "GDK_SCROLL_DOWN":
                case "GDK_SCROLL_RIGHT":
                    if (modality == Modality.NORMAL_VIEW)
                        grid_view.go_to_next ();
                    else if (modality == Modality.CATEGORY_VIEW)
                        category_view.app_view.go_to_next ();
                    break;

            }

            return false;

        }

        public void show_slingshot () {

            dummy_search_entry.text = "";
            real_search_entry.text = "";

            reposition ();
            show_all ();
            present ();

            set_focus(null);
            get_current_search_entry ().grab_focus ();
            set_modality ((Modality) view_selector.selected);
        }

        private void set_modality (Modality new_modality) {

			if (modality == new_modality)
				return;

            modality = new_modality;

            switch (modality) {
                case Modality.NORMAL_VIEW:

                    if (Slingshot.settings.use_category)
                        Slingshot.settings.use_category = false;
                    view_selector.show_all ();
					main_stack.set_visible_child_name ("apps");
                    stack.set_visible_child_name ("normal");

                    // change the paddings/margins back to normal
                    get_content_area ().set_margin_left (PADDINGS.left + SHADOW_SIZE + 5);
                    center.set_margin_left (12);
                    top.set_margin_left (12);
                    stack.set_size_request (default_columns * 130, default_rows * 145);

					dummy_search_entry.grab_focus ();
                    break;

                case Modality.CATEGORY_VIEW:

                    if (!Slingshot.settings.use_category)
                        Slingshot.settings.use_category = true;
                    view_selector.show_all ();
					main_stack.set_visible_child_name ("apps");
                    stack.set_visible_child_name ("category");

                    // remove the padding/margin on the left
                    get_content_area ().set_margin_left (PADDINGS.left + SHADOW_SIZE);
                    center.set_margin_left (0);
                    top.set_margin_left (17);
                    stack.set_size_request (default_columns * 130 + 17, default_rows * 145);

					dummy_search_entry.grab_focus ();
                    break;

                case Modality.SEARCH_VIEW:
                    view_selector.hide ();
					main_stack.set_visible_child_name ("search");

                    var content_area = get_content_area ();
					content_area.margin_left = content_area.margin_right = SHADOW_SIZE - 1;
                    break;

            }
        }

        private async void search (string text, Synapse.SearchMatch? search_match = null,
			Synapse.Match? target = null) {

            var stripped = text.strip ();

            if (stripped == "") {
				// this code was making problems when selecting the currently searched text
				// and immediately replacing it. In that case two async searches would be
				// started and both requested switching from and to search view, which would
				// result in a Gtk error and the first letter of the new search not being
				// picked up. If we add an idle and recheck that the entry is indeed still
				// empty before switching, this problem is gone.
				Idle.add (() => {
					if (real_search_entry.text.strip () == "")
						set_modality ((Modality) view_selector.selected);
					return false;
				});
				return;
            }

            if (modality != Modality.SEARCH_VIEW)
                set_modality (Modality.SEARCH_VIEW);

			Gee.List<Synapse.Match> matches;

			if (search_match != null) {
				search_match.search_source = target;
				matches = yield synapse.search (text, search_match);
			} else {
				matches = yield synapse.search (text);
			}

            search_view.clear ();
			search_view.set_results (matches, text);

			search_view.selected = 0;

        }

        public void populate_grid_view () {

            grid_view.clear ();

            foreach (Backend.App app in app_system.get_apps_by_name ()) {

                var app_entry = new Widgets.AppEntry (app);
                app_entry.app_launched.connect (() => hide ());
                grid_view.append (app_entry);
                app_entry.show_all ();
            }

            stack.set_visible_child_name ("normal");

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
                category_view.show_filtered_apps (category_view.category_ids.get (category_view.category_switcher.selected));
            }

        }

        private void normal_move_focus (int delta_column, int delta_row) {
            if (get_focus () as Widgets.AppEntry != null) { // we check if any AppEntry has focus. If it does, we move
                if (column_focus + delta_column < 0 || row_focus + delta_row < 0)
                    return;
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
                    grid_view.go_to_next ();
                else if (delta_column < 0 && (column_focus + 1) % grid_view.get_page_columns () == 0) //check if we need to change page
                    grid_view.go_to_previous ();
                new_focus.grab_focus ();
            }
            else { // we move to the first app in the top left corner of the current page
                column_focus = (grid_view.get_current_page ()-1) * grid_view.get_page_columns ();
                if (column_focus >= 0)
                    grid_view.get_child_at (column_focus, 0).grab_focus ();
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
                          && category_view.app_view.get_current_page ()+ 1 != category_view.app_view.get_n_pages ()) {
                    category_view.app_view.go_to_next ();
                    top_left_focus ();
                    return;
                }
                else if (category_column_focus == 0 && delta_column < 0) {
                    get_current_search_entry ().grab_focus ();
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
                category_view.app_view.go_to_next ();
            }
            else if (delta_column < 0 && (category_column_focus + 1) % category_view.app_view.get_page_columns () == 0) {
                // check if we need to change page
                category_view.app_view.go_to_previous ();
            }
            new_focus.grab_focus ();
        }

        // this method moves focus to the first AppEntry in the top left corner of the current page. Works in CategoryView only
        private void top_left_focus () {
            // this is the first column of the current page
            int first_column = (grid_view.get_current_page ()-1) * category_view.app_view.get_page_columns ();
            category_view.app_view.get_child_at (first_column, 0).grab_focus ();
            category_column_focus = first_column;
            category_row_focus = 1;
        }

        public void reset_category_focus () {
            category_column_focus = 0;
            category_row_focus = 0;
        }
    }

}
