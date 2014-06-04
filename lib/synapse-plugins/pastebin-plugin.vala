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
  public class PastebinPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class PastebinAction: BaseAction
    {
      public PastebinAction ()
      {
        Object (title: _ ("Pastebin"),
                description: _ ("Pastebin selection"),
                match_type: MatchType.ACTION,
                icon_name: "document-send", has_thumbnail: false,
                default_relevancy: Match.Score.AVERAGE);
      }
      
      protected async string? pastebin_file (string path)
      {
        string[] argv = {"pastebinit", "-i", path};

        try
        {
          Pid pid;
          int read_fd;

          Process.spawn_async_with_pipes (null, argv, null,
                                          SpawnFlags.SEARCH_PATH,
                                          null, out pid, null, out read_fd);

          UnixInputStream read_stream = new UnixInputStream (read_fd, true);
          DataInputStream pastebinit_output = new DataInputStream (read_stream);

          string? line = null;
          string complete_output = "";
          do
          {
            line = yield pastebinit_output.read_line_async (Priority.DEFAULT_IDLE);
            if (line != null)
            {
              complete_output += line;
            }
          } while (line != null);
          
          Regex url = new Regex ("^http(s)?://.*$"); // url
          if (url.match (complete_output))
          {
            return complete_output;
          }
          else
          {
            throw new IOError.INVALID_DATA (complete_output);
          }
        }
        catch (Error err)
        {
          Utils.Logger.warning (this, "%s", err.message);
        }
        
        return null;
      }

      protected async string? pastebin_text (string content)
      {
        string[] argv = {"pastebinit"};
        
        try
        {
          Pid pid;
          int read_fd;
          int write_fd;

          Process.spawn_async_with_pipes (null, argv, null,
                                          SpawnFlags.SEARCH_PATH,
                                          null, out pid, out write_fd, out read_fd);

          UnixInputStream read_stream = new UnixInputStream (read_fd, true);
          DataInputStream pastebinit_output = new DataInputStream (read_stream);
          UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);

          yield write_stream.write_async (content.data);
          yield write_stream.close_async ();

          string? line = null;
          string complete_output = "";
          do
          {
            line = yield pastebinit_output.read_line_async (Priority.DEFAULT_IDLE);
            if (line != null)
            {
              complete_output += line;
            }
          } while (line != null);
          
          Regex url = new Regex ("^http(s)?://.*$"); // url
          if (url.match (complete_output))
          {
            return complete_output;
          }
          else
          {
            throw new IOError.INVALID_DATA (complete_output);
          }
        }
        catch (Error err)
        {
          Utils.Logger.warning (this, "%s", err.message);
        }
        
        return null;
      }
      
      protected virtual void process_pastebin_result (string? url, Match? target = null)
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
            summary: _ ("Synapse - Pastebin"),
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
          var f = File.new_for_uri (uri_match.uri);
          string path = f.get_path ();
          if (path == null)
          {
            Utils.Logger.warning (this, "Unable to get path for %s", uri_match.uri);
            return;
          }
          pastebin_file.begin (path, (obj, res) =>
          {
            string? url = pastebin_file.end (res);
            process_pastebin_result (url, target);
          });
        }
        else if (match.match_type == MatchType.TEXT)
        {
          TextMatch? text_match = match as TextMatch;
          string content = text_match != null ? text_match.get_text () : match.title;
          pastebin_text.begin (content, (obj, res) =>
          {
            string? url = pastebin_text.end (res);
            process_pastebin_result (url, target);
          });
        }
      }
      
      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.TEXT:
            return true;
          case MatchType.GENERIC_URI:
            var um = match as UriMatch;
            var f = File.new_for_uri (um.uri);
            if (f.get_path () == null) return false;
            return ContentType.is_a (um.mime_type, "text/*");
          default:
            return false;
        }
      }
    }
    
    private class PastebinToContactAction : PastebinAction
    {
      public PastebinToContactAction ()
      {
        Object (title: _ ("Pastebin to contact.."),
                description: _ ("Pastebin selection"),
                match_type: MatchType.ACTION,
                icon_name: "document-send", has_thumbnail: false,
                default_relevancy: Match.Score.AVERAGE);
      }
      
      protected override void process_pastebin_result (string? url, Match? target = null)
      {
        ContactMatch? contact = target as ContactMatch;
        if (contact == null || url == null)
        {
          base.process_pastebin_result (url, null);
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
        typeof (PastebinPlugin),
        _ ("Pastebin"),
        _ ("Upload files to pastebin."),
        "document-send",
        register_plugin,
        Environment.find_program_in_path ("pastebinit") != null,
        _ ("Unable to find \"pastebinit\" program")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Gee.List<PastebinAction> actions;

    construct
    {
      actions = new Gee.ArrayList<PastebinAction> ();
      actions.add (new PastebinAction ());
      //actions.add (new PastebinToContactAction ());
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
