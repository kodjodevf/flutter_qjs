cmake_minimum_required(VERSION 3.10)
set(CXX_LIB_DIR ${CMAKE_CURRENT_LIST_DIR})
set(CMAKE_CXX_STANDARD 17)

# quickjs
set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs)
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
add_library(quickjs STATIC
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
    ${QUICK_JS_LIB_DIR}/libbf.c
)

project(quickjs LANGUAGES C)
target_compile_options(quickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(quickjs PRIVATE "-DDUMP_LEAKS")

if(MSVC)
    # https://github.com/ekibun/flutter_qjs/issues/7
    target_compile_options(quickjs PRIVATE "/Oi-")
endif()