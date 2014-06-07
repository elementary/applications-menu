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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

namespace Synapse
{
	public class TelepathyPlugin: Object, Activatable, ItemProvider, ActionProvider
	{
		public bool enabled { get; set; default = true; }

		public void activate ()
		{

		}

		public void deactivate ()
		{

		}

		static void register_plugin ()
		{
			DataSink.PluginRegistry.get_default ().register_plugin (
					typeof (PidginPlugin),
					"Telepathy",
					_ ("Get access to your Telepathy contacts"),
					"empathy",
					register_plugin,
					true, // available condition TODO
					""   // not available error message
			);
		}

		static construct
		{
			register_plugin ();
		}

		private class SendToContact : BaseAction
		{
			public SendToContact ()
			{
				Object (title: _ ("Send in chat to.."),
						description: _ ("Send selected file within Pidgin"),
						match_type: MatchType.ACTION,
						icon_name: "document-send", has_thumbnail: false,
						default_relevancy: Match.Score.AVERAGE);
			}

			public override void do_execute (Match? match, Match? target = null)
			{
				Contact? c = target as Contact;
				UriMatch? u = match as UriMatch;
				if (c == null) return;

				c.send_file (u.uri);
			}

			public override bool valid_for_match (Match match)
			{
				switch (match.match_type)
				{
					case MatchType.GENERIC_URI:
						UriMatch um = match as UriMatch;
						return (um.file_type & QueryFlags.FILES) != 0;
					default:
						return false;
				}
			}

			public override bool needs_target () {
				return true;
			}

			public override QueryFlags target_flags ()
			{
				return QueryFlags.CONTACTS;
			}
		}

		private class StartChat : BaseAction
		{
			public StartChat ()
			{
				Object (title: _ ("Start chat"),
						description: _ ("Open a chat"),
						match_type: MatchType.ACTION,
						icon_name: "internet-chat", has_thumbnail: false,
						default_relevancy: Match.Score.EXCELLENT);
			}

			public override void do_execute (Match? match, Match? target = null)
			{
				var contact = (match as Contact).persona.contact;

				if (contact == null)
					return;

				var request = new TelepathyGLib.AccountChannelRequest.text (contact.get_account (), 0);
				request.set_target_contact (contact);

				request.create_channel_async.begin ("", null, (obj, res) => {
					try {
						if (!request.create_channel_async.end (res))
							warning ("Creating channel failed");
					} catch (GLib.Error e) { warning (e.message); }
				});
			}

			public override bool valid_for_match (Match match)
			{
				return match.match_type == MatchType.CONTACT && match is Contact;
			}

			public override bool needs_target () {
				return false;
			}
		}

		private class Contact: Object, Match, ContactMatch
		{
			// from Match interface
			public string title { get; construct set; }
			public string description { get; set; }
			public string icon_name { get; construct set; }
			public bool has_thumbnail { get; construct set; }
			public string thumbnail_path { get; construct set; }
			public MatchType match_type { get; construct set; }

			public Tpf.Persona persona { get; construct set; }

			public Contact (Tpf.Persona persona)
			{
				var avatar_file = persona.contact.avatar_file;

				Object (title: persona.alias,
						description: persona.full_name, // FIXME
						icon_name: "avatar-default",
						has_thumbnail: avatar_file != null,
						thumbnail_path: avatar_file != null ? avatar_file.get_path () : "",
						match_type: MatchType.CONTACT,
						persona: persona);
			}

			public virtual void send_message (string message, bool present)
			{
			}

			public virtual void open_chat ()
			{
			}

			public void send_file (string path)
			{
			}
		}

		private Gee.LinkedList<Contact> contacts;

		private Gee.List<BaseAction> actions;
		private Folks.Backend? telepathy_backend = null;

		construct
		{
			actions = new Gee.ArrayList<BaseAction> ();
			// TODO actions.add (new SendToContact ());
			actions.add (new StartChat ());

			contacts = new Gee.LinkedList<Contact> ();

			var backend_store = Folks.BackendStore.dup ();
			backend_store.load_backends.begin ((obj, res) => {
				try {
					backend_store.load_backends.end (res);
				} catch (Error e) {
					error ("Loading backends failed, telepathy plugin won't be available: %s\n", e.message);
				}
			});

			backend_store.backend_available.connect ((backend) => {
				if (backend.name == "telepathy") {
					telepathy_backend = backend;

					telepathy_backend.prepare.begin ((obj, res) => {
						try {
							telepathy_backend.prepare.end (res);
						} catch (Error e) { error (e.message); }

						foreach (var store in telepathy_backend.persona_stores.values) {
							register_persona_store (store as Tpf.PersonaStore);
						}
					});

					telepathy_backend.persona_store_added.connect ((store) => register_persona_store (store));
					telepathy_backend.persona_store_removed.connect ((store) => {
						var it = contacts.iterator ();
						while (it.next ()) {
							var contact = it.get ();
							if (contact.persona.store == store)
								it.remove ();
						}
					});
				}
			});
		}

		private void register_persona_store (Folks.PersonaStore store)
		{
			store.personas_changed.connect ((added, removed) => {
				foreach (var persona in added) {
					contacts.add (new Contact (persona as Tpf.Persona));
				}

				foreach (var persona in removed) {
					var it = contacts.iterator ();
					while (it.next ()) {
						var contact = it.get ();
						if (contact.persona == persona)
							it.remove ();
					}
				}
			});

			store.prepare.begin ();
		}

		public ResultSet? find_for_match (ref Query query, Match match)
		{
			if (contacts.size < 1) return null;

			bool query_empty = query.query_string == "";
			var results = new ResultSet ();

			if (query_empty)
			{
				foreach (var action in actions)
				{
					if (!action.valid_for_match (match)) continue;
					results.add (action, action.get_relevancy_for_match (match));
				}
			}
			else
			{
				var matchers = Query.get_matchers_for_query (query.query_string, 0,
						RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
				foreach (var action in actions)
				{
					if (!action.valid_for_match (match)) continue;
					foreach (var matcher in matchers)
					{
						if (matcher.key.match (action.title))
						{
							results.add (action, matcher.value);
							break;
						}
					}
				}
			}

			return results;
		}

		public bool handles_query (Query query)
		{
			return (QueryFlags.CONTACTS in query.query_type);
		}

		public async ResultSet? search (Query q) throws SearchError
		{
			// we only search for actions
			if (!(QueryFlags.CONTACTS in q.query_type)) return null;

			var result = new ResultSet ();

			var matchers = Query.get_matchers_for_query (q.query_string, 0,
					RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

			foreach (var contact in contacts)
			{
				var presence = contact.persona.presence_type;
				if (presence != Folks.PresenceType.AVAILABLE
					&& presence != Folks.PresenceType.AWAY)
					continue;

				foreach (var matcher in matchers)
				{
					if (matcher.key.match (contact.title))
					{
						result.add (contact, matcher.value - Match.Score.INCREMENT_SMALL);
						break;
					}
				}
			}

			q.check_cancellable ();

			return result;
		}


	}
}

