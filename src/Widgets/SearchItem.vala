/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *           2011-2012 Giulio Collura
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Slingshot.Widgets.SearchItem : Gtk.ListBoxRow {
    public enum ResultType {
        UNKNOWN = 0,
        TEXT,
        APPLICATION,
        GENERIC_URI,
        ACTION,
        SEARCH,
        CONTACT,
        INTERNET,
        SETTINGS,
        APP_ACTIONS,
        LINK;

        public string to_string () {
            string str;
            switch (this) {
                case TEXT:
                    str = _("Text");
                    break;
                case APPLICATION:
                    str = _("Applications");
                    break;
                case GENERIC_URI:
                    str = _("Files");
                    break;
                case LINK:
                case ACTION:
                    str = _("Actions");
                    break;
                case SEARCH:
                    str = _("Search");
                    break;
                case CONTACT:
                    str = _("Contacts");
                    break;
                case INTERNET:
                    str = _("Internet");
                    break;
                case SETTINGS:
                    str = _("Settings");
                    break;
                case APP_ACTIONS:
                    str = _("Application Actions");
                    break;
                default:
                    str = _("Other");
                    break;
            }

            return str;
        }
    }

    private const int ICON_SIZE = 32;

    public signal bool launch_app ();

    public Backend.App app { get; construct; }
    public string search_term { get; construct; }
    public ResultType result_type { public get; construct; }

    public Gtk.Image icon { public get; private set; }
    public string? app_uri { get; private set; }

    private Gtk.Label name_label;
    private Cancellable? cancellable = null;

    public SearchItem (Backend.App app, string search_term = "", ResultType result_type = ResultType.UNKNOWN) {
        Object (
            app: app,
            search_term: search_term,
            result_type: result_type
        );
    }

    construct {
        string markup;
        if (result_type == SearchItem.ResultType.TEXT) {
            markup = app.match.title;
        } else if (result_type == SearchItem.ResultType.APP_ACTIONS) {
            markup = Backend.SynapseSearch.markup_string_with_search (app.match.title, search_term);
        } else {
            markup = Backend.SynapseSearch.markup_string_with_search (app.name, search_term);
        }

        name_label = new Gtk.Label (markup);
        name_label.set_ellipsize (Pango.EllipsizeMode.END);
        name_label.use_markup = true;
        name_label.xalign = 0;

        icon = new Gtk.Image ();
        icon.gicon = app.icon;
        icon.pixel_size = ICON_SIZE;

        tooltip_text = app.description;

        // load a favicon if we're an internet page
        var uri_match = app.match as Synapse.UriMatch;
        if (uri_match != null && uri_match.uri.has_prefix ("http")) {
            cancellable = new Cancellable ();
            Backend.SynapseSearch.get_favicon_for_match.begin (uri_match, ICON_SIZE, cancellable, (obj, res) => {
                var pixbuf = Backend.SynapseSearch.get_favicon_for_match.end (res);
                if (pixbuf != null) {
                    icon.set_from_pixbuf (pixbuf);
                }
            });
        } else if (app.match != null && app.match.icon_name.has_prefix (Path.DIR_SEPARATOR_S)) {
            var pixbuf = Backend.SynapseSearch.get_pathicon_for_match (app.match, ICON_SIZE);
            if (pixbuf != null) {
                icon.set_from_pixbuf (pixbuf);
            }
        }

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (icon);
        grid.add (name_label);
        grid.margin = 6;
        grid.margin_start = 18;

        add (grid);

        if (result_type != SearchItem.ResultType.APP_ACTIONS) {
            launch_app.connect (app.launch);
        }

        app_uri = null;
        var app_match = app.match as Synapse.ApplicationMatch;
        if (app_match != null) {
            app_uri = File.new_for_path (app_match.filename).get_uri ();
        }
    }

    public override void destroy () {
        base.destroy ();
        if (cancellable != null)
            cancellable.cancel ();
    }
}
