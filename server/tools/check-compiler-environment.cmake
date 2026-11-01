# SPDX-License-Identifier: GPL-3.0-only
# Compiler environment variables can add implicit headers after CMake has generated compile_commands.json. Keep the
# product build deterministic by refusing such overrides both during configuration and immediately before targets build.
set(_sco_relay_compiler_environment_variables
  CPATH CPLUS_INCLUDE_PATH C_INCLUDE_PATH OBJC_INCLUDE_PATH
  CFLAGS CXXFLAGS OBJCFLAGS LDFLAGS
  LIBRARY_PATH LIB LINK _LINK_
  GCC_EXEC_PREFIX COMPILER_PATH CL _CL_ CCC_OVERRIDE_OPTIONS)
foreach(_sco_relay_environment_name IN LISTS _sco_relay_compiler_environment_variables)
  if(NOT "$ENV{${_sco_relay_environment_name}}" STREQUAL "")
    message(FATAL_ERROR
      "sc-mp relay: ${_sco_relay_environment_name} changes compiler or linker search/options; unset it and reconfigure")
  endif()
endforeach()

set(_sco_relay_cmake_flag_variables
  CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS
  CMAKE_MODULE_LINKER_FLAGS CMAKE_STATIC_LINKER_FLAGS
  CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG
  CMAKE_C_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_MINSIZEREL
  CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE
  CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_RELWITHDEBINFO
  CMAKE_EXE_LINKER_FLAGS_DEBUG CMAKE_SHARED_LINKER_FLAGS_DEBUG CMAKE_MODULE_LINKER_FLAGS_DEBUG
  CMAKE_EXE_LINKER_FLAGS_MINSIZEREL CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL CMAKE_MODULE_LINKER_FLAGS_MINSIZEREL
  CMAKE_EXE_LINKER_FLAGS_RELEASE CMAKE_SHARED_LINKER_FLAGS_RELEASE CMAKE_MODULE_LINKER_FLAGS_RELEASE
  CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO
  CMAKE_STATIC_LINKER_FLAGS_DEBUG CMAKE_STATIC_LINKER_FLAGS_MINSIZEREL
  CMAKE_STATIC_LINKER_FLAGS_RELEASE CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO)

if(DEFINED CMAKE_CXX_COMPILER_ID)
  # The audited targets do not use caller-supplied global flags. Compare all generic and per-configuration compiler/
  # linker flags with CMake's selected platform defaults; this catches environment and cache injections while
  # retaining the stock MSVC flags and architecture options required by the Visual Studio generator.
  if(CMAKE_TOOLCHAIN_FILE OR CMAKE_USER_MAKE_RULES_OVERRIDE OR CMAKE_USER_MAKE_RULES_OVERRIDE_C OR
     CMAKE_USER_MAKE_RULES_OVERRIDE_CXX OR CMAKE_PROJECT_INCLUDE_BEFORE OR CMAKE_PROJECT_INCLUDE OR
     CMAKE_PROJECT_sc-mp_INCLUDE_BEFORE OR CMAKE_PROJECT_sc-mp_INCLUDE OR
     CMAKE_PROJECT_TOP_LEVEL_INCLUDES OR
     CMAKE_C_COMPILER_LAUNCHER OR CMAKE_CXX_COMPILER_LAUNCHER OR
     CMAKE_C_COMPILER_ARG1 OR CMAKE_CXX_COMPILER_ARG1 OR
     CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN OR CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN)
    message(FATAL_ERROR "sc-mp relay: custom CMake toolchains, rules hooks and compiler launchers are not allowed")
  endif()
  foreach(_sco_relay_flag_variable IN LISTS _sco_relay_cmake_flag_variables)
    if(NOT DEFINED ${_sco_relay_flag_variable})
      message(FATAL_ERROR "sc-mp relay: ${_sco_relay_flag_variable} is missing after project()")
    endif()
    set(_sco_relay_init_variable "${_sco_relay_flag_variable}_INIT")
    if(DEFINED ${_sco_relay_init_variable})
      set(_sco_relay_expected_flag_value "${${_sco_relay_init_variable}}")
    else()
      set(_sco_relay_expected_flag_value "")
    endif()
    string(STRIP "${${_sco_relay_flag_variable}}" _sco_relay_actual_flag_value)
    string(STRIP "${_sco_relay_expected_flag_value}" _sco_relay_expected_flag_value)
    if(NOT "${_sco_relay_actual_flag_value}" STREQUAL "${_sco_relay_expected_flag_value}")
      message(FATAL_ERROR "sc-mp relay: ${_sco_relay_flag_variable} differs from the selected platform default")
    endif()
  endforeach()
endif()

if(NOT DEFINED SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT OR SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT STREQUAL "")
  if(NOT DEFINED CMAKE_BINARY_DIR OR CMAKE_BINARY_DIR STREQUAL "")
    message(FATAL_ERROR "sc-mp relay: compiler environment snapshot path is required")
  endif()
  set(SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT "${CMAKE_BINARY_DIR}/sco-relay-compiler-environment.txt")
endif()

set(_sco_relay_include_dirs "")
if(NOT "$ENV{INCLUDE}" STREQUAL "")
  set(_sco_relay_raw_include_dirs "$ENV{INCLUDE}")
  foreach(_sco_relay_include_dir IN LISTS _sco_relay_raw_include_dirs)
    if(_sco_relay_include_dir STREQUAL "" OR NOT IS_DIRECTORY "${_sco_relay_include_dir}")
      message(FATAL_ERROR "sc-mp relay: INCLUDE contains an empty or unavailable directory")
    endif()
    file(REAL_PATH "${_sco_relay_include_dir}" _sco_relay_include_real)
    string(TOLOWER "${_sco_relay_include_real}" _sco_relay_include_key)
    list(APPEND _sco_relay_include_dirs "${_sco_relay_include_key}")
  endforeach()
endif()

if(DEFINED CMAKE_CXX_COMPILER_ID)
  # Visual Studio's developer environment sets INCLUDE to compiler/SDK system headers. Admit those only when they
  # are inside the selected compiler installation or selected Windows SDK version.
  if(_sco_relay_include_dirs)
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      message(FATAL_ERROR "sc-mp relay: INCLUDE is accepted only for the native MSVC toolchain")
    endif()
    get_filename_component(_sco_relay_compiler "${CMAKE_CXX_COMPILER}" REALPATH)
    get_filename_component(_sco_relay_msvc_x64_dir "${_sco_relay_compiler}" DIRECTORY)
    get_filename_component(_sco_relay_msvc_host_dir "${_sco_relay_msvc_x64_dir}" DIRECTORY)
    get_filename_component(_sco_relay_msvc_bin_dir "${_sco_relay_msvc_host_dir}" DIRECTORY)
    get_filename_component(_sco_relay_msvc_root "${_sco_relay_msvc_bin_dir}" DIRECTORY)
    set(_sco_relay_trusted_include_roots "${_sco_relay_msvc_root}")

    if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION)
      list(APPEND _sco_relay_trusted_include_roots
        "C:/Program Files (x86)/Windows Kits/10/Include/${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}")
    endif()

    set(_sco_relay_trusted_include_roots_normalized "")
    foreach(_sco_relay_root IN LISTS _sco_relay_trusted_include_roots)
      if(IS_DIRECTORY "${_sco_relay_root}")
        file(REAL_PATH "${_sco_relay_root}" _sco_relay_root_real)
        string(TOLOWER "${_sco_relay_root_real}" _sco_relay_root_key)
        list(APPEND _sco_relay_trusted_include_roots_normalized "${_sco_relay_root_key}")
      endif()
    endforeach()
    if(NOT _sco_relay_trusted_include_roots_normalized)
      message(FATAL_ERROR "sc-mp relay: could not identify the selected MSVC and Windows SDK include roots")
    endif()

    foreach(_sco_relay_include_key IN LISTS _sco_relay_include_dirs)
      set(_sco_relay_include_is_trusted FALSE)
      foreach(_sco_relay_root_key IN LISTS _sco_relay_trusted_include_roots_normalized)
        string(FIND "${_sco_relay_include_key}/" "${_sco_relay_root_key}/" _sco_relay_root_match)
        if(_sco_relay_root_match EQUAL 0)
          set(_sco_relay_include_is_trusted TRUE)
          break()
        endif()
      endforeach()
      if(NOT _sco_relay_include_is_trusted)
        message(FATAL_ERROR "sc-mp relay: INCLUDE contains a path outside the selected MSVC/Windows SDK roots")
      endif()
    endforeach()
  endif()

  file(WRITE "${SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT}"
    "compiler_id=${CMAKE_CXX_COMPILER_ID}\n")
  foreach(_sco_relay_include_key IN LISTS _sco_relay_include_dirs)
    file(APPEND "${SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT}" "include=${_sco_relay_include_key}\n")
  endforeach()
  foreach(_sco_relay_flag_variable IN LISTS _sco_relay_cmake_flag_variables)
    file(APPEND "${SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT}"
      "flag_${_sco_relay_flag_variable}=${${_sco_relay_flag_variable}}\n")
  endforeach()
else()
  # The build-time check must see the exact compiler and INCLUDE list that passed configuration.
  if(NOT EXISTS "${SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT}")
    message(FATAL_ERROR "sc-mp relay: compiler environment snapshot is missing; reconfigure")
  endif()
  if(NOT DEFINED SCO_RELAY_CMAKE_CACHE OR NOT EXISTS "${SCO_RELAY_CMAKE_CACHE}")
    message(FATAL_ERROR "sc-mp relay: CMake cache path is missing; reconfigure")
  endif()
  file(STRINGS "${SCO_RELAY_CMAKE_CACHE}" _sco_relay_cache_lines)
  file(STRINGS "${SCO_RELAY_COMPILER_ENVIRONMENT_SNAPSHOT}" _sco_relay_snapshot_lines)
  foreach(_sco_relay_flag_variable IN LISTS _sco_relay_cmake_flag_variables)
    set(_sco_relay_cache_value "")
    set(_sco_relay_cache_key_seen FALSE)
    set(_sco_relay_snapshot_value "")
    set(_sco_relay_snapshot_key_seen FALSE)
    foreach(_sco_relay_cache_line IN LISTS _sco_relay_cache_lines)
      if(_sco_relay_cache_line MATCHES "^${_sco_relay_flag_variable}:[^=]*=(.*)$")
        set(_sco_relay_cache_value "${CMAKE_MATCH_1}")
        set(_sco_relay_cache_key_seen TRUE)
        break()
      endif()
    endforeach()
    foreach(_sco_relay_snapshot_line IN LISTS _sco_relay_snapshot_lines)
      if(_sco_relay_snapshot_line MATCHES "^flag_${_sco_relay_flag_variable}=(.*)$")
        set(_sco_relay_snapshot_value "${CMAKE_MATCH_1}")
        set(_sco_relay_snapshot_key_seen TRUE)
        break()
      endif()
    endforeach()
    if(NOT _sco_relay_cache_key_seen OR NOT _sco_relay_snapshot_key_seen OR
       NOT "${_sco_relay_cache_value}" STREQUAL "${_sco_relay_snapshot_value}")
      message(FATAL_ERROR "sc-mp relay: ${_sco_relay_flag_variable} changed since configuration; reconfigure")
    endif()
  endforeach()
  set(_sco_relay_snapshot_compiler_id "")
  set(_sco_relay_snapshot_include_dirs "")
  foreach(_sco_relay_snapshot_line IN LISTS _sco_relay_snapshot_lines)
    if(_sco_relay_snapshot_line MATCHES "^compiler_id=(.*)$")
      set(_sco_relay_snapshot_compiler_id "${CMAKE_MATCH_1}")
    elseif(_sco_relay_snapshot_line MATCHES "^include=(.*)$")
      list(APPEND _sco_relay_snapshot_include_dirs "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  if(DEFINED SCO_RELAY_COMPILER_ID AND NOT "${SCO_RELAY_COMPILER_ID}" STREQUAL "${_sco_relay_snapshot_compiler_id}")
    message(FATAL_ERROR "sc-mp relay: selected compiler changed after configuration; reconfigure")
  endif()
  if(NOT "${_sco_relay_include_dirs}" STREQUAL "${_sco_relay_snapshot_include_dirs}")
    message(FATAL_ERROR "sc-mp relay: INCLUDE changed after configuration; reconfigure")
  endif()
endif()
