calculator_plugin_test = executable(
    meson.project_name() + 'calculator-test',
    'CalculatorPluginTest.vala',
    meson.source_root() + '/src/synapse-plugins/calculator-plugin/calculator-plugin-backend.vala',
    dependencies: [
        glib_dep,
        gio_dep,
        gio_unix_dep,     
    ]
)
converter_plugin_test = executable(
    meson.project_name() + 'converter-test',
    'ConverterPluginTest.vala',
    meson.source_root() + '/src/synapse-plugins/converter-plugin/converter-plugin-backend.vala',
    meson.source_root() + '/src/synapse-plugins/converter-plugin/converter-data.vala',
    dependencies: [
        glib_dep,
        gio_dep,
        gio_unix_dep,     
    ]
)

test('Calculator Plugin core test', calculator_plugin_test)
test('Converter Plugin core test', converter_plugin_test)
