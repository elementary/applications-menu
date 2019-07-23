# Some dependencies
set (CORE_DEPS "gobject-2.0;gio-2.0;gio-unix-2.0;libsoup-2.4;gee-0.8;libgnome-menu-3.0;${UNITY_DEPS};${PLANK_DEPS};")
set (UI_DEPS "gtk+-3.0>=3.12.0;granite;wingpanel-2.0;${ZEITGEIST_DEPS};")

# Check for these dependencies
pkg_check_modules (DEPS REQUIRED "${CORE_DEPS}${UI_DEPS}" gthread-2.0)

# Compiling options
vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
    Slingshot.vala
    SlingshotView.vala
    Settings.vala
    Pixels.vala
    Backend/AppSystem.vala
    Backend/DBusService.vala
    Backend/App.vala
    Backend/RelevancyService.vala
    Backend/SynapseSearch.vala
    Backend/AppCenter.vala
    Widgets/AppEntry.vala
    Widgets/Grid.vala
    Widgets/Switcher.vala
    Widgets/SearchView.vala
    Widgets/SearchItem.vala
    Widgets/Sidebar.vala
    Widgets/CategoryView.vala
    Widgets/PageChecker.vala
PACKAGES
    ${CORE_DEPS}
    ${UI_DEPS}
    synapse-core
    synapse-plugins
    appstream
CUSTOM_VAPIS
    ../vapi/config.vapi
OPTIONS
    --thread
    --target-glib=2.32
    --vapidir=${CMAKE_BINARY_DIR}/lib/synapse-core
    --vapidir=${CMAKE_BINARY_DIR}/lib/synapse-plugins
    -g
    ${UNITY_OPTIONS}
    ${ZEITGEIST_OPTIONS}
    ${PLANK_OPTIONS}
)

add_definitions(${DEPS_CFLAGS})

include (GResource)
glib_compile_resources (GLIB_RESOURCES_ICONS SOURCE ../data/icons.gresource.xml)

# Library
add_library (${CMAKE_PROJECT_NAME} MODULE ${VALA_C} ${GLIB_RESOURCES_ICONS})
target_link_libraries(${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

target_link_libraries(${CMAKE_PROJECT_NAME} synapse-plugins)

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} DESTINATION ${PKGDATADIR})
