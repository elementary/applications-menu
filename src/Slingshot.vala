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

    private SlingshotView view = null;
    public static bool silent = false;
    public static bool command_mode = false;

    private Gtk.Label dynamic_icon;
    
    public static Settings settings { get; private set; default = null; }
    //public static CssProvider style_provider { get; private set; default = null; }
    public static Gtk.IconTheme icon_theme { get; set; default = null; }
    private DBusService? dbus_service = null;

    public Slingshot () {
		Object (code_name: Wingpanel.Indicator.SESSION,
		display_name: _("Slingshot"),
		description:_("The app-menu indicator"));
	}

    public override Gtk.Widget get_widget () {
		if (view == null) {
            settings = new Settings ();
            
            var view = new SlingshotView ();
          
            if (dbus_service == null)
                dbus_service = new DBusService (view);
		}
		
        view.show_slingshot ();
		return view;
	}    

    public override Gtk.Widget get_display_widget () {
		if (dynamic_icon == null)
			dynamic_icon = new Gtk.Label ("Applications");

		return dynamic_icon;
	}
	
	public override void opened () {

	}

	public override void closed () {

	}
	
}

public Wingpanel.Indicator get_indicator (Module module) {
	debug ("Activating Session Indicator");
	var indicator = new Slingshot.Slingshot ();
	return indicator;
}

