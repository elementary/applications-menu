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
  // verbatim string
  private const string GOOGLE_SEARCH_XML = """
<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
  <ShortName>Google</ShortName>
  <Description>Search the web using google.com</Description>
  <Url type="text/html" method="get" template="http://www.google.com/search?q={searchTerms}&amp;hl={language}"/>
  <Url type="application/x-suggestions+json" template="http://suggestqueries.google.com/complete/search?output=firefox&amp;client=firefox&amp;hl=en&amp;q={searchTerms}"/>

  <Developer>Synapse dev team</Developer>
  <InputEncoding>UTF-8</InputEncoding>
</OpenSearchDescription>
""";
  private const string GOOGLE_MAPS_XML = """
<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
  <ShortName>Google Maps</ShortName>
  <Description>Search using Google Maps</Description>
  <Url type="text/html" method="get" template="http://maps.google.com/maps?q={searchTerms}&amp;hl={language}"/>

  <Developer>Synapse dev team</Developer>
  <InputEncoding>UTF-8</InputEncoding>
</OpenSearchDescription>
""";

  public class OpenSearchPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      actions = new Gee.ArrayList<SearchAction> ();
      load_xmls.begin ();
    }

    public void deactivate ()
    {
      
    }

    private class OpenSearchParser: Object
    {
      const MarkupParser parser =
      {
        start, end, text, null, null
      };

      MarkupParseContext context;
      bool is_opensearch = false;
      bool in_name_elem = false;
      bool in_description_elem = false;

      bool has_name = false;
      bool has_desc = false;
      bool has_url = false;

      public string short_name { get; set; }
      public string description { get; set; }
      public string query_url { get; set; }
      public string suggestion_url { get; set; }
      
      construct
      {
        context = new MarkupParseContext (parser, 0, this, null);
      }

      public bool parse (string content) throws MarkupError
      {
        return context.parse (content, -1);
      }
      
      public bool has_valid_result ()
      {
        return is_opensearch && has_name && has_desc && has_url;
      }

      private void process_url (string[] attrs, string[] vals)
      {
        uint len = strv_length (attrs);
        bool main_type = false;
        bool suggestion_type = false;
        
        for (uint i=0; i<len; i++)
        {
          switch (attrs[i])
          {
            case "type":
              if (vals[i] == "text/html") main_type = true;
              else if (vals[i] == "application/x-suggestions+json") suggestion_type = true;
              break;
            case "template":
              if (main_type)
              {
                query_url = vals[i];
                has_url = true;
              }
              else if (suggestion_type) suggestion_url = vals[i];
              break;
            default: break;
          }
        }
      }

      private void start (MarkupParseContext ctx, string name,
                          string[] attr_names, string[] attr_vals) throws MarkupError
      {
        switch (name)
        {
          case "SearchPlugin": //try to support Mozilla OpenSearch xmls
            if ("xmlns:os" in attr_names)
              is_opensearch = true;
            break;
          case "OpenSearchDescription": is_opensearch = true; break;
          case "os:ShortName":
          case "ShortName": has_name = true; in_name_elem = true; break;
          case "os:Description":
          case "Description": has_desc = true; in_description_elem = true; break;
          case "os:Url":
          case "Url": process_url (attr_names, attr_vals); break;
          default: break;
        }
      }
      
      private void end (MarkupParseContext ctx, string name) throws MarkupError
      {
        switch (name)
        {
          case "os:ShortName":
          case "ShortName": in_name_elem = false; break;
          case "os:Description":
          case "Description": in_description_elem = false; break;
          default: break;
        }
      }
      
      private void text (MarkupParseContext ctx, string text, size_t text_len) throws MarkupError
      {
        if (in_name_elem) short_name = text;
        else if (in_description_elem) description = text;
      }
    }
    
    private class SearchAction: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; default = Match.Score.INCREMENT_MINOR; }
      public string query_template { get; construct set; }

      public void execute (Match? match)
      {
        try
        {
          string what = (match is TextMatch) ?
            (match as TextMatch).get_text () : match.title;
          AppInfo.launch_default_for_uri (get_query_url (what),
                                          new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      protected string get_query_url (string query)
      {
        string result;
        result = query_template.replace ("{searchTerms}",
                                         Uri.escape_string (query, "", false));
        result = result.replace ("{language}", get_lang ());
        // FIXME: remove all other "{codes}"

        return result;
      }
      
      protected string get_lang ()
      {
        string? result = null;
        foreach (unowned string lang in Intl.get_language_names ())
        {
          if (lang.length == 2)
          {
            result = lang;
            break;
          }
        }

        return result ?? "en";
      }

      public SearchAction (string name, string description, string url)
      {
        Object (title: name,
                description: description,
                query_template: url,
                has_thumbnail: false, icon_name: "applications-internet");
      }
    }
    
    private class Config: ConfigObject
    {
      public bool use_internal { get; set; default = true; }

      private string[] _search_engines;
      public string[] search_engines
      {
        get
        {
          return _search_engines;
        }
        set
        {
          _search_engines = value;
        }
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (OpenSearchPlugin),
        "OpenSearch",
        _ ("Search the web."),
        "applications-internet",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();

      // keep in sync with the internal XMLs!
      unowned string dummy;
      dummy = N_ ("Google");
      dummy = N_ ("Search the web using google.com");
      dummy = N_ ("Google Maps");
      dummy = N_ ("Search using Google Maps");
    }

    private Gee.List<SearchAction> actions;
    private Config config;

    construct
    {
      var cs = ConfigService.get_default ();
      config = (Config) cs.get_config ("plugins", "opensearch", typeof (Config));
    }
    
    private async void load_xmls ()
    {
      OpenSearchParser parser;
      if (config.use_internal)
      {
        Gee.List<unowned string> internals = new Gee.ArrayList<unowned string> ();
        internals.add (GOOGLE_SEARCH_XML);
        internals.add (GOOGLE_MAPS_XML);
        foreach (unowned string s in internals)
        {
          parser = new OpenSearchParser ();
          try
          {
            parser.parse (s);
            if (parser.has_valid_result ())
            {
              actions.add (new SearchAction (_ (parser.short_name),
                                             _ (parser.description),
                                             parser.query_url));
            }
          }
          catch (Error no_way) { /* this really shouldn't happen */ }
        }
      }

      string[] xmls = config.search_engines;
      foreach (unowned string xml in xmls)
      {
        string xml_path = xml;
        if (xml_path.has_prefix ("~"))
        {
          xml_path = Environment.get_home_dir () +
                     xml_path.substring (1);
        }
        var f = File.new_for_path (xml_path);
        try
        {
          uint8[] file_contents;
          string contents;
          size_t len;
          yield f.load_contents_async (null, out file_contents, null);
          contents = (string) file_contents;
          len = file_contents.length;
          
          parser = new OpenSearchParser ();
          parser.parse (contents);
          if (parser.has_valid_result ())
          {
            actions.add (new SearchAction (parser.short_name,
                                           parser.description,
                                           parser.query_url));
          }
          else warning ("Unable to parse search plugin [%s]", xml);
        }
        catch (Error err)
        {
          warning ("Unable to load search plugin [%s]: %s", xml, err.message);
        }
      }
    }
    
    public bool handles_unknown ()
    {
      return true;
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      if (match.match_type != MatchType.UNKNOWN &&
          match.match_type != MatchType.TEXT)
      {
        return null;
      }
      var my_flags = QueryFlags.ACTIONS | QueryFlags.INTERNET;
      if ((query.query_type & my_flags) == 0) return null;

      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        foreach (var action in actions)
        {
          results.add (action, action.default_relevancy);
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.CASELESS);
        foreach (var item in actions)
        {
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (item.title))
            {
              results.add (item, matcher.value);
              break;
            }
          }
        }
      }

      return results;
    }
  }
}
