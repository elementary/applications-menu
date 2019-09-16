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

public class Slingshot.Widgets.AppButton : Gtk.Button {
    private static Slingshot.AppMenu menu;

    public signal void app_launched ();

    public Gtk.Label app_label;
    public unowned string exec_name {
        get {
            return application.exec;
        }
    }

    public unowned string app_name {
        get {
            return application.name;
        }
    }

    public unowned string desktop_id {
        get {
            return application.desktop_id;
        }
    }

    public unowned string desktop_path {
        get {
            return application.desktop_path;
        }
    }

    private static Gtk.CssProvider css_provider;

    private new Granite.AsyncImage image;
    private Gtk.Label badge;
    private bool dragging = false; //prevent launching
    private Backend.App application;

    static construct {
#if HAS_PLANK
        Plank.Paths.initialize ("plank", Build.PKGDATADIR);
        plank_client = Plank.DBusClient.get_instance ();
#endif

        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/desktop/wingpanel/applications-menu/applications-menu.css");
    }

    private const int ICON_SIZE = 64;

#if HAS_PLANK
    private static Plank.DBusClient plank_client;
    private string desktop_uri {
        owned get {
            return File.new_for_path (desktop_path).get_uri ();
        }
    }
#endif

    public AppButton (Backend.App app) {
        Gtk.TargetEntry dnd = {"text/uri-list", 0, 0};
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {dnd},
                             Gdk.DragAction.COPY);

        application = app;
        tooltip_text = app.description;

        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        app_label = new Gtk.Label (app_name);
        app_label.halign = Gtk.Align.CENTER;
        app_label.justify = Gtk.Justification.CENTER;
        app_label.set_line_wrap (true);
        app_label.lines = 2;
        app_label.set_single_line_mode (false);
        app_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        app_label.set_ellipsize (Pango.EllipsizeMode.END);

        image = new Granite.AsyncImage.from_gicon_async (app.icon, ICON_SIZE);

        image.pixel_size = ICON_SIZE;
        image.margin_top = 9;
        image.margin_end = 6;
        image.margin_start = 6;

        badge = new Gtk.Label ("!");
        badge.visible = false;
        badge.height_request = 24;
        badge.width_request = 24;
        badge.halign = Gtk.Align.END;
        badge.valign = Gtk.Align.START;

        unowned Gtk.StyleContext badge_style_context = badge.get_style_context ();
        badge_style_context.add_class ("badge");
        badge_style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var overlay = new Gtk.Overlay ();
        overlay.halign = Gtk.Align.CENTER;
        overlay.add (image);
#if HAS_PLANK
        overlay.add_overlay (badge);
#endif

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
                return false;
            }

            menu = new Slingshot.AppMenu (desktop_id, desktop_path);
            menu.app_launched.connect (() => {
                app_launched ();
            });

            if (menu != null && menu.get_children () != null) {
                menu.popup (null, null, null, e.button, e.time);
                return true;
            }
            return false;
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
            sel.set_uris ({File.new_for_path (desktop_path).get_uri ()});
        });

#if HAS_PLANK
        app.notify["current-count"].connect (update_badge_count);
        app.notify["count-visible"].connect (update_badge_visibility);

        update_badge_count ();
#endif

        app.notify["icon"].connect (() => image.set_from_gicon_async.begin (app.icon, ICON_SIZE));
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = Pixels.ITEM_SIZE;
        natural_width = Pixels.ITEM_SIZE;
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = Pixels.ITEM_SIZE;
        natural_height = Pixels.ITEM_SIZE;
    }

    public void launch_app () {
        application.launch ();
        app_launched ();
    }
#if HAS_PLANK
    private void update_badge_count () {
        badge.label = "%lld".printf (application.current_count);
        update_badge_visibility ();
    }

    private void update_badge_visibility () {
        var count_visible = application.count_visible && application.current_count > 0;
        badge.no_show_all = !count_visible;
        if (count_visible) {
            badge.show_all ();
        } else {
            badge.hide ();
        }
    }
#endif
}
