/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2022 elementary LLC. (https://elementary.io)
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

namespace Synapse {
    public class CalculatorPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }
        public void deactivate () { }

        private class Result: Synapse.Match, Synapse.TextMatch {
            public int default_relevancy { get; set; default = 0; }

            public string text { get; construct set; default = ""; }
            public Synapse.TextOrigin text_origin { get; set; }

            public Result (double result, string match_string) {
                Object (match_type: MatchType.TEXT,
                        text: "%f".printf (result), //Copied to clipboard
                        title: "%g".printf (result), //Label for search item row
                        icon_name: "accessories-calculator",
                        text_origin: Synapse.TextOrigin.UNKNOWN
                );
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (
                typeof (CalculatorPlugin),
                _("Calculator"),
                _("Calculate basic expressions."),
                "accessories-calculator",
                register_plugin,
                Environment.find_program_in_path ("bc") != null,
                _("bc is not installed")
            );
        }

        private Regex express_regex;
        private Regex base_regex;

        static construct {
            register_plugin ();
        }

        construct {
            try {
                /* The express_regex describes a string which *resembles* a mathematical expression in one of two forms:
                <alphanum><operator><alphanum> e.g. 2 + 2
                <opening parenthesis><number expression><closing parenthesis) e.g. sqrt (0.5)
                */
                express_regex = new Regex (
                    """^.*(\w+[\/\+\-\*\^\%\!\&\|]{1,2}\.?\w+|\(\d+.*\))+.*$""",
                    RegexCompileFlags.OPTIMIZE
                );
                /* The base_regex describes a string which starts with a bc number base expression */
                base_regex = new Regex (
                    """^.base=\d+;.*$""",
                    RegexCompileFlags.OPTIMIZE
                );
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
            }
        }

        public bool handles_query (Query query) {
            return (QueryFlags.ACTIONS in query.query_type);
        }

        public async ResultSet? search (Query query) throws SearchError {
            ResultSet? results = null;
            try {
                double d = yield CalculatorPluginBackend.get_instance ().get_solution (
                    query.query_string,
                    query.cancellable
                ); // throws error if no valid solution found

                Result result = new Result (d, query.query_string);
                result.description = "%s\n%s".printf (
                    "%s = %g".printf (query.query_string, d),
                    Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Click to copy result to clipboard"))
                );  // Used for search item tooltip

                results = new ResultSet ();

                results.add (result, Match.Score.AVERAGE);
            } catch (Error e) {
                if (!(e is IOError.FAILED_HANDLED)) {
                    warning ("Error processing %s with bc: %s", query.query_string, e.message);
                }
            }

            query.check_cancellable ();
            return results;
        }
    }
}
