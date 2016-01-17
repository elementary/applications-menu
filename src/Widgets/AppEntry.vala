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

public class Slingshot.Widgets.AppEntry : Gtk.Button {
    private static Gtk.Menu menu;

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

    private new Gtk.Image image;
    private bool dragging = false; //prevent launching
    private Backend.App application;

#if HAS_PLANK
    static construct {
#if HAS_PLANK_0_11
        plank_client = Plank.DBusClient.get_instance ();
#else
        plank_client = Plank.DBus.Client.get_instance ();
#endif
    }

#if HAS_PLANK_0_11
    private static Plank.DBusClient plank_client;
#else
    private static Plank.DBus.Client plank_client;
#endif
    private bool docked = false;
    private string desktop_uri {
        owned get {
            return File.new_for_path (desktop_path).get_uri ();
        }
    }
#endif

    public AppEntry (Backend.App app) {
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

        image = new Gtk.Image ();
        image.gicon = app.icon;
        image.pixel_size = 64;
        image.margin_top = 12;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 6;
        grid.expand = true;
        grid.halign = Gtk.Align.CENTER;
        grid.add (image);
        grid.add (app_label);

        add (grid);

        this.clicked.connect (launch_app);

        this.button_press_event.connect ((e) => {
            if (e.button != Gdk.BUTTON_SECONDARY)
                return false;

            create_menu ();
            if (menu != null && menu.get_children () != null) {
                menu.popup (null, null, null, e.button, e.time);
                return true;
            }
            return false;
        });

        this.drag_begin.connect ( (ctx) => {
            this.dragging = true;
            Gtk.drag_set_icon_gicon (ctx, app.icon, 0, 0);
        });

        this.drag_end.connect ( () => {
            this.dragging = false;
        });

        this.drag_data_get.connect ( (ctx, sel, info, time) => {
            sel.set_uris ({File.new_for_path (desktop_path).get_uri ()});
        });

        app.notify["icon"].connect (() => {
            ((Gtk.Image) image).gicon = app.icon;
        });
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

    private void create_menu () {
        // Display the apps static quicklist items in a popover menu
        if (application.actions == null) {
            try {
                application.init_actions ();
            } catch (KeyFileError e) {
                critical ("%s: %s", desktop_path, e.message);
            }
        }

        menu = new Gtk.Menu ();

        foreach (var action in application.actions) {
            var menuitem = new Gtk.MenuItem.with_mnemonic (action);
            menu.add (menuitem);

            menuitem.activate.connect (() => {
                try {
                    var values = application.actions_map.get (action).split (";;");
                    AppInfo.create_from_commandline (values[0], null, AppInfoCreateFlags.NONE).launch (null, null);
                    app_launched ();
                } catch (Error e) {
                    critical ("%s: %s", desktop_path, e.message);
                }
            });
        }

#if HAS_PLANK
        if (plank_client != null && plank_client.is_connected) {
            if (menu.get_children ().length () > 0)
                menu.add (new Gtk.SeparatorMenuItem ());

            menu.add (get_plank_menuitem ());
        }
#endif

        menu.show_all ();
    }

#if HAS_PLANK
    private Gtk.MenuItem get_plank_menuitem () {
        docked = (desktop_uri in plank_client.get_persistent_applications ());

        var plank_menuitem = new Gtk.MenuItem ();
        plank_menuitem.set_use_underline (true);

        if (docked)
            plank_menuitem.set_label (_("Remove from _Dock"));
        else
            plank_menuitem.set_label (_("Add to _Dock"));

        plank_menuitem.activate.connect (plank_menuitem_activate);

        return plank_menuitem;
    }

    private void plank_menuitem_activate () {
        if (plank_client == null || !plank_client.is_connected)
            return;

        if (docked)
            plank_client.remove_item (desktop_uri);
        else
            plank_client.add_item (desktop_uri);
    }
#endif
}
