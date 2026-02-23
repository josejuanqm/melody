#ifndef CLua_h
#define CLua_h

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

// Swift-callable shims for C macros that Swift cannot import

static inline int clua_upvalueindex(int i) {
    return lua_upvalueindex(i);
}

static inline int clua_isinteger(lua_State *L, int idx) {
    return lua_isinteger(L, idx);
}

static inline int clua_isstring(lua_State *L, int idx) {
    return lua_isstring(L, idx);
}

static inline int clua_isnumber(lua_State *L, int idx) {
    return lua_isnumber(L, idx);
}

static inline void clua_pop(lua_State *L, int n) {
    lua_pop(L, n);
}

static inline int clua_pcall(lua_State *L, int nargs, int nresults, int msgh) {
    return lua_pcall(L, nargs, nresults, msgh);
}

static inline int clua_registryindex(void) {
    return LUA_REGISTRYINDEX;
}

#endif /* CLua_h */
