project(
  'slingshot',
  'vala', 'c',
  version : '2.1.2'
)

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

gettext_name = meson.project_name()
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_name), language:'c')
add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], 
                      language: 'vala')

subdir('data')
subdir('po')
subdir('lib')
subdir('src')

meson.add_install_script('meson/post_install.py')