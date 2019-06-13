synapse_plugins_sources = [
    'calculator-plugin.vala',
    'command-plugin.vala',
    'desktop-file-plugin.vala',
    'switchboard-plugin.vala',
    'system-managment.vala',
    'link-plugin.vala',
    'appcenter-plugin.vala',
    'window-switcher-plugin.vala'
    ]

synapse_plugins_deps = [
    glib_dep,
    gio_unix_dep,
    json_glib_dep,
    gee_dep,
    gtk_dep,
    switchboard_dep,
    synapse_core_dep,
    wnck_dep
]


synapse_plugins = static_library('synapse-plugins',
                        synapse_plugins_sources,
                        link_with: synapse_core,
                        dependencies: synapse_plugins_deps,
                        c_args : ['-DGMENU_I_KNOW_THIS_IS_UNSTABLE','-DWNCK_I_KNOW_THIS_IS_UNSTABLE'],
                        install : true)

synapse_plugins_dep = declare_dependency(
    link_with: synapse_plugins,
    include_directories: include_directories('.')
)
