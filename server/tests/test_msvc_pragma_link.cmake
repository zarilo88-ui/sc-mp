# SPDX-License-Identifier: GPL-3.0-only
# Confirm with MSVC that _Pragma("comment(lib, ...)") emits a linker library record.
if(NOT DEFINED SCO_RELAY_COMPILER OR NOT DEFINED SCO_RELAY_TEST_BINARY_DIR)
  message(FATAL_ERROR "test requires the MSVC compiler and a temporary binary directory")
endif()

file(REMOVE_RECURSE "${SCO_RELAY_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${SCO_RELAY_TEST_BINARY_DIR}")
set(_missing_library "scmp_pragma_probe_missing_8236.lib")
set(_source "${SCO_RELAY_TEST_BINARY_DIR}/pragma_probe.cpp")
set(_program "${SCO_RELAY_TEST_BINARY_DIR}/pragma_probe.exe")
file(WRITE "${_source}" "_Pragma(\"comment(lib, \\\"${_missing_library}\\\")\")\nint main() { return 0; }\n")

execute_process(
  COMMAND "${SCO_RELAY_COMPILER}" /nologo "/Fe${_program}" "${_source}"
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _stdout
  ERROR_VARIABLE _stderr)
set(_output "${_stdout}${_stderr}")
if(_result EQUAL 0)
  message(FATAL_ERROR "MSVC did not fail while linking the _Pragma-injected library; linker injection was not demonstrated")
endif()
if(NOT _output MATCHES "LNK1104" OR NOT _output MATCHES "${_missing_library}")
  message(FATAL_ERROR "MSVC _Pragma probe failed for an unrelated reason: ${_output}")
endif()
message(STATUS "MSVC _Pragma comment(lib, ...) generated the expected unresolved library search record")
