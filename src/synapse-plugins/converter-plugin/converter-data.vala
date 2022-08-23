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
    const string AREA = "unit of area";
    const string VOLUME = "unit of volume";
    const string TIME = "unit of time";
    const string VELOCITY = "unit of velocity";

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
        {"atto", "a", 1E-18},
        {"zepto", "z", 1E-21},
        {"yocto", "y", 1E-24}
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
        {UnitType.MASS, UnitSystem.SI, "gram", "g|gm|gramme", NC_(MASS, "SI gram"), "1", ""},
        {UnitType.MASS, UnitSystem.SI, "kilogram", "kilo", NC_(MASS, "kilogram"), "1000", "gram"},
        {UnitType.MASS, UnitSystem.SI, "tonne", "t|ton", NC_(MASS, "SI tonne"), "1E6", "gram"},
        {UnitType.MASS, UnitSystem.SI, "metriccarat", "carat|ct", NC_(MASS, "metric carat"), "0.2", "gram"},
        {UnitType.MASS, UnitSystem.SI, "metricgrain", "grain|gr", NC_(MASS, "metric grain"), "1/4", "metriccarat"},

        {UnitType.MASS, UnitSystem.IMPERIAL, "pound", "lb", NC_(MASS, "pound"), "454", "gram"}, // Local root
        {UnitType.MASS, UnitSystem.IMPERIAL, "stone", "st", NC_(MASS, "stone"), "14", "pound"},
        {UnitType.MASS, UnitSystem.IMPERIAL, "ounce", "oz", NC_(MASS, "ounce"), "1/16", "pound"},
        {UnitType.MASS, UnitSystem.IMPERIAL, "dram", "dr", NC_(MASS, "dram"), "1/16", "ounce"},
        {UnitType.MASS, UnitSystem.IMPERIAL, "grain", "gr", NC_(MASS, "grain"), "1/7000", "pound"},
        {UnitType.MASS, UnitSystem.IMPERIAL_UK, "brhundredweight", "hundredweight|cwt", NC_(MASS, "British hundredweight"), "8", "stone"},
        {UnitType.MASS, UnitSystem.IMPERIAL_US, "ushundredweight", "hundredweight|cwt", NC_(MASS, "US hundredweight"), "100", "pound"},
        {UnitType.MASS, UnitSystem.IMPERIAL_US, "ukton", "t|ton|longton", NC_(MASS, "British ton"), "20", "brhundredweight"},
        {UnitType.MASS, UnitSystem.IMPERIAL_UK, "uston", "t|ton|shortton", NC_(MASS, "US ton"), "2000", "pound"},

        // Length units
        {UnitType.DIMENSION, UnitSystem.SI, "meter", "m", NC_(LENGTH, "meter"), "1", ""}, // Fundamental for length, area, volume
        {UnitType.DIMENSION, UnitSystem.SI, "click", "", NC_(LENGTH, "kilometer"), "1000", "meter"},
        {UnitType.DIMENSION, UnitSystem.SI, "astronomicalunit", "au", NC_(LENGTH, "astronomical unit"), "49597870700", "meter"},
        {UnitType.DIMENSION, UnitSystem.SI, "parsec", "pc", NC_(LENGTH, "parsec"), "206264.806247096", "astronomicalunit"}, // wikipedia
        {UnitType.DIMENSION, UnitSystem.SI, "lightyear", "ly", NC_(LENGTH, "light year"), "9.46073047258E15", "meter"}, // Google

        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "inch", "in", NC_(LENGTH, "International inch"), "0.0254", "meter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "yard", "yd", NC_(LENGTH, "International yard"), "3", "foot"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "foot", "ft", NC_(LENGTH, "International foot"), "12", "inch"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "fathom", "", NC_(LENGTH, "fathom"), "6", "foot"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "chain", "ch", NC_(LENGTH, "chain"), "66", "foot"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "surveyorschain", "surveyorchain|ch", NC_(LENGTH, "US surveyors chain"), "66", "surveyfoot"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "surveyfoot", "surveyft|ft", NC_(LENGTH, "US survey foot"), "1200/3937", "meter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "link", "", NC_(LENGTH, "link"), "1/100", "chain"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "furlong", "", NC_(LENGTH, "furlong"), "1/8", "imile"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "imile", "mi|mile", NC_(LENGTH, "mile"), "1760", "yard"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "nmile", "mi|nmi|mile", NC_(LENGTH, "nautical mile"), "1852", "yard"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "cmile", "mi|cmi|mile", NC_(LENGTH, "country mile"), "2200", "yard"},

        // Area units
        {UnitType.DIMENSION, UnitSystem.IMPERIAL, "iacre", "acre", NC_(AREA, "International acre"), "10", "chain2"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usacre", "acre", NC_(AREA, "US acre"), "10", "surveyorschain2"},

        // Volume Units
        {UnitType.DIMENSION, UnitSystem.SI, "liter", "l", NC_(VOLUME, "liter"), "0.001", "meter3"},

        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukgal", "gal|gallon", NC_(VOLUME, "British gallon"), "4.54609", "liter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukqt", "qt|quart", NC_(VOLUME, "British quart"), "1/4", "ukgal"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukpint", "pt|pint", NC_(VOLUME, "British pint"), "1/8", "ukgal"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukfluidounce", "ukflozfloz", NC_(VOLUME, "British fluid ounce"), "1/20", "ukpint"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "gill", "", NC_(VOLUME, "gill"), "1/4", "ukpint"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukcup", "cup", NC_(VOLUME, "British cup"), "1/2", "ukpint"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukteacup", "teacup", NC_(VOLUME, "British teacup"), "1/3", "ukpint"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uktbsp", "tbsp", NC_(VOLUME, "British tablespoon"), "15/1000", "liter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uktsp", "tsp", NC_(VOLUME, "British teaspoon"), "1/3", "uktbsp"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "uksmalltsp", "tsp", NC_(VOLUME, "British small teaspoon"), "1/4", "uktbsp"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_UK, "ukdessertspoon", "dsp", NC_(VOLUME, "British dessertspoon"), "2", "ukteaspoon"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usgal", "gal|gallon", NC_(VOLUME, "US liquid gallon"), "231", "inch3"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usqt", "qt|quart", NC_(VOLUME, "US liquid quart"), "1/4", "usgal"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uspint", "pt|pint", NC_(VOLUME, "US liquid pint"), "1/8", "usgal"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usfluidounce", "usfloz|floz", NC_(VOLUME, "US fluid ounce"), "1/16", "uspint"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uscup", "cup", NC_(VOLUME, "US cup"), "8", "usfluidounce"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uslegalcup", "legalcup|cup", NC_(VOLUME, "US legal cup"), "240/1000", "liter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "metriccup", "cup", NC_(VOLUME, "US metric cup"), "250/1000", "liter"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "ustablespoon", "ustbsp|tbsp", NC_(VOLUME, "US tablespoon"), "1/16", "uscup"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "uslegaltablespoon", "legaltbsp|tbsp", NC_(VOLUME, "US legal tablespoon"), "1/16", "uslegalcup"},
        {UnitType.DIMENSION, UnitSystem.IMPERIAL_US, "usteaspoon", "ustsp|tsp", NC_(VOLUME, "US teaspoon"), "1/3", "ustablespoon"},

        //Time units
        {UnitType.TIME, UnitSystem.SI, "second", "sec|s", NC_(TIME, "second"), "1", ""}, // Fundamental
        {UnitType.TIME, UnitSystem.SI, "minute", "min|m", NC_(TIME, "minute"), "60", "second"},
        {UnitType.TIME, UnitSystem.SI, "hour", "hr|h", NC_(TIME, "hour"), "60", "minute"},
        {UnitType.TIME, UnitSystem.SI, "day", "da|d", NC_(TIME, "day"), "24", "hour"},
        {UnitType.TIME, UnitSystem.SI, "week", "wk", NC_(TIME, "week"), "7", "day"},
        {UnitType.TIME, UnitSystem.SI, "fortnight", "", NC_(TIME, "fortnight"), "14", "day"},
        {UnitType.TIME, UnitSystem.SI, "commonyear", "calendaryear|year|yr", NC_(TIME, "Common year"), "365", "day"},
        {UnitType.TIME, UnitSystem.SI, "leapyear", "yr", NC_(TIME, "leap year"), "366", "day"},
        {UnitType.TIME, UnitSystem.SI, "julianyear", "yr", NC_(TIME, "Julian year"), "365.25", "day"},
        {UnitType.TIME, UnitSystem.SI, "gregorianyear", "yr", NC_(TIME, "Gregorian year"), "366.2425", "day"},
        {UnitType.TIME, UnitSystem.SI, "islamicyear", "yr", NC_(TIME, "Islamic year"), "354", "day"},
        {UnitType.TIME, UnitSystem.SI, "islamicleapyear", "yr", NC_(TIME, "Islamic leap year"), "354", "day"},
        {UnitType.TIME, UnitSystem.SI, "decade", "", NC_(TIME, "decade"), "10", "commonyear"},
        {UnitType.TIME, UnitSystem.SI, "century", "", NC_(TIME, "century"), "100", "commonyear"},
        {UnitType.TIME, UnitSystem.SI, "millenium", "", NC_(TIME, "millenium"), "1000", "commonyear"},

        // Velocity units  - at present treated as separate unit system although could be calculated from components
        {UnitType.VELOCITY, UnitSystem.SI, "meterpersecond", "m/s", NC_(VELOCITY, "meters per second"), "1", ""}, // Fundamental
        {UnitType.VELOCITY, UnitSystem.SI, "lightspeed", "c", NC_(VELOCITY, "speed of light"), "299792458", "meterpersecond"},
        {UnitType.VELOCITY, UnitSystem.SI, "kilometersperhour", "km/h|kph", NC_(VELOCITY, "kilometers per hour"), "1000/3600", "meterpersecond"},
        {UnitType.VELOCITY, UnitSystem.SI, "milesperhour", "m/h|mph", NC_(VELOCITY, "miles per hour"), "1609.34/3600", "meterpersecond"},
        {UnitType.VELOCITY, UnitSystem.SI, "mach", "", NC_(VELOCITY, "Mach (speed of sound)"), "331.46", "meterpersecond"},
    };
}
