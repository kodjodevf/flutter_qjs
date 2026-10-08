cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_qjs")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

set(CXX_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cxx")
set(QUICKJS_DIR "${CXX_DIR}/quickjs")

add_library(${PLUGIN_NAME} SHARED
  "${PLUGIN_NAME}.cc"
  "${CXX_DIR}/ffi.c"
  "${QUICKJS_DIR}/cutils.c"
  "${QUICKJS_DIR}/libregexp.c"
  "${QUICKJS_DIR}/libunicode.c"
  "${QUICKJS_DIR}/quickjs.c"
  "${QUICKJS_DIR}/dtoa.c"
)

apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET default
  C_VISIBILITY_PRESET default)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
  CONFIG_VERSION="2026-06-04"
  DUMP_LEAKS=1
)
target_compile_options(${PLUGIN_NAME} PRIVATE
  -Wno-error
  -w
)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CXX_DIR}"
  "${QUICKJS_DIR}"
)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE m)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_qjs_bundled_libraries
  ""
  PARENT_SCOPE
)
