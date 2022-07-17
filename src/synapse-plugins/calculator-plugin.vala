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

namespace Synapse {
    public class CalculatorPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }
        public void deactivate () { }

        private class Result: Synapse.Match, Synapse.TextMatch {
            public int default_relevancy { get; set; default = 0; }

            public string text { get; construct set; default = ""; }
            public Synapse.TextOrigin text_origin { get; set; }

            public Result (string result, string match_string) {
                Object (match_type: MatchType.TEXT,
                        text: result, //Copied to clipboard
                        title: result, //Label for search item row
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
                <number><operator><number> e.g. 2 + 2
                <opening parenthesis><number expression><closing parenthesis) e.g. c (0.5)
                */
                express_regex = new Regex (
                    """^.*(\d+[\/\+\-\*\^]{1,2}\.?\d+|\(\d+.*\))+.*$""",
                    RegexCompileFlags.OPTIMIZE
                );
                /* The base_regex describes a string which starts with a bc number base expression */
                base_regex = new Regex (
                    """^.base=\d+;*$""",
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
            string input = query.query_string.replace (" ", "").replace (",", ".");
            // Mark characters not allowed in simple bc expressions
            bool matched = true;
            if (base_regex.match (input)) {
                // If a number base is set, the expression may include hexadecimals
                input.canon ("1234567890ABCDEFscalej();%^&*/-+|!<>iobase=.", '@');
                // express_regex does not cope with hexadecimal expressions so omit test
            } else {
                // Disallow capitals as well
                input = input.down ();
                input.canon ("1234567890scalej();%^&*/-+|!<>=.", '@');
                // Test whether there is at least one arithmetic expression to avoid spurious
                // solutions for some input.
                matched = express_regex.match (input);
            }

            if (input.contains ("@")) {
               matched = false;
            }

            if (matched) {
                // Pass the input into `bc` which will return a solution if it is valid bc syntax.
                Pid pid;
                int read_fd, write_fd;
                /* Must include math library to get non-integer results and to access standard math functions */
                string[] argv = {"bc", "-l"};
                string? solution = null;

                try {
                    Process.spawn_async_with_pipes (null, argv, null,
                    SpawnFlags.SEARCH_PATH,
                    null, out pid, out write_fd, out read_fd);
                    UnixInputStream read_stream = new UnixInputStream (read_fd, true);
                    DataInputStream bc_output = new DataInputStream (read_stream);

                    UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
                    DataOutputStream bc_input = new DataOutputStream (write_stream);

                    bc_input.put_string (input + "\n", query.cancellable);
                    yield bc_input.close_async (Priority.DEFAULT, query.cancellable);
                    solution = yield bc_output.read_line_async (Priority.DEFAULT_IDLE, query.cancellable);

                    if (solution != null) {
                        Result result = new Result (solution, query.query_string);
                        result.description = "%s\n%s".printf (
                            "%s = %s".printf (query.query_string, solution),
                            Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Click to copy result to clipboard"))
                        );  // Used for search item tooltip

                        ResultSet results = new ResultSet ();
                        results.add (result, Match.Score.AVERAGE);
                        query.check_cancellable ();

                        return results;
                    }
                } catch (Error err) {
                    if (!query.is_cancelled ()) {
                        warning ("Calculator error: %s", err.message);
                    }
                }
            }

            query.check_cancellable ();
            return null;
        }
    }
}
