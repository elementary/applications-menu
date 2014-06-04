/*
 * Copyright (C) 2011 Antono Vasiljev <self@antono.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
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
 * Authored by Antono Vasiljev <self@antono.info>
 *
 */

using Gee;

namespace Synapse
{
  public class SshPlugin: Object, Activatable, ItemProvider
  {
    public  bool      enabled { get; set; default = true; }
    private HashMap<string, SshHost> hosts;
    
    protected File config_file;
    protected FileMonitor monitor;

    static construct
    {
      register_plugin ();
    }
    
    construct
    {
      hosts = new HashMap<string, SshHost> ();
    }

    public void activate ()
    {
      this.config_file = File.new_for_path (Environment.get_home_dir () + "/.ssh/config");

      parse_ssh_config.begin ();

      try {
        this.monitor = config_file.monitor_file (FileMonitorFlags.NONE);
        this.monitor.changed.connect (this.handle_ssh_config_update);
      }
      catch (IOError e)
      {
        Utils.Logger.warning (this, "Failed to start monitoring changes of ssh client config file");
      }
    }

    public void deactivate () {}

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (SshPlugin),
    		"SSH", // Plugin title
        _ ("Connect to host with SSH"), // description
        "terminal",	// icon name
        register_plugin, // reference to this function
    		// true if user's system has all required components which the plugin needs
        (Environment.find_program_in_path ("ssh") != null),
        _ ("ssh is not installed") // error message
      );
    }

    private async void parse_ssh_config ()
    {
      hosts.clear ();

      try
      {
        var dis = new DataInputStream (config_file.read ());

        // TODO: match key boundary
        Regex host_key_re = new Regex ("(host\\s)", RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        Regex comment_re  = new Regex ("#.*$", RegexCompileFlags.OPTIMIZE);
        Regex ws_re = new Regex ("[\\s]+", RegexCompileFlags.OPTIMIZE);

        string line;

        while ((line = yield dis.read_line_async (Priority.DEFAULT)) != null)
        {
          /* Delete comments */
          line = comment_re.replace (line, -1, 0, "");
          if (host_key_re.match (line))
          {
            /* remove "Host" key */
            line = host_key_re.replace (line, -1, 0, "");
            /* Replace multiple whitespaces with a single space char */
            line = ws_re.replace (line, -1, 0, " ").strip ();
            /* split to find multiple host definition */
            foreach (var host in line.split (" "))
            {
              string host_stripped = host.strip ();
              if (host_stripped != "" && host_stripped.index_of ("*") == -1 && host_stripped.index_of ("?") == -1)
              {
                Utils.Logger.debug (this, "host added: %s\n", host_stripped);
                hosts.set (host_stripped, new SshHost (host_stripped));
              }
            }
          }
        }
      }
      catch (Error e)
      {
        Utils.Logger.warning (this, "%s: %s", config_file.get_path (), e.message);
      }
    }
    
    public void handle_ssh_config_update (FileMonitor monitor,
                                          File file,
                                          File? other_file,
                                          FileMonitorEvent event_type)
    {
      if (event_type == FileMonitorEvent.CHANGES_DONE_HINT)
      {
        Utils.Logger.log (this, "ssh_config is changed, reparsing");
        parse_ssh_config.begin ();
      }
    }

    public bool handles_query (Query query)
    {
      return hosts.size > 0 && 
            ( QueryFlags.ACTIONS in query.query_type ||
              QueryFlags.INTERNET in query.query_type);
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      Idle.add (search.callback);
      yield;
      q.check_cancellable ();

      var results = new ResultSet ();
      
      var matchers = Query.get_matchers_for_query (q.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var host in hosts.values) //workaround for missing HashMap.iterator() method
      {
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (host.host_query))
          {
            results.add (host, matcher.value - Match.Score.INCREMENT_SMALL);
            break;
          }
        }
      }

      q.check_cancellable ();

      return results;
    }

    private class SshHost : Object, Match
    {
      public string title           { get; construct set; }
      public string description     { get; set; }
      public string icon_name       { get; construct set; }
      public bool   has_thumbnail   { get; construct set; }
      public string thumbnail_path  { get; construct set; }
      public string host_query      { get; construct set; }
      public MatchType match_type   { get; construct set; }

      public void execute (Match? match)
      {
        try
        {
          AppInfo ai = AppInfo.create_from_commandline (
            "ssh %s".printf (this.title),
            "ssh", AppInfoCreateFlags.NEEDS_TERMINAL);
          ai.launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public SshHost (string host_name)
      {
        Object (
          match_type: MatchType.ACTION,
          title: host_name,
          description: _("Connect with SSH"),
          has_thumbnail: false,
          icon_name: "terminal",
          host_query: host_name
        );
        
      }
    }
  }
}

// vim: expandtab softtabstop tabstop=2

