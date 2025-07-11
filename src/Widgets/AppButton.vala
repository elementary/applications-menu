/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.AppButton : Gtk.Button {
    public signal void app_launched ();

    public Backend.App app { get; construct; }

    private const int ICON_SIZE = 64;

    private Gtk.Label badge;
    private bool dragging = false; //prevent launching

    private Gtk.GestureMultiPress click_controller;
    private Gtk.EventControllerKey menu_key_controller;

    public AppButton (Backend.App app) {
        Object (app: app);
    }

    construct {
        Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd},
                             Gdk.DragAction.COPY);

        tooltip_text = app.description;

        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var app_label = new Gtk.Label (app.name) {
            halign = CENTER,
            ellipsize = END,
            justify = CENTER,
            lines = 2,
            max_width_chars = 16,
            width_chars = 16,
            wrap_mode = WORD_CHAR
        };

        var icon = app.icon;
        unowned var theme = Gtk.IconTheme.get_default ();
        if (icon == null || theme.lookup_by_gicon (icon, ICON_SIZE, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        var image = new Gtk.Image.from_gicon (icon, ICON_SIZE) {
            margin_top = 9,
            margin_end = 6,
            margin_start = 6,
            pixel_size = ICON_SIZE
        };

        badge = new Gtk.Label ("!") {
            halign = END,
            valign = START,
            visible = false
        };
        badge.get_style_context ().add_class (Granite.STYLE_CLASS_BADGE);

        var overlay = new Gtk.Overlay () {
            child = image,
            halign = CENTER
        };
        overlay.add_overlay (badge);

        var box = new Gtk.Box (VERTICAL, 6) {
            halign = CENTER,
            hexpand = true,
            vexpand = true
        };
        box.add (overlay);
        box.add (app_label);

        child = box;

        app.launched.connect (() => app_launched ());

        this.clicked.connect (launch_app);

        click_controller = new Gtk.GestureMultiPress (this) {
            button = 0,
            exclusive = true
        };
        click_controller.pressed.connect ((n_press, x, y) => {
            var sequence = click_controller.get_current_sequence ();
            var event = click_controller.get_last_event (sequence);

            if (event.triggers_context_menu ()) {
                var context_menu = new Gtk.Menu.from_model (app.get_menu_model ());
                context_menu.insert_action_group (Backend.App.ACTION_GROUP_PREFIX, app.action_group);
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
                        var context_menu = new Gtk.Menu.from_model (app.get_menu_model ());
                        context_menu.insert_action_group (Backend.App.ACTION_GROUP_PREFIX, app.action_group);
                        context_menu.popup_at_widget (this, EAST, CENTER);
                    }
                    break;
                case Gdk.Key.Menu:
                case Gdk.Key.MenuKB:
                    var context_menu = new Gtk.Menu.from_model (app.get_menu_model ());
                    context_menu.insert_action_group (Backend.App.ACTION_GROUP_PREFIX, app.action_group);
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
