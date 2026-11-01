# SPDX-License-Identifier: GPL-3.0-only
# Compiler environment variables can add implicit headers after CMake has generated compile_commands.json. Keep the
# product build deterministic by refusing such overrides both during configuration and immediately before targets build.
set(_sco_relay_compiler_environment_variables
  CPATH CPLUS_INCLUDE_PATH C_INCLUDE_PATH OBJC_INCLUDE_PATH INCLUDE
  LIBRARY_PATH LIB LINK _LINK_
  GCC_EXEC_PREFIX COMPILER_PATH CL _CL_ CCC_OVERRIDE_OPTIONS)
foreach(_sco_relay_environment_name IN LISTS _sco_relay_compiler_environment_variables)
  if(NOT "$ENV{${_sco_relay_environment_name}}" STREQUAL "")
    message(FATAL_ERROR
      "sc-mp relay: ${_sco_relay_environment_name} changes compiler or linker search/options; unset it and reconfigure")
  endif()
endforeach()
