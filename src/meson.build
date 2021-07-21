zeitgeist_backend_source = []
if get_option('with-zeitgeist')
    zeitgeist_backend_source = [
        'synapse-core/relevancy-backend-zg.vala'
    ]
endif

sources = [
    'Indicator.vala',
    'SlingshotView.vala',

    'Backend/AppSystem.vala',
    'Backend/DBusService.vala',
    'Backend/App.vala',
    'Backend/RelevancyService.vala',
    'Backend/SynapseSearch.vala',
    'Backend/AppCenter.vala',
    'Backend/SwitcherooControl.vala',

    'Views/CategoryView.vala',
    'Views/GridView.vala',
    'Views/SearchView.vala',

    'Widgets/AppButton.vala',
    'Widgets/AppContextMenu.vala',
    'Widgets/AppListBox.vala',
    'Widgets/AppListRow.vala',
    'Widgets/Switcher.vala',
    'Widgets/SearchItem.vala',
    'Widgets/PageChecker.vala',

    'synapse-core/Actions/TerminalRunnerAction.vala',
    'synapse-core/Actions/RunnerAction.vala',
    'synapse-core/Actions/CommonAction.vala',
    'synapse-core/Actions/ClipboardCopyAction.vala',
    'synapse-core/Actions/BaseAction.vala',
    'synapse-core/Interfaces/ItemProvider.vala',
    'synapse-core/Interfaces/Configurable.vala',
    'synapse-core/Interfaces/Activatable.vala',
    'synapse-core/Interfaces/ActionProvider.vala',
    'synapse-core/Matches/UriMatch.vala',
    'synapse-core/Matches/TextMatch.vala',
    'synapse-core/Matches/SearchMatch.vala',
    'synapse-core/Matches/Match.vala',
    'synapse-core/Matches/DefaultMatch.vala',
    'synapse-core/Matches/ApplicationMatch.vala',
    'synapse-core/config-service.vala',
    'synapse-core/data-sink.vala',
    'synapse-core/dbus-service.vala',
    'synapse-core/desktop-file-service.vala',
    'synapse-core/query.vala',
    'synapse-core/relevancy-service.vala',
    'synapse-core/result-set.vala',
    'synapse-core/utils.vala',
    zeitgeist_backend_source,

    'synapse-plugins/worker-link.vala',
    'synapse-plugins/calculator-plugin.vala',
    'synapse-plugins/command-plugin.vala',
    'synapse-plugins/desktop-file-plugin.vala',
    'synapse-plugins/switchboard-plugin.vala',
    'synapse-plugins/system-managment.vala',
    'synapse-plugins/link-plugin.vala',
    'synapse-plugins/appcenter-plugin.vala',
    asresources
]

dependencies = [
    glib_dep,
    gobject_dep,
    gio_dep,
    gio_unix_dep,
    granite_dep,
    gee_dep,
    gtk_dep,
    json_glib_dep,
    zeitgeist_dep,
    libgnome_menu_dep,
    libsoup_dep,
    appstream_dep,
    plank_dep,
    wingpanel_dep,
    libhandy_dep,
    posix_dep,
]

wingpanel_indicatorsdir = wingpanel_dep.get_pkgconfig_variable('indicatorsdir', define_variable: ['libdir', libdir])

c_args = [
    '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
    '-DHANDY_USE_UNSTABLE_API',
]

shared_module(
    meson.project_name(),
    sources,
    dependencies: dependencies,
    c_args : c_args,
    install: true,
    install_dir: wingpanel_indicatorsdir
)

executable(
    'switchboard-plugin',
    'synapse-plugins/switchboard-plugin/plugin.vala',
    dependencies: [
        glib_dep,
        gobject_dep,
        gio_dep,
        gio_unix_dep,
        switchboard_dep,
        gee_dep,
    ],
    install: true,
    install_dir: pluginsdir
)
