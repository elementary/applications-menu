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
    public class CalculatorPluginBackend : Object {
        public static CalculatorPluginBackend get_instance () {
            if (instance == null) {
                instance = new CalculatorPluginBackend ();
            }

            return instance;
        }

        private Regex? express_regex = null;
        private Regex? base_regex = null;
        private static CalculatorPluginBackend instance = null;

        construct {
            try {
                /* The express_regex describes a string which *resembles* a mathematical expression in one of two forms:
                <alphanum><operator><alphanum> e.g. 2 + 2
                <opening parenthesis><number expression><closing parenthesis) e.g. sqrt (0.5)
                */
                express_regex = new Regex (
                    """^.*(\w+[\/\+\-\*\^\%\!\&\|]{1,2}\.?\w+|\(-?\d+.*\))+.*$""",
                    RegexCompileFlags.OPTIMIZE
                );
                /* The base_regex describes a string which starts with a bc number base expression */
                base_regex = new Regex (
                    """^.base=\d+;.*$""",
                    RegexCompileFlags.OPTIMIZE
                );
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
                assert_not_reached ();
            }
        }

        public async double get_solution (string query_string, Cancellable cancellable) throws Error {
            string? solution = null;
            string input = query_string.replace (" ", "").replace (",", ".").replace ("x", "*");
            // Mark characters not allowed in simple bc expressions
            bool matched = true;
            if (base_regex.match (input)) {
                // If a number base is set, the expression may include hexadecimals
                // or be doing a conversion, in which there is no expression
                // so omit regex test and instead limit to certain characters for simple expressions
                input.canon ("1234567890ABCDEF();%^&|!*/-+iobase=.", '@');

            } else {
                // Disallow capitals and test for possible mathematical expression
                input = input.down ();
                matched = express_regex.match (input);
            }

            if (input.contains ("@")) {
               matched = false;
            }

            if (matched) {
                debug ("Matched");
                // 'bc' does not like expressions like -5--5
                input = input.replace ("--", "- -").replace ("+-", "+ -");
                Pid pid;
                int read_fd, write_fd;
                /* Must include math library to get non-integer results and to access standard math functions */
                string[] argv = {"bc", "-l"};

                Process.spawn_async_with_pipes (
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH, null,
                    out pid, out write_fd, out read_fd
                );

                UnixInputStream read_stream = new UnixInputStream (read_fd, true);
                DataInputStream bc_output = new DataInputStream (read_stream);

                UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
                DataOutputStream bc_input = new DataOutputStream (write_stream);
                debug ("bc input string %s\n", input);
                bc_input.put_string (input + "\n", cancellable);
                yield bc_input.close_async (Priority.DEFAULT, cancellable);
                solution = yield bc_output.read_line_async (
                    Priority.DEFAULT_IDLE, cancellable
                );  // May return null without error
            } else {
                debug ("Query %s produced input %s, which did not match regex", query_string, input);
            }

            if (solution == null || solution == "") {
                // Do not usually want additional warning message for invalid input
                // as bc will output error messages for invalid syntax
                // Errors with the stream handling will throw different errors
                throw new IOError.FAILED_HANDLED ("No solution found");
            } else {
                return double.parse (solution);
            }
        }
    }
}
