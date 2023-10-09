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

        private static CalculatorPluginBackend instance = null;
        private const string VALID_NUM = "0123456789ABCDEF";
        private const string VALID_OP = ".()%^&|!*/-+";
        private string use_num;

        public async string get_solution (string query_string, Cancellable cancellable) throws Error {
            string? solution = null;
            // Assume base 10 unless indicated otherwise
            use_num = VALID_NUM.slice (0, 10);
            //Replace common math expressions with their bc equivalent
            var input = query_string.replace (" ", "")
                        .replace (",", ".")
                        .replace ("exp(", "e(") // Must do before replacing "x"
                        .replace ("x", "*")
                        .replace ("ln(", "l(")
                        .replace ("sin(", "s(")
                        .replace ("cos(", "c(")
                        .replace ("pi", "(a(1)*4)")
                        .replace ("π", "(a(1)*4)");
            string[] expressions = input.split (";");
            var final_input = "";
            foreach (string expr in expressions) {
                bool is_base_expr;
                if (!allowed_expression (expr, out is_base_expr)) {
                    critical ("Invalid expression %s", expr);
                    throw new IOError.FAILED_HANDLED ("Invalid expression");
                }
                // Put base expressions first for reliable output by 'bc'
                if (is_base_expr) {
                    final_input = string.join (";", expr, final_input);
                } else {
                    final_input = string.join (";", final_input, expr);
                }
            }

            // 'bc' does not like expressions like -5--5
            final_input = final_input.replace ("--", "- -").replace ("+-", "+ -");
            // Construction of final_input can result in double semi-colons. Does not affect
            // result but remove anyway.
            final_input = final_input.replace (";;", ";");
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
            debug ("bc input string %s\n", final_input);
            bc_input.put_string (final_input + "\n", cancellable);
            yield bc_input.close_async (Priority.DEFAULT, cancellable);
            solution = yield bc_output.read_line_async (
                Priority.DEFAULT_IDLE, cancellable
            );  // May return null without error

            if (solution == null || solution == "") {
                // Do not usually want additional warning message for invalid input
                // as bc will output error messages for invalid syntax
                // Errors with the stream handling will throw different errors
                throw new IOError.FAILED_HANDLED ("No solution found");
            } else {
                return solution;
                // return double.parse (solution);
            }
        }


        private bool allowed_expression (string expr, out bool is_base_expr) {
            is_base_expr = false;
            if (expr.length > 6) {
                var suffix_int = int.parse (expr.slice (6, expr.length));
                if (expr.has_prefix ("ibase=") || expr.has_prefix ("obase=")) {
                    var valid = suffix_int > 1 && suffix_int <= 16;
                    if (valid && expr.has_prefix ("ibase=")) {
                        use_num = VALID_NUM.slice (0, suffix_int);
                    }

                    is_base_expr = true;
                    return valid;
                }

                if (expr.has_prefix ("scale=")) {
                    is_base_expr = true;
                    return suffix_int >= 0;
                }
            }

            // Allow operator words to pass
            var test_expr = expr.replace ("sqrt(", "(") // Square root
                            .replace ("s(", "(") // Sine
                            .replace ("c(", "(") // Cosine
                            .replace ("a(", "(") // Arctangent
                            .replace ("l(", "(") // Natural log
                            .replace ("e(", "(") // Natural exponential
                            .replace ("j(", "("); // Bessel function
            test_expr.canon (use_num + VALID_OP, '@');
            return !test_expr.contains ("@");
        }
    }
}
