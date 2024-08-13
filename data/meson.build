i18n.merge_file(
    input: 'applications-menu.metainfo.xml.in',
    output: 'io.elementary.wingpanel.applications-menu.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: datadir / 'metainfo',
)

install_data(
    'io.elementary.desktop.wingpanel.applications-menu.gschema.xml',
    install_dir: datadir / 'glib-2.0' / 'schemas'
)

