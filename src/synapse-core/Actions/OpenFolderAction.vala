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

private class Synapse.OpenFolderAction: Synapse.BaseAction {
    public OpenFolderAction () {
        Object (title: _("Open folder"),
                description: _("Open folder containing this file"),
                icon_name: "folder-open", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.AVERAGE);
    }

    public override void do_execute (Match? match, Match? target = null) {
        unowned UriMatch uri_match = match as UriMatch;
        return_if_fail (uri_match != null);
        var f = File.new_for_uri (uri_match.uri);
        f = f.get_parent ();
        try {
            var app_info = f.query_default_handler (null);
            List<File> files = new List<File> ();
            files.prepend (f);
            var display = Gdk.Display.get_default ();
            app_info.launch (files, display.get_app_launch_context ());
        } catch (Error err) {
            critical (err.message);
        }
    }

    public override bool valid_for_match (Match match) {
        if (match.match_type != MatchType.GENERIC_URI) {
            return false;
        }
        unowned UriMatch uri_match = match as UriMatch;
        var f = File.new_for_uri (uri_match.uri);
        var parent = f.get_parent ();

        return parent != null && f.is_native ();
    }
}
