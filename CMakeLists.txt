# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (slingshot)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/slingshot")
set (GETTEXT_PACKAGE "slingshot")
set (RELEASE_NAME "Donatello")
set (VERSION "0.7.2")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")

# Files

#file (GLOB stylesheets "${CMAKE_CURRENT_SOURCE_DIR}/data/style/*.css")
file (GLOB applications_menu "${CMAKE_CURRENT_SOURCE_DIR}/data/pantheon-applications.menu")

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# Slingshot

set (CORE_DEPS "gobject-2.0;glib-2.0;gio-2.0;gio-unix-2.0;gee-1.0;libgnome-menu;libwnck-3.0;gdk-x11-3.0;unity;")
set (UI_DEPS "gtk+-3.0>=3.2.0;granite;zeitgeist-1.0;")

find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED "${CORE_DEPS}${UI_DEPS}" gthread-2.0)

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.15.1" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
    src/Slingshot.vala
    src/SlingshotView.vala
    src/Settings.vala
    src/Utils.vala
    src/Backend/AppSystem.vala
    src/Backend/DBusService.vala
    src/Backend/App.vala
    src/Backend/RelevancyService.vala
    src/Widgets/AppEntry.vala
    src/Widgets/Grid.vala
    src/Widgets/Switcher.vala
    src/Widgets/SearchView.vala
    src/Widgets/SearchItem.vala
    src/Widgets/Sidebar.vala
    src/Widgets/CategoryView.vala
PACKAGES
    ${CORE_DEPS}
    ${UI_DEPS}
CUSTOM_VAPIS
    vapi/config.vapi
OPTIONS
	--thread
    -g
)

add_definitions (${DEPS_CFLAGS} -DGMENU_I_KNOW_THIS_IS_UNSTABLE -DWNCK_I_KNOW_THIS_IS_UNSTABLE -include config.h)
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

add_executable (slingshot-launcher ${VALA_C})
target_link_libraries(slingshot-launcher m)

# Installation
install (TARGETS slingshot-launcher RUNTIME DESTINATION bin)
install (FILES ${applications_menu} DESTINATION /etc/xdg/menus)

#
# GSettings Schema
#
include (GSettings)
add_schema ("org.pantheon.desktop.slingshot.gschema.xml")

# Translations
add_subdirectory (po)
