plugin_test = executable(
    meson.project_name() + '-test',
    'PluginTest.vala',
    meson.source_root() + '/src/synapse-plugins/calculator-plugin/calculator-plugin-backend.vala',
    dependencies: [
        glib_dep,
        gio_dep,
        gio_unix_dep,     
    ]
)

test('Plugin core test', plugin_test)
