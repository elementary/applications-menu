sources = [
    'Slingshot.vala',
    'SlingshotView.vala',
    'Utils.vala',
    'Pixels.vala',

    'Backend/AppSystem.vala',
    'Backend/DBusService.vala',
    'Backend/App.vala',
    'Backend/RelevancyService.vala',
    'Backend/SynapseSearch.vala',
    'Backend/AppCenter.vala',

    'Widgets/AppEntry.vala',
    'Widgets/Grid.vala',
    'Widgets/Switcher.vala',
    'Widgets/SearchView.vala',
    'Widgets/SearchItem.vala',
    'Widgets/Sidebar.vala',
    'Widgets/CategoryView.vala',
    'Widgets/PageChecker.vala',
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
    switchboard_dep,
    json_glib_dep,
    zeitgeist_dep,
    libgnome_menu_dep,
    libsoup_dep,
    appstream_dep,
    plank_dep,
    unity_dep,
    wingpanel_dep,
    synapse_core_dep,
    synapse_plugins_dep,
    meson.get_compiler('vala').find_library('config', dirs: join_paths(meson.source_root(), 'vapi'))
]

shared_module(
    meson.project_name(),
    sources,
    dependencies: dependencies,
    c_args : '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
    install: true,
    install_dir: wingpanel_dep.get_pkgconfig_variable('indicatorsdir')
)
