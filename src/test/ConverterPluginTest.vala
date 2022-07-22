/*-
 * Copyright (c) 2022 elementary LLC. (https://elementary.io)
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
        // 1st parameter is user input string, second result is expected conversion factor
        // For simplicity, only unambiguous conversions are tested, with only one result.
        // For simplicity, we only test the conversion factor, not the accompanying description
        assert_equal ("1kg=>g", 1000);
        assert_equal ("2m=>km", 0.002);
        assert_equal ("ukgal=>ukpint", 8);
        assert_equal ("usgal=>in3", 231);
        assert_equal ("123456 sec => year", 0.00391476);
        assert_equal ("leapyear => min", 527040);
        assert_throw ("1kg=>foot", 0);
        assert_throw ("1kg=>xxx", 0);

        // Test how many results are expected from a (possibly) ambiguous conversion.
        assert_ambiguous ("gallon=>pint", 4); // Gallon and pint can each be either US or UK size.
        assert_ambiguous ("gal=>in3", 2); // Gallon can be either US or UK size.
        assert_ambiguous ("gal=>liter", 2); // Gallon can be either US or UK size.
        assert_ambiguous ("y=>d", 2); // year may be a leap year.
        assert_ambiguous ("hr=>m", 1); // 'm' could be meter but that would not be a valid conversion.

        return 0;
    }

    static void assert_equal (string input, double result) {
        run_conversion (input, result, true);
    }

    static void assert_throw (string input, double result) {
        run_conversion (input, 0, false);
    }

    static void run_conversion (string input, double result, bool expect_pass) {
        var backend = ConverterPluginBackend.get_instance ();
        stderr.printf ("\n%s = ", input);
        var results = backend.get_conversion_data (input);
        if (results.length == 0) {
            stderr.printf ("No result");
            assert (!expect_pass);
        } else {
            stderr.printf ("Result %g, expected %g", results[0].factor, result);
            var diff = (results[0].factor - result).abs ();
            assert (
                (expect_pass && diff <= 1E-06) ||
                (!expect_pass && diff > 1E-06)
            );
        }
    }

    static void assert_ambiguous (string input, int n_results) {
        var backend = ConverterPluginBackend.get_instance ();
        stderr.printf ("\n%s = ", input);
        var results = backend.get_conversion_data (input);
        assert (results.length == n_results);
    }
}
