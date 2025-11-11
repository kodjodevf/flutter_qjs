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
    ${QUICK_JS_LIB_DIR}/dtoa.c
)

project(quickjs LANGUAGES C)
target_compile_options(quickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(quickjs PRIVATE "-DDUMP_LEAKS")

if(MSVC)
    # https://github.com/ekibun/flutter_qjs/issues/7
    target_compile_options(quickjs PRIVATE "/Oi-")
    # Windows compatibility: sys/time.h doesn't exist on Windows
    target_compile_definitions(quickjs PRIVATE "_CRT_SECURE_NO_WARNINGS")
    target_compile_definitions(quickjs PRIVATE "_WINSOCK_DEPRECATED_NO_WARNINGS")
    # Suppress warnings in QuickJS code
    target_compile_options(quickjs PRIVATE 
        "/wd4018"  # signed/unsigned mismatch in libunicode.c
        "/wd4013"  # function undefined (mp_div1norm declaration issue)
        "/wd4244"  # conversion warnings in dtoa.c
    )
endif()