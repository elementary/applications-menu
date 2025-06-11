/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2017-2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Slingshot.Widgets.PageChecker : Gtk.Button {
    public const double MIN_OPACITY = 0.4;

    public unowned Adw.Carousel carousel { get; construct; }
    public int index { get; construct; }

    public PageChecker (Adw.Carousel carousel, int index) {
        Object (
            carousel: carousel,
            index: index
        );
    }

    class construct {
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/applications-menu/PageChecker.css");

        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    construct {
        add_css_class ("switcher");

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
