# Main configuration
cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Project information
project (slingshot)
set (INDICATORTITLE "Slingshot")
set (INDICATORDESCRIPTION "Application menu")

# Set some variables
include (GNUInstallDirs)
set (DATADIR "${CMAKE_INSTALL_FULL_LIBDIR}/wingpanel")
set (PKGDATADIR "${DATADIR}")
set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}")
set (RELEASE_NAME "Donatello")
set (VERSION "0.8")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")

# Files
file (GLOB applications_menu "${CMAKE_CURRENT_SOURCE_DIR}/data/pantheon-applications.menu")

# Configuration file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/lib/synapse-core/config.h)

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

# Include CPack
include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# Option to configure the use of the unity integration
option (USE_UNITY "Use Unity integration" ON)
if (USE_UNITY)
  message ("-- Unity integration enabled")
  set (UNITY_DEPS unity)
  set (UNITY_OPTIONS --define=HAVE_UNITY)
else ()
  message ("-- Unity integration disabled")
endif ()

# Option to configure the use of the zeitgeist integration
option (USE_ZEITGEIST "Use Zeitgeist integration" ON)
if (USE_ZEITGEIST)
  message ("-- Zeitgeist integration enabled")
  set (ZEITGEIST_DEPS zeitgeist-2.0)
  set (ZEITGEIST_OPTIONS --define=HAVE_ZEITGEIST)
else ()
  message ("-- Zeitgeist integration disabled")
endif ()

# Gettext package
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Comment this out to enable C compiler warnings
add_definitions (-w)

# Load PkgConfig
find_package (PkgConfig)

# Check for Vala
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26.2" MINIMUM)

# Include vala precompile
include (ValaPrecompile)

# Synapse libraries
include_directories (${CMAKE_BINARY_DIR}/lib/synapse-core)
include_directories (${CMAKE_BINARY_DIR}/lib/synapse-plugins)

# Link some libraries
add_definitions (${DEPS_CFLAGS} -DGMENU_I_KNOW_THIS_IS_UNSTABLE -include config.h)
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

# Installation
install (TARGETS ${APPNAME} RUNTIME DESTINATION bin)
install (FILES ${applications_menu} DESTINATION /etc/xdg/menus)
file (GLOB resources "${CMAKE_CURRENT_SOURCE_DIR}/data/*")

# Settings schema
include (GSettings)
add_schema ("org.pantheon.desktop.slingshot.gschema.xml")

# Directories
add_subdirectory (lib/synapse-core)
add_subdirectory (lib/synapse-plugins)
add_subdirectory (src)
add_subdirectory (po)
