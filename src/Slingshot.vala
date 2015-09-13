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

public class Slingshot.Slingshot : Wingpanel.Indicator {

    private SlingshotView? view = null;

    private Gtk.Label? indicator_label = null;

    public static Settings settings { get; private set; default = null; }
    public static Gtk.IconTheme icon_theme { get; set; default = null; }

    private DBusService? dbus_service = null;

    public Slingshot () {
        Object (code_name: Wingpanel.Indicator.APP_LAUNCHER,
        display_name: _("Slingshot"),
        description:_("The app-menu indicator"));
    }

    public override Gtk.Widget? get_widget () {
        if (view == null) {
            settings = new Settings ();

            view = new SlingshotView ();

            if (dbus_service == null)
                dbus_service = new DBusService (view);
        }

        return view;
    }

    public override Gtk.Widget get_display_widget () {
        if (indicator_label == null)
            indicator_label = new Gtk.Label ("Applications");

        visible = true;

        return indicator_label;
    }

    public override void opened () {
        if (view != null)
            view.show_slingshot ();
    }

    public override void closed () {
        // TODO: Do we need to do anyhting here?
    }

}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating Slingshot");
    var indicator = new Slingshot.Slingshot ();
    return indicator;
}

