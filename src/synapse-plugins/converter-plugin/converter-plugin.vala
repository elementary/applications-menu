/*
* Copyright (c) 2022 elementary LLC.
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
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

namespace Synapse {
    public class ConverterPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }
        public void activate () { }
        public void deactivate () { }

        private class Result: Synapse.Match, Synapse.TextMatch {
            public int default_relevancy { get; set; default = 0; }
            public string text { get; construct set; default = ""; }
            public Synapse.TextOrigin text_origin { get; set; }

            public Result (double result, string title) {
                Object (match_type: MatchType.TEXT,
                        text: "%g".printf (result), //Copied to clipboard
                        title: title, //Label for search item row
                        icon_name: "accessories-calculator",
                        text_origin: Synapse.TextOrigin.UNKNOWN
                );
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (
                typeof (ConverterPlugin),
                "accessories-converter",
                register_plugin,
                Environment.find_program_in_path ("bc") != null
            );
        }

        static construct {
            register_plugin ();
        }

        public bool handles_query (Query query) {
            return (QueryFlags.ACTIONS in query.query_type);
        }

        public async ResultSet? search (Query query) throws SearchError {
            ResultSet? results = null;
            var result_data = ConverterPluginBackend.get_instance ().get_conversion_data (query.query_string);
            if (result_data.length > 0) {
                results = new ResultSet ();
            }
            foreach (ResultData rd in result_data) {
                var result = new Result (
                    rd.factor,
                    ///TRANSLATORS first %s represents unit converted from, second %s represents unit converted to
                    _("%g (%s to %s)").printf (rd.factor, rd.from_description, rd.to_description)
                );
                result.description = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (
                    _("Click to copy %g to clipboard").printf (rd.factor)
                );

                results.add (result, Match.Score.AVERAGE);
            }
            query.check_cancellable ();
            return results;
        }
    }
}
