// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
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

namespace Slingshot.Backend
{
	public class SynapseSearch : Object
	{
		private static Type[] plugins = {
			typeof (Synapse.DesktopFilePlugin),
			typeof (Synapse.HybridSearchPlugin),
			typeof (Synapse.GnomeSessionPlugin),
			typeof (Synapse.GnomeScreenSaverPlugin),
			typeof (Synapse.SystemManagementPlugin),
			typeof (Synapse.CommandPlugin),
			typeof (Synapse.RhythmboxActions),
			typeof (Synapse.BansheeActions),
			typeof (Synapse.DirectoryPlugin),
			typeof (Synapse.LaunchpadPlugin),
			typeof (Synapse.CalculatorPlugin),
			typeof (Synapse.SelectionPlugin),
			typeof (Synapse.SshPlugin),
			typeof (Synapse.XnoiseActions),
			typeof (Synapse.ZeitgeistPlugin),
			typeof (Synapse.ZeitgeistRelated),
			typeof (Synapse.DevhelpPlugin),
			typeof (Synapse.OpenSearchPlugin),
			typeof (Synapse.LocatePlugin),
			typeof (Synapse.PastebinPlugin),
			typeof (Synapse.DictionaryPlugin),
			// typeof (Synapse.FilezillaPlugin),
			typeof (Synapse.WolframAlphaPlugin)
		};

		private static Synapse.DataSink? sink = null;

		Cancellable? current_search = null;

		public SynapseSearch ()
		{
			if (sink == null) {
				sink = new Synapse.DataSink ();
				foreach (var plugin in plugins) {
					sink.register_static_plugin (plugin);
				}
			}
		}

		public async Gee.List<Synapse.Match>? search (string text, Synapse.SearchProvider? provider = null)
		{
			if (current_search != null)
				current_search.cancel ();

			if (provider == null)
				provider = sink;

			var results = new Synapse.ResultSet ();

			try {
				return yield provider.search (text, Synapse.QueryFlags.ALL, results, current_search);
			} catch (Error e) { warning (e.message); }

			return null;
		}

		public static Gee.List<Synapse.Match> find_actions_for_match (Synapse.Match match)
		{
			return sink.find_actions_for_match (match, null, Synapse.QueryFlags.ALL);
		}
	}
}

