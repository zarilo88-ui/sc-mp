# SPDX-License-Identifier: GPL-3.0-only
# Confirm with MSVC which source-level pragma forms emit linker library records.
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

set(_macro_missing_library "scmp_macro_pragma_probe_missing_3147.lib")
set(_macro_source "${SCO_RELAY_TEST_BINARY_DIR}/macro_pragma_probe.cpp")
set(_macro_program "${SCO_RELAY_TEST_BINARY_DIR}/macro_pragma_probe.exe")
file(WRITE "${_macro_source}"
  "#define LINKER_COMMENT comment\n#pragma LINKER_COMMENT(lib, \"${_macro_missing_library}\")\nint main() { return 0; }\n")
execute_process(
  COMMAND "${SCO_RELAY_COMPILER}" /nologo "/Fe${_macro_program}" "${_macro_source}"
  RESULT_VARIABLE _macro_result
  OUTPUT_VARIABLE _macro_stdout
  ERROR_VARIABLE _macro_stderr)
set(_macro_output "${_macro_stdout}${_macro_stderr}")
if(_macro_result EQUAL 0)
  message(STATUS "MSVC did not emit a linker search record from a macro-expanded #pragma name")
elseif(_macro_output MATCHES "LNK1104" AND _macro_output MATCHES "${_macro_missing_library}")
  message(STATUS "MSVC macro-expanded #pragma name generated the expected unresolved library search record")
else()
  message(FATAL_ERROR "MSVC macro-expanded #pragma probe failed for an unrelated reason: ${_macro_output}")
endif()
