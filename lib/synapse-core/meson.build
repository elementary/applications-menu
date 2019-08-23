zeitgeist_backend_source = []

if get_option('with-zeitgeist')
    zeitgeist_backend_source = [
        'relevancy-backend-zg.vala'
    ]
endif

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
    'volume-service.vala',
    zeitgeist_backend_source
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

synapse_core_deps = [
    glib_dep,
    gio_unix_dep,
    json_glib_dep,
    gee_dep,
    gtk_dep,
    zeitgeist_dep
]
   
synapse_core = static_library(
    'synapse-core',
    synapse_core_sources,
    config_file,
    dependencies: synapse_core_deps,
    c_args : '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
    install : false
)

synapse_core_dep = declare_dependency(
    link_with: synapse_core,
    include_directories: include_directories('.')
)
