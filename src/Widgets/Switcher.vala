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
                _carousel.notify["n-pages"].disconnect (update_pages);
            }

            _carousel = value;

            update_pages ();
            _carousel.notify["n-pages"].connect (update_pages);
        }
    }

    construct {
        spacing = 3;
        can_focus = false;
    }

    private void update_pages () {
        while (get_first_child () != null) {
            remove (get_first_child ());
        }

        if (_carousel.n_pages == 1) {
            hide ();
            return;
        } else {
            show ();
        }

        for (int i = 0; i < _carousel.get_n_pages (); i++) {
            var button = new PageChecker (_carousel, i);
            append (button);
        }
    }
}
