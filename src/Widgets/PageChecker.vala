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

public class Slingshot.Widgets.PageChecker : Gtk.ToggleButton {
    public unowned Gtk.Widget referred_widget { get; construct; }

    private static Gtk.CssProvider provider;

    public PageChecker (Gtk.Widget referred_widget) {
        Object (referred_widget: referred_widget);
    }

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/applications-menu/PageChecker.css");
    }

    construct {
        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        style_context.add_class ("switcher");
        style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        add (new Gtk.Image.from_icon_name ("pager-checked-symbolic", Gtk.IconSize.MENU));

        var stack = (Gtk.Stack) referred_widget.parent;
        active = stack.visible_child == referred_widget;

        toggled.connect (() => {
            if (active) {
                stack.visible_child = referred_widget;
            } else {
                active = stack.visible_child == referred_widget;
            }
        });

        stack.notify["visible-child"].connect (() => {
            active = stack.visible_child == referred_widget;
        });

        referred_widget.destroy.connect (() => {
            destroy ();
        });
    }
}
