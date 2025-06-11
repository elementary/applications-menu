/*
 * Copyright (c) 2017-2019 elementary, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Slingshot.Widgets.PageChecker : Gtk.Button {
    public const double MIN_OPACITY = 0.4;

    public unowned Hdy.Carousel carousel { get; construct; }
    public int index { get; construct; }

    public PageChecker (Hdy.Carousel carousel, int index) {
        Object (
            carousel: carousel,
            index: index
        );
    }

    class construct {
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/applications-menu/PageChecker.css");

        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    construct {
        get_style_context ().add_class ("switcher");

        child = new Gtk.Image.from_icon_name ("pager-checked-symbolic", MENU);

        update_opacity ();

        carousel.notify["position"].connect (() => {
            update_opacity ();
        });
    }

    private void update_opacity () {
        double progress = double.max (1 - (carousel.position - index).abs (), 0);

        opacity = MIN_OPACITY + (1 - MIN_OPACITY) * progress;
    }
}
