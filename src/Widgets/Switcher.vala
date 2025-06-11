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
                get_children ().foreach ((child) => {
                    child.destroy ();
                });
            }

            _carousel = value;

            if (_carousel.n_pages == 1) {
                hide ();
                return;
            }

            foreach (unowned var child in _carousel.get_children ()) {
                add_child (child);
            }

            _carousel.add.connect_after (add_child);
        }
    }

    construct {
        spacing = 3;
        can_focus = false;
    }

    private void add_child (Gtk.Widget widget) {
        var button = new PageChecker (_carousel, _carousel.get_children ().index (widget));
        button.show ();

        add (button);

        button.clicked.connect (() => {
            _carousel.scroll_to (widget);
        });

        widget.destroy.connect (() => {
            button.destroy ();
        });
    }
}
