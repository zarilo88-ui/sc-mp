# SPDX-License-Identifier: GPL-3.0-only
# Exercise the portable source-level linker-directive check with clean and hostile fixtures.
if(NOT DEFINED SCO_RELAY_ROOT OR NOT IS_DIRECTORY "${SCO_RELAY_ROOT}/server")
  message(FATAL_ERROR "test needs -DSCO_RELAY_ROOT=<repository>")
endif()

set(_sco_relay_checker "${SCO_RELAY_ROOT}/server/tools/check-no-implicit-link-directives.cmake")
set(_sco_relay_fixture "${CMAKE_CURRENT_BINARY_DIR}/relay-link-directive-fixture")
file(REMOVE_RECURSE "${_sco_relay_fixture}")
file(MAKE_DIRECTORY "${_sco_relay_fixture}/server" "${_sco_relay_fixture}/plugins/multiplayer")
file(WRITE "${_sco_relay_fixture}/server/example.cpp" "int relay_example() { return 0; }\n")
file(WRITE "${_sco_relay_fixture}/plugins/multiplayer/relay_wire.h" "#pragma once\n")

execute_process(
  COMMAND "${CMAKE_COMMAND}" "-DSCO_RELAY_ROOT=${_sco_relay_fixture}" -P "${_sco_relay_checker}"
  RESULT_VARIABLE _sco_relay_clean_result
  OUTPUT_VARIABLE _sco_relay_output
  ERROR_VARIABLE _sco_relay_error)
if(NOT _sco_relay_clean_result EQUAL 0)
  file(REMOVE_RECURSE "${_sco_relay_fixture}")
  message(FATAL_ERROR "clean source fixture was rejected: ${_sco_relay_output}${_sco_relay_error}")
endif()

function(_sco_relay_expect_refused description source_text)
  file(WRITE "${_sco_relay_fixture}/server/example.cpp" "${source_text}\n")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DSCO_RELAY_ROOT=${_sco_relay_fixture}" -P "${_sco_relay_checker}"
    RESULT_VARIABLE _sco_relay_hostile_result
    OUTPUT_VARIABLE _sco_relay_output
    ERROR_VARIABLE _sco_relay_error)
  if(_sco_relay_hostile_result EQUAL 0)
    message(FATAL_ERROR "${description}: source-level link directive was accepted")
  endif()
  if(NOT "${_sco_relay_output}${_sco_relay_error}" MATCHES "source-level comment pragma can inject linker inputs")
    message(FATAL_ERROR "${description}: source was refused for the wrong reason: ${_sco_relay_output}${_sco_relay_error}")
  endif()
endfunction()

_sco_relay_expect_refused("plain pragma" "#pragma comment(lib, \"game.lib\")")
_sco_relay_expect_refused("plain __pragma" "__pragma(comment(linker, \"/DEFAULTLIB:game.lib\"))")
_sco_relay_expect_refused("block-comment-separated pragma tokens" "#/**/pragma/**/comment(lib, \"game.lib\")")
_sco_relay_expect_refused("digraph pragma" "%:pragma comment(lib, \"game.lib\")")
_sco_relay_expect_refused("block-comment-separated digraph pragma" "%:/**/pragma/**/comment(lib, \"game.lib\")")
_sco_relay_expect_refused("block-comment-separated __pragma tokens"
  "__pragma/**/(comment(linker, \"/DEFAULTLIB:game.lib\"))")
_sco_relay_expect_refused("line-spliced pragma token" "#\\\npragma comment(lib, \"game.lib\")")
file(REMOVE_RECURSE "${_sco_relay_fixture}")
message(STATUS "sc-mp relay: clean source accepted and plain, comment-obfuscated and line-spliced MSVC directives refused")
