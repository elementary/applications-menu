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
    enum UnitType {
        MASS,
        LENGTH,
        VOLUME,
        UNKNOWN
    }

    struct Unit {
        public UnitType type;
        public string abbreviation;
        public string description;
        public string size;
    }

    public class ConverterPlugin: Object, Activatable, ItemProvider {
        const string MASS = "unit of mass";
        const string LENGTH = "unit of length";
        const string VOLUME = "unit of volume";

        const Unit[] UNITS = {
            {UnitType.MASS, "|kg|kilo|", NC_(MASS, "kilogram"), "1.0"},
            {UnitType.MASS, "|g|gm|", NC_(MASS, "gram"), "0.001"},
            {UnitType.MASS, "|t|tonne", NC_(MASS, "metric tonne"), "1000"},
            {UnitType.MASS, "|lb|", NC_(MASS, "pound"), "0.454"},
            {UnitType.MASS, "|oz|", NC_(MASS, "ounce"), "0.0283495"},
            {UnitType.MASS, "|st|", NC_(MASS, "stone"), "6.35029"},
            {UnitType.LENGTH, "|m|", NC_(LENGTH, "meter"), "1.0"},
            {UnitType.LENGTH, "|cm|", NC_(LENGTH, "centimeter"), "0.01"},
            {UnitType.LENGTH, "|mm|", NC_(LENGTH, "millimeter"), "0.001"},
            {UnitType.LENGTH, "|km|", NC_(LENGTH, "kilometer"), "1000"},
            {UnitType.LENGTH, "|yd|", NC_(LENGTH, "yard"), "0.9144"},
            {UnitType.LENGTH, "|ft|", NC_(LENGTH, "foot"), "0.3048"},
            {UnitType.LENGTH, "|in|", NC_(LENGTH, "inch"), "0.0254"},
            {UnitType.LENGTH, "|mi|", NC_(LENGTH, "mile"), "1609.34"},
            {UnitType.VOLUME, "|l|", NC_(VOLUME, "liter"), "1.0"},
            {UnitType.VOLUME, "|ml|", NC_(VOLUME, "milliliter"), "0.001"},
            {UnitType.VOLUME, "|cm3|", NC_(VOLUME, "cubic centimeter"), "0.001"},
            {UnitType.VOLUME, "|m3|", NC_(VOLUME, "cubic meter"), "1000"},
            {UnitType.VOLUME, "|gal|gallon|", NC_(VOLUME, "Imperial gallon"), "4.54609"},
            {UnitType.VOLUME, "|gal|gallon|", NC_(VOLUME, "US liquid gallon"), "3.78541"},
            {UnitType.VOLUME, "|qt|quart|", NC_(VOLUME, "Imperial quart"), "1.13652"},
            {UnitType.VOLUME, "|qt|quart|", NC_(VOLUME, "US liquid quart"), "0.946353"},
            {UnitType.VOLUME, "|pt|pint|", NC_(VOLUME, "Imperial pint"), "0.568261"},
            {UnitType.VOLUME, "|pt|pint|", NC_(VOLUME, "US liquid pint"), "0.473176"},
        };

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
            /* The regex describes a string which *resembles* a mathematical expression. It does not
            check for pairs of parantheses to be used correctly and only whitespace-stripped strings
            will match. Basically it matches strings of the form:
            "paratheses_open* number (operator paratheses_open* number paratheses_close*)+"
            */
            try {
                convert_regex = new Regex (
                    """^\d*.?\d+[a-zA-Z]+(2|3)?=>[a-zA-Z]+(2|3)?$""",
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
                var parts = input.split ("=>", 2);
                var num_s = parts[0];
                num_s.canon ("1234567890.", '\0');
                var abbrev1 = parts[0].slice (num_s.length, parts[0].length);
                var abbrev2 = parts[1];
                var term1 = "|" + abbrev1 + "|";
                var term2 = "|" + abbrev2 + "|";
                num = double.parse (num_s);
                foreach (Unit u in UNITS) {
                    if (u.abbreviation.contains (term1) ||
                        abbrev1 == u.description) {

                        unit1_type = u.type;
                        unit1 += u;
                    } else if (u.abbreviation.contains (term2) ||
                               abbrev2 == u.description) {

                        unit2_type = u.type;
                        unit2 += u;
                    }
                }

                debug ("num %f unit1 %s unit2 %s, unit1_type %s, expect %u results", num, abbrev1, abbrev2, unit1_type.to_string (), unit1.length * unit2.length);
            }

            if (num != 0.0 && unit1_type == unit2_type && unit1_type != UnitType.UNKNOWN) {
                results = new ResultSet ();
                foreach (var u1 in unit1) {
                    foreach (var u2 in unit2) {
                        var solution = yield get_solution (num, u1.size, u2.size, query.cancellable);
                        var d = double.parse (solution);
                        var result = new Result (
                            d,
                            ///TRANSLATORS first %s represents unit converted from, second %s represents unit converted to
                            _("%g (%s to %s)").printf (d, _(u1.description), _(u2.description))
                        );
                        result.description = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Click to copy %g to clipboard").printf (d)); //Do not arbitrarily truncate copied number (?)
                        results.add (result, Match.Score.AVERAGE);
                    }
                }
            }

            query.check_cancellable ();
            return results;
        }

        private async string? get_solution (double num, string size1, string size2, Cancellable cancellable) {
            var calc_s = "%f * %s / %s".printf (num, size1, size2);
            debug ("calc s %s", calc_s);
            Pid pid;
            int read_fd, write_fd;
            /* Must include math library to get non-integer results and to access standard math functions */
            string[] argv = {"bc", "-l"};

            try {
                Process.spawn_async_with_pipes (null, argv, null,
                SpawnFlags.SEARCH_PATH,
                null, out pid, out write_fd, out read_fd);
                UnixInputStream read_stream = new UnixInputStream (read_fd, true);
                DataInputStream bc_output = new DataInputStream (read_stream);

                UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
                DataOutputStream bc_input = new DataOutputStream (write_stream);

                bc_input.put_string (calc_s + "\n", cancellable);
                yield bc_input.close_async (Priority.DEFAULT, cancellable);
                return yield bc_output.read_line_async (Priority.DEFAULT_IDLE, cancellable);
            } catch (Error err) {
                if (!cancellable.is_cancelled ()) {
                    warning ("%s", err.message);
                }
            }

            return null;
        }
    }
}
