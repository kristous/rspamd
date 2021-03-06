SET(TESTSRC		rspamd_mem_pool_test.c
				rspamd_statfile_test.c
				rspamd_url_test.c
				rspamd_dns_test.c
				rspamd_async_test.c
				rspamd_dkim_test.c
				rspamd_rrd_test.c
				rspamd_radix_test.c
				rspamd_shingles_test.c
				rspamd_upstream_test.c
				rspamd_http_test.c
				rspamd_lua_test.c
				rspamd_cryptobox_test.c
				rspamd_test_suite.c)

ADD_EXECUTABLE(rspamd-test EXCLUDE_FROM_ALL ${TESTSRC})
SET_TARGET_PROPERTIES(rspamd-test PROPERTIES LINKER_LANGUAGE C)
SET_TARGET_PROPERTIES(rspamd-test PROPERTIES COMPILE_FLAGS "-DRSPAMD_TEST")
ADD_DEPENDENCIES(rspamd-test rspamd-server)
IF(NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	TARGET_LINK_LIBRARIES(rspamd-test "-Wl,-whole-archive ${CMAKE_BINARY_DIR}/src/librspamd-server.a -Wl,-no-whole-archive")
ELSE(NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	TARGET_LINK_LIBRARIES(rspamd-test "-Wl,-force_load ${CMAKE_BINARY_DIR}/src/librspamd-server.a")
ENDIF(NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin")
TARGET_LINK_LIBRARIES(rspamd-test rspamd-cdb)
TARGET_LINK_LIBRARIES(rspamd-test lcbtrie)
TARGET_LINK_LIBRARIES(rspamd-test rspamd-http-parser)
TARGET_LINK_LIBRARIES(rspamd-test ${RSPAMD_REQUIRED_LIBRARIES})
IF (ENABLE_SNOWBALL MATCHES "ON")
	TARGET_LINK_LIBRARIES(rspamd-test stemmer)
ENDIF()
IF(ENABLE_HIREDIS MATCHES "ON")
	TARGET_LINK_LIBRARIES(rspamd-test rspamd-hiredis)
ENDIF()
IF (ENABLE_HYPERSCAN MATCHES "ON")
	TARGET_LINK_LIBRARIES(rspamd-test hs)
	SET_TARGET_PROPERTIES(rspamd-test PROPERTIES LINKER_LANGUAGE CXX)
ENDIF()
TARGET_LINK_LIBRARIES(rspamd-test rspamd-actrie)

ADD_CUSTOM_TARGET(rspamd-func-test COMMAND 
		"/bin/sh"
		"${CMAKE_CURRENT_BINARY_DIR}/functional/tests.sh")
		
ADD_DEPENDENCIES(rspamd-func-test rspamd-test)
ADD_DEPENDENCIES(rspamd-func-test rspamc)
ADD_DEPENDENCIES(rspamd-func-test rspamd)

IF(NOT "${CMAKE_CURRENT_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_BINARY_DIR}")
	# Also add dependencies for convenience
	FILE(GLOB_RECURSE LUA_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/lua/*")
	ADD_CUSTOM_TARGET(units-dir COMMAND
		${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/lua/unit"
	)
	ADD_DEPENDENCIES(rspamd-test units-dir)
	FOREACH(_LF IN LISTS LUA_TESTS)
		GET_FILENAME_COMPONENT(_NM "${_LF}" NAME)
		IF("${_LF}" MATCHES "^.*/unit/.*$")
			SET(_DS "${CMAKE_CURRENT_BINARY_DIR}/lua/unit/${_NM}")
		ELSE()
			SET(_DS "${CMAKE_CURRENT_BINARY_DIR}/lua/${_NM}")
		ENDIF()
		ADD_CUSTOM_TARGET("${_NM}" COMMAND
			${CMAKE_COMMAND} -E copy_if_different ${_LF} ${_DS}
			SOURCES "${_LF}"
		)
		ADD_DEPENDENCIES(rspamd-test "${_NM}")
	ENDFOREACH()
	
	ADD_CUSTOM_TARGET(functional-dir COMMAND
		${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/functional/cases"
		COMMAND ${CMAKE_COMMAND} -E make_directory 
		"${CMAKE_CURRENT_BINARY_DIR}/functional/configs" 
		COMMAND ${CMAKE_COMMAND} -E make_directory 
		"${CMAKE_CURRENT_BINARY_DIR}/functional/messages"
	)
	ADD_DEPENDENCIES(rspamd-func-test functional-dir)
	FILE(GLOB_RECURSE BATS_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/functional/*")
	FOREACH(_LF IN LISTS BATS_TESTS)
		GET_FILENAME_COMPONENT(_NM "${_LF}" NAME)
		STRING(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}"
			_DS "${_LF}")
		ADD_CUSTOM_TARGET("${_NM}" COMMAND
			${CMAKE_COMMAND} -E copy_if_different ${_LF} ${_DS}
			SOURCES "${_LF}"
		)
		ADD_DEPENDENCIES(rspamd-func-test "${_NM}")
	ENDFOREACH()
ENDIF()