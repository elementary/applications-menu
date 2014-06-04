/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  errordomain UploadError
  {
    LIMIT_REACHED,
    UNKNOWN_ERROR
  }
  
  public class ImgUrPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    private Gee.List<ImgUrAction> actions;

    public void activate ()
    {
      actions.add (new ImgUrAction ());
      //actions.add (new ImgUrToContactAction ());
    }

    public void deactivate ()
    {
      actions.clear ();
    }

    private class ImgUrAction: BaseAction
    {
      public ImgUrAction ()
      {
        Object (title: _ ("Upload to imgur"),
                description: _ ("Upload selection to imgur image sharer"),
                match_type: MatchType.ACTION,
                icon_name: "document-send", has_thumbnail: false,
                default_relevancy: Match.Score.AVERAGE - Match.Score.INCREMENT_MINOR);
      }

      private Rest.Proxy proxy;

      construct
      {
        proxy = new Rest.Proxy ("http://api.imgur.com/2/", false);
      }

      private async string? upload_file (string uri) throws Error
      {
        // open the uri and base64 encode it
        var f = File.new_for_uri (uri);
        var input = yield f.read_async (Priority.DEFAULT, null);
        
        int chunk_size = 128*1024;
        uint8[] buffer = new uint8[chunk_size];
        char[] encode_buffer = new char[(chunk_size / 3 + 1) * 4 + 4];
        size_t read_bytes;
        int state = 0;
        int save = 0;
        var encoded = new StringBuilder ();

        read_bytes = yield input.read_async (buffer);
        while (read_bytes != 0)
        {
          buffer.length = (int) read_bytes;
          size_t enc_len = Base64.encode_step ((uchar[]) buffer, false, encode_buffer,
                                               ref state, ref save);
          encoded.append_len ((string) encode_buffer, (ssize_t) enc_len);
          read_bytes = yield input.read_async (buffer);
        }
        size_t enc_close = Base64.encode_close (false, encode_buffer, ref state, ref save);
        encoded.append_len ((string) encode_buffer, (ssize_t) enc_close);
        
        var call = proxy.new_call ();

        call.set_method ("POST");
        call.set_function ("upload.json");
        call.add_param ("key", "ae208d46a27310d4758e462a05c7f12e");
        call.add_param ("image", encoded.str);

        Error? err = null;

        call.run_async ((call_obj, error, obj) =>
        {
          err = error;
          upload_file.callback ();
        }, this);
        yield;
        if (err != null) throw err;

        unowned string limit_remaining = call.lookup_response_header ("X-RateLimit-Remaining");
        
        unowned string reset_time = call.lookup_response_header ("X-RateLimit-Reset");

        if (call.get_status_code () != 200)
        {
          if (limit_remaining != null && reset_time != null)
          {
            int remaining = int.parse (limit_remaining);
            long reset = long.parse (reset_time);
            if (remaining < 10 && reset > 0)
            {
              var cur_time = TimeVal ();
              long delta = (reset - cur_time.tv_sec) / 60;
              delta = long.max (1, delta);
              throw new UploadError.LIMIT_REACHED (@"Upload limit reached, reset in $delta minutes");
            }
            else
            {
              throw new UploadError.UNKNOWN_ERROR (call.get_status_message ());
            }
          }
          else
          {
            throw new UploadError.UNKNOWN_ERROR (call.get_status_message ());
          }
        }

        var parser = new Json.Parser ();
        parser.load_from_data (call.get_payload (), (ssize_t)call.get_payload_length ());

        unowned Json.Object node_obj = parser.get_root ().get_object ();
        if (node_obj != null)
        {
          node_obj = node_obj.get_object_member ("upload");
          if (node_obj != null)
          {
            node_obj = node_obj.get_object_member ("links");
            if (node_obj != null)
            {
              return node_obj.get_string_member ("imgur_page");
            }
          }
        }
        
        throw new UploadError.UNKNOWN_ERROR ("Unable to parse result");
      }
      
      protected virtual void process_result (string? url, Match? target = null)
      {
        string msg;
        if (url != null)
        {
          var cb = Gtk.Clipboard.get (Gdk.Atom.NONE);
          cb.set_text (url, -1);

          msg = _ ("The selection was successfully uploaded and its URL was copied to clipboard.");
        }
        else
        {
          msg = _ ("An error occurred during upload, please check the log for more information.");
        }

        try
        {
          // yey for breaking API!
          var notification = Object.new (
            typeof (Notify.Notification),
            summary: _ ("Synapse - Imgur"),
            body: msg,
            icon_name: "synapse",
            null) as Notify.Notification;
          notification.set_timeout (10);
          notification.show ();
        }
        catch (Error err)
        {
          Utils.Logger.warning (this, "%s", err.message);
        }
      }

      public override void do_execute (Match? match, Match? target = null)
      {
        if (match.match_type == MatchType.GENERIC_URI && match is UriMatch)
        {
          var uri_match = match as UriMatch;
          upload_file.begin (uri_match.uri, (obj, res) =>
          {
            string? url = null;
            try
            {
              url = upload_file.end (res);
              Utils.Logger.log (this, "%s", url);
            }
            catch (Error err)
            {
              Utils.Logger.warning (this, "%s", err.message);
            }
            
            process_result (url, target);
          });
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            var um = match as UriMatch;
            // FIXME: maybe we shouldn't care about the real path?
            var f = File.new_for_uri (um.uri);
            if (f.get_path () == null) return false;
            return ContentType.is_a (um.mime_type, "image/*");
          default:
            return false;
        }
      }
    }
    
    private class ImgUrToContactAction : ImgUrAction
    {
      public ImgUrToContactAction ()
      {
        Object (title: _ ("Upload to imgur to contact.."),
                description: _ ("Upload selection to imgur image sharer, and send the link to contact"),
                match_type: MatchType.ACTION,
                icon_name: "document-send", has_thumbnail: false,
                default_relevancy: Match.Score.AVERAGE - Match.Score.INCREMENT_MINOR);
      }
      
      protected override void process_result (string? url, Match? target = null)
      {
        ContactMatch? contact = target as ContactMatch;
        if (contact == null || url == null)
        {
          base.process_result (url, null);
        }
        else
        {
          contact.send_message (url, true);
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

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (ImgUrPlugin),
        _ ("Imgur"),
        _ ("Share images using imgur."),
        "document-send",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    construct
    {
      actions = new Gee.ArrayList<ImgUrAction> ();
    }

    public ResultSet? find_for_match (ref Query q, Match match)
    {
      if (!actions[0].valid_for_match (match)) return null;

      // strip query
      q.query_string = q.query_string.strip ();
      bool query_empty = q.query_string == "";

      var results = new ResultSet ();

      if (query_empty)
      {
        int rel = actions[0].default_relevancy;
        foreach (var action in actions)
          results.add (action, rel);
      }
      else
      {
        var matchers = Query.get_matchers_for_query (q.query_string, 0,
          RegexCompileFlags.CASELESS);
        foreach (var action in actions)
        {
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
  }
}
