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
        TIME,
        UNKNOWN
    }

    enum UnitSystem {
        METRIC,
        UK,
        US,
    }

    struct Unit {
        public UnitType type;
        public UnitSystem system;
        public string abbreviation;
        public string description;
        public string size;
        public string base_unit;
    }

    const string MASS = "unit of mass";
    const string LENGTH = "unit of length";
    const string VOLUME = "unit of volume";

    const Unit[] UNITS = {
        {UnitType.MASS, UnitSystem.METRIC, "|kg|kilo|", NC_(MASS, "kilogram"), "1", ""},
        {UnitType.MASS, UnitSystem.METRIC, "|g|gm|", NC_(MASS, "gram"), "1/1000", "kg"},
        {UnitType.MASS, UnitSystem.METRIC, "|t|tonne", NC_(MASS, "metric tonne"), "1000", "kg"},
        {UnitType.MASS, UnitSystem.UK, "|lb|", NC_(MASS, "pound"), "0.454", "kg"},
        {UnitType.MASS, UnitSystem.UK, "|oz|", NC_(MASS, "ounce"), "1/16", "lb"},
        {UnitType.MASS, UnitSystem.UK, "|st|", NC_(MASS, "stone"), "14", "lb"},
        {UnitType.LENGTH, UnitSystem.METRIC, "|m|", NC_(LENGTH, "meter"), "1", ""},
        {UnitType.LENGTH, UnitSystem.METRIC, "|cm|", NC_(LENGTH, "centimeter"), "1/100", "m"},
        {UnitType.LENGTH, UnitSystem.METRIC, "|mm|", NC_(LENGTH, "millimeter"), "1/10", "cm"},
        {UnitType.LENGTH, UnitSystem.METRIC,"|km|", NC_(LENGTH, "kilometer"), "1000", "m"},
        {UnitType.LENGTH, UnitSystem.UK, "|yd|", NC_(LENGTH, "yard"), "0.9144", "m"},
        {UnitType.LENGTH, UnitSystem.UK, "|ft|", NC_(LENGTH, "foot"), "1/3", "yd"},
        {UnitType.LENGTH, UnitSystem.UK, "|fathom|", NC_(LENGTH, "fathom"), "6", "ft"},
        {UnitType.LENGTH, UnitSystem.UK, "|ch|chain|", NC_(LENGTH, "chain"), "66", "ft"},
        {UnitType.LENGTH, UnitSystem.UK, "|link|", NC_(LENGTH, "link"), "1/100", "ch"},
        {UnitType.LENGTH, UnitSystem.UK, "|in|", NC_(LENGTH, "inch"), "1/12", "ft"},
        {UnitType.LENGTH, UnitSystem.UK, "|mi|", NC_(LENGTH, "mile"), "1760", "yd"},
        {UnitType.LENGTH, UnitSystem.UK, "|mi|nmi|", NC_(LENGTH, "nautical mile"), "1852", "yd"},
        {UnitType.LENGTH, UnitSystem.UK, "|mi|cmi|", NC_(LENGTH, "country mile"), "2200", "yd"},
        {UnitType.VOLUME,  UnitSystem.METRIC, "|l|liter|", NC_(VOLUME, "liter"), "1","dm3"},
        {UnitType.VOLUME, UnitSystem.METRIC, "|dm3|", NC_(VOLUME, "cubic decimeter"), "1", ""},
        {UnitType.VOLUME, UnitSystem.METRIC, "|ml|", NC_(VOLUME, "milliliter"), "1/1000", "dm3"},
        {UnitType.VOLUME, UnitSystem.METRIC, "|cm3|", NC_(VOLUME, "cubic centimeter"), "1/1000", "dm3"},
        {UnitType.VOLUME, UnitSystem.UK, "|in3|", NC_(VOLUME, "cubic inch"), "16.3871", "cm3"},
        {UnitType.VOLUME, UnitSystem.METRIC, "|m3|", NC_(VOLUME, "cubic meter"), "1000", "dm3"},
        {UnitType.VOLUME, UnitSystem.UK, "|gal|igal|gallon|", NC_(VOLUME, "Imperial gallon"), "4.54609", "dm3"},
        {UnitType.VOLUME, UnitSystem.US, "|gal|usgal|gallon|", NC_(VOLUME, "US liquid gallon"), "231", "in3"},
        {UnitType.VOLUME, UnitSystem.UK, "|qt|iqt|quart|", NC_(VOLUME, "Imperial quart"), "1/4", "igal"},
        {UnitType.VOLUME, UnitSystem.US, "|qt|usqt|quart|", NC_(VOLUME, "US liquid quart"), "1/4", "usgal"},
        {UnitType.VOLUME, UnitSystem.UK, "|pt|ipint|pint|", NC_(VOLUME, "Imperial pint"), "1/8", "igal"},
        {UnitType.VOLUME, UnitSystem.US, "|pt|uspint|pint|", NC_(VOLUME, "US liquid pint"), "1/8", "usgal"},
    };
}

