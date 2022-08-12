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
            double size = unit.get_factor ();
            for (int i = 0; i < dimension; i++) {
                factor *= prefix.factor;
                factor *= size;
            }

            return factor;
        }
    }

    public struct ResultData {
        double factor;
        string from_description;
        string to_description;
    }

    public class ConverterPluginBackend : Object {
        public static ConverterPluginBackend get_instance () {
            if (instance == null) {
                instance = new ConverterPluginBackend ();
            }

            return instance;
        }

        private Regex? convert_regex = null;
        private static ConverterPluginBackend instance = null;

        construct {
            /* The regex describes a string which *resembles* a unit conversion request in the form
             * <number> <unit> => <unit>.
             * Some restrictions are placed on the form of <unit> (letters maybe followed by a 2 or 3).
             */

            try {
                convert_regex = new Regex (
                    //  Number? - space? - unit1 - dimension1 - space? => - space? - unit2 - dimension
                    """^([[:digit:]]*\.?[[:digit:]]*)\s*([[:alpha:]\/ ]+?)([23]?)\s*[=\-]>\s*([[:alpha:]\/ ]+?)([23]?)$""",
                    RegexCompileFlags.OPTIMIZE
                );
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
            }
        }

        public ResultData[] get_conversion_data (string query_string) {
            ResultData [] results = {};
            if (!(query_string.contains ("=>") || query_string.contains ("->"))) {
                return results;
            }

            var input = query_string.replace (",", ".");
            MatchInfo? match_info = null;
            var matched = convert_regex.match (input, 0, out match_info);
            var num = 1.0;
            UnitMatch[] match_arr1 = {}, match_arr2 = {};
            SIPrefix prefix1 = SIPrefix.get_default (), prefix2 = SIPrefix.get_default ();
            string prefix1_s = "", prefix2_s = "";
            int dimension1 = 1, dimension2 = 1;
            bool use_prefix = false;

            if (matched) {
                // Some abbreviations are ambiguous (used in >1 system) so get all possible matching units
                num = double.parse (match_info.fetch (1));
                num = num == 0 ? 1.0 : num;
                var unit1_s = match_info.fetch (2);
                dimension1 = int.parse (match_info.fetch (3)).clamp (1, 3);
                var unit2_s = match_info.fetch (4);
                dimension2 = int.parse (match_info.fetch (5)).clamp (1, 3);
                get_prefix (unit1_s, out prefix1_s, out prefix1);
                get_prefix (unit2_s, out prefix2_s, out prefix2);
                debug ("num %f, unit1_s %s, unit2_s, %s, prefix1 %s, prefix2 %s, dimension1 %i, dimension2 %i",
                       num, unit1_s, unit2_s, prefix1_s, prefix2_s, dimension1, dimension2
                );

                // Try and find matching unit(s) in data table, indicating whether match includes prefix and/or dimension
                // Match could be with uid, an abbreviation or the description
                // Matches could be in incompatible system - these are rejected later
                foreach (Unit u in UNITS) {
                    if (check_match (u, unit1_s, prefix1_s, dimension1, out use_prefix)) {
                        match_arr1 += UnitMatch () {
                            unit = u,
                            prefix = use_prefix ? prefix1 : SIPrefix.get_default (),
                            dimension = dimension1
                        };
                    }

                    if (check_match (u, unit2_s, prefix2_s, dimension2, out use_prefix)) {
                        match_arr2 += UnitMatch () {
                            unit = u,
                            prefix = use_prefix ? prefix2 : SIPrefix.get_default (),
                            dimension = dimension2
                        };
                    }
                }
            }

            debug ("Expect %u results", match_arr1.length * match_arr2.length);
            if (num != 0.0) {
                // Get conversion data for each combination of input and output units of same type
                foreach (var match1 in match_arr1) {
                    foreach (var match2 in match_arr2) {
                        // Can only square or cube dimension type
                        if (match1.unit.type == match2.unit.type) {
                            if (match1.unit.type == UnitType.DIMENSION ||
                                (match1.dimension == 1 && match2.dimension == 1)) {

                                var result = calculate_conversion_data (num, match1, match2);
                                if (result != null) {
                                    results += result;
                                }
                            }
                        }
                    }
                }
            }

            return results;
        }

        private ResultData? calculate_conversion_data (
            double num,
            UnitMatch match1,
            UnitMatch match2) {

            Unit u1 = match1.unit, u2 = match2.unit;
            int dim1 = match1.dimension, dim2 = match2.dimension;
            double factor1 = match1.factor (), factor2 = match2.factor (); // Takes into account dimension
            string descr1 = match1.description (), descr2 = match2.description ();
            bool same_system = u1.system == u2.system;

            // Find factor for each unit to a common base unit (taking into account dimensionality and prefixes)
            // If both given units are in the same system stop at the base unit for that system, otherwise
            // convert to SI.
            Unit? parent = u1; // Parent should only be null in the case of an error in the data structure.

            debug ("finding root of %s - start dimension %i, start factor %f", u1.uid, dim1, factor1);
            find_root (ref parent, ref dim1, ref factor1, same_system, u1.system);
            if (parent == null) {
                debug ("parent1 is null");
                return null;
            }

            var ultimate_parent1 = parent.uid;
            parent = u2;
            debug ("finding root of %s - start dimension %i, start factor2 %f", u2.uid, dim2, factor2);
            find_root (ref parent, ref dim2, ref factor2, same_system, u2.system);
            // The two given units must be traceable to the same root with the same dimensionality.
            if (parent != null &&
                ultimate_parent1 == parent.uid &&
                factor1 > 0 && factor2 > 0 &&
                dim1 == dim2) {
                var d = num * factor1 / factor2;

                return ResultData () {
                    factor = d,
                    from_description = descr1,
                    to_description = descr2
                };
            }

            return null;
        }

        private void find_root (ref Unit? parent, ref int dim, ref double factor, bool same_system, UnitSystem match_unit_system) {
            while (parent != null &&
                   parent.base_unit != "" &&
                   (!same_system || parent.system == match_unit_system)) {

                int link_dimension = 1;
                var base_uid = parent.base_unit;
                var length = base_uid.length;
                if (length > 1) {
                    char last_c = base_uid.@get (length - 1);
                    if (last_c.isdigit ()) {
                        link_dimension = last_c.digit_value ();
                        base_uid = base_uid[0 : -1];
                        debug ("Link dimension %i, base_uid %s", link_dimension, base_uid);
                    }
                }

                parent = null;
                foreach (Unit u in UNITS) {
                    if (u.uid == base_uid) {
                        parent = u;
                        break;
                    }
                }

                if (parent == null) {
                    critical ("Unable to find parent for %s - data error", base_uid);
                    return;
                }

                var pfactor = parent.get_factor ();
                debug ("Found parent %s parent_dimension %i, parent_factor %f",
                    parent.uid, link_dimension, pfactor
                );

                dim *= link_dimension;
                debug ("Dim now %i", dim);
                for (int i = 0; i < dim; i++) {
                    factor *= pfactor;
                }
            }
        }

        private bool check_match (
            Unit u,
            string unit_s,
            string prefix,
            int dimension,
            out bool use_prefix) {

            use_prefix = false;
            string[] ids = {u.uid};
            string[] abbreviations = u.abbreviations.split ("|");
            foreach (string s in abbreviations) {
                ids += s;
            }

            ids += _(u.description).down ();

            var match = unit_s.down (); //Does not include dimension
            var match_no_prefix = match[prefix.length : match.length];
            debug ("match %s, match no prefix %s", match, match_no_prefix);
            foreach (string id in ids) {
                if (match == id) {
                    debug ("unit less dimension (if any) matches %s", id);
                    return true;
                } else if (match_no_prefix == id) { // If prefix == "" already matched
                    debug ("unit less dimension (if any) and less prefix matches %s", id);
                    use_prefix = true;
                    return true;
                }
            }

            return false;
        }

        private void get_prefix (
            string unit_s,
            out string prefix_s,
            out SIPrefix prefix) {

            prefix = SIPrefix.get_default ();
            prefix_s = "";
            var length = unit_s.length;

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
    }
}
