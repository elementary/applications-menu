// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Slingshot Developers
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Gtk;

namespace Slingshot.Widgets {

    public class SearchEntry : Granite.Widgets.SearchBar {

        /**
         * This class basically add to Granite SearchBar few features
         * such as a delayed changed signal.
         * Based on Ubuntu Software Center SearchEntry widget
        **/

        private int SEARCH_TIMEOUT = 200;
        private uint timeout_id = 0;

        public signal void terms_changed (string text);

        public SearchEntry (string hint_string) {

            base (hint_string);

            changed.connect_after (on_changed);

        }

        private void on_changed () {

            if (timeout_id > 0)
                Source.remove (timeout_id);
            timeout_id = Timeout.add (SEARCH_TIMEOUT, (SourceFunc) emit_terms_changed);

        }

        private void emit_terms_changed () {

            var terms = get_text ();
            terms_changed (terms); // Emit signal

        }

    }

}
