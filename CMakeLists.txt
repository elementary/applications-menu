# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (slingshot)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/slingshot")
set (GETTEXT_PACKAGE "slingshot")
set (RELEASE_NAME "Slingshot is a lightweight app launcher for Elementary, written in Vala and utilizing GTK+ and Cairo.")
set (VERSION "0.4")
set (VERSION_INFO "Testing")

# Files

file (GLOB stylesheets "${CMAKE_CURRENT_SOURCE_DIR}/data/style/*.css")

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

# Slingshot

set (SLINGSHOT_DEPS "gobject-2.0;glib-2.0;gio-2.0;gio-unix-2.0;gee-1.0;gtk+-3.0;libgnome-menu;granite")

find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED ${SLINGSHOT_DEPS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
    src/Slingshot.vala
    src/SlingshotView.vala
    src/Settings.vala
    src/Utils.vala
    src/Backend/AppSystem.vala    
    src/Backend/App.vala
    src/Widgets/AppEntry.vala
    src/Widgets/Grid.vala
    src/Widgets/Switcher.vala
    src/Widgets/SearchView.vala
    src/Widgets/SearchItem.vala
PACKAGES
	${SLINGSHOT_DEPS}
CUSTOM_VAPIS
    vapi/config.vapi
OPTIONS
	--thread
)

add_definitions (${DEPS_CFLAGS} -DGMENU_I_KNOW_THIS_IS_UNSTABLE -include config.h)
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

add_executable (slingshot ${VALA_C})

# Installation
install (TARGETS slingshot RUNTIME DESTINATION bin)
install (FILES ${stylesheets} DESTINATION ${PKGDATADIR}/style)


#
# GSettings Schema
#
include (GSettings)
add_schema ("org.elementary.slingshot.gschema.xml")
