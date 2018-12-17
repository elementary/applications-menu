
synapse_core_sources = [
    'common-actions.vala',
    'config-service.vala',
    'data-sink.vala',
    'dbus-service.vala',
    'desktop-file-service.vala',
    'match.vala',
    'plugin.vala',
    'query.vala',
    'relevancy-service.vala',
    'result-set.vala',
    'utils.vala',
    'volume-service.vala'
    ]

synapse_core_dir = include_directories('.')
    
synapse_core = static_library('synapse-core',
                        synapse_core_sources,
                        include_directories : synapse_core_dir,
                        dependencies :  [
                            dependency('glib-2.0'),
                            dependency('gio-unix-2.0'),
                            dependency('json-glib-1.0'),
                            dependency('gee-0.8'),
                            dependency('gtk+-3.0'),
                            dependency('zeitgeist-2.0')
                        ],
                        c_args : '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
                        install : true)