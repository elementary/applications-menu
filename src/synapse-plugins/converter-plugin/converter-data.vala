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
    const string MASS = "unit of mass";
    const string LENGTH = "unit of length";
    const string VOLUME = "unit of volume";
    const string TIME = "unit of time";

    const SIPrefix [] PREFIXES = {
        {"yotta", "Y", 1E24},
        {"zetta", "Z", 1E21},
        {"exa", "E", 1E18},
        {"peta", "P", 1E15},
        {"tera", "T", 1E12},
        {"giga", "G", 1E9},
        {"mega", "M", 1E6},
        {"kilo", "k", 1000},
        {"hecto", "h", 100},
        {"deca", "da", 10},
        {"deci", "d", 0.1},
        {"centi", "c", 0.01},
        {"milli", "m", 0.001},
        {"micro", "u", 1E-6},
        {"nano", "n", 1E-9},
        {"pico", "p", 1E-12},
        {"femto", "f", 1E-15},
        {"atto", "a", 1E-24},
        {"zepto", "z", 1E-21},
        {"yocto", "y", 1E-24}
    };

    enum UnitSystem {
        SI,
        IMPERIAL,
    }

    struct Unit {
        public UnitSystem system; // e.g. SI, Imperial, Chinese
        public string uid; // Unique identifier for the purposes of the converter - not official
        public string abbreviations; // Vala does not support arrays in structs? Use strings concatenated with "|"
        public string description; // Translatable specific description
        public string size_s; // Size as proportion of base unit (or 1 if fundamental)
        public string base_unit; // The uid of the unit this is based on (or "" if fundamental)

        public double size () {
            var parts = size_s.split ("/");  // Deal with possible fraction

            switch (parts.length) {
                case 1:
                    return double.parse (parts[0]);
                case 2:
                    var divisor = double.parse (parts[1]);
                    return divisor != 0.0 ? double.parse (parts[0]) / divisor : 0.0;
                default:
                    return 0.0;
            }
        }
    }

    struct SIPrefix {
        string prefix;
        string abbrev;
        double factor;

        public static SIPrefix get_default () {
            return {"", "", 1.0};
        }
    }

    // Local units are within the same Unit System
    // There must be no links between different types of unit (e.g. mass to length)
    // All non-SI units must be convertable either directly or indirectly to SI (SI).
    // Local root should be small and local conversion factors should be integers where possible, else simple fractions
    // All other local units must be convertable to the local root either directly or indirectly
    // SI units with standard prefixes are omitted as SI prefixes are handled automatically, however
    // equivalents with a non-standard name are included e.g. "click".
    // All links must use the target unit's uid (possibly followed by a dimension)
    // Abbreviations must be separated by |, without whitespace
    // UIDs never have a prefix or dimension
    // TEMPLATE:         {UnitSystem., "", "", NC_("", ""), "", ""},
    const Unit[] UNITS = {
        // Mass and weight units
        {UnitSystem.SI, "gram", "gm|g", NC_(MASS, "gram"), "1", ""}, // Fundamental
        {UnitSystem.SI, "tonne", "t", NC_(MASS, "SI tonne"), "1E6", "gram"},

        {UnitSystem.IMPERIAL, "pound", "lb", NC_(MASS, "pound"), "454", "gram"}, // Local root
        {UnitSystem.IMPERIAL, "ounce", "oz", NC_(MASS, "ounce"), "1/16", "pound"},
        {UnitSystem.IMPERIAL, "stone", "st", NC_(MASS, "stone"), "14", "pound"},

        // Length units
        {UnitSystem.SI, "meter", "m", NC_(LENGTH, "meter"), "1", ""}, // Fundamental for length, area, volume
        {UnitSystem.SI, "click", "", NC_(LENGTH, "kilometer"), "1000", "meter"},

        {UnitSystem.IMPERIAL, "inch", "in", NC_(LENGTH, "inch"), "0.0254", "meter"},
        {UnitSystem.IMPERIAL, "yard", "yd", NC_(LENGTH, "yard"), "3", "foot"},
        {UnitSystem.IMPERIAL, "foot", "ft", NC_(LENGTH, "foot"), "12", "inch"},
        {UnitSystem.IMPERIAL, "fathom", "", NC_(LENGTH, "fathom"), "6", "foot"},
        {UnitSystem.IMPERIAL, "chain", "ch", NC_(LENGTH, "chain"), "66", "foot"},
        {UnitSystem.IMPERIAL, "link", "", NC_(LENGTH, "link"), "1/100", "chain"},
        {UnitSystem.IMPERIAL, "imile", "mi|mile", NC_(LENGTH, "mile"), "1760", "yard"},
        {UnitSystem.IMPERIAL, "nmile", "mi|nmi|mile", NC_(LENGTH, "nautical mile"), "1852", "yard"},
        {UnitSystem.IMPERIAL, "cmile", "mi|cmi|mile", NC_(LENGTH, "country mile"), "2200", "yard"},

        // Volume Units
        {UnitSystem.SI, "liter", "l", NC_(VOLUME, "liter"), "0.001", "meter3"},

        {UnitSystem.IMPERIAL, "ukgal", "gal|gallon", NC_(VOLUME, "UK gallon"), "4.54609", "liter"},
        {UnitSystem.IMPERIAL, "ukqt", "qt|quart", NC_(VOLUME, "UK quart"), "1/4", "ukgal"},
        {UnitSystem.IMPERIAL, "ukpint", "pt|pint", NC_(VOLUME, "UK pint"), "1/8", "ukgal"},
        {UnitSystem.IMPERIAL, "usgal", "gal|gallon", NC_(VOLUME, "US liquid gallon"), "231", "inch3"},
        {UnitSystem.IMPERIAL, "usqt", "qt|quart", NC_(VOLUME, "US liquid quart"), "1/4", "usgal"},
        {UnitSystem.IMPERIAL, "uspint", "pt|pint", NC_(VOLUME, "US liquid pint"), "1/8", "usgal"},

        //Time units
        {UnitSystem.SI, "second", "sec|s", NC_(TIME, "second"), "1", ""}, // Fundamental
        {UnitSystem.SI, "minute", "min|m", NC_(TIME, "minute"), "60", "second"},
        {UnitSystem.SI, "hour", "hr|h", NC_(TIME, "hour"), "60", "minute"},
        {UnitSystem.SI, "day", "da|d", NC_(TIME, "day"), "24", "hour"},
        {UnitSystem.SI, "week", "wk", NC_(TIME, "week"), "7", "day"},
        {UnitSystem.SI, "fortnight", "", NC_(TIME, "fortnight"), "14", "day"},
        {UnitSystem.SI, "year", "yr|y", NC_(TIME, "year"), "365", "day"},
        {UnitSystem.SI, "leapyear", "yr|y", NC_(TIME, "leap year"), "366", "day"},
        {UnitSystem.SI, "century", "", NC_(TIME, "century"), "100", "year"},
        {UnitSystem.SI, "millenium", "", NC_(TIME, "millenium"), "1000", "year"},
    };
}
