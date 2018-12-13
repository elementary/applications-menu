
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

#
# Configuration file
#
config_data = configuration_data()
config_data.set('DATADIR', join_paths(get_option('prefix'), get_option('libdir'), 'wingpanel'))
config_data.set('PKGDATADIR', join_paths(get_option('prefix'), get_option('libdir'), 'wingpanel'))
config_data.set('GETTEXT_PACKAGE', meson.project_name())
config_data.set('RELEASE_NAME', 'Donatello')
config_data.set('VERSION', meson.project_version())
config_data.set('VERSION_INFO', 'Release')

config_file = configure_file(
    input: 'config.h.in',
    output: 'config.h',
    configuration: config_data
)

synapse_core_dir = include_directories('.')
    
synapse_core = static_library('synapse-core',
                        synapse_core_sources,
                        config_file,
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