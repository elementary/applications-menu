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

        struct UnitMatch {
            Unit unit; // Unit that matches in UNITS
            SIPrefix prefix; // Prefix taken into account
            int dimension; // Dimension taken into account

            public string description () {
                string dim = "";
                if (dimension == 2) {
                    dim = _("squared");
                } else if (dimension == 3) {
                    dim = _("cubed");
                }

                /// TRANSLATORS First %s SI prefix, Second %s unit name, Third %s dimension (blank, squared or cubed);
                return _("%s%s %s").printf (prefix.prefix, unit.description, dim);
            }

            public double factor () { // Taking into account size, prefix and dimension
                double factor = 1.0;
                double size = unit.size ();
                for (int i = 0; i < dimension; i++) {
                    factor *= prefix.factor;
                    factor *= size;
                }

                return factor;
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (
                typeof (ConverterPlugin),
                _("Converter"),
                _("Convert between units."),
                "accessories-converter",
                register_plugin,
                Environment.find_program_in_path ("bc") != null,
                _("bc is not installed")
            );
        }

        static construct {
            register_plugin ();
        }

        private Regex convert_regex;

        construct {
            /* The regex describes a string which *resembles* a unit conversion request in the form
             * <number> <unit> => <unit>.
             * Some restrictions are placed on the form of <unit> (letters maybe followed by a 2 or 3).
             */
            try {
                convert_regex = new Regex (
                    """^\d*.?\d*[a-zA-Z ]+(2|3)?=>[a-zA-Z ]+(2|3)?$""",
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
            var input = query.query_string.replace (" ", "").replace (",", ".").replace ("|", "");
            var matched = convert_regex.match (input);
            var num = 1.0;
            UnitMatch[] match_arr1 = {}, match_arr2 = {};
            SIPrefix prefix1 = SIPrefix.get_default (), prefix2 = SIPrefix.get_default ();
            string prefix1_s = "", prefix2_s = "";
            int dimension1 = 1, dimension2 = 1;
            bool use_prefix = false, use_dimension = false;

            if (matched) {
                // Parse input into a number and two unit match arrays
                // Some abbreviations are ambiguous (used in >1 system) so get all possible units
                var parts = input.split ("=>", 2);

                var num_s = parts[0];
                num_s.canon ("1234567890.", '\0');
                if (num_s.length > 0) { // If leading number omitted, assume it to be 1.0
                    num = double.parse (num_s);
                }

                string unit1_s = parts[0].slice (num_s.length, parts[0].length);
                string unit2_s = parts[1];

                get_prefix_and_dimension (unit1_s, out prefix1_s, out prefix1, out dimension1);
                get_prefix_and_dimension (unit2_s, out prefix2_s, out prefix2, out dimension2);
                debug ("unit1_s %s, unit2_s, %s, prefix1 %s, prefix2 %s",
                       unit1_s, unit2_s, prefix1_s, prefix2_s
                );

                foreach (Unit u in UNITS) {
                    if (check_match (u, unit1_s, prefix1_s, dimension1, out use_prefix, out use_dimension)) {
                        match_arr1 += UnitMatch () {
                            unit = u,
                            prefix = use_prefix ? prefix1 : SIPrefix.get_default (),
                            dimension = use_dimension ? dimension1 : 1
                        };
                    }

                    if (check_match (u, unit2_s, prefix2_s, dimension2, out use_prefix, out use_dimension)) {
                        match_arr2 += UnitMatch () {
                            unit = u,
                            prefix = use_prefix ? prefix2 : SIPrefix.get_default (),
                            dimension = use_dimension ? dimension2 : 1
                        };
                    }
                }
            }

            debug ("Expect %u results", match_arr1.length * match_arr2.length);
            if (num != 0.0) {
                // Get results for each combination of input and output units
                results = new ResultSet ();
                foreach (var match1 in match_arr1) {
                    foreach (var match2 in match_arr2) {
                        var result = calculate_conversion_results (num, match1, match2);
                        if (result != null) {
                            results.add (result, Match.Score.AVERAGE);
                        }
                    }
                }
            }

            query.check_cancellable ();
            return results;
        }

        private Result? calculate_conversion_results (double num, UnitMatch match1, UnitMatch match2) {
            Result? result = null;
            Unit u1 = match1.unit, u2 = match2.unit;
            int dim1 = match1.dimension, dim2 = match2.dimension;
            double factor1 = match1.factor (), factor2 = match2.factor (); // Takes into account dimension
            string descr1 = match1.description (), descr2 = match2.description ();
            // bool same_system = u1.system == u2.system;

            warning ("Unit1 - %s: dimension %i, factor %g", descr1, dim1, factor1);
            warning ("Unit2 - %s: dimension %i, factor %g", descr2, dim2, factor2);

            // Find factor for each unit to a common base unit (taking into account dimensionality and prefixes)
            // If both given units are in the same system stop at the base unit for that system, otherwise
            // convert to SI.
            Unit? parent = u1; // Parent should only be null in the case of an error in the data structure.
            int parent_dimension = 1;
            while (parent != null &&
                   parent.base_unit != "") {

                parent = find_parent_unit (parent.base_unit, out parent_dimension);
                debug ("parent1 %s parent_dimension1 %i, parent_factor1 %f",
                       parent.uid, parent_dimension, parent.size ()
                );
                for (int i = 0; i < parent_dimension; i++) {
                    factor1 *= parent.size ();
                }

                dim1 *= parent_dimension;
            }

            if (parent == null) {
                return null;
            }

            parent_dimension = 1;
            var ultimate_parent1 = parent.uid;
            parent = u2;
            while (parent != null && parent.base_unit != "") {

                parent = find_parent_unit (parent.base_unit, out parent_dimension);
                debug ("parent2 %s parent_dimension2 %i, parent_factor2 %f",
                        parent.uid, parent_dimension, parent.size ()
                );
                 for (int i = 0; i < parent_dimension; i++) {
                     factor2 *= parent.size ();
                 }

                 dim2 *= parent_dimension;
            }

            // The two given units must be traceable to the same root with the same dimensionality.
            if (parent != null &&
                ultimate_parent1 == parent.uid &&
                factor1 > 0 && factor2 > 0 &&
                dim1 == dim2) {

                warning ("VALID CONVERSION");
                var d = num * factor1 / factor2;
                result = new Result (
                    d,
                    ///TRANSLATORS first %s represents unit converted from, second %s represents unit converted to
                    _("%g (%s to %s)").printf (d, descr1, descr2)
                );
                result.description = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (
                    _("Click to copy %g to clipboard").printf (d)
                );
            } else {
                warning ("INVALID CONVERSION. Parent null %s, no common root %s, dim1 %i, dim2 %i",
                (parent == null).to_string (),
                parent != null ? (parent.uid != ultimate_parent1).to_string () : "",
                dim1,
                dim2 );
            }

            return result;
        }

        private bool check_match (
            Unit u,
            string unit_s,
            string prefix,
            int dimension,
            out bool use_prefix,
            out bool use_dimension) {

            use_prefix = false;
            use_dimension = false;
            string[] ids = {u.uid};
            string[] abbreviations = u.abbreviations.split ("|");
            foreach (string s in abbreviations) {
                ids += s;
            }

            ids += _(u.description);

            var match = unit_s;
            // Test match whole unit
            foreach (string id in ids) {
                if (match == id) {
                    return true;
                }
            }

            if (prefix != "") {
                //Test match without prefix
                match = unit_s[prefix.length : unit_s.length];
                foreach (string id in ids) {
                    if (match == id) {
                        use_prefix = true;
                        return true;
                    }
                }
            }

            if (dimension > 1) {
                //Test match without dimension
                match = unit_s[0 : -1];
                foreach (string id in ids) {
                    if (match == id) {
                        use_dimension = true;
                        return true;
                    }
                }
            }

            if (prefix != "" && dimension > 1) {
                //Test match without either prefix or dimension
                match = unit_s[prefix.length : -1];
                foreach (string id in ids) {
                    if (match == id) {
                        use_prefix = use_dimension = true;
                        return true;
                    }
                }
            }

            return false;
        }

        private void get_prefix_and_dimension (
            string unit_s,
            out string prefix_s,
            out SIPrefix prefix,
            out int dimension) {

            prefix = SIPrefix.get_default ();
            prefix_s = "";
            dimension = 1;
            var length = unit_s.length;
            if (length > 1) {
                char last_c = unit_s.@get (length - 1);
                if (last_c.isdigit ()) {
                    dimension = last_c.digit_value ();
                    length --;
                }
            }

            foreach (Synapse.SIPrefix p in PREFIXES) {
                if (length > p.prefix.length && unit_s.has_prefix (p.prefix)) {
                    prefix_s = p.prefix;
                    prefix = p;
                    break;
                } else if (length > p.abbrev.length && unit_s.has_prefix (p.abbrev)) {
                    prefix_s = p.abbrev;
                    prefix = p;
                    break;
                }
            }
        }

        private Unit? find_parent_unit (string uid, out int dimension) {
            dimension = 1;
            var base_uid = uid;
            var length = uid.length;
            if (length > 1) {
                char last_c = uid.@get (length - 1);
                if (last_c.isdigit ()) {
                    dimension = last_c.digit_value ();
                    base_uid = uid[0 : -1];
                }
            }

            foreach (Unit u in UNITS) {
                if (u.uid == base_uid) {
                    return u;
                }
            }

            critical ("Unable to find parent for %s - data error", uid);
            return null;
        }
    }
}
