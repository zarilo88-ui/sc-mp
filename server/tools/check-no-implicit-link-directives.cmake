# SPDX-License-Identifier: GPL-3.0-only
# Reject MSVC source directives that can add libraries or raw linker options outside the checked CMake link graph.
if(NOT DEFINED SCO_RELAY_ROOT OR NOT IS_DIRECTORY "${SCO_RELAY_ROOT}/server")
  message(FATAL_ERROR "usage: cmake -DSCO_RELAY_ROOT=<repository> -P check-no-implicit-link-directives.cmake")
endif()

file(GLOB _sco_relay_source_files LIST_DIRECTORIES false
  "${SCO_RELAY_ROOT}/server/*.cpp"
  "${SCO_RELAY_ROOT}/server/*.h")
list(APPEND _sco_relay_source_files "${SCO_RELAY_ROOT}/plugins/multiplayer/relay_wire.h")

foreach(_sco_relay_source IN LISTS _sco_relay_source_files)
  if(NOT EXISTS "${_sco_relay_source}")
    message(FATAL_ERROR "sc-mp relay: production source is missing: ${_sco_relay_source}")
  endif()
  file(READ "${_sco_relay_source}" _sco_relay_source_text)
  string(TOLOWER "${_sco_relay_source_text}" _sco_relay_source_lower)
  string(REPLACE "\\\r\n" "" _sco_relay_source_spliced "${_sco_relay_source_lower}")
  string(REPLACE "\\\n" "" _sco_relay_source_spliced "${_sco_relay_source_spliced}")
  string(REGEX REPLACE "/\\*([^*]|\\*+[^*/])*\\*+/" " " _sco_relay_source_checked
    "${_sco_relay_source_spliced}")
  if(_sco_relay_source_checked MATCHES "(#|%:)[ \t]*pragma[ \t]+comment" OR
     _sco_relay_source_checked MATCHES "__pragma[ \t]*\\([ \t]*comment")
    message(FATAL_ERROR
      "sc-mp relay: source-level comment pragma can inject linker inputs: ${_sco_relay_source}")
  endif()
endforeach()

message(STATUS "sc-mp relay: no source-level MSVC linker comment pragmas")
