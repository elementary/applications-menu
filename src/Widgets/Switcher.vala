/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2014 Corentin Noël <tintou@mailoo.org>
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.Switcher : Gtk.Box {
    private Adw.Carousel _carousel;
    public Adw.Carousel carousel {
        set {
            if (_carousel != null) {
                while (get_first_child () != null) {
                    remove (get_first_child ());
                }
            }

            _carousel = value;

            if (_carousel.n_pages == 1) {
                hide ();
                return;
            }

            for (int i = 1; i <= _carousel.n_pages; i++) {
                add_child (carousel.get_nth_page (i));
            }

            _carousel.append.connect_after (add_child);
        }
    }

    construct {
        spacing = 3;
        can_focus = false;
    }

    private void add_child (Gtk.Widget widget) {
        var button = new PageChecker (_carousel, widget);

        append (button);
    }
}
