set(PLUGINS_LIB_VERSION 0.1)
set(PLUGINS_LIB_SOVERSION 0)
set(PLUGINS_LIBRARY_NAME synapse-plugins)
set(PLUGINS_PKG
	glib-2.0
	zeitgeist-1.0
	gio-unix-2.0
	json-glib-1.0
	gee-0.8
	libnotify
	gtk+-3.0
	libsoup-2.4
	rest-0.7
	folks
	folks-telepathy
)

pkg_check_modules(PLUGINS_DEPS REQUIRED ${PLUGINS_PKG})

set(PLUGINS_SOURCE
	banshee-plugin.vala
	calculator-plugin.vala
	chat-actions-plugin.vala
	chromium-plugin.vala
	command-plugin.vala
	desktop-file-plugin.vala
	devhelp-search.vala
	dictionary.vala
	directory-plugin.vala
	file-op-plugin.vala
	gnome-screensaver-plugin.vala
	gnome-session-plugin.vala
	hello-world-plugin.vala
	hybrid-search-plugin.vala
	imgur-plugin.vala
	launchpad-plugin.vala
	locate-plugin.vala
	opensearch.vala
	pastebin-plugin.vala
	pidgin-plugin.vala
	rhythmbox-plugin.vala
	selection-plugin.vala
	ssh-plugin.vala
	system-management.vala
	telepathy-plugin.vala
	test-slow-plugin.vala
	xnoise-media-player-plugin.vala
	wolframalpha-plugin.vala
	zeitgeist-plugin.vala
	zeitgeist-related.vala
)

set(LINK_MODE STATIC)

vala_precompile(PLUGINS_VALA_C ${PLUGINS_LIBRARY_NAME}
	${PLUGINS_SOURCE}
PACKAGES
	${PLUGINS_PKG}
	synapse-core
OPTIONS
	--vapidir=${CMAKE_BINARY_DIR}/lib/synapse-core
GENERATE_VAPI
	${PLUGINS_LIBRARY_NAME}
GENERATE_HEADER
	${PLUGINS_LIBRARY_NAME}
)

add_definitions(${PLUGINS_DEPS_CFLAGS} -include config.h)
link_directories(${PLUGINS_DEPS_LIBRARY_DIRS})
include_directories(${CMAKE_BINARY_DIR}/lib/synapse-core)

add_library(${PLUGINS_LIBRARY_NAME} STATIC ${PLUGINS_VALA_C})

set_target_properties(${PLUGINS_LIBRARY_NAME} PROPERTIES
	OUTPUT_NAME ${PLUGINS_LIBRARY_NAME}
	VERSION ${PLUGINS_LIB_VERSION}
	SOVERSION ${PLUGINS_LIB_SOVERSION}
)

target_link_libraries (${PLUGINS_LIBRARY_NAME} ${PLUGINS_DEPS_LIBRARIES} synapse-core)

