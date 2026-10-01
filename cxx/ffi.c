#include "ffi.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

static inline JSValue *new_jsvalue(JSValue v)
{
  JSValue *val = (JSValue *)malloc(sizeof(JSValue));
  if (val)
    *val = v;
  return val;
}

DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
{
  return new_jsvalue(JS_Throw(ctx, JS_DupValue(ctx, *obj)));
}

DLLEXPORT JSValue *jsEXCEPTION(void)
{
  return new_jsvalue(JS_EXCEPTION);
}

DLLEXPORT JSValue *jsUNDEFINED(void)
{
  return new_jsvalue(JS_UNDEFINED);
}

DLLEXPORT JSValue *jsNULL(void)
{
  return new_jsvalue(JS_NULL);
}

struct RuntimeOpaque {
  JSChannel *channel;
  int64_t timeout;
  int64_t start;
};
typedef struct RuntimeOpaque RuntimeOpaque;

static JSModuleDef *js_module_loader(
    JSContext *ctx,
    const char *module_name, void *opaque)
{
  const char *str = (char *)((RuntimeOpaque *)opaque)->channel(ctx, JSChannelType_MODULE, (void *)module_name);
  if (str == NULL)
    return NULL;
  JSValue func_val = JS_Eval(ctx, str, strlen(str), module_name, JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
  if (JS_IsException(func_val))
    return NULL;
  /* the module is already referenced, so we must free it */
  JSModuleDef *m = (JSModuleDef *)JS_VALUE_GET_PTR(func_val);
  JS_FreeValue(ctx, func_val);
  return m;
}

static JSValue js_channel(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValue *func_data)
{
  JSRuntime *rt = JS_GetRuntime(ctx);
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  void *data[4];
  data[0] = (void *)&this_val;
  data[1] = (void *)&argc;
  data[2] = (void *)argv;
  data[3] = (void *)func_data;
  return *(JSValue *)opaque->channel(ctx, JSChannelType_METHON, data);
}

static void js_promise_rejection_tracker(JSContext *ctx, JSValueConst promise,
                                         JSValueConst reason,
                                         JS_BOOL is_handled, void *opaque)
{
  if (is_handled)
    return;
  ((RuntimeOpaque *)opaque)->channel(ctx, JSChannelType_PROMISE_TRACK, (void *)&reason);
}

static int js_interrupt_handler(JSRuntime *rt, void *opaque)
{
  RuntimeOpaque *op = (RuntimeOpaque *)opaque;
  if (op->timeout && op->start && (clock() - op->start) > op->timeout * CLOCKS_PER_SEC / 1000) {
    op->start = 0;
    return 1;
  }
  return 0;
}

DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel, int64_t timeout)
{
  JSRuntime *rt = JS_NewRuntime();
  RuntimeOpaque *opaque = (RuntimeOpaque *)malloc(sizeof(RuntimeOpaque));
  if (opaque) {
    opaque->channel = channel;
    opaque->timeout = timeout;
    opaque->start = 0;
  }
  JS_SetRuntimeOpaque(rt, opaque);
  JS_SetHostPromiseRejectionTracker(rt, js_promise_rejection_tracker, opaque);
  JS_SetModuleLoaderFunc(rt, NULL, js_module_loader, opaque);
  JS_SetInterruptHandler(rt, js_interrupt_handler, opaque);
  return rt;
}

static void js_class_finalizer(JSRuntime *rt, JSValue obj)
{
  JSClassID classid = JS_GetClassID(obj);
  void *opaque = JS_GetOpaque(obj, classid);
  RuntimeOpaque *runtimeOpaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  if (runtimeOpaque == NULL)
    return;
  runtimeOpaque->channel((JSContext *)rt, JSChannelType_FREE_OBJECT, opaque);
}

DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
{
  JSClassID QJSClassId = 0;
  JS_NewClassID(&QJSClassId);
  JSRuntime *rt = JS_GetRuntime(ctx);
  if (!JS_IsRegisteredClass(rt, QJSClassId))
  {
    JSClassDef def;
    memset(&def, 0, sizeof(def));
    def.class_name = name;
    def.finalizer = js_class_finalizer;
    int e = JS_NewClass(rt, QJSClassId, &def);
    if (e < 0)
    {
      JS_ThrowInternalError(ctx, "Cant register class %s", name);
      return 0;
    }
  }
  return QJSClassId;
}

DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
{
  return JS_GetOpaque(*obj, classid);
}

DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
{
  JSValue *jsobj = new_jsvalue(JS_NewObjectClass(ctx, QJSClassId));
  if (jsobj == NULL || JS_IsException(*jsobj))
    return jsobj;
  JS_SetOpaque(*jsobj, opaque);
  return jsobj;
}

DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
{
  JS_SetMaxStackSize(rt, stack_size);
}

DLLEXPORT void jsSetMemoryLimit(JSRuntime *rt, size_t limit)
{
  JS_SetMemoryLimit(rt, limit);
}

DLLEXPORT void jsFreeRuntime(JSRuntime *rt)
{
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  if (opaque)
    free(opaque);
  JS_SetRuntimeOpaque(rt, NULL);
  JS_FreeRuntime(rt);
}

DLLEXPORT JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
{
  return new_jsvalue(JS_NewCFunctionData(ctx, js_channel, 0, 0, 1, funcData));
}

DLLEXPORT JSContext *jsNewContext(JSRuntime *rt)
{
  JS_UpdateStackTop(rt);
  JSContext *ctx = JS_NewContext(rt);
  return ctx;
}

DLLEXPORT void jsFreeContext(JSContext *ctx)
{
  JS_FreeContext(ctx);
}

DLLEXPORT JSRuntime *jsGetRuntime(JSContext *ctx)
{
  return JS_GetRuntime(ctx);
}

static void js_begin_call(JSRuntime *rt)
{
  JS_UpdateStackTop(rt);
  RuntimeOpaque *opaque = (RuntimeOpaque *)JS_GetRuntimeOpaque(rt);
  if (opaque)
    opaque->start = clock();
}

DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int32_t eval_flags)
{
  JSRuntime *rt = JS_GetRuntime(ctx);
  js_begin_call(rt);
  return new_jsvalue(JS_Eval(ctx, input, input_len, filename, eval_flags));
}

DLLEXPORT int32_t jsValueGetTag(JSValue *val)
{
  return JS_VALUE_GET_TAG(*val);
}

DLLEXPORT void *jsValueGetPtr(JSValue *val)
{
  return JS_VALUE_GET_PTR(*val);
}

DLLEXPORT int32_t jsTagIsFloat64(int32_t tag)
{
  return JS_TAG_IS_FLOAT64(tag);
}

DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int32_t val)
{
  return new_jsvalue(JS_NewBool(ctx, val));
}

DLLEXPORT JSValue *jsNewInt64(JSContext *ctx, int64_t val)
{
  return new_jsvalue(JS_NewInt64(ctx, val));
}

DLLEXPORT JSValue *jsNewFloat64(JSContext *ctx, double val)
{
  return new_jsvalue(JS_NewFloat64(ctx, val));
}

DLLEXPORT JSValue *jsNewString(JSContext *ctx, const char *str)
{
  return new_jsvalue(JS_NewString(ctx, str));
}

DLLEXPORT JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
{
  return new_jsvalue(JS_NewArrayBufferCopy(ctx, buf, len));
}

DLLEXPORT JSValue *jsNewArray(JSContext *ctx)
{
  return new_jsvalue(JS_NewArray(ctx));
}

DLLEXPORT JSValue *jsNewObject(JSContext *ctx)
{
  return new_jsvalue(JS_NewObject(ctx));
}

DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v, int32_t free_mem)
{
  JS_FreeValue(ctx, *v);
  if (free_mem)
    free(v);
}

DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v, int32_t free_mem)
{
  JS_FreeValueRT(rt, *v);
  if (free_mem)
    free(v);
}

DLLEXPORT JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
{
  return new_jsvalue(JS_DupValue(ctx, *v));
}

DLLEXPORT JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
{
  return new_jsvalue(JS_DupValueRT(rt, *v));
}

DLLEXPORT int32_t jsToBool(JSContext *ctx, JSValueConst *val)
{
  return JS_ToBool(ctx, *val);
}

DLLEXPORT int64_t jsToInt64(JSContext *ctx, JSValueConst *val)
{
  int64_t p;
  JS_ToInt64(ctx, &p, *val);
  return p;
}

DLLEXPORT double jsToFloat64(JSContext *ctx, JSValueConst *val)
{
  double p;
  JS_ToFloat64(ctx, &p, *val);
  return p;
}

DLLEXPORT const char *jsToCString(JSContext *ctx, JSValueConst *val)
{
  JSRuntime *rt = JS_GetRuntime(ctx);
  js_begin_call(rt);
  return JS_ToCString(ctx, *val);
}

DLLEXPORT void jsFreeCString(JSContext *ctx, const char *ptr)
{
  JS_FreeCString(ctx, ptr);
}

DLLEXPORT uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
{
  return JS_GetArrayBuffer(ctx, psize, *obj);
}

DLLEXPORT int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
{
  return JS_IsFunction(ctx, *val);
}

DLLEXPORT int32_t jsIsPromise(JSContext *ctx, JSValueConst *val)
{
  return JS_IsPromise(ctx, *val);
}

DLLEXPORT int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
{
  return JS_IsArray(ctx, *val);
}

DLLEXPORT int32_t jsIsMap(JSContext *ctx, JSValueConst *val)
{
  return JS_IsMap(ctx, *val);
}

DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValueConst *val)
{
  return JS_IsError(ctx, *val);
}

DLLEXPORT JSValue *jsNewError(JSContext *ctx)
{
  return new_jsvalue(JS_NewError(ctx));
}

DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
                                 JSAtom prop)
{
  return new_jsvalue(JS_GetProperty(ctx, *this_obj, prop));
}

DLLEXPORT int32_t jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
                                        JSAtom prop, JSValue *val, int32_t flags)
{
  return JS_DefinePropertyValue(ctx, *this_obj, prop, *val, flags);
}

DLLEXPORT void jsFreeAtom(JSContext *ctx, JSAtom v)
{
  JS_FreeAtom(ctx, v);
}

DLLEXPORT JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
{
  return JS_ValueToAtom(ctx, *val);
}

DLLEXPORT JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
{
  return new_jsvalue(JS_AtomToValue(ctx, val));
}

DLLEXPORT int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
                                        uint32_t *plen, JSValueConst *obj, int32_t flags)
{
  return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
}

DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i)
{
  return ptab[i].atom;
}

DLLEXPORT uint32_t sizeOfJSValue(void)
{
  return (uint32_t)sizeof(JSValue);
}

DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val)
{
  list[i] = *val;
}

DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
                          int32_t argc, JSValueConst *argv)
{
  JSRuntime *rt = JS_GetRuntime(ctx);
  js_begin_call(rt);
  return new_jsvalue(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
}

DLLEXPORT int32_t jsIsException(JSValueConst *val)
{
  return JS_IsException(*val);
}

DLLEXPORT JSValue *jsGetException(JSContext *ctx)
{
  return new_jsvalue(JS_GetException(ctx));
}

DLLEXPORT int32_t jsExecutePendingJob(JSRuntime *rt)
{
  js_begin_call(rt);
  JSContext *ctx;
  return JS_ExecutePendingJob(rt, &ctx);
}

DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
{
  return new_jsvalue(JS_NewPromiseCapability(ctx, resolving_funcs));
}

DLLEXPORT void jsFree(JSContext *ctx, void *ptab)
{
  js_free(ctx, ptab);
}

DLLEXPORT uint8_t *CompileScript(JSContext *ctx, const char *script, const char *fileName, size_t *lengthPtr)
{
  JSValue value = JS_Eval(ctx, script, strlen(script), fileName, JS_EVAL_FLAG_COMPILE_ONLY);

  if (JS_IsException(value)) {
    JS_FreeValue(ctx, value);
    return NULL;
  }

  return JS_WriteObject(ctx, lengthPtr, value, JS_WRITE_OBJ_BYTECODE);
}

DLLEXPORT JSValue *EvaluateBytecode(JSContext *ctx, size_t length, uint8_t *buf)
{
  JSValue obj = JS_ReadObject(ctx, buf, length, JS_READ_OBJ_BYTECODE);

  if (JS_IsException(obj)) {
    return NULL;
  }

  JSValue value = JS_EvalFunction(ctx, obj);
  return new_jsvalue(value);
}
