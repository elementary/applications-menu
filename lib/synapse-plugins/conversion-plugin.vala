/*
* Copyright (c) 2018 Peter Uithoven <peter@peteruithoven.nl>
*               2018 elementary LLC.
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
* Authored by: Peter Uithoven <peter@peteruithoven.nl>
*/

namespace Synapse {
    public class ConversionPlugin: Object, Activatable, ItemProvider {
        public bool enabled { get; set; default = true; }

        public void activate () { }
        public void deactivate () { }

        private class Result: Object, Match {
            // from Match interface
            public string title { get; construct set; }
            public string description { get; set; }
            public string icon_name { get; construct set; }
            public bool has_thumbnail { get; construct set; }
            public string thumbnail_path { get; construct set; }
            public MatchType match_type { get; construct set; }

            public int default_relevancy { get; set; default = 0; }

            public Result (string result, string match_string) {
                Object (match_type: MatchType.TEXT,
                        title: result,
                        description: result,
                        has_thumbnail: false, icon_name: "accessories-calculator");
            }
        }

        static void register_plugin () {
            DataSink.PluginRegistry.get_default ().register_plugin (typeof (ConversionPlugin),
                                                                    _("Conversion"),
                                                                    _("Unit conversion."),
                                                                    "accessories-calculator",
                                                                    register_plugin,
                                                                    Environment.find_program_in_path ("qalc") != null,
                                                                    _("qalc is not installed"));
        }

        static construct {
            register_plugin ();
        }

        private Regex regex;

        construct {
            /* The regex describes a string which *resembles* a unit conversion expression.
            Basically it matches strings of the form:
            "number unit to unit"
            */
            try {
                regex = new Regex ("^(-?\\d+([.,]\\d+)?)\\s*([\\w/]+)\\s+(to)\\s+([\\w/]+)$", RegexCompileFlags.OPTIMIZE);
            } catch (Error e) {
                critical ("Error creating regexp: %s", e.message);
            }
        }

        public bool handles_query (Query query) {
            return (QueryFlags.ACTIONS in query.query_type);
        }
        
        public async ResultSet? search (Query query) throws SearchError {
            string input = query.query_string;
            bool matched = regex.match (input);
            if (matched) {
                try {
                    string[] command = get_command(input);
                    Subprocess subprocess = new Subprocess.newv (command, SubprocessFlags.STDOUT_PIPE);
                    string output = get_output(subprocess);
                    
                    if (yield subprocess.wait_check_async ()) {
                        Result result = new Result (output, input);
                        ResultSet results = new ResultSet ();
                        results.add (result, Match.Score.AVERAGE);
                        query.check_cancellable ();
                        return results;
                    }
                } catch (Error e) {
                    if (!query.is_cancelled ()) {
                        error ("error: %s\n", e.message);
                    }
                }
            }

            query.check_cancellable ();
            return null;
        }
        
        private string[] get_command (string query) {
            var array = new GenericArray<string> ();
            array.add ("qalc");
            array.add (query);
            return array.data;
        }
        
        private string get_output (Subprocess subprocess) {
            InputStream stdout_stream = subprocess.get_stdout_pipe ();
            DataInputStream stdout_datastream = new DataInputStream (stdout_stream);
            string stdout_text = "";
            string stdout_line = "";
            while ((stdout_line = stdout_datastream.read_line (null)) != null) {
                stdout_text += stdout_line + "\n";
            }
            return stdout_text.strip();
        }
    }
}
