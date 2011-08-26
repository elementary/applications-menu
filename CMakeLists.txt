# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)

project (slingshot)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/slingshot")
set (GETTEXT_PACKAGE "slingshot")
set (RELEASE_NAME "Slingshot is a lightweight app launcher for Elementary, written in Vala and utilizing GTK+ and Cairo.")
set (VERSION "0.2")
set (VERSION_INFO "Testing")

# Files

file (GLOB imagefiles "${CMAKE_CURRENT_SOURCE_DIR}/data/style/images/*")
file (GLOB stylesheets "${CMAKE_CURRENT_SOURCE_DIR}/data/style/*.css")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)
add_definitions(-include config.h)

# Slingshot

set (SLINGSHOT_DEPS "gobject-2.0;glib-2.0;gio-2.0;gio-unix-2.0;gee-1.0;gtk+-3.0;libgnome-menu;granite;")

find_package (PkgConfig)
pkg_check_modules (GLIB REQUIRED "glib-2.0 >= 2.26.0")
pkg_check_modules (GOBJECT REQUIRED "gobject-2.0 >= 2.26.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26.0")
pkg_check_modules (GIOUNIX REQUIRED "gio-unix-2.0 >= 2.26.0")
pkg_check_modules (GEE REQUIRED "gee-1.0")
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.0.8")
pkg_check_modules (LIBGNOME REQUIRED "libgnome-menu")
pkg_check_modules (LIBGRANITE REQUIRED "granite")
pkg_check_modules (DEPS REQUIRED ${SLINGSHOT_DEPS})

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
    src/Slingshot.vala
    src/SlingshotView.vala
    src/Settings.vala
    src/Utils.vala
    src/Widgets/App.vala
    src/Widgets/Grid.vala
PACKAGES
	${SLINGSHOT_DEPS}
CUSTOM_VAPIS
    vapi/config.vapi
OPTIONS
	--thread
    --save-temps
)

add_definitions (${CFLAGS} -DGMENU_I_KNOW_THIS_IS_UNSTABLE -g)
add_executable (slingshot ${VALA_C})

# Installation
install (TARGETS slingshot RUNTIME DESTINATION bin)
install (FILES ${imagefiles} DESTINATION ${PKGDATADIR}/style/images)
install (FILES ${stylesheets} DESTINATION ${PKGDATADIR}/style)


#
# GSettings Schema
#
SET (SLINGSHOT_SCHEMAS "org.elementary.slingshot.gschema.xml")

# Have an option to not install the schema into where GLib is
option (GSETTINGS_LOCALINSTALL "Install GSettings Schemas locally instead of to the GLib prefix" OFF)
if (GSETTINGS_LOCALINSTALL)
    SET (GSETTINGS_DIR "${CMAKE_INSTALL_PREFIX}/share/glib-2.0/schemas/")
else (GSETTINGS_LOCALINSTALL)
    execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} glib-2.0 --variable prefix OUTPUT_VARIABLE _glib_prefix OUTPUT_STRIP_TRAILING_WHITESPACE)
    SET (GSETTINGS_DIR "${_glib_prefix}/share/glib-2.0/schemas/")
endif (GSETTINGS_LOCALINSTALL)

# Run the validator and error if it fails
execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} gio-2.0 --variable glib_compile_schemas  OUTPUT_VARIABLE _glib_comple_schemas OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process (COMMAND ${_glib_comple_schemas} --dry-run --schema-file=${CMAKE_CURRENT_SOURCE_DIR}/${SLINGSHOT_SCHEMAS} ERROR_VARIABLE _schemas_invalid OUTPUT_STRIP_TRAILING_WHITESPACE)

if (_schemas_invalid)
  message (SEND_ERROR "Schema validation error: ${_schemas_invalid}")
endif (_schemas_invalid)

# Actually install and recomple schemas
message (STATUS "GSettings schemas will be installed into ${GSETTINGS_DIR}")
install (FILES ${SLINGSHOT_SCHEMAS} DESTINATION ${GSETTINGS_DIR} OPTIONAL)
install (CODE "message (STATUS \"Compiling GSettings schemas\")")
install (CODE "execute_process (COMMAND ${_glib_comple_schemas} ${GSETTINGS_DIR})")
