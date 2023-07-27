include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(networking_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(networking_setup_options)
  option(networking_ENABLE_HARDENING "Enable hardening" ON)
  option(networking_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    networking_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    networking_ENABLE_HARDENING
    OFF)

  networking_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR networking_PACKAGING_MAINTAINER_MODE)
    option(networking_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(networking_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(networking_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(networking_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(networking_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(networking_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(networking_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(networking_ENABLE_PCH "Enable precompiled headers" OFF)
    option(networking_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(networking_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(networking_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(networking_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(networking_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(networking_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(networking_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(networking_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(networking_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(networking_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(networking_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(networking_ENABLE_PCH "Enable precompiled headers" OFF)
    option(networking_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      networking_ENABLE_IPO
      networking_WARNINGS_AS_ERRORS
      networking_ENABLE_USER_LINKER
      networking_ENABLE_SANITIZER_ADDRESS
      networking_ENABLE_SANITIZER_LEAK
      networking_ENABLE_SANITIZER_UNDEFINED
      networking_ENABLE_SANITIZER_THREAD
      networking_ENABLE_SANITIZER_MEMORY
      networking_ENABLE_UNITY_BUILD
      networking_ENABLE_CLANG_TIDY
      networking_ENABLE_CPPCHECK
      networking_ENABLE_COVERAGE
      networking_ENABLE_PCH
      networking_ENABLE_CACHE)
  endif()

  networking_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (networking_ENABLE_SANITIZER_ADDRESS OR networking_ENABLE_SANITIZER_THREAD OR networking_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(networking_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(networking_global_options)
  if(networking_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    networking_enable_ipo()
  endif()

  networking_supports_sanitizers()

  if(networking_ENABLE_HARDENING AND networking_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR networking_ENABLE_SANITIZER_UNDEFINED
       OR networking_ENABLE_SANITIZER_ADDRESS
       OR networking_ENABLE_SANITIZER_THREAD
       OR networking_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${networking_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${networking_ENABLE_SANITIZER_UNDEFINED}")
    networking_enable_hardening(networking_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(networking_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(networking_warnings INTERFACE)
  add_library(networking_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  networking_set_project_warnings(
    networking_warnings
    ${networking_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(networking_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(networking_options)
  endif()

  include(cmake/Sanitizers.cmake)
  networking_enable_sanitizers(
    networking_options
    ${networking_ENABLE_SANITIZER_ADDRESS}
    ${networking_ENABLE_SANITIZER_LEAK}
    ${networking_ENABLE_SANITIZER_UNDEFINED}
    ${networking_ENABLE_SANITIZER_THREAD}
    ${networking_ENABLE_SANITIZER_MEMORY})

  set_target_properties(networking_options PROPERTIES UNITY_BUILD ${networking_ENABLE_UNITY_BUILD})

  if(networking_ENABLE_PCH)
    target_precompile_headers(
      networking_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(networking_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    networking_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(networking_ENABLE_CLANG_TIDY)
    networking_enable_clang_tidy(networking_options ${networking_WARNINGS_AS_ERRORS})
  endif()

  if(networking_ENABLE_CPPCHECK)
    networking_enable_cppcheck(${networking_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(networking_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    networking_enable_coverage(networking_options)
  endif()

  if(networking_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(networking_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(networking_ENABLE_HARDENING AND NOT networking_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR networking_ENABLE_SANITIZER_UNDEFINED
       OR networking_ENABLE_SANITIZER_ADDRESS
       OR networking_ENABLE_SANITIZER_THREAD
       OR networking_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    networking_enable_hardening(networking_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
