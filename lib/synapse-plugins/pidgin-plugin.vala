/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
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
  [DBus (name = "im.pidgin.purple.PurpleInterface")]
  interface PurpleInterface : Object {
      public const string UNIQUE_NAME = "im.pidgin.purple.PurpleService";
      public const string OBJECT_PATH = "/im/pidgin/purple/PurpleObject";
      
      public abstract string purple_account_get_protocol_name (int account) throws IOError;
      public abstract int purple_buddy_get_account (int buddy) throws IOError;
      public abstract string purple_buddy_get_name (int buddy) throws IOError;
      public abstract string purple_buddy_get_alias (int buddy) throws IOError;
      public abstract string purple_buddy_icon_get_full_path (int icon) throws IOError;
      public abstract int purple_buddy_get_icon (int buddy) throws IOError;
      public abstract int purple_buddy_is_online (int buddy) throws IOError;
      
      public abstract int[] purple_accounts_get_all_active () throws IOError;
      public abstract int[] purple_find_buddies (int account, string pattern = "") throws IOError;
      
      public abstract int purple_conversation_new (int type, int account, string name) throws IOError;
      public abstract void purple_conversation_present (int conv) throws IOError;
      public abstract int purple_conv_im (int conv) throws IOError;
      public abstract void purple_conv_im_send (int im, string mess) throws IOError;
      
      public abstract signal void account_added (int acc);
      public abstract signal void account_removed (int acc);
      public abstract signal void buddy_added (int buddy);
      public abstract signal void buddy_removed (int buddy);
      public abstract signal void buddy_signed_on (int buddy);
      public abstract signal void buddy_signed_off (int buddy);
      public abstract signal void buddy_icon_changed (int buddy);
      
      public abstract void serv_send_file (int conn, string who, string file) throws IOError;
      public abstract int purple_account_get_connection (int account) throws IOError;
  }

  public class PidginPlugin: Object, Activatable, ItemProvider, ActionProvider
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
        "Pidgin",
        _ ("Get access to your Pidgin contacts"),
        "pidgin",
        register_plugin,
        Environment.find_program_in_path ("pidgin") != null,
        _ ("Pidgin is not installed.")
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private class SendToContact: BaseAction
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
    
    private class Contact: Object, Match, ContactMatch
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      public PidginPlugin plugin { get; construct set; }
      
      public int account_id { get; construct set; }
      public int contact_id { get; construct set; }
      public string name { get; construct set; }
      public bool online { get; set; }
      
      public Contact (PidginPlugin plugin, int account_id, int contact_id, string name, bool online,
                           string alias, string? icon_path, string description)
      {
        Object (title: alias,
                description: description,
                online: online,
                name: name,
                icon_name: icon_path ?? "stock_person",
                has_thumbnail: false,
                match_type: MatchType.CONTACT,
                plugin: plugin,
                account_id: account_id,
                contact_id: contact_id);
      }

      public virtual void send_message (string message, bool present)
      {
        plugin.send_message (this, message, present);
      }
      
      public virtual void open_chat ()
      {
        plugin.open_chat (this);
      }
      
      public void send_file (string path)
      {
        plugin.send_file (this, path);
      }
    }
    
    private void send_file (Contact contact, string uri)
    {
      File f;
      f = File.new_for_uri (uri);
      if (!f.query_exists ())
      {
        Utils.Logger.warning (this, _("File \"%s\"does not exist."), uri);
        return;
      }
      string path = f.get_path ();
      try {
        int conn = p.purple_account_get_connection (contact.account_id);
        if (conn <= 0)
        {
          Utils.Logger.warning (this, "Cannot send file to %s", contact.title);
          return;
        }
        p.serv_send_file (conn, contact.name, path);
      } catch (IOError err)
      {
        Utils.Logger.warning (this, "Cannot send file to %s", contact.title);
      }
    }
    
    private void send_message (Contact contact, string? message, bool present)
    {
      try {
        var conv = p.purple_conversation_new (1, contact.account_id, contact.name);
        if (message != null)
        {
          var im = p.purple_conv_im (conv);
          p.purple_conv_im_send (im, message);
        }
        if (present) p.purple_conversation_present (conv);
      } catch (IOError err)
      {
        Utils.Logger.warning (this, "Cannot open chat for %s", contact.title);
      }
    }
    
    private void open_chat (Contact contact)
    {
      send_message (contact, null, true);
    }

    private Gee.Map<int, Contact> contacts;
    private PurpleInterface p;

    private void connect_to_bus ()
    {
      p = null;

      PurpleInterface p = Bus.get_proxy_sync (BusType.SESSION,
                                   PurpleInterface.UNIQUE_NAME,
                                   PurpleInterface.OBJECT_PATH);
      
      if (p != null)
      {
        init_contacts.begin (
        (obj, res) => {
          connect_to_signals ();
        });
      }
    }
    
    private void connect_to_signals ()
    {
      p.account_added.connect ((acc)=>{
        init_contacts.begin ();
      });
      
      p.account_removed.connect ((acc)=>{
        init_contacts.begin ();
      });
      
      p.buddy_added.connect ((buddy)=>{
        contact_changed (buddy, -1, 1);
      });
      p.buddy_removed.connect ((buddy)=>{
        contact_changed (buddy, -1, 0);
      });
      p.buddy_signed_on.connect ((buddy)=>{
        contact_changed (buddy, 1);
      });
      p.buddy_signed_off.connect ((buddy)=>{
        contact_changed (buddy, 0);
      });
      p.buddy_icon_changed.connect ((buddy)=>{
        contact_changed (buddy, -1, 0);
        contact_changed (buddy, -1, 1);
      });
    }
    
    private void contact_changed (int buddy, int online = -1, int addremove = -1)
    {
      if (online >= 0)
      {
        var contact = contacts[buddy];
        if (contact == null) return;
        contact.online = online > 0;
      }
      else if (addremove >= 0)
      {
        if (addremove == 1)
          get_contact (buddy);
        else
          contacts.unset (buddy);
      }
    }
    
    private Gee.List<BaseAction> actions;
    
    construct
    {
      actions = new Gee.ArrayList<BaseAction> ();
      actions.add (new SendToContact ());
      
      contacts = new Gee.HashMap<int, Contact> ();
      var service = DBusService.get_default ();
      
      if (service.name_has_owner (PurpleInterface.UNIQUE_NAME))
      {
        connect_to_bus ();
      }
      
      service.owner_changed.connect ((name, is_owned)=>{
        if (name == PurpleInterface.UNIQUE_NAME)
        {
          if (is_owned)
            connect_to_bus ();
          else
          {
            p = null;
            contacts.clear ();
          }
        }
      });
    }
    
    public ResultSet? find_for_match (ref Query query, Match match)
    {
      if (p == null) return null;
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
    
    private async void get_contact (int buddy, int account = -1, string? protocol = null) throws IOError
    {
      if (p == null) return;
      string prot = protocol;
      if (account < 0)
        account = p.purple_buddy_get_account (buddy);
      if (protocol == null)
        prot = p.purple_account_get_protocol_name (account);
      
      string alias = p.purple_buddy_get_alias (buddy);
      string name = p.purple_buddy_get_name (buddy);
      
      bool online = p.purple_buddy_is_online (buddy) > 0;
      
      if (alias == null || alias == "") alias = name;
      
      int iconid = p.purple_buddy_get_icon (buddy);
      string icon = null;
      if (iconid > 0)
        icon = p.purple_buddy_icon_get_full_path (iconid);
      
      contacts[buddy] = new Contact (this, account, buddy, name, online, alias, icon, "%s (%s)".printf (name, prot));
    }
    
    private async void init_contacts ()
    {
      contacts.clear ();
      if (p == null) return;
      try {
        var accounts = p.purple_accounts_get_all_active ();
        foreach (var account in accounts)
        {
          if (p == null) return;
          var protocol = p.purple_account_get_protocol_name (account);
          var buddies = p.purple_find_buddies (account);
          
          foreach (var buddy in buddies)
          {
            if (p == null) return;
            yield get_contact (buddy, account, protocol);
          }
        }
      
      } catch (IOError err) {
        Utils.Logger.warning (this, "Cannot load Pidgin contacts");
      }
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
      
      var matches = contacts.entries;

      foreach (var contact in matches)
      {
        if (!contact.value.online) continue;
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (contact.value.title))
          {
            result.add (contact.value, matcher.value - Match.Score.INCREMENT_SMALL);
            break;
          }
        }
      }

      q.check_cancellable ();

      return result;
    }

    
  }
}
