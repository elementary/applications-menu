project(
  'slingshot',
  'vala', 'c',
  version : '8.0.1',
  meson_version: '>=0.58.0'
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

prefix = get_option('prefix')
datadir = prefix / get_option('datadir')
libdir = prefix / get_option('libdir')

add_project_arguments(
    '-DPKGDATADIR="@0@"'.format(libdir / 'wingpanel'),
    language: 'c'
)

pluginsdir = libdir / 'io.elementary.wingpanel.applications-menu'
add_project_arguments(
    '-DPLUGINSDIR="@0@"'.format(pluginsdir),
    language: 'c'
)

glib_dep = dependency('glib-2.0')
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk4')
granite_dep = dependency('granite-7', version: '>=6.1.0')
gobject_dep = dependency('gobject-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
json_glib_dep = dependency('json-glib-1.0')
switchboard_dep = dependency('switchboard-3')
libhandy_dep = dependency('libadwaita-1', version: '>= 0.83.0')
wingpanel_dep = dependency('wingpanel-8', version: '>=2.1.0')
posix_dep = meson.get_compiler('vala').find_library('posix')

zeitgeist_dep = []

if get_option('with-zeitgeist')
    zeitgeist_dep = dependency('zeitgeist-2.0')
    add_project_arguments('--define=HAVE_ZEITGEIST', language: 'vala')
endif

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', prefix / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

subdir('src')
subdir('data')
subdir('po')

gnome.post_install(glib_compile_schemas: true)
