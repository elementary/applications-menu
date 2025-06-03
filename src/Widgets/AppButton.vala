/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2011-2012 Giulio Collura
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Slingshot.Widgets.AppButton : Gtk.Button {
    public signal void app_launched ();

    public Backend.App app { get; construct; }

    private const int ICON_SIZE = 64;

    private Gtk.Label badge;
    private bool dragging = false; //prevent launching

    private Gtk.GestureClick click_controller;
    private Gtk.EventControllerKey menu_key_controller;

    public AppButton (Backend.App app) {
        Object (app: app);
    }

    construct {
        // Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd},
                             Gdk.DragAction.COPY);

        tooltip_text = app.description;

        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var app_label = new Gtk.Label (app.name);
        app_label.halign = Gtk.Align.CENTER;
        app_label.justify = Gtk.Justification.CENTER;
        app_label.lines = 2;
        app_label.max_width_chars = 16;
        app_label.width_chars = 16;
        app_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        app_label.set_ellipsize (Pango.EllipsizeMode.END);

        var image = new Gtk.Image.from_gicon (app.icon, ICON_SIZE) {
            margin_top = 9,
            margin_end = 6,
            margin_start = 6,
            pixel_size = ICON_SIZE
        };

        badge = new Gtk.Label ("!");
        badge.visible = false;
        badge.halign = Gtk.Align.END;
        badge.valign = Gtk.Align.START;

        unowned Gtk.StyleContext badge_style_context = badge.get_style_context ();
        badge_style_context.add_class (Granite.STYLE_CLASS_BADGE);

        var overlay = new Gtk.Overlay ();
        overlay.halign = Gtk.Align.CENTER;
        overlay.add (image);
        overlay.add_overlay (badge);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 6;
        grid.expand = true;
        grid.halign = Gtk.Align.CENTER;
        grid.add (overlay);
        grid.add (app_label);

        add (grid);

        var context_menu = new Slingshot.AppContextMenu (app.desktop_id, app.desktop_path);
        context_menu.app_launched.connect (() => {
            app_launched ();
        });

        this.clicked.connect (launch_app);

        click_controller = new Gtk.GestureClick (this) {
            button = 0,
            exclusive = true
        };
        click_controller.pressed.connect ((n_press, x, y) => {
            var sequence = click_controller.get_current_sequence ();
            var event = click_controller.get_last_event (sequence);

            if (event.triggers_context_menu ()) {
                context_menu.popup_at_pointer ();

                click_controller.set_state (CLAIMED);
                click_controller.reset ();
            }
        });

        menu_key_controller = new Gtk.EventControllerKey (this);
        menu_key_controller.key_released.connect ((keyval, keycode, state) => {
            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            switch (keyval) {
                case Gdk.Key.F10:
                    if (mods == Gdk.ModifierType.SHIFT_MASK) {
                        context_menu.popup_at_widget (this, EAST, CENTER);
                    }
                    break;
                case Gdk.Key.Menu:
                case Gdk.Key.MenuKB:
                    context_menu.popup_at_widget (this, EAST, CENTER);
                    break;
                default:
                    return;
            }
        });

        this.drag_begin.connect ((ctx) => {
            this.dragging = true;
            Gtk.drag_set_icon_gicon (ctx, app.icon, 16, 16);
            app_launched ();
        });

        this.drag_end.connect ( () => {
            this.dragging = false;
        });

        this.drag_data_get.connect ( (ctx, sel, info, time) => {
            sel.set_uris ({File.new_for_path (app.desktop_path).get_uri ()});
        });

        app.notify["current-count"].connect (update_badge_count);
        app.notify["count-visible"].connect (update_badge_visibility);

        update_badge_count ();

        app.bind_property ("icon", image, "gicon");
    }

    public void launch_app () {
        app.launch ();
        app_launched ();
    }

    private void update_badge_count () {
        if (app.current_count > 999) {
            badge.label = "999+";
        } else {
            badge.label = "%lld".printf (app.current_count);
        }

        update_badge_visibility ();
    }

    private void update_badge_visibility () {
        var count_visible = app.count_visible && app.current_count > 0;
        badge.no_show_all = !count_visible;
        if (count_visible) {
            badge.show_all ();
        } else {
            badge.hide ();
        }
    }
}
