cmake_minimum_required(VERSION 3.22.1)
project("lua_bridge" C)

# Share Lua 5.4 sources with iOS — single source of truth at Sources/CLua/
set(LUA_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Sources/CLua")

file(GLOB LUA_SOURCES "${LUA_SRC_DIR}/*.c")
list(FILTER LUA_SOURCES EXCLUDE REGEX "lua\\.c$")
list(FILTER LUA_SOURCES EXCLUDE REGEX "luac\\.c$")

add_library(lua_bridge SHARED
    lua_bridge.c
    ${LUA_SOURCES}
)

target_include_directories(lua_bridge PRIVATE
    "${LUA_SRC_DIR}"
    "${LUA_SRC_DIR}/include"
)

# LUA_USE_LINUX for Android (POSIX-compatible)
target_compile_definitions(lua_bridge PRIVATE
    LUA_USE_LINUX
)

target_link_libraries(lua_bridge
    android
    log
    m
    dl
)
