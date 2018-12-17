synapse_plugins_sources = [
    'calculator-plugin.vala',
    'command-plugin.vala',
    'desktop-file-plugin.vala',
    'switchboard-plugin.vala',
    'system-managment.vala',
    'link-plugin.vala',
    'appcenter-plugin.vala'
    ]

synapse_plugins_dir = include_directories('.')

synapse_plugins = static_library('synapse-plugins',
                        synapse_plugins_sources,
                        link_with : synapse_core,
                        include_directories : [synapse_core_dir, synapse_plugins_dir],
                        dependencies :  [
                            dependency('glib-2.0'),
                            dependency('gio-unix-2.0'),
                            dependency('json-glib-1.0'),
                            dependency('gee-0.8'),
                            dependency('gtk+-3.0'),
                            dependency('switchboard-2.0')
                        ],
                        c_args : '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
                        install : true)
