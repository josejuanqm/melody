#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include <android/log.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define LOG_TAG "LuaBridge"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Cached JVM and callback class references */
static JavaVM *g_jvm = NULL;
static jclass g_callbackClass = NULL;
static jmethodID g_callbackMethod = NULL;

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    g_jvm = vm;
    JNIEnv *env;
    if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    jclass cls = (*env)->FindClass(env, "com/melody/lua/LuaBridge");
    if (cls) {
        g_callbackClass = (*env)->NewGlobalRef(env, cls);
        g_callbackMethod = (*env)->GetStaticMethodID(env, g_callbackClass,
            "dispatchCallback", "(JI)I");
    }
    return JNI_VERSION_1_6;
}

/* Helper: get JNIEnv for current thread */
static JNIEnv* getEnv(void) {
    JNIEnv *env;
    if ((*g_jvm)->GetEnv(g_jvm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
        (*g_jvm)->AttachCurrentThread(g_jvm, &env, NULL);
    }
    return env;
}

/* ------- Dynamic String Buffer ------- */

typedef struct {
    char *data;
    int pos;
    int capacity;
} DynBuf;

static DynBuf dynbuf_new(int initial_capacity) {
    DynBuf db;
    db.data = (char*)malloc(initial_capacity);
    db.pos = 0;
    db.capacity = initial_capacity;
    if (db.data) db.data[0] = '\0';
    return db;
}

static void dynbuf_ensure(DynBuf *db, int additional) {
    if (db->pos + additional >= db->capacity) {
        int new_cap = db->capacity * 2;
        while (new_cap < db->pos + additional + 1) new_cap *= 2;
        char *new_data = (char*)realloc(db->data, new_cap);
        if (new_data) {
            db->data = new_data;
            db->capacity = new_cap;
        }
    }
}

static void dynbuf_append(DynBuf *db, const char *str) {
    int len = strlen(str);
    dynbuf_ensure(db, len);
    if (db->pos + len < db->capacity) {
        memcpy(db->data + db->pos, str, len);
        db->pos += len;
    }
    db->data[db->pos] = '\0';
}

static void dynbuf_append_escaped(DynBuf *db, const char *str) {
    dynbuf_append(db, "\"");
    while (*str) {
        dynbuf_ensure(db, 3);
        switch (*str) {
            case '"':  dynbuf_append(db, "\\\""); break;
            case '\\': dynbuf_append(db, "\\\\"); break;
            case '\n': dynbuf_append(db, "\\n"); break;
            case '\r': dynbuf_append(db, "\\r"); break;
            case '\t': dynbuf_append(db, "\\t"); break;
            default:
                if (db->pos < db->capacity - 1) {
                    db->data[db->pos] = *str;
                    db->pos++;
                    db->data[db->pos] = '\0';
                }
                break;
        }
        str++;
    }
    dynbuf_append(db, "\"");
}

static void dynbuf_free(DynBuf *db) {
    free(db->data);
    db->data = NULL;
    db->pos = 0;
    db->capacity = 0;
}

/* ------- Value Conversion Helpers ------- */

/* Forward declarations */
static void lua_table_to_json_db(lua_State *L, JNIEnv *env, int index, DynBuf *db);
static void lua_value_to_json_db(lua_State *L, JNIEnv *env, int index, DynBuf *db);

static void lua_value_to_json_db(lua_State *L, JNIEnv *env, int index, DynBuf *db) {
    int type = lua_type(L, index);
    switch (type) {
        case LUA_TSTRING: {
            const char *s = lua_tostring(L, index);
            dynbuf_append_escaped(db, s);
            break;
        }
        case LUA_TNUMBER: {
            char num[64];
            if (lua_isinteger(L, index)) {
                snprintf(num, sizeof(num), "%lld", (long long)lua_tointeger(L, index));
            } else {
                double d = lua_tonumber(L, index);
                snprintf(num, sizeof(num), "%.17g", d);
            }
            dynbuf_append(db, num);
            break;
        }
        case LUA_TBOOLEAN:
            dynbuf_append(db, lua_toboolean(L, index) ? "true" : "false");
            break;
        case LUA_TTABLE:
            lua_table_to_json_db(L, env, index, db);
            break;
        case LUA_TNIL:
        default:
            dynbuf_append(db, "null");
            break;
    }
}

static void lua_table_to_json_db(lua_State *L, JNIEnv *env, int index, DynBuf *db) {
    int abs_index = index > 0 ? index : lua_gettop(L) + index + 1;

    /* Detect if array: check if all keys are sequential integers starting from 1 */
    int is_array = 1;
    int max_idx = 0;
    int count = 0;

    lua_pushnil(L);
    while (lua_next(L, abs_index) != 0) {
        count++;
        if (lua_type(L, -2) == LUA_TNUMBER && lua_isinteger(L, -2)) {
            lua_Integer i = lua_tointeger(L, -2);
            if (i > max_idx) max_idx = (int)i;
        } else {
            is_array = 0;
        }
        lua_pop(L, 1);
    }

    if (count == 0) {
        /* Empty table - default to object */
        dynbuf_append(db, "{}");
        return;
    }

    if (is_array && max_idx == count) {
        /* Array */
        dynbuf_append(db, "[");
        for (int i = 1; i <= max_idx; i++) {
            if (i > 1) dynbuf_append(db, ",");
            lua_rawgeti(L, abs_index, i);
            lua_value_to_json_db(L, env, -1, db);
            lua_pop(L, 1);
        }
        dynbuf_append(db, "]");
    } else {
        /* Object */
        dynbuf_append(db, "{");
        int first = 1;
        lua_pushnil(L);
        while (lua_next(L, abs_index) != 0) {
            if (lua_type(L, -2) == LUA_TSTRING) {
                if (!first) dynbuf_append(db, ",");
                first = 0;
                const char *key = lua_tostring(L, -2);
                dynbuf_append_escaped(db, key);
                dynbuf_append(db, ":");
                lua_value_to_json_db(L, env, -1, db);
            }
            lua_pop(L, 1);
        }
        dynbuf_append(db, "}");
    }
}

/* Parse a JSON string and push the corresponding Lua value */
/* Simple recursive-descent JSON parser */
typedef struct {
    const char *data;
    int pos;
    int len;
} JsonParser;

static void json_skip_ws(JsonParser *p) {
    while (p->pos < p->len && (p->data[p->pos] == ' ' || p->data[p->pos] == '\t'
           || p->data[p->pos] == '\n' || p->data[p->pos] == '\r')) {
        p->pos++;
    }
}

static void json_parse_value(lua_State *L, JsonParser *p);

static void json_parse_string(lua_State *L, JsonParser *p) {
    p->pos++; /* skip opening quote */
    char buf[65536];
    int bpos = 0;
    while (p->pos < p->len && p->data[p->pos] != '"') {
        if (p->data[p->pos] == '\\' && p->pos + 1 < p->len) {
            p->pos++;
            switch (p->data[p->pos]) {
                case '"': buf[bpos++] = '"'; break;
                case '\\': buf[bpos++] = '\\'; break;
                case '/': buf[bpos++] = '/'; break;
                case 'n': buf[bpos++] = '\n'; break;
                case 'r': buf[bpos++] = '\r'; break;
                case 't': buf[bpos++] = '\t'; break;
                case 'b': buf[bpos++] = '\b'; break;
                case 'f': buf[bpos++] = '\f'; break;
                default: buf[bpos++] = p->data[p->pos]; break;
            }
        } else {
            if (bpos < (int)sizeof(buf) - 1) buf[bpos++] = p->data[p->pos];
        }
        p->pos++;
    }
    if (p->pos < p->len) p->pos++; /* skip closing quote */
    buf[bpos] = '\0';
    lua_pushstring(L, buf);
}

static void json_parse_number(lua_State *L, JsonParser *p) {
    const char *start = p->data + p->pos;
    int has_dot = 0;
    if (p->data[p->pos] == '-') p->pos++;
    while (p->pos < p->len && ((p->data[p->pos] >= '0' && p->data[p->pos] <= '9')
           || p->data[p->pos] == '.' || p->data[p->pos] == 'e' || p->data[p->pos] == 'E'
           || p->data[p->pos] == '+' || p->data[p->pos] == '-')) {
        if (p->data[p->pos] == '.' || p->data[p->pos] == 'e' || p->data[p->pos] == 'E')
            has_dot = 1;
        p->pos++;
    }
    char tmp[64];
    int len = (int)((p->data + p->pos) - start);
    if (len > 63) len = 63;
    memcpy(tmp, start, len);
    tmp[len] = '\0';
    if (has_dot) {
        lua_pushnumber(L, atof(tmp));
    } else {
        long long val = atoll(tmp);
        if (val >= LUA_MININTEGER && val <= LUA_MAXINTEGER) {
            lua_pushinteger(L, (lua_Integer)val);
        } else {
            lua_pushnumber(L, (lua_Number)val);
        }
    }
}

static void json_parse_array(lua_State *L, JsonParser *p) {
    p->pos++; /* skip [ */
    lua_newtable(L);
    int idx = 1;
    json_skip_ws(p);
    if (p->pos < p->len && p->data[p->pos] == ']') { p->pos++; return; }
    while (p->pos < p->len) {
        json_skip_ws(p);
        json_parse_value(L, p);
        lua_rawseti(L, -2, idx++);
        json_skip_ws(p);
        if (p->pos < p->len && p->data[p->pos] == ',') { p->pos++; continue; }
        break;
    }
    if (p->pos < p->len && p->data[p->pos] == ']') p->pos++;
}

static void json_parse_object(lua_State *L, JsonParser *p) {
    p->pos++; /* skip { */
    lua_newtable(L);
    json_skip_ws(p);
    if (p->pos < p->len && p->data[p->pos] == '}') { p->pos++; return; }
    while (p->pos < p->len) {
        json_skip_ws(p);
        if (p->data[p->pos] != '"') break;
        json_parse_string(L, p);  /* key */
        json_skip_ws(p);
        if (p->pos < p->len && p->data[p->pos] == ':') p->pos++;
        json_skip_ws(p);
        json_parse_value(L, p);   /* value */
        lua_settable(L, -3);
        json_skip_ws(p);
        if (p->pos < p->len && p->data[p->pos] == ',') { p->pos++; continue; }
        break;
    }
    if (p->pos < p->len && p->data[p->pos] == '}') p->pos++;
}

static void json_parse_value(lua_State *L, JsonParser *p) {
    json_skip_ws(p);
    if (p->pos >= p->len) { lua_pushnil(L); return; }
    char c = p->data[p->pos];
    if (c == '"') {
        json_parse_string(L, p);
    } else if (c == '{') {
        json_parse_object(L, p);
    } else if (c == '[') {
        json_parse_array(L, p);
    } else if (c == 't') {
        p->pos += 4; lua_pushboolean(L, 1);
    } else if (c == 'f') {
        p->pos += 5; lua_pushboolean(L, 0);
    } else if (c == 'n') {
        p->pos += 4; lua_pushnil(L);
    } else if (c == '-' || (c >= '0' && c <= '9')) {
        json_parse_number(L, p);
    } else {
        lua_pushnil(L);
    }
}

/* ------- C closure callback dispatcher ------- */

/* Data stored in upvalue for each registered function */
typedef struct {
    int callbackId;
} CallbackData;

static int lua_callback_dispatcher(lua_State *L) {
    CallbackData *cb = (CallbackData*)lua_touserdata(L, lua_upvalueindex(1));
    if (!cb || !g_callbackClass || !g_callbackMethod) return 0;

    JNIEnv *env = getEnv();

    /* Push args as JSON onto a temporary Lua global */
    int nargs = lua_gettop(L);
    DynBuf db = dynbuf_new(65536);
    if (!db.data) return 0;

    dynbuf_append(&db, "[");
    for (int i = 1; i <= nargs; i++) {
        if (i > 1) dynbuf_append(&db, ",");
        lua_value_to_json_db(L, env, i, &db);
    }
    dynbuf_append(&db, "]");

    /* Store args JSON as a Lua global so Kotlin can retrieve it */
    lua_pushstring(L, db.data);
    lua_setglobal(L, "_jni_callback_args");
    dynbuf_free(&db);

    /* Call Kotlin dispatcher */
    int nresults = (*env)->CallStaticIntMethod(env, g_callbackClass, g_callbackMethod,
        (jlong)(intptr_t)L, (jint)cb->callbackId);

    /* Clear any pending JNI exception to prevent crash on next JNI call */
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        return 0;
    }

    /* Return value should have been pushed onto the stack by Kotlin via pushValue */
    return nresults;
}

/* ------- JNI Functions ------- */

JNIEXPORT jlong JNICALL
Java_com_melody_lua_LuaBridge_newState(JNIEnv *env, jclass cls) {
    lua_State *L = luaL_newstate();
    if (L) luaL_openlibs(L);
    return (jlong)(intptr_t)L;
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_closeState(JNIEnv *env, jclass cls, jlong ptr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    if (L) lua_close(L);
}

JNIEXPORT jstring JNICALL
Java_com_melody_lua_LuaBridge_execute(JNIEnv *env, jclass cls, jlong ptr, jstring script) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *code = (*env)->GetStringUTFChars(env, script, NULL);

    int status = luaL_loadstring(L, code);
    (*env)->ReleaseStringUTFChars(env, script, code);

    if (status != LUA_OK) {
        const char *msg = lua_tostring(L, -1);
        jstring err = (*env)->NewStringUTF(env, msg ? msg : "syntax error");
        lua_pop(L, 1);
        return err;
    }

    status = lua_pcall(L, 0, 1, 0);
    if (status != LUA_OK) {
        const char *msg = lua_tostring(L, -1);
        jstring err = (*env)->NewStringUTF(env, msg ? msg : "runtime error");
        lua_pop(L, 1);
        return err;
    }

    /* Leave result on stack for getValue */
    return NULL; /* null = success */
}

JNIEXPORT jstring JNICALL
Java_com_melody_lua_LuaBridge_evaluate(JNIEnv *env, jclass cls, jlong ptr, jstring expr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *code = (*env)->GetStringUTFChars(env, expr, NULL);

    /* Wrap in "return " */
    size_t len = strlen(code);
    char *wrapped = malloc(len + 8);
    strcpy(wrapped, "return ");
    strcat(wrapped, code);
    (*env)->ReleaseStringUTFChars(env, expr, code);

    int status = luaL_loadstring(L, wrapped);
    free(wrapped);

    if (status != LUA_OK) {
        const char *msg = lua_tostring(L, -1);
        jstring err = (*env)->NewStringUTF(env, msg ? msg : "syntax error");
        lua_pop(L, 1);
        return err;
    }

    status = lua_pcall(L, 0, 1, 0);
    if (status != LUA_OK) {
        const char *msg = lua_tostring(L, -1);
        jstring err = (*env)->NewStringUTF(env, msg ? msg : "runtime error");
        lua_pop(L, 1);
        return err;
    }

    /* Convert result to JSON */
    DynBuf db = dynbuf_new(65536);
    lua_value_to_json_db(L, env, -1, &db);
    lua_pop(L, 1);
    jstring result = (*env)->NewStringUTF(env, db.data ? db.data : "null");
    dynbuf_free(&db);
    return result;
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_pushValue(JNIEnv *env, jclass cls, jlong ptr, jstring json) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *str = (*env)->GetStringUTFChars(env, json, NULL);
    JsonParser p = { str, 0, (int)strlen(str) };
    json_parse_value(L, &p);
    (*env)->ReleaseStringUTFChars(env, json, str);
}

JNIEXPORT jstring JNICALL
Java_com_melody_lua_LuaBridge_getValue(JNIEnv *env, jclass cls, jlong ptr, jint index) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    DynBuf db = dynbuf_new(65536);
    lua_value_to_json_db(L, env, (int)index, &db);
    jstring result = (*env)->NewStringUTF(env, db.data ? db.data : "null");
    dynbuf_free(&db);
    return result;
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_getGlobal(JNIEnv *env, jclass cls, jlong ptr, jstring name) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *n = (*env)->GetStringUTFChars(env, name, NULL);
    lua_getglobal(L, n);
    (*env)->ReleaseStringUTFChars(env, name, n);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_setGlobal(JNIEnv *env, jclass cls, jlong ptr, jstring name) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *n = (*env)->GetStringUTFChars(env, name, NULL);
    lua_setglobal(L, n);
    (*env)->ReleaseStringUTFChars(env, name, n);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_pop(JNIEnv *env, jclass cls, jlong ptr, jint count) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    lua_pop(L, (int)count);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_registerFunction(JNIEnv *env, jclass cls, jlong ptr,
        jstring table, jstring name, jint callbackId) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *tbl = (*env)->GetStringUTFChars(env, table, NULL);
    const char *nm = (*env)->GetStringUTFChars(env, name, NULL);

    lua_getglobal(L, tbl);
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setglobal(L, tbl);
        lua_getglobal(L, tbl);
    }

    CallbackData *cb = (CallbackData*)lua_newuserdata(L, sizeof(CallbackData));
    cb->callbackId = (int)callbackId;
    lua_pushcclosure(L, lua_callback_dispatcher, 1);
    lua_setfield(L, -2, nm);
    lua_pop(L, 1); /* pop table */

    (*env)->ReleaseStringUTFChars(env, table, tbl);
    (*env)->ReleaseStringUTFChars(env, name, nm);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_setTableField(JNIEnv *env, jclass cls, jlong ptr,
        jstring table, jstring key, jstring json) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *tbl = (*env)->GetStringUTFChars(env, table, NULL);
    const char *k = (*env)->GetStringUTFChars(env, key, NULL);
    const char *j = (*env)->GetStringUTFChars(env, json, NULL);

    lua_getglobal(L, tbl);
    if (lua_istable(L, -1)) {
        JsonParser p = { j, 0, (int)strlen(j) };
        json_parse_value(L, &p);
        lua_setfield(L, -2, k);
    }
    lua_pop(L, 1);

    (*env)->ReleaseStringUTFChars(env, table, tbl);
    (*env)->ReleaseStringUTFChars(env, key, k);
    (*env)->ReleaseStringUTFChars(env, json, j);
}

JNIEXPORT jstring JNICALL
Java_com_melody_lua_LuaBridge_getTableField(JNIEnv *env, jclass cls, jlong ptr,
        jstring table, jstring key) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *tbl = (*env)->GetStringUTFChars(env, table, NULL);
    const char *k = (*env)->GetStringUTFChars(env, key, NULL);

    lua_getglobal(L, tbl);
    jstring result;
    if (lua_istable(L, -1)) {
        lua_getfield(L, -1, k);
        DynBuf db = dynbuf_new(65536);
        lua_value_to_json_db(L, env, -1, &db);
        result = (*env)->NewStringUTF(env, db.data ? db.data : "null");
        dynbuf_free(&db);
        lua_pop(L, 2);
    } else {
        result = (*env)->NewStringUTF(env, "null");
        lua_pop(L, 1);
    }

    (*env)->ReleaseStringUTFChars(env, table, tbl);
    (*env)->ReleaseStringUTFChars(env, key, k);
    return result;
}

/* Proxy metatable __index: read from backing data table */
static int proxy_index(lua_State *L) {
    const char *data_name = lua_tostring(L, lua_upvalueindex(1));
    const char *key = lua_tostring(L, 2);
    if (!data_name || !key) {
        LOGE("proxy_index: null data_name or key");
        lua_pushnil(L);
        return 1;
    }
    lua_getglobal(L, data_name);
    lua_getfield(L, -1, key);
    lua_remove(L, -2); /* remove the data table, keep only the value */
    return 1;
}

/* Proxy metatable __newindex: write to data table and notify Kotlin */
static int proxy_newindex(lua_State *L) {
    CallbackData *cb = (CallbackData*)lua_touserdata(L, lua_upvalueindex(1));
    const char *data_name = lua_tostring(L, lua_upvalueindex(2));
    const char *key = lua_tostring(L, 2);

    /* Store in data table */
    lua_getglobal(L, data_name);
    lua_pushvalue(L, 3);
    lua_setfield(L, -2, key);
    lua_pop(L, 1);

    /* Notify Kotlin via callback */
    JNIEnv *env = getEnv();
    if (!env) {
        LOGE("proxy_newindex: getEnv() returned NULL");
        return 0;
    }

    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
    }

    if (g_callbackClass && g_callbackMethod) {
        DynBuf db = dynbuf_new(65536);
        if (db.data) {
            dynbuf_append(&db, "[");
            dynbuf_append_escaped(&db, key);
            dynbuf_append(&db, ",");
            lua_value_to_json_db(L, env, 3, &db);
            dynbuf_append(&db, "]");

            lua_pushstring(L, db.data);
            lua_setglobal(L, "_jni_callback_args");
            dynbuf_free(&db);

            (*env)->CallStaticIntMethod(env, g_callbackClass, g_callbackMethod,
                (jlong)(intptr_t)L, (jint)cb->callbackId);

            if ((*env)->ExceptionCheck(env)) {
                LOGE("proxy_newindex: JNI exception for key=%s", key ? key : "(null)");
                (*env)->ExceptionDescribe(env);
                (*env)->ExceptionClear(env);
            }
        } else {
            LOGE("proxy_newindex: malloc failed");
        }
    }
    return 0;
}

/* Create state proxy table with metatable for __index/__newindex callbacks */
JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_createStateProxy(JNIEnv *env, jclass cls, jlong ptr,
        jstring proxyName, jstring dataName, jint callbackId) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *proxy = (*env)->GetStringUTFChars(env, proxyName, NULL);
    const char *data = (*env)->GetStringUTFChars(env, dataName, NULL);

    /* Create the data backing table */
    lua_newtable(L);
    lua_setglobal(L, data);

    /* Create proxy table */
    lua_newtable(L);

    /* Create metatable */
    lua_newtable(L);

    /* __index: read from data table */
    lua_pushstring(L, data);
    lua_pushcclosure(L, proxy_index, 1);
    lua_setfield(L, -2, "__index");

    /* __newindex: write to data table and notify Kotlin */
    CallbackData *cb = (CallbackData*)lua_newuserdata(L, sizeof(CallbackData));
    cb->callbackId = (int)callbackId;
    lua_pushstring(L, data);
    lua_pushcclosure(L, proxy_newindex, 2);
    lua_setfield(L, -2, "__newindex");

    /* Set metatable on proxy */
    lua_setmetatable(L, -2);
    lua_setglobal(L, proxy);

    (*env)->ReleaseStringUTFChars(env, proxyName, proxy);
    (*env)->ReleaseStringUTFChars(env, dataName, data);
}

/* ------- Coroutine Support ------- */

JNIEXPORT jlong JNICALL
Java_com_melody_lua_LuaBridge_newThread(JNIEnv *env, jclass cls, jlong ptr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    lua_State *co = lua_newthread(L);
    return (jlong)(intptr_t)co;
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_resumeThread(JNIEnv *env, jclass cls, jlong mainPtr,
        jlong coPtr, jint nargs, jintArray nresultsOut) {
    lua_State *L = (lua_State*)(intptr_t)mainPtr;
    lua_State *co = (lua_State*)(intptr_t)coPtr;
    int nresults = 0;

    int status = lua_resume(co, L, (int)nargs, &nresults);

    if ((*env)->ExceptionCheck(env)) {
        LOGE("resumeThread: JNI exception after lua_resume");
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }

    jint nr = nresults;
    (*env)->SetIntArrayRegion(env, nresultsOut, 0, 1, &nr);
    return (jint)status;
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_loadString(JNIEnv *env, jclass cls, jlong ptr, jstring code) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    const char *c = (*env)->GetStringUTFChars(env, code, NULL);
    int status = luaL_loadstring(L, c);
    (*env)->ReleaseStringUTFChars(env, code, c);
    return (jint)status;
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_xmove(JNIEnv *env, jclass cls, jlong fromPtr, jlong toPtr, jint n) {
    lua_State *from = (lua_State*)(intptr_t)fromPtr;
    lua_State *to = (lua_State*)(intptr_t)toPtr;
    lua_xmove(from, to, (int)n);
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_saveRef(JNIEnv *env, jclass cls, jlong ptr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    return (jint)luaL_ref(L, LUA_REGISTRYINDEX);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_releaseRef(JNIEnv *env, jclass cls, jlong ptr, jint ref) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    luaL_unref(L, LUA_REGISTRYINDEX, (int)ref);
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_getTop(JNIEnv *env, jclass cls, jlong ptr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    return (jint)lua_gettop(L);
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_typeAt(JNIEnv *env, jclass cls, jlong ptr, jint index) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    return (jint)lua_type(L, (int)index);
}

JNIEXPORT jstring JNICALL
Java_com_melody_lua_LuaBridge_getCallbackArgs(JNIEnv *env, jclass cls, jlong ptr) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    lua_getglobal(L, "_jni_callback_args");
    const char *args = lua_tostring(L, -1);
    jstring result = args ? (*env)->NewStringUTF(env, args) : (*env)->NewStringUTF(env, "[]");
    lua_pop(L, 1);
    return result;
}

JNIEXPORT jlong JNICALL
Java_com_melody_lua_LuaBridge_tableLen(JNIEnv *env, jclass cls, jlong ptr, jint index) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    return (jlong)luaL_len(L, (int)index);
}

JNIEXPORT void JNICALL
Java_com_melody_lua_LuaBridge_rawGetI(JNIEnv *env, jclass cls, jlong ptr, jint index, jlong n) {
    lua_State *L = (lua_State*)(intptr_t)ptr;
    lua_rawgeti(L, (int)index, (lua_Integer)n);
}

/* LUA_OK / LUA_YIELD constants for Kotlin */
JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_getLuaOk(JNIEnv *env, jclass cls) {
    return LUA_OK;
}

JNIEXPORT jint JNICALL
Java_com_melody_lua_LuaBridge_getLuaYield(JNIEnv *env, jclass cls) {
    return LUA_YIELD;
}
