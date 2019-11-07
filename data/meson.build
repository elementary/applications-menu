i18n.merge_file(
    input: 'applications-menu.appdata.xml.in',
    output: 'io.elementary.wingpanel.applications-menu.appdata.xml',
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    type: 'xml',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
)

install_data(
    'io.elementary.desktop.wingpanel.applications-menu.gschema.xml',
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

install_data(
    'pantheon-applications.menu',
    install_dir: join_paths(get_option('sysconfdir'), 'xdg', 'menus')
)
