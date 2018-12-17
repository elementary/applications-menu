
wingpanel_dep = dependency('wingpanel-2.0', version: '>=2.1.0')

files = files(
    'Slingshot.vala',
    'SlingshotView.vala',
    'Settings.vala',
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
    'Widgets/PageChecker.vala'
)

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gio-unix-2.0'),
    dependency('granite'),
    dependency('gtk+-3.0'),
    dependency('gee-0.8'),
    dependency('switchboard-2.0'),
    dependency('json-glib-1.0'),
    dependency('zeitgeist-2.0'),
    dependency('libgnome-menu-3.0'),
    dependency('libsoup-2.4'),
    dependency('unity'),
    dependency('plank'),
    dependency('appstream'),
    meson.get_compiler('vala').find_library('posix'),
    wingpanel_dep
]

shared_module(
    meson.project_name(),
    files,
    dependencies: dependencies,
    vala_args: [
        meson.source_root() + '/vapi/config.vapi'
    ],
    link_with: [synapse_core, synapse_plugins],
    include_directories: [synapse_core_dir, synapse_plugins_dir],
    c_args : '-DGMENU_I_KNOW_THIS_IS_UNSTABLE',
    install: true,
    install_dir: wingpanel_dep.get_pkgconfig_variable('indicatorsdir')
)