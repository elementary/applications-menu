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
    const SIPrefix [] PREFIXES = {
// TRANSLATORS: S.I. Unit Prefix
        {N_("yotta"), "Y", 1E24},
// TRANSLATORS: S.I. Unit Prefix
        {N_("zetta"), "Z", 1E21},
// TRANSLATORS: S.I. Unit Prefix
        {N_("exa"), "E", 1E18},
// TRANSLATORS: S.I. Unit Prefix
        {N_("peta"), "P", 1E15},
// TRANSLATORS: S.I. Unit Prefix
        {N_("tera"), "T", 1E12},
// TRANSLATORS: S.I. Unit Prefix
        {N_("giga"), "G", 1E9},
// TRANSLATORS: S.I. Unit Prefix
        {N_("mega"), "M", 1E6},
// TRANSLATORS: S.I. Unit Prefix
        {N_("kilo"), "k", 1000},
// TRANSLATORS: S.I. Unit Prefix
        {N_("hecto"), "h", 100},
// TRANSLATORS: S.I. Unit Prefix
        {N_("deca"), "da", 10},
// TRANSLATORS: S.I. Unit Prefix
        {N_("deci"), "d", 0.1},
// TRANSLATORS: S.I. Unit Prefix
        {N_("centi"), "c", 0.01},
// TRANSLATORS: S.I. Unit Prefix
        {N_("milli"), "m", 0.001},
// TRANSLATORS: S.I. Unit Prefix
        {N_("micro"), "u", 1E-6},
// TRANSLATORS: S.I. Unit Prefix
        {N_("nano"), "n", 1E-9},
// TRANSLATORS: S.I. Unit Prefix
        {N_("pico"), "p", 1E-12},
// TRANSLATORS: S.I. Unit Prefix
        {N_("femto"), "f", 1E-15},
// TRANSLATORS: S.I. Unit Prefix
        {N_("atto"), "a", 1E-18},
// TRANSLATORS: S.I. Unit Prefix
        {N_("zepto"), "z", 1E-21},
// TRANSLATORS: S.I. Unit Prefix
        {N_("yocto"), "y", 1E-24}
    };

    enum UnitSystem {
        SI,
        IMPERIAL, // Where definition same in US and UK or there is no equivalent in other country and defined in terms of an IMPERIAL measure
        IMPERIAL_UK, // Where definition differs from US or not defined in IMPERIAL measure
        IMPERIAL_US, // Where definition differs from UK or not defined in IMPERIAL measure
    }

    enum UnitType { // UnitTypes are not interconvertible with dimensions
        MASS,
        DIMENSION, // Length, Area, Volume are interconvertible with dimensions (L^1, L^2, L^3)
        TIME,
        VELOCITY
    }

    struct Unit {
        public UnitType type; // Units of different types cannot be interconverted
        public UnitSystem system; // e.g. SI, Imperial
        public string uid; // Unique identifier for the purposes of the converter - not official
        public string abbreviations; // Vala does not support arrays in structs? Use strings concatenated with "|"
        public string description; // Translatable specific description
        public string size_s; // Size as proportion of base unit (or 1 if fundamental)
        public string base_unit; // The uid of the unit this is based on (or "" if fundamental)

        public double get_factor () {
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
        public string prefix;
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
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.SI, "gram", "g|gm|gramme", N_("SI gram"), "1", ""},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.SI, "kilogram", "kilo", N_("kilogram"), "1000", "gram"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.SI, "tonne", "t|ton", N_("SI tonne"), "1E6", "gram"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.SI, "metriccarat", "carat|ct", N_("metric carat"), "0.2", "gram"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.SI, "metricgrain", "grain|gr", N_("metric grain"), "1/4", "metriccarat"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL, "pound", "lb", N_("pound"), "454", "gram"}, // Local root
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL, "stone", "st", N_("stone"), "14", "pound"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL, "ounce", "oz", N_("ounce"), "1/16", "pound"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL, "dram", "dr", N_("dram"), "1/16", "ounce"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL, "grain", "gr", N_("grain"), "1/7000", "pound"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL_UK, "brhundredweight", "hundredweight|cwt", N_("British hundredweight"), "8", "stone"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL_US, "ushundredweight", "hundredweight|cwt", N_("US hundredweight"), "100", "pound"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL_US, "ukton", "t|ton|longton", N_("British ton"), "20", "brhundredweight"},
// TRANSLATORS: Unit of mass
        {UnitType.MASS, UnitSystem.IMPERIAL_UK, "uston", "t|ton|shortton", N_("US ton"), "2000", "pound"},

        // Length units
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.SI, "meter", "m", N_("meter"), "1", ""}, // Fundamental for length, area, volume
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.SI, "click", "", N_("kilometer"), "1000", "meter"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.SI, "astronomicalunit", "au", N_("astronomical unit"), "49597870700", "meter"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.SI, "parsec", "pc", N_("parsec"), "206264.806247096", "astronomicalunit"}, // wikipedia
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.SI, "lightyear", "ly", N_("light year"), "9.46073047258E15", "meter"}, // Google
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "inch", "in", N_("International inch"), "0.0254", "meter"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "yard", "yd", N_("International yard"), "3", "foot"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "foot", "ft", N_("International foot"), "12", "inch"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "fathom", "", N_("fathom"), "6", "foot"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "chain", "ch", N_("chain"), "66", "foot"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "surveyorschain", "surveyorchain|ch", N_("US surveyors chain"), "66", "surveyfoot"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "surveyfoot", "surveyft|ft", N_("US survey foot"), "1200/3937", "meter"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "link", "", N_("link"), "1/100", "chain"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "furlong", "", N_("furlong"), "1/8", "imile"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "imile", "mi|mile", N_("mile"), "1760", "yard"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "nmile", "mi|nmi|mile", N_("nautical mile"), "1852", "yard"},
// TRANSLATORS: Unit of length
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "cmile", "mi|cmi|mile", N_("country mile"), "2200", "yard"},

        // Area units
// TRANSLATORS: Unit of area
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "iacre", "acre", N_("International acre"), "10", "chain2"},
// TRANSLATORS: Unit of area
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usacre", "acre", N_("US acre"), "10", "surveyorschain2"},

        // Volume Units
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.SI, "liter", "l", N_("liter"), "0.001", "meter3"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukgal", "gal|gallon", N_("British gallon"), "4.54609", "liter"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukqt", "qt|quart", N_("British quart"), "1/4", "ukgal"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukpint", "pt|pint", N_("British pint"), "1/8", "ukgal"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukfluidounce", "ukflozfloz", N_("British fluid ounce"), "1/20", "ukpint"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "gill", "", N_("gill"), "1/4", "ukpint"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukcup", "cup", N_("British cup"), "1/2", "ukpint"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukteacup", "teacup", N_("British teacup"), "1/3", "ukpint"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uktbsp", "tbsp", N_("British tablespoon"), "15/1000", "liter"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uktsp", "tsp", N_("British teaspoon"), "1/3", "uktbsp"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uksmalltsp", "tsp", N_("British small teaspoon"), "1/4", "uktbsp"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukdessertspoon", "dsp", N_("British dessertspoon"), "2", "ukteaspoon"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usgal", "gal|gallon", N_("US liquid gallon"), "231", "inch3"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usqt", "qt|quart", N_("US liquid quart"), "1/4", "usgal"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uspint", "pt|pint", N_("US liquid pint"), "1/8", "usgal"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usfluidounce", "usfloz|floz", N_("US fluid ounce"), "1/16", "uspint"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uscup", "cup", N_("US cup"), "8", "usfluidounce"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uslegalcup", "legalcup|cup", N_("US legal cup"), "240/1000", "liter"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "metriccup", "cup", N_("US metric cup"), "250/1000", "liter"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "ustablespoon", "ustbsp|tbsp", N_("US tablespoon"), "1/16", "uscup"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uslegaltablespoon", "legaltbsp|tbsp", N_("US legal tablespoon"), "1/16", "uslegalcup"},
// TRANSLATORS: Unit of volume
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usteaspoon", "ustsp|tsp", N_("US teaspoon"), "1/3", "ustablespoon"},

        //Time units
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "second", "sec|s", N_("second"), "1", ""}, // Fundamental
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "minute", "min|m", N_("minute"), "60", "second"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "hour", "hr|h", N_("hour"), "60", "minute"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "day", "da|d", N_("day"), "24", "hour"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "week", "wk", N_("week"), "7", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "fortnight", "", N_("fortnight"), "14", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "commonyear", "calendaryear|year|yr", N_("Common year"), "365", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "leapyear", "yr", N_("leap year"), "366", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "julianyear", "yr", N_("Julian year"), "365.25", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "gregorianyear", "yr", N_("Gregorian year"), "366.2425", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "islamicyear", "yr", N_("Islamic year"), "354", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "islamicleapyear", "yr", N_("Islamic leap year"), "354", "day"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "decade", "", N_("decade"), "10", "commonyear"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "century", "", N_("century"), "100", "commonyear"},
// TRANSLATORS: Unit of time
        {UnitType.TIME, UnitSystem.SI, "millenium", "", N_("millenium"), "1000", "commonyear"},

        // Velocity units  - at present treated as separate unit system although could be calculated from components
// TRANSLATORS: Unit of velocity
        {UnitType.VELOCITY, UnitSystem.SI, "meterpersecond", "m/s", N_("meters per second"), "1", ""}, // Fundamental
// TRANSLATORS: Unit of velocity
        {UnitType.VELOCITY, UnitSystem.SI, "lightspeed", "c", N_("speed of light"), "299792458", "meterpersecond"},
// TRANSLATORS: Unit of velocity
        {UnitType.VELOCITY, UnitSystem.SI, "kilometersperhour", "km/h|kph", N_("kilometers per hour"), "1000/3600", "meterpersecond"},
// TRANSLATORS: Unit of velocity
        {UnitType.VELOCITY, UnitSystem.SI, "milesperhour", "m/h|mph", N_("miles per hour"), "1609.34/3600", "meterpersecond"},
// TRANSLATORS: Unit of velocity
        {UnitType.VELOCITY, UnitSystem.SI, "mach", "", N_("Mach (speed of sound)"), "331.46", "meterpersecond"},
    };
}
