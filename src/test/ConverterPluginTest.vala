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

        validate_data ();
        // 1st parameter is user input string, second result is expected conversion factor
        // For simplicity, only unambiguous conversions are tested, with only one result.
        // For simplicity, we only test the conversion factor, not the accompanying description
        // Non-simple factors are taken from Google

        assert_equal ("1kg=>g", 1000);
        assert_equal ("21.45kg=>g", 21450);
        assert_equal ("2m=>km", 0.002);
        assert_equal ("gram=>metricgrain", 20);
        assert_equal ("uston=>ukton", 0.892857);
        assert_equal ("ukgal=>ukpint", 8);
        assert_equal ("usgal=>in3", 231);
        assert_equal ("usacre=>in2", 6272665);
        assert_equal ("iacre=>foot2", 43560);
        assert_equal ("iacre=>m2", 4046.8564224);
        assert_equal ("123456 sec => commonyear", 0.00391476408);
        assert_equal ("leapyear => min", 527040);
        assert_equal ("mph=>kph", 1.60934);
        assert_equal ("3 US cup => ml", 709.765);
        assert_throw ("1kg=>foot", 0);
        assert_throw ("1kg=>xxx", 0);
        assert_throw ("1..5kg=>g", 0);

        // Test how many results are expected from a (possibly) ambiguous conversion.
        assert_ambiguous ("gallon=>pint", 4); // Gallon and pint can each be either US or UK size.
        assert_ambiguous ("gal=>in3", 2); // Gallon can be either US or UK size.
        assert_ambiguous ("gal=>liter", 2); // Gallon can be either US or UK size.
        assert_ambiguous ("y=>d", 6); // year may also be a leap, Julian, Gregorian, Islamic, Islamic leap.
        assert_ambiguous ("hr=>m", 1); // 'm' could be meter but that would not be a valid conversion.
        assert_ambiguous ("mile=>in", 3); // mile could also be nautical or country mile
        assert_ambiguous ("ton=>ton", 9); // ton could be US, UK or metric

        return 0;
    }

    static void validate_data () {
        int index = 0;
        foreach (Unit u in UNITS) {
            // Give index as well in case of error as uid could be blank.
            stderr.printf ("Unit index %i, uid %s\n", index, u.uid);
            index++;

            double size = u.get_factor ();
            var uid = u.uid;
            bool valid = (uid != "" && u.size_s != "" && u.description != "" &&
                   size > 0.0 && (u.base_unit != "" || size == 1.0));

            if (valid) {
                char last_c = uid.@get (uid.length - 1);
                valid = valid && !last_c.isdigit ();
            }

            assert (valid);
        }
    }

    static void assert_equal (string input, double result) {
        run_conversion (input, result, true);
    }

    static void assert_throw (string input, double result) {
        run_conversion (input, 0, false);
    }

    static void assert_ambiguous (string input, int n_results) {
        var backend = ConverterPluginBackend.get_instance ();
        stderr.printf ("\n%s = ", input);
        var results = backend.get_conversion_data (input);
        assert (results.length == n_results);
    }

    static void run_conversion (string input, double result, bool expect_pass) {
        var backend = ConverterPluginBackend.get_instance ();
        stderr.printf ("\n%s = ", input);
        var results = backend.get_conversion_data (input);
        if (results.length == 0) {
            stderr.printf ("No result");
            assert (!expect_pass);
        } else {

            var diff = (results[0].factor - result).abs () / result;
            stderr.printf ("Result %f, expected %f Diff %g", results[0].factor, result, diff);
            assert (
                (expect_pass && diff <= 1E-05) ||
                (!expect_pass && diff > 1E-05)
            );
        }
    }
}
