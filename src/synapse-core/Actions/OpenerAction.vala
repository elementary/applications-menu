/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017 elementary LLC.
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
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

private class Synapse.OpenerAction: Synapse.BaseAction {
    public OpenerAction () {
        Object (title: _("Open"),
                description: _("Open using default application"),
                icon_name: "fileopen", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.GOOD);
    }

    public override void do_execute (Match? match, Match? target = null) {
        unowned UriMatch uri_match = match as UriMatch;

        if (uri_match != null) {
            CommonActions.open_uri (uri_match.uri);
        } else if (file_path.match (match.title)) {
            File f;
            if (match.title.has_prefix ("~")) {
                f = File.new_for_path (
                    Path.build_filename (Environment.get_home_dir (), match.title.substring (1), null)
                );
            } else {
                f = File.new_for_path (match.title);
            }
            CommonActions.open_uri (f.get_uri ());
        } else {
            CommonActions.open_uri (match.title);
        }
    }

    public override bool valid_for_match (Match match) {
        switch (match.match_type) {
            case MatchType.GENERIC_URI:
                return true;
            case MatchType.UNKNOWN:
                return web_uri.match (match.title) || file_path.match (match.title);
            default:
                return false;
        }
    }

    private static Regex web_uri;
    private static Regex file_path;

    static construct {
        try {
            web_uri = new Regex ("^(ftp|http(s)?)://[^.]+\\.[^.]+", RegexCompileFlags.OPTIMIZE);
            file_path = new Regex ("^(/|~/)[^/]+", RegexCompileFlags.OPTIMIZE);
        } catch (Error err) {
            critical (err.message);
        }
    }
}
