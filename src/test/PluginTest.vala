/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

class Synapse.CalculatorPluginTest : Object {
    public static int main (string[] args) {
        // Tests taken from // https://github.com/elementary/calculator/
        // Some calculations are currently known to be unhandled in the plugin that are handled in the calculator app
        // These are asserted to fail here
        // In some cases the precision of the result expected is less.
        assert_equal ("0+0", 0);
        assert_equal ("2+2", 4);
        assert_equal ("4.23 + 1.11", 5.34);
        assert_equal (".13 + .51", 0.64);
        assert_equal ("25.123 - 234.2", -209.077); // https://github.com/elementary/calculator/issues/48

        assert_equal ("1*1", 1);
        assert_equal ("11 * 1.1", 12.1);
        assert_equal ("5 x -1", -5.0); // https://github.com/elementary/calculator/issues/37
        assert_equal ("5 x -2", -10); // https://github.com/elementary/calculator/issues/37
        assert_equal ("-5 * -1", 5); // https://github.com/elementary/calculator/issues/37
        assert_equal ("-5 * -2", 10); // https://github.com/elementary/calculator/issues/37
        assert_equal ("-1 / -1", 1); // https://github.com/elementary/calculator/pull/38/files
        assert_equal ("89 * 56", 4984); // https://github.com/elementary/calculator/issues/48
        assert_equal ("-1 / (-1)", 1); // https://github.com/elementary/calculator/issues/59
        assert_equal ("144 / 15", 9.6);
        assert_equal ("1440 / 15", 96);
        assert_equal ("14400 / 12", 1200); // https://github.com/elementary/calculator/issues/48
        assert_equal ("144000 / 12", 12000); // https://github.com/elementary/calculator/issues/48

        assert_equal ("2^5", 32);
        assert_throw ("3456^0.5 - sqrt(3456)", 0);
        assert_throw ("3456^-0.5 * sqrt(3456)", 1);
        assert_throw ("723 mod 5", 3);
        assert_throw ("2%", 0.02);
        assert_throw ("(2 + 2)% - 0.04", 0); // https://github.com/elementary/calculator/issues/59

        assert_throw ("14E-2", 0.14); // https://github.com/elementary/calculator/issues/16
        assert_throw ("1.1E2 - 1E1", 100);

        assert_throw ("pi", 3.141592654);
        assert_throw ("pi - 2", 1.141592654); // https://github.com/elementary/calculator/issues/59
        assert_throw ("(π)", 3.141592654);
        assert_throw ("e", 2.718281828);

        assert_throw ("sqrt(144)", 12);
        assert_throw ("√423", 20.566963801);
        assert_throw ("sin(pi ÷ 2)", 1);
        assert_throw ("sin(-pi)", 0); // https://github.com/elementary/calculator/issues/1
        assert_throw ("cos(90)", -0.448073616);
        assert_throw ("sinh(2)", 3.626860408);
        assert_throw ("cosh(2)", 3.762195691);

        assert_equal ("2 + 2 * 2.2", 6.4);
        assert_equal ("(2 + 2) * 2.2", 8.8);
        assert_throw ("sin(0.123)^2 + cos(0.123)^2", 1);
        assert_throw ("tan(0.245) - sin(0.245) / cos(0.245)", 0);
        assert_throw ("asin(0.532) + acos(0.532)", 1.570796327);
        assert_throw ("exp(ln(2.2))", 2.2);
        assert_throw ("atan(1)", 0.785398163);
        assert_throw ("sqrt(5^2 - 4^2)", 3);
        assert_throw ("sqrt(423) + (3.23 * 8.56) - 1E2", -51.784236199);
        assert_throw ("sqrt(-1 + 423 + 1) + (3.23 * 8.56) - sin(90 + 0.2)", 47.428606036);
        assert_throw ("e^5.25 / exp(5.25)", 1);
        assert_throw ("10^(log(2.2))", 2.2);
        assert_equal ("3.141592654*3.141592654", 9.869604); // Lower precision
        assert_throw ("10 + 5 - 10%", 14.9); // https://github.com/elementary/calculator/issues/44
        assert_throw ("10 - 10% + 5", 14.9); // https://github.com/elementary/calculator/issues/44

        assert_equal ("25,123 - 234,2", -209.077); // Commas always treated as decimal point
        assert_throw ("25.000,123 - 234000,2", -209.000077); // Commas always treated as decimal point valid - so in
        assert_equal ("-.25^2", 0.0625); //https://github.com/elementary/calculator/issues/153
        assert_equal ("-.25*.25", -0.0625); //https://github.com/elementary/calculator/issues/153
        assert_equal ("-.2 - -.2", 0);
        assert_equal ("-.2+-.2", -0.4);
        return 0;
    }

    static void assert_equal (string input, double result) {
        run_calculation (input, result, true);
    }

    static void assert_throw (string input, double result) {
        run_calculation (input, 0, false);
    }

    static void run_calculation (string input, double result, bool expect_pass) {
        var loop = new MainLoop ();
            double d = 0.0;
            var cancellable = new Cancellable ();
            var backend = CalculatorPluginBackend.get_instance ();
            stderr.printf ("\n%s = ", input);
            backend.get_solution.begin (
                input,
                cancellable,
                (obj, res) => {
                    try {
                        d = backend.get_solution.end (res);
                        var diff = (d - result).abs ();
                        // Output only appears when assert fails
                        stderr.printf (
                            "Result returned %f, expect result %f, diff %g expected pass %s assert %s\n",
                             d, result,
                             (d - result).abs (),
                             expect_pass.to_string (),
                             ((expect_pass && diff <= 1E-06)).to_string ()
                        );
                        assert (
                            (expect_pass && diff <= 1E-06) ||
                            (!expect_pass && diff > 1E-06)
                        );
                    } catch (Error e) {
                        stderr.printf ("Error thrown: %s ", e.message);
                        assert (!expect_pass);
                    } finally {
                        stderr.printf ("Result returned = %s\n", d.to_string ());
                        loop.quit ();
                    }
                }
            ); // throws error if no valid solution found

        loop.run ();
    }
}
