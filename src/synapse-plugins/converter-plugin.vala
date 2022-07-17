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
        public string size;
    }

    public class ConverterPlugin: Object, Activatable, ItemProvider {
        const Unit[] UNITS = {
            {UnitType.MASS, "kg", "1.0"},
            {UnitType.MASS, "g", "0.001"},
            {UnitType.MASS, "t", "1000"},
            {UnitType.MASS, "lb", "0.454"},
            {UnitType.MASS, "oz", "0.0283495"},
            {UnitType.MASS, "st", "6.35029"},
            {UnitType.LENGTH, "m", "1.0"},
            {UnitType.LENGTH, "cm", "0.01"},
            {UnitType.LENGTH, "mm", "0.001"},
            {UnitType.LENGTH, "km", "1000"},
            {UnitType.LENGTH, "yd", "0.9144"},
            {UnitType.LENGTH, "ft", "0.3048"},
            {UnitType.LENGTH, "in", "0.0254"},
            {UnitType.LENGTH, "mi", "1609.34"},
            {UnitType.VOLUME, "l", "1.0"},
            {UnitType.VOLUME, "ml", "0.001"},
            {UnitType.VOLUME, "cm3", "0.001"},
            {UnitType.VOLUME, "m3", "1000"},
            {UnitType.VOLUME, "gal", "4.54609"}, //Imperial
            {UnitType.VOLUME, "gal", "3.78541"}, //US 
            {UnitType.VOLUME, "qt", "1.13652"}, //Imperial
            {UnitType.VOLUME, "qt", "0.946353"}, //US 
            {UnitType.VOLUME, "pt", "0.568261"}, //Imperial
            {UnitType.VOLUME, "pt", "0.473176"}, //US 
        };
        //TODO Disambiguate some units (or give both results)
        public bool enabled { get; set; default = true; }

        public void activate () { }
        public void deactivate () { }

        private class Result: Synapse.Match, Synapse.TextMatch {
            public int default_relevancy { get; set; default = 0; }

            public string text { get; construct set; default = ""; }
            public Synapse.TextOrigin text_origin { get; set; }

            public Result (double result, string match_string) {
                Object (match_type: MatchType.TEXT,
                        text: "%g".printf (result), //Copied to clipboard
                        title: "%g".printf (result), //Label for search item row
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
                    """^\d*.?\d+[a-zA-Z]{1,3}=>[a-zA-Z]{1,3}$""",
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
            string input = query.query_string.replace (" ", "").replace (",", ".");
            bool matched = convert_regex.match (input);
            double num = 0.0;
            string unit1_size = "", unit2_size = "";
            UnitType unit1_type = UnitType.UNKNOWN, unit2_type = UnitType.UNKNOWN;
            if (matched) {
                var parts = input.split ("=>", 2);
                var num_s = parts[0];
                num_s.canon ("1234567890.", '\0');
                var unit1 = parts[0].slice (num_s.length, parts[0].length);
                var unit2 = parts[1];
                num = double.parse (num_s);
                foreach (Unit u in UNITS) {
                    if (unit1 == u.abbreviation) {
                        unit1_type = u.type;
                        unit1_size = u.size;
                    } else if (unit2 == u.abbreviation) { // Only consider different units
                        unit2_type = u.type;
                        unit2_size = u.size;
                    }
                }

                debug ("num %f unit1 %s unit2 %s, unit1_type %s, unit1_size %s", num, unit1, unit2, unit1_type.to_string (), unit1_size);
            }

            if (num != 0.0 && unit1_type == unit2_type && unit1_size != "") {
                var calc_s = "%f * %s / %s".printf (num, unit1_size, unit2_size);
                debug ("calc s %s", calc_s);
                Pid pid;
                int read_fd, write_fd;
                /* Must include math library to get non-integer results and to access standard math functions */
                string[] argv = {"bc", "-l"};
                string? solution = null;

                try {
                    Process.spawn_async_with_pipes (null, argv, null,
                    SpawnFlags.SEARCH_PATH,
                    null, out pid, out write_fd, out read_fd);
                    UnixInputStream read_stream = new UnixInputStream (read_fd, true);
                    DataInputStream bc_output = new DataInputStream (read_stream);

                    UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
                    DataOutputStream bc_input = new DataOutputStream (write_stream);

                    bc_input.put_string (calc_s + "\n", query.cancellable);
                    yield bc_input.close_async (Priority.DEFAULT, query.cancellable);
                    solution = yield bc_output.read_line_async (Priority.DEFAULT_IDLE, query.cancellable);

                    if (solution != null) {
                        double d = double.parse (solution);
                        Result result = new Result (d, query.query_string);
                        result.description = "%s\n%s".printf (
                            "%s = %g".printf (query.query_string, d),
                            Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Click to copy result to clipboard"))
                        );  // Used for search item tooltip

                        ResultSet results = new ResultSet ();
                        results.add (result, Match.Score.AVERAGE);
                        query.check_cancellable ();

                        return results;
                    }
                } catch (Error err) {
                    if (!query.is_cancelled ()) {
                        warning ("%s", err.message);
                    }
                }
            }

            query.check_cancellable ();
            return null;
        }
    }
}
