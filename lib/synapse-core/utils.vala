/*
* Copyright (c) 2010 Michal Hruby <michal.mhr@gmail.com>
*               2017 elementary LLC.
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
* Authored by: Michal Hruby <michal.mhr@gmail.com>
*/

namespace Synapse {
	[CCode (gir_namespace = "SynapseUtils", gir_version = "1.0")]
	namespace Utils {
		/* Make sure setlocale was called before calling this function
		*   (Gtk.init calls it automatically)
		*/
		public static string? remove_accents (string input) {
			string? result;
			unowned string charset;
			GLib.get_charset (out charset);

			try {
				result = GLib.convert (input, input.length,
				"US-ASCII//TRANSLIT", charset);
				// no need to waste cpu cycles if the input is the same
				if (input == result) {
					return null;
				}
			} catch (ConvertError err) {
				result = null;
			}

			return result;
		}

		public static string? remove_last_unichar (string input) {
			long char_count = input.char_count ();
			int len = input.index_of_nth_char (char_count - 1);

			return input.substring (0, len);
		}

		public static async bool query_exists_async (GLib.File f) {
			bool exists;

			try {
				yield f.query_info_async (FileAttribute.STANDARD_TYPE, 0, 0, null);
				exists = true;
			} catch (Error err) {
				exists = false;
			}

			return exists;
		}

		public string extract_type_name (Type obj_type) {
			string obj_class = obj_type.name ();
			if (obj_class.has_prefix ("Synapse")) {
				return obj_class.substring (7);
			}

			return obj_class;
		}

		[Compact]
		private class DelegateWrapper {
			public SourceFunc callback;

			public DelegateWrapper (owned SourceFunc cb) {
				callback = (owned) cb;
			}
		}

		/*
		* Asynchronous Once.
		*
		* Usage:
		* private AsyncOnce<string> once = new AsyncOnce<string> ();
		* public async void foo ()
		* {
		*   if (!once.is_initialized ()) // not stricly necessary but improves perf
		*   {
		*     if (yield once.enter ())
		*     {
		*       // this block will be executed only once, but the method
		*       // is reentrant; it's also recommended to wrap this block
		*       // in try { } and call once.leave() in finally { }
		*       // if any of the operations can throw an error
		*       var s = yield get_the_string ();
		*       once.leave (s);
		*     }
		*   }
		*   // if control reaches this point the once was initialized
		*   yield do_something_for_string (once.get_data ());
		* }
		*/
		public class AsyncOnce<G> {
			private enum OperationState {
				NOT_STARTED,
				IN_PROGRESS,
				DONE
			}

			private G inner;

			private OperationState state;
			private DelegateWrapper[] callbacks = {};

			public AsyncOnce () {
				state = OperationState.NOT_STARTED;
			}

			public unowned G get_data () {
				return inner;
			}

			public bool is_initialized () {
				return state == OperationState.DONE;
			}

			public async bool enter () {
				if (state == OperationState.NOT_STARTED) {
					state = OperationState.IN_PROGRESS;
					return true;
				} else if (state == OperationState.IN_PROGRESS) {
					yield wait_async ();
				}

				return false;
			}

			public void leave (G result) {
				if (state != OperationState.IN_PROGRESS) {
					warning ("Incorrect usage of AsyncOnce");
					return;
				}

				state = OperationState.DONE;
				inner = result;
				notify_all ();
			}

			/* Once probably shouldn't have this, but it's useful */
			public void reset () {
				if (state == OperationState.IN_PROGRESS) {
					warning ("AsyncOnce.reset() cannot be called in the middle of initialization.");
				} else {
					state = OperationState.NOT_STARTED;
					inner = null;
				}
			}

			private void notify_all () {
				foreach (unowned DelegateWrapper wrapper in callbacks) {
					wrapper.callback ();
				}
				callbacks = {};
			}

			private async void wait_async () {
				callbacks += new DelegateWrapper (wait_async.callback);
				yield;
			}
		}

		public class FileInfo {
			private static string interesting_attributes;
			static construct {
				interesting_attributes =
				string.join (",", FileAttribute.STANDARD_TYPE,
				FileAttribute.STANDARD_IS_HIDDEN,
				FileAttribute.STANDARD_IS_BACKUP,
				FileAttribute.STANDARD_DISPLAY_NAME,
				FileAttribute.STANDARD_ICON,
				FileAttribute.STANDARD_FAST_CONTENT_TYPE,
				FileAttribute.THUMBNAIL_PATH,
				null);
			}

			public string uri;
			public string parse_name;
			public QueryFlags file_type;
			public UriMatch? match_obj;
			private bool initialized;
			private Type match_obj_type;

			public FileInfo (string uri, Type obj_type) {
				assert (obj_type.is_a (typeof (UriMatch)));
				this.uri = uri;
				this.match_obj = null;
				this.match_obj_type = obj_type;
				this.initialized = false;
				this.file_type = QueryFlags.UNCATEGORIZED;

				var f = File.new_for_uri (uri);
				this.parse_name = f.get_parse_name ();
			}

			public bool is_initialized () {
				return this.initialized;
			}

			public async void initialize () {
				initialized = true;
				var f = File.new_for_uri (uri);

				try {
					var fi = yield f.query_info_async (interesting_attributes, 0, 0, null);
					if (fi.get_file_type () == FileType.REGULAR && !fi.get_is_hidden () && !fi.get_is_backup ()) {
						match_obj = (UriMatch) Object.new (match_obj_type,
															"thumbnail-path", fi.get_attribute_byte_string (FileAttribute.THUMBNAIL_PATH),
															"icon-name", fi.get_icon ().to_string (),
															"uri", uri,
															"title", fi.get_display_name (),
															"description", f.get_parse_name (),
															"match-type", MatchType.GENERIC_URI,
															null);

						// let's determine the file type
						unowned string mime_type = fi.get_attribute_string (FileAttribute.STANDARD_FAST_CONTENT_TYPE);
						if (ContentType.is_unknown (mime_type)) {
							file_type = QueryFlags.UNCATEGORIZED;
						} else if (ContentType.is_a (mime_type, "audio/*")) {
							file_type = QueryFlags.AUDIO;
						} else if (ContentType.is_a (mime_type, "video/*")) {
							file_type = QueryFlags.VIDEO;
						} else if (ContentType.is_a (mime_type, "image/*")) {
							file_type = QueryFlags.IMAGES;
						} else if (ContentType.is_a (mime_type, "text/*")) {
							file_type = QueryFlags.DOCUMENTS;
						} else if (ContentType.is_a (mime_type, "application/*")) { // FIXME: this isn't right
							file_type = QueryFlags.DOCUMENTS;
						}

						match_obj.file_type = file_type;
						match_obj.mime_type = mime_type;
					}
				} catch (Error err) {
					warning ("%s", err.message);
				}
			}

			public async bool exists () {
				var f = File.new_for_uri (uri);
				bool result = yield query_exists_async (f);

				return result;
			}
		}
	}
}
