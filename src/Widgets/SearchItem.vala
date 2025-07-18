/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019-2025 elementary, Inc. (https://elementary.io)
 *                         2011-2012 Giulio Collura
 */

public class Slingshot.Widgets.SearchItem : Gtk.ListBoxRow {
    private const int ICON_SIZE = 32;

    public signal bool launch_app ();

    public Backend.App app { get; construct; }
    public string search_term { get; construct; }
    public ResultType result_type { public get; construct; }

    public Gtk.Image image { public get; private set; }
    public string? app_uri { get; private set; }

    private Gtk.Label name_label;

    public SearchItem (Backend.App app, string search_term = "", ResultType result_type = ResultType.UNKNOWN) {
        Object (
            app: app,
            search_term: search_term,
            result_type: result_type
        );
    }

    class construct {
        set_css_name ("modelbutton");
    }

    construct {
        string markup;
        if (result_type == ResultType.TEXT) {
            markup = app.match.title;
        } else if (result_type == ResultType.APP_ACTIONS) {
            markup = markup_string_with_search (app.match.title, search_term);
        } else {
            markup = markup_string_with_search (app.name, search_term);
        }

        name_label = new Gtk.Label (markup) {
            ellipsize = END,
            use_markup = true,
            xalign = 0
        };

        var icon = app.icon;
        unowned var theme = Gtk.IconTheme.get_default ();
        if (icon == null || theme.lookup_by_gicon (icon, ICON_SIZE, Gtk.IconLookupFlags.USE_BUILTIN) == null) {
            icon = new ThemedIcon ("application-default-icon");
        }

        image = new Gtk.Image () {
            gicon = icon,
            pixel_size = ICON_SIZE
        };

        tooltip_markup = app.description;

        if (app.match != null && app.match.icon_name.has_prefix (Path.DIR_SEPARATOR_S)) {
            var pixbuf = Backend.SynapseSearch.get_pathicon_for_match (app.match, ICON_SIZE);
            if (pixbuf != null) {
                image.set_from_pixbuf (pixbuf);
            }
        }

        var box = new Gtk.Box (HORIZONTAL, 12) {
            margin_start = 6
        };
        box.add (image);
        box.add (name_label);

        child = box;

        if (result_type != ResultType.APP_ACTIONS) {
            launch_app.connect (app.launch);
        }

        app_uri = null;
        var app_match = app.match as Synapse.ApplicationMatch;
        if (app_match != null && app_match.filename != null) {
            app_uri = File.new_for_path (app_match.filename).get_uri ();
        }
    }

    private static string markup_string_with_search (string text, string pattern) {
        const string MARKUP = "%s";

        if (pattern == "") {
            return MARKUP.printf (Markup.escape_text (text));
        }

        // if no text found, use pattern
        if (text == "") {
            return MARKUP.printf (Markup.escape_text (pattern));
        }

        var matchers = Synapse.Query.get_matchers_for_query (
            pattern,
            0,
            RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
        );

        string? highlighted = null;
        foreach (var matcher in matchers) {
            MatchInfo mi;
            if (matcher.key.match (text, 0, out mi)) {
                int start_pos;
                int end_pos;
                int last_pos = 0;
                int cnt = mi.get_match_count ();
                StringBuilder res = new StringBuilder ();
                for (int i = 1; i < cnt; i++) {
                    mi.fetch_pos (i, out start_pos, out end_pos);
                    warn_if_fail (start_pos >= 0 && end_pos >= 0);
                    res.append (Markup.escape_text (text.substring (last_pos, start_pos - last_pos)));
                    last_pos = end_pos;
                    res.append (Markup.printf_escaped ("<b>%s</b>", mi.fetch (i)));
                    if (i == cnt - 1) {
                        res.append (Markup.escape_text (text.substring (last_pos)));
                    }
                }
                highlighted = res.str;
                break;
            }
        }

        if (highlighted != null) {
            return MARKUP.printf (highlighted);
        } else {
            return MARKUP.printf (Markup.escape_text (text));
        }
    }

    public Gtk.Menu? create_context_menu () {
        if (result_type != APPLICATION) {
            return null;
        }

        var context_menu = new Gtk.Menu.from_model (app.get_menu_model ());
        context_menu.insert_action_group (Backend.App.ACTION_GROUP_PREFIX, app.action_group);

        return context_menu;
    }
}
