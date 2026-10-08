cmake_minimum_required(VERSION 3.15)

set(PROJECT_NAME "flutter_qjs")
project(${PROJECT_NAME} LANGUAGES C CXX)
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

set(CXX_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cxx")
set(QUICKJS_DIR "${CXX_DIR}/quickjs")

add_library(${PLUGIN_NAME} SHARED
  "${PLUGIN_NAME}.cpp"
  "${CXX_DIR}/ffi.c"
  "${QUICKJS_DIR}/cutils.c"
  "${QUICKJS_DIR}/libregexp.c"
  "${QUICKJS_DIR}/libunicode.c"
  "${QUICKJS_DIR}/quickjs.c"
  "${QUICKJS_DIR}/dtoa.c"
)
apply_standard_settings(${PLUGIN_NAME})

target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
  CONFIG_VERSION="2026-06-04"
  DUMP_LEAKS=1
  $<$<CXX_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS>
  $<$<CXX_COMPILER_ID:MSVC>:_WINSOCK_DEPRECATED_NO_WARNINGS>
)

target_compile_options(${PLUGIN_NAME} PRIVATE
  $<$<CXX_COMPILER_ID:MSVC>:/WX->
  $<$<CXX_COMPILER_ID:MSVC>:/w>
  $<$<CXX_COMPILER_ID:MSVC>:/Oi->
  $<$<CXX_COMPILER_ID:MSVC>:/wd4018>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4132>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4146>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4201>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4232>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4244>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4245>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4267>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4334>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4389>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4456>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4457>
  $<$<CXX_COMPILER_ID:MSVC>:/wd4996>
)

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CXX_DIR}"
  "${QUICKJS_DIR}"
)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_qjs_bundled_libraries
  ""
  PARENT_SCOPE
)
