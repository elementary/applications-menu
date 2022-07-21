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
    public class CalculatorPluginBackend : Object {
        public static CalculatorPluginBackend get_instance () {
            if (instance == null) {
                instance = new CalculatorPluginBackend ();
            }

            return instance;
        }

        private Regex? regex = null;
        private static CalculatorPluginBackend instance = null;

        construct {
            /* The regex describes a string which *resembles* a mathematical expression. It does not
            check for pairs of parantheses to be used correctly and only whitespace-stripped strings
            will match. Basically it matches strings of the form:
            "paratheses_open* number (operator paratheses_open* number paratheses_close*)+"
            */
            try {
                regex = new Regex (
                    "^\\(*(-?([.,]\\d+)?)([*/+-^]\\(*(-?([.,]\\d+)?)\\)*)+$",
                    RegexCompileFlags.OPTIMIZE
                );
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
                assert_not_reached ();
            }
        }

        public async double get_solution (string query_string, Cancellable cancellable) throws Error {
            string? solution = null;
            string input = query_string.replace (" ", "").replace (",", ".");
            bool matched = regex.match (input);

            if (!matched && input.length > 1) {
                input = input[0 : input.length - 1];
                matched = regex.match (input);
            }

            if (matched) {
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

                bc_input.put_string (input + "\n", cancellable);
                yield bc_input.close_async (Priority.DEFAULT, cancellable);
                solution = yield bc_output.read_line_async (
                    Priority.DEFAULT_IDLE, cancellable
                );  // May return null without error
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
