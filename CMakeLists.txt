# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (slingshot)

set (APPNAME "${CMAKE_PROJECT_NAME}-launcher")
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}")
set (RELEASE_NAME "Donatello")
set (VERSION "0.8.1.1")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")

# Files
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

option (USE_UNITY "Use Unity integration" ON)

if (USE_UNITY)
  message ("-- Unity integration enabled")
  set (UNITY_DEPS unity)
  set (UNITY_OPTIONS --define=HAVE_UNITY)
else ()
  message ("-- Unity integration disabled")
endif ()

option (USE_ZEITGEIST "Use Zeitgeist integration" ON)

if (USE_ZEITGEIST)
  message ("-- Zeitgeist integration enabled")
  set (ZEITGEIST_DEPS zeitgeist-2.0)
  set (ZEITGEIST_OPTIONS --define=HAVE_ZEITGEIST)
else ()
  message ("-- Zeitgeist integration disabled")
endif ()

find_package (PkgConfig)
 
pkg_check_modules(PLANK011 QUIET plank>=0.10.9)
if (PLANK011_FOUND)
  set (PLANK_DEPS plank)
  set (PLANK_OPTIONS --define=HAS_PLANK --define=HAS_PLANK_0_11)
else ()
  pkg_check_modules(PLANK QUIET plank>=0.9.0)
  if (PLANK_FOUND)
    set (PLANK_DEPS plank)
    set (PLANK_OPTIONS --define=HAS_PLANK)
  endif ()
endif ()

set (CORE_DEPS "gobject-2.0;glib-2.0;gio-2.0;gio-unix-2.0;libsoup-2.4;gee-0.8;libgnome-menu-3.0;json-glib-1.0;${UNITY_DEPS};${PLANK_DEPS};")
set (UI_DEPS "gtk+-3.0>=3.12.0;granite;${ZEITGEIST_DEPS};")

pkg_check_modules (DEPS REQUIRED "${CORE_DEPS}${UI_DEPS}" gthread-2.0)

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26.2" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C ${APPNAME}
    src/Slingshot.vala
    src/SlingshotView.vala
    src/Settings.vala
    src/Utils.vala
    src/Pixels.vala
    src/Backend/AppSystem.vala
    src/Backend/DBusService.vala
    src/Backend/App.vala
    src/Backend/RelevancyService.vala
    src/Backend/SynapseSearch.vala
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
    synapse-core
    synapse-plugins
CUSTOM_VAPIS
    vapi/config.vapi
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

include_directories(${CMAKE_BINARY_DIR}/lib/synapse-core)
include_directories(${CMAKE_BINARY_DIR}/lib/synapse-plugins)

add_subdirectory(lib/synapse-core)
add_subdirectory(lib/synapse-plugins)

# Comment this out to enable C compiler warnings
add_definitions (-w)

add_definitions (${DEPS_CFLAGS} -DGMENU_I_KNOW_THIS_IS_UNSTABLE -include config.h)
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

add_executable (${APPNAME} ${VALA_C})
target_link_libraries(${APPNAME} m synapse-core synapse-plugins)

# Installation
install (TARGETS ${APPNAME} RUNTIME DESTINATION bin)
install (FILES ${applications_menu} DESTINATION /etc/xdg/menus)

#
# GSettings Schema
#
include (GSettings)
add_schema ("org.pantheon.desktop.slingshot.gschema.xml")

# Translations
add_subdirectory (po)
