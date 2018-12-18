project(
  'slingshot',
  'vala', 'c',
  version : '2.1.2'
)

i18n = import('i18n')
gnome = import('gnome')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

asresources = gnome.compile_resources(
    'as-resources', 'data/icons.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

glib_dep = dependency('glib-2.0')
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk+-3.0')
granite_dep = dependency('granite')
gobject_dep = dependency('gobject-2.0')
libsoup_dep = dependency('libsoup-2.4')
appstream_dep = dependency('appstream')
gio_unix_dep = dependency('gio-unix-2.0')
json_glib_dep = dependency('json-glib-1.0')
zeitgeist_dep = dependency('zeitgeist-2.0')
switchboard_dep = dependency('switchboard-2.0')
libgnome_menu_dep = dependency('libgnome-menu-3.0')
wingpanel_dep = dependency('wingpanel-2.0', version: '>=2.1.0')

unity_dep = []
plank_dep = []

if get_option('with-unity')
    unity_dep = dependency('unity', version: '>=4.0.0')
    add_project_arguments('--define=HAVE_UNITY', language: 'vala')

    plank_dep = dependency('plank')
    if plank_dep.version().version_compare('>=0.10.9')
        add_project_arguments('--define=HAS_PLANK_0_11', language: 'vala')
    endif
    if plank_dep.version().version_compare('>=0.9.0')
        add_project_arguments('--define=HAS_PLANK', language: 'vala')
    endif
endif

subdir('lib')
subdir('src')
subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')