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

    private static Slingshot.AppContextMenu menu;

    private const int ICON_SIZE = 64;

    private Gtk.Label badge;
    private bool dragging = false; //prevent launching

    public AppButton (Backend.App app) {
        Object (app: app);
    }

    construct {
        Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
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

        var image = new Granite.AsyncImage.from_gicon_async (app.icon, ICON_SIZE);
        image.pixel_size = ICON_SIZE;
        image.margin_top = 9;
        image.margin_end = 6;
        image.margin_start = 6;

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

        this.clicked.connect (launch_app);

        this.button_press_event.connect ((e) => {
            if (e.button != Gdk.BUTTON_SECONDARY) {
                return Gdk.EVENT_PROPAGATE;
            }

            return create_context_menu (e);
        });

        this.key_press_event.connect ((e) => {
            if (e.keyval == Gdk.Key.Menu) {
                return create_context_menu (e);
            }

            return Gdk.EVENT_PROPAGATE;
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

        app.notify["icon"].connect (() => image.set_from_gicon_async.begin (app.icon, ICON_SIZE));
    }

    public void launch_app () {
        app.launch ();
        app_launched ();
    }

    private void update_badge_count () {
        if (app.current_count > 1000) {
            badge.label = "∞";
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

    private bool create_context_menu (Gdk.Event e) {
        menu = new Slingshot.AppContextMenu (app.desktop_id, app.desktop_path);
        menu.app_launched.connect (() => {
            app_launched ();
        });

        if (menu.get_children () != null) {
            if (e.type == Gdk.EventType.KEY_PRESS) {
                menu.popup_at_widget (this, Gdk.Gravity.EAST, Gdk.Gravity.CENTER, e);
                return Gdk.EVENT_STOP;
            } else if (e.type == Gdk.EventType.BUTTON_PRESS) {
                menu.popup_at_pointer (e);
                return Gdk.EVENT_STOP;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }
}
