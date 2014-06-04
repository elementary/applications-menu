set(CORE_LIB_VERSION 0.1)
set(CORE_LIB_SOVERSION 0)
set(CORE_LIBRARY_NAME synapse-core)
set(CORE_PKG
	glib-2.0
	zeitgeist-1.0
	gio-unix-2.0
	json-glib-1.0
	gee-0.8
	gtk+-3.0
)

pkg_check_modules(CORE_DEPS REQUIRED ${CORE_PKG})

set(CORE_SOURCE
	common-actions.vala
	config-service.vala
	data-sink.vala
	dbus-service.vala
	desktop-file-service.vala
	match.vala
	plugin.vala
	query.vala
	relevancy-backend-zg.vala
	relevancy-service.vala
	result-set.vala
	utils.vala
	volume-service.vala
)

set(LINK_MODE STATIC)

vala_precompile(CORE_VALA_C ${CORE_LIBRARY_NAME}
	${CORE_SOURCE}
PACKAGES
	${CORE_PKG}
GENERATE_VAPI
	${CORE_LIBRARY_NAME}
GENERATE_HEADER
	${CORE_LIBRARY_NAME}
)

add_definitions(${CORE_DEPS_CFLAGS} -include config.h)
link_directories(${CORE_DEPS_LIBRARY_DIRS})

add_library(${CORE_LIBRARY_NAME} STATIC ${CORE_VALA_C})
target_link_libraries (${CORE_LIBRARY_NAME} ${CORE_DEPS_LIBRARIES})

set_target_properties(${CORE_LIBRARY_NAME} PROPERTIES
	OUTPUT_NAME ${CORE_LIBRARY_NAME}
	VERSION ${CORE_LIB_VERSION}
	SOVERSION ${CORE_LIB_SOVERSION}
)

