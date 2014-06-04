/*
 * Copyright (C) 2011 Michal Hruby <michal.mhr@gmail.com>
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
  public class LaunchpadPlugin: Object, Activatable, ItemProvider //, Configurable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    private LaunchpadAuthObject? auth_object;

    public void activate ()
    {
      //auth_object = new LaunchpadAuthObject ();
    }

    public void deactivate ()
    {
      auth_object = null;
    }
    
    public Gtk.Widget create_config_widget ()
    {
      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
      box.show ();

      var authorize_button = new Gtk.Button.with_label (_("Authorize with Launchpad"));
      authorize_button.show ();
      box.pack_start (authorize_button, true, false);
      
      var spinner = new Gtk.Spinner ();
      box.pack_start (spinner);

      var label = new Gtk.Label (_ ("Please press the Finish button once you login to Launchpad with your web browser"));
      label.set_width_chars (40);
      label.set_line_wrap (true);
      var proceed_button = new Gtk.Button.with_label (_ ("Finish authorization"));
      box.pack_start (label);
      box.pack_start (proceed_button, true, false);

      /*
      HashTable<string, string>? step1_result = null;

      // i'm quite sure this leaks as hell, but it works :)
      authorize_button.clicked.connect (() =>
      {
        authorize_button.hide ();
        spinner.show ();
        spinner.start ();
        auth_object.auth_step1.begin ((obj, res) =>
        {
          // FIXME: handle error
          step1_result = auth_object.auth_step1.end (res);
          auth_object.auth_step2 (step1_result.lookup ("oauth_token"));
          Timeout.add_seconds (5, () =>
          {
            spinner.hide ();
            spinner.stop ();
            label.show ();
            proceed_button.show ();

            return false;
          });
        });
      });

      proceed_button.clicked.connect (() =>
      {
        proceed_button.hide ();
        label.hide ();
        spinner.show ();
        spinner.start ();
        auth_object.auth_step3.begin (step1_result.lookup ("oauth_token"),
                                      step1_result.lookup ("oauth_token_secret"),
                                      (obj, res) =>
        {
          spinner.hide ();
          try
          {
            var step3_result = auth_object.auth_step3.end (res);
            Utils.Logger.log (this, "token: %s", step3_result.lookup ("oauth_token"));
            Utils.Logger.log (this, "token_secret: %s", step3_result.lookup ("oauth_token_secret"));

            label.set_text (_ ("Successfully authenticated"));
          }
          catch (Error e)
          {
            label.set_text (_ ("Authentication failed") + " (%s)".printf (e.message));
          }
          
          label.show ();
        });
      });
      */

      return box;
    }

    private class LaunchpadAuthObject: Object
    {
      const string CONSUMER_KEY = "Synapse.LaunchpadPlugin";
/*
      private Rest.Proxy proxy;

      protected HashTable<string, string> parse_form_reply (string payload)
      {
        var ht = new HashTable<string, string> (str_hash, str_equal);

        string[] parameters = payload.split ("&");
        foreach (unowned string p in parameters)
        {
          string[] parameter = p.split ("=", 2);
          ht.insert (parameter[0], parameter[1]);
        }

        return ht;
      }
      
      private class Credentials: ConfigObject
      {
        public string token { get; set; default = ""; }
        public string token_secret { get; set; default = ""; }
      }

      private Credentials creds;

      construct
      {
        // make sure we keep a ref to this, otherwise it'll crash when the call
        // finishes
        proxy = new Rest.Proxy ("https://launchpad.net/", false);
        
        creds = ConfigService.get_default ().bind_config (
          "plugins", "launchpad-plugin", typeof (Credentials)
        ) as Credentials;
      }
      
      public bool is_authenticated ()
      {
        return creds.token != "" && creds.token_secret != "";
      }
      
      public void get_tokens (out string token, out string token_secret)
      {
        token = creds.token;
        token_secret = creds.token_secret;
      }
      
      public async HashTable<string, string> auth_step1 () throws Error
      {
        Error? err = null;

        var call = proxy.new_call ();

        call.set_method ("POST");
        call.set_function ("+request-token");
        call.add_param ("oauth_consumer_key", CONSUMER_KEY);
        call.add_param ("oauth_signature_method", "PLAINTEXT");
        call.add_param ("oauth_signature", "&");

        call.run_async ((call_obj, error, obj) =>
        {
          err = error;
          auth_step1.callback ();
        }, this);
        yield;

        if (err != null) throw err;

        // the reply should have oauth_token & oauth_token_secret
        var result = parse_form_reply (call.get_payload ());
        return result;
      }
      
      public void auth_step2 (string oauth_token)
      {
        // https://launchpad.net/+authorize-token?oauth_token={oauth_token}
        CommonActions.open_uri ("https://launchpad.net/+authorize-token?oauth_token=" + oauth_token);
      }
      
      public async HashTable<string, string> auth_step3 (string oauth_token,
                                                         string token_secret) throws Error
      {
        Error? err = null;

        var call = proxy.new_call ();
        call.set_method ("POST");
        call.set_function ("+access-token");
        call.add_param ("oauth_token", oauth_token);
        call.add_param ("oauth_consumer_key", CONSUMER_KEY);
        call.add_param ("oauth_signature_method", "PLAINTEXT");
        call.add_param ("oauth_signature", "&" + token_secret);

        call.run_async ((call_obj, error, obj) =>
        {
          err = error;
          auth_step3.callback ();
        }, this);
        yield;

        if (err != null) throw err;

        // the reply should have new oauth_token & oauth_token_secret
        var result = parse_form_reply (call.get_payload ());
        creds.token = result.lookup ("oauth_token") ?? "";
        creds.token_secret = result.lookup ("oauth_token_secret") ?? "";

        return result;
      }
*/
    }

    private class LaunchpadObject: Object, Match, UriMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for UriMatch
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }
      
      public LaunchpadObject (string title, string desc, string uri)
      {
        Object (title: title, description: desc,
                icon_name: ContentType.get_icon ("text/html").to_string (),
                match_type: MatchType.GENERIC_URI,
                uri: uri, mime_type: "text/html",
                file_type: QueryFlags.INTERNET);
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (LaunchpadPlugin),
        "Launchpad",
        _ ("Find bugs and branches on Launchpad."),
        "applications-internet",
        register_plugin
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private Regex bug_regex;
    private Regex branch_regex;

    construct
    {
      try
      {
        bug_regex = new Regex ("(?:bug|lp|#):?\\s*#?\\s*(\\d+)$", RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        branch_regex = new Regex ("lp:(~?[a-z]+[+-/_a-z0-9]*)", RegexCompileFlags.OPTIMIZE);
      }
      catch (RegexError err)
      {
        Utils.Logger.warning (this, "Unable to construct regex: %s", err.message);
      }
    }
    
    public bool handles_query (Query q)
    {
      return (QueryFlags.INTERNET in q.query_type || QueryFlags.ACTIONS in q.query_type);
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      string? uri = null;
      string title = null;
      string description = null;
      var result = new ResultSet ();

      string stripped = q.query_string.strip ();
      if (stripped == "") return null;

      MatchInfo mi;
      if (branch_regex.match (stripped, 0, out mi))
      {
        string branch = mi.fetch (1);
        string[] groups = branch.split ("/");
        if (groups.length == 1)
        {
          // project link (lp:synapse)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Bazaar branches for %s").printf (branch);
          description = uri;
        }
        else if (groups.length == 2 && !branch.has_prefix ("~"))
        {
          // series link (lp:synapse/0.3)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Series %s for Project %s").printf (groups[1], groups[0]);
          description = uri;
        }
        else if (branch.has_prefix ("~"))
        {
          // branch link (lp:~mhr3/synapse/lp-plugin)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Bazaar branch %s").printf (branch);
          description = uri;
        }

        if (uri != null)
        {
          result.add (new LaunchpadObject (title, description, uri),
                      Match.Score.EXCELLENT);
        }
      }
      else if (bug_regex.match (stripped, 0, out mi))
      {
        string bug_num = mi.fetch (1);
        
        uri = "https://bugs.launchpad.net/bugs/" + bug_num;
        title = _ ("Launchpad: Bug #%s").printf (bug_num);
        description = uri;
        result.add (new LaunchpadObject (title, description, uri),
                    Match.Score.ABOVE_AVERAGE);
      }

      q.check_cancellable ();
      return result;
    }
    
    public ResultSet? find_for_match (ref Query query, Match match)
    {
      return null;
    }
  }
}
