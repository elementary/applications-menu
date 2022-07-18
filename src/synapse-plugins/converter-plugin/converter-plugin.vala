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
             * <number> <unit> => <unit>.  Some restrictions are placed on the form of <unit> (letters maybe followed by a 2 or 3).
            */
            try {
                convert_regex = new Regex (
                    """^\d*.?\d+[a-zA-Z ]+(2|3)?=>[a-zA-Z ]+(2|3)?$""",
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
            ResultSet results = null;
            string input = query.query_string.replace (" ", "").replace (",", ".").replace ("|", "");
            bool matched = convert_regex.match (input);
            double num = 0.0;
            Unit[] unit1 = {}, unit2 = {};
            UnitType unit1_type = UnitType.UNKNOWN, unit2_type = UnitType.UNKNOWN;
            if (matched) {
                // Parse input into a number and two (known) units
                var parts = input.split ("=>", 2);
                var num_s = parts[0];
                num_s.canon ("1234567890.", '\0');
                var abbrev1 = parts[0].slice (num_s.length, parts[0].length);
                var abbrev2 = parts[1];
                var term1 = abbrev1 + "|";
                var term2 = abbrev2 + "|";
                num = double.parse (num_s);
                foreach (Unit u in UNITS) {
                    if (u.uid == abbrev1 ||
                        u.abbreviation.contains (term1) ||
                        abbrev1 == u.description) {

                        unit1_type = u.type;
                        unit1 += u;
                    } else if (u.uid == abbrev2 ||
                               u.abbreviation.contains (term2) ||
                               abbrev2 == u.description) {

                        unit2_type = u.type;
                        unit2 += u;
                    }
                }

                debug ("num %f unit1 %s unit2 %s, unit1_type %s, expect %u results", num, abbrev1, abbrev2, unit1_type.to_string (), unit1.length * unit2.length);
            }

            if (num != 0.0 && unit1_type == unit2_type && unit1_type != UnitType.UNKNOWN) {
                // Get result(s)
                results = new ResultSet ();
                foreach (var u1 in unit1) {
                    foreach (var u2 in unit2) {
                        // Find factor for each unit to a common base unit
                        bool same_system = u1.system == u2.system; // Whether common base will be in same system or metric
                        var parent = u1;
                        double factor1 = 1.0, factor2 = 1.0;
                        while (parent.base_unit != "" &&
                               (!same_system || u1.system == parent.system)) {
                               debug ("u1 parent id %s, parent size %s", parent.uid, parent.size);
                            factor1 *= get_factor (parent.size);
                            parent = find_parent_unit (parent.base_unit);
                        }

                        var ultimate_parent1 = parent.uid;
                        parent = u2;
                        while (parent.base_unit != "" &&
                               (!same_system || u2.system == parent.system)) {
                               debug ("u2 parent id %s, parent size %s, parent factor %f", parent.uid, parent.size, get_factor (parent.size));
                            factor2 *= get_factor (parent.size);
                            parent = find_parent_unit (parent.base_unit);
                        }

                        if (ultimate_parent1 == parent.uid &&
                            factor1 > 0 && factor2 > 0 ) {
                            debug ("factor1 %f, factor2 %f", factor1, factor2);
                            // var solution = yield get_solution (num, factor1, factor2, query.cancellable);
                            // var d = double.parse (solution);
                            var d = num * factor1 / factor2;

                            var result = new Result (
                                d,
                                ///TRANSLATORS first %s represents unit converted from, second %s represents unit converted to
                                _("%g (%s to %s)").printf (d, _(u1.description), _(u2.description))
                            );
                            result.description = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (
                                _("Click to copy %g to clipboard").printf (d)  //Do not arbitrarily truncate copied number (?)
                            );
                            results.add (result, Match.Score.AVERAGE);
                        }
                    }
                }
            }

            query.check_cancellable ();
            return results;
        }

        private Unit? find_parent_unit (string uid) {
            foreach (Unit u in UNITS) {
                if (u.uid == uid) {
                    return u;
                }
            }

            return null;
        }

        private double get_factor (string size) {
            var parts = size.split ("/");  // Deal with possible fraction
            debug ("get factor for %s, parts length %u", size, parts.length);

            switch (parts.length) {
                case 1:
                    return double.parse (parts[0]);
                case 2:
                    var divisor = double.parse (parts[1]);
                    debug ("divisor part %s, double %f", parts[1], divisor);
                    return divisor != 0.0 ? double.parse (parts[0]) / divisor : 0.0;
                default:
                    return 0.0;
            }
        }
    }
}
