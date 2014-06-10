/*
 * Copyright (C) 2014 Tom Beckmann <tomjonabc@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Tom Beckmann <tomjonabc@gmail.com>
 *
 */

namespace Synapse
{
	public class ContractorPlugin : Object, Activatable, ActionProvider
	{
		public bool enabled { get; set; default = true; }

		public void activate ()
		{
		}

		public void deactivate ()
		{
		}

		private class ContractorAction : BaseAction
		{
			public Granite.Services.Contract contract { get; construct; }

			public ContractorAction (Granite.Services.Contract contract)
			{
				Object (title: contract.get_display_name (),
						description: contract.get_description (),
						match_type: MatchType.ACTION,
						icon_name: contract.get_icon ().to_string (),
						contract: contract);
			}

			public override void do_execute (Match? match, Match? target = null)
			{
				if (match.match_type == MatchType.GENERIC_URI && match is UriMatch) {
					var uri_match = match as UriMatch;

					contract.execute_with_file (File.new_for_uri (uri_match.uri));
				}
			}

			public override bool valid_for_match (Match match)
			{
				switch (match.match_type) {
					case MatchType.GENERIC_URI:
						// TODO local files only
						return true;
					default:
						return false;
				}
			}
		}

		public ResultSet? find_for_match (ref Query q, Match match)
		{
			if (!(match is UriMatch))
				return null;

			// strip query
			q.query_string = q.query_string.strip ();
			bool query_empty = q.query_string == "";

			var results = new ResultSet ();

			var file = File.new_for_uri ((match as UriMatch).uri);
			var contracts = Granite.Services.ContractorProxy.get_contracts_for_file (file);
			var actions = new Gee.LinkedList<ContractorAction> ();
			foreach (var contract in contracts) {
				actions.add (new ContractorAction (contract));
			}

			if (query_empty) {
				int rel = actions[0].default_relevancy;
				foreach (var action in actions)
					results.add (action, rel);
			} else {
				var matchers = Query.get_matchers_for_query (q.query_string, 0,
					RegexCompileFlags.CASELESS);

				foreach (var action in actions) {
					foreach (var matcher in matchers) {
						if (matcher.key.match (action.title)) {
							results.add (action, matcher.value);
							break;
						}
					}
				}
			}

			return results;
		}
	}
}

