/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *                         2014 Corentin Noël <tintou@mailoo.org>
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.Switcher : Gtk.Box {
    private Hdy.Carousel _carousel;
    public Hdy.Carousel carousel {
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
        get_children ().foreach ((child) => {
            child.destroy ();
        });

        if (_carousel.n_pages == 1) {
            hide ();
            return;
        }

        for (int i = 0; i < _carousel.get_n_pages (); i++) {
            // In Adwaita, Carousel has a get_nth_page function
            unowned var page = _carousel.get_children ().nth_data (i);

            var button = new PageChecker (_carousel, i);
            button.show ();

            add (button);

            button.clicked.connect (() => {
                _carousel.scroll_to (page);
            });
        }
    }
}
