/*
 * @Description: wrapper
 * @Author: ekibun
 * @Date: 2020-09-19 22:07:47
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:03
 */
part of 'quickjs_runtime2.dart';

dynamic _parseJSException(Pointer<JSContext> ctx, [Pointer<JSValue>? perr]) {
  final e = perr ?? jsGetException(ctx);
  var err;
  try {
    err = _jsToDart(ctx, e);
  } catch (exception) {
    err = exception;
  }
  if (perr == null) jsFreeValue(ctx, e);
  return err;
}

void _definePropertyValue(
  Pointer<JSContext> ctx,
  Pointer<JSValue> obj,
  dynamic key,
  dynamic val, {
  Map<dynamic, Pointer<JSValue>>? cache,
}) {
  final jsAtomVal = _dartToJs(ctx, key, cache: cache);
  final jsAtom = jsValueToAtom(ctx, jsAtomVal);
  jsDefinePropertyValue(
    ctx,
    obj,
    jsAtom,
    _dartToJs(ctx, val, cache: cache),
    JSProp.C_W_E,
  );
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
}

Pointer<JSValue> _jsGetPropertyValue(
  Pointer<JSContext> ctx,
  Pointer<JSValue> obj,
  dynamic key, {
  Map<dynamic, Pointer<JSValue>>? cache,
}) {
  final jsAtomVal = _dartToJs(ctx, key, cache: cache);
  final jsAtom = jsValueToAtom(ctx, jsAtomVal);
  final jsProp = jsGetProperty(ctx, obj, jsAtom);
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
  return jsProp;
}

/// Fast path: copy a Dart [TypedData] view directly into a JS TypedArray via a
/// single memcpy, bypassing per-element marshaling. Returns null for typed data
/// kinds without a matching JS TypedArray (falls back to the generic path).
Pointer<JSValue>? _typedDataToJs(Pointer<JSContext> ctx, TypedData val) {
  final int type;
  if (val is Int8List)
    type = JSTypedArrayType.INT8;
  else if (val is Uint8ClampedList)
    type = JSTypedArrayType.UINT8C;
  else if (val is Uint8List)
    type = JSTypedArrayType.UINT8;
  else if (val is Int16List)
    type = JSTypedArrayType.INT16;
  else if (val is Uint16List)
    type = JSTypedArrayType.UINT16;
  else if (val is Int32List)
    type = JSTypedArrayType.INT32;
  else if (val is Uint32List)
    type = JSTypedArrayType.UINT32;
  else if (val is Int64List)
    type = JSTypedArrayType.BIG_INT64;
  else if (val is Uint64List)
    type = JSTypedArrayType.BIG_UINT64;
  else if (val is Float32List)
    type = JSTypedArrayType.FLOAT32;
  else if (val is Float64List)
    type = JSTypedArrayType.FLOAT64;
  else
    return null;
  final byteLength = val.lengthInBytes;
  final ptr = jsAllocBuffer(byteLength);
  if (ptr.address == 0) throw JSError('Out of memory');
  final bytes = val.buffer.asUint8List(val.offsetInBytes, byteLength);
  ptr.asTypedList(byteLength).setAll(0, bytes);
  return jsNewTypedArrayOwned(ctx, ptr, byteLength, type);
}

/// Fast path: convert a JS TypedArray to the matching Dart typed list via a
/// single memcpy. Returns null when [val] is not a typed array.
TypedData? _jsTypedArrayToDart(Pointer<JSContext> ctx, Pointer<JSValue> val) {
  final plength = malloc<IntPtr>();
  final ptype = malloc<Int32>();
  final data = jsGetTypedArrayData(ctx, val, plength, ptype);
  if (data.address == 0) {
    malloc.free(plength);
    malloc.free(ptype);
    return null;
  }
  final byteLength = plength.value;
  final type = ptype.value;
  malloc.free(plength);
  malloc.free(ptype);
  final bytes = data.asTypedList(byteLength);
  // Copy into a Dart-owned buffer (data is owned by the JS engine).
  final copy = Uint8List.fromList(bytes);
  final bd = copy.buffer;
  switch (type) {
    case JSTypedArrayType.INT8:
      return bd.asInt8List();
    case JSTypedArrayType.UINT8:
      return copy;
    case JSTypedArrayType.UINT8C:
      return Uint8ClampedList.fromList(copy);
    case JSTypedArrayType.INT16:
      return bd.asInt16List();
    case JSTypedArrayType.UINT16:
      return bd.asUint16List();
    case JSTypedArrayType.INT32:
      return bd.asInt32List();
    case JSTypedArrayType.UINT32:
      return bd.asUint32List();
    case JSTypedArrayType.BIG_INT64:
      return bd.asInt64List();
    case JSTypedArrayType.BIG_UINT64:
      return bd.asUint64List();
    case JSTypedArrayType.FLOAT32:
      return bd.asFloat32List();
    case JSTypedArrayType.FLOAT64:
      return bd.asFloat64List();
    default:
      return copy;
  }
}

Pointer<JSValue> _dartToJs(
  Pointer<JSContext> ctx,
  dynamic val, {
  Map<dynamic, Pointer<JSValue>>? cache,
}) {
  if (val == null) return jsUNDEFINED();
  if (val is Error) return _dartToJs(ctx, JSError(val, val.stackTrace));
  if (val is Exception) return _dartToJs(ctx, JSError(val));
  if (val is JSError) {
    final ret = jsNewError(ctx);
    _definePropertyValue(ctx, ret, "name", "");
    _definePropertyValue(ctx, ret, "message", val.message);
    _definePropertyValue(ctx, ret, "stack", val.stack);
    return ret;
  }
  if (val is _JSObject) return jsDupValue(ctx, val._val!);
  if (val is Future) {
    final resolvingFunc = malloc<Uint8>(sizeOfJSValue * 2).cast<JSValue>();
    final resolvingFunc2 = Pointer<JSValue>.fromAddress(
      resolvingFunc.address + sizeOfJSValue,
    );
    final ret = jsNewPromiseCapability(ctx, resolvingFunc);
    final _JSFunction res = _jsToDart(ctx, resolvingFunc);
    final _JSFunction rej = _jsToDart(ctx, resolvingFunc2);
    jsFreeValue(ctx, resolvingFunc, free: false);
    jsFreeValue(ctx, resolvingFunc2, free: false);
    malloc.free(resolvingFunc);
    final refRes = _DartObject(ctx, res);
    final refRej = _DartObject(ctx, rej);
    res.free();
    rej.free();
    val
        .then(
          (value) {
            res.invoke([value]);
          },
          onError: (e) {
            rej.invoke([e]);
          },
        )
        .whenComplete(() {
          refRes.free();
          refRej.free();
        });
    return ret;
  }
  if (cache == null) cache = Map();
  if (val is bool) return jsNewBool(ctx, val ? 1 : 0);
  if (val is int) return jsNewInt64(ctx, val);
  if (val is double) return jsNewFloat64(ctx, val);
  if (val is String) return jsNewString(ctx, val);
  if (val is TypedData) {
    final ta = _typedDataToJs(ctx, val);
    if (ta != null) return ta;
  }
  // ByteBuffer without a TypedArray view → ArrayBuffer.
  if (val is ByteBuffer) {
    final bytes = val.asUint8List();
    final ptr = jsAllocBuffer(bytes.length);
    if (ptr.address == 0) throw JSError('Out of memory');
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    return jsNewArrayBufferOwned(ctx, ptr, bytes.length);
  }
  if (cache.containsKey(val)) {
    return jsDupValue(ctx, cache[val]!);
  }
  if (val is List) {
    final ret = jsNewArray(ctx);
    cache[val] = ret;
    for (int i = 0; i < val.length; ++i) {
      final jsItem = _dartToJs(ctx, val[i], cache: cache);
      jsDefinePropertyValueUint32(ctx, ret, i, jsItem, JSProp.C_W_E);
    }
    return ret;
  }
  if (val is Map) {
    final ret = jsNewObject(ctx);
    cache[val] = ret;
    for (MapEntry<dynamic, dynamic> entry in val.entries) {
      _definePropertyValue(ctx, ret, entry.key, entry.value, cache: cache);
    }
    return ret;
  }
  // wrap Function to JSInvokable
  final valWrap = JSInvokable._wrap(val);
  final dartObjectClassId =
      runtimeOpaques[jsGetRuntime(ctx)]?.dartObjectClassId ?? 0;
  if (dartObjectClassId == 0) return jsUNDEFINED();
  final dartObject = jsNewObjectClass(
    ctx,
    dartObjectClassId,
    identityHashCode(_DartObject(ctx, valWrap)),
  );
  if (valWrap is JSInvokable) {
    final ret = jsNewCFunction(ctx, dartObject);
    jsFreeValue(ctx, dartObject);
    return ret;
  }
  return dartObject;
}

dynamic _jsToDart(
  Pointer<JSContext> ctx,
  Pointer<JSValue> val, {
  Map<int, dynamic>? cache,
}) {
  if (cache == null) cache = Map();
  final tag = jsValueGetTag(val);
  if (jsTagIsFloat64(tag) != 0) {
    return jsToFloat64(ctx, val);
  }
  switch (tag) {
    case JSTag.BOOL:
      return jsToBool(ctx, val) != 0;
    case JSTag.INT:
      return jsToInt64(ctx, val);
    case JSTag.STRING:
      return jsToCString(ctx, val);
    case JSTag.OBJECT:
      final rt = jsGetRuntime(ctx);
      final dartObjectClassId = runtimeOpaques[rt]?.dartObjectClassId;
      if (dartObjectClassId != null) {
        final dartObject = _DartObject.fromAddress(
          rt,
          jsGetObjectOpaque(val, dartObjectClassId),
        );
        if (dartObject != null) return dartObject._obj;
      }
      final psize = malloc<IntPtr>();
      final buf = jsGetArrayBuffer(ctx, psize, val);
      final size = psize.value;
      malloc.free(psize);
      if (buf.address != 0) {
        return Uint8List.fromList(buf.asTypedList(size));
      }
      final typedArray = _jsTypedArrayToDart(ctx, val);
      if (typedArray != null) return typedArray;
      final valptr = jsValueGetPtr(val);
      if (cache.containsKey(valptr)) {
        return cache[valptr];
      }
      if (jsIsFunction(ctx, val) != 0) {
        return _JSFunction(ctx, val);
      } else if (jsIsError(ctx, val) != 0) {
        final err = jsToCString(ctx, val);
        final pstack = _jsGetPropertyValue(ctx, val, 'stack');
        final stack = jsToBool(ctx, pstack) != 0
            ? jsToCString(ctx, pstack)
            : null;
        jsFreeValue(ctx, pstack);
        return JSError(err, stack);
      } else if (jsIsPromise(ctx, val) != 0) {
        final jsPromiseThen = _jsGetPropertyValue(ctx, val, 'then');
        final _JSFunction promiseThen = _jsToDart(
          ctx,
          jsPromiseThen,
          cache: cache,
        );
        jsFreeValue(ctx, jsPromiseThen);
        final completer = Completer();
        completer.future.catchError((e) {});
        final jsPromise = _JSObject(ctx, val);
        final jsRet = promiseThen._invoke([
          (v) {
            JSRef.dupRecursive(v);
            if (!completer.isCompleted) completer.complete(v);
          },
          (e) {
            JSRef.dupRecursive(e);
            if (!completer.isCompleted) completer.completeError(e);
          },
        ], jsPromise);
        jsPromise.free();
        promiseThen.free();
        final isException = jsIsException(jsRet) != 0;
        jsFreeValue(ctx, jsRet);
        if (isException) throw _parseJSException(ctx);
        return completer.future;
      } else if (jsIsArray(ctx, val) != 0) {
        final jslength = _jsGetPropertyValue(ctx, val, 'length');
        final length = jsToInt64(ctx, jslength);
        jsFreeValue(ctx, jslength);
        final ret = [];
        cache[valptr] = ret;
        for (var i = 0; i < length; ++i) {
          final jsProp = jsGetPropertyUint32(ctx, val, i);
          ret.add(_jsToDart(ctx, jsProp, cache: cache));
          jsFreeValue(ctx, jsProp);
        }
        return ret;
      } else {
        final ptab = malloc<Pointer<JSPropertyEnum>>();
        final plen = malloc<Uint32>();
        if (jsGetOwnPropertyNames(ctx, ptab, plen, val, -1) != 0) {
          malloc.free(plen);
          malloc.free(ptab);
          return null;
        }
        final len = plen.value;
        malloc.free(plen);
        final ret = Map();
        cache[valptr] = ret;
        for (var i = 0; i < len; ++i) {
          final jsAtom = jsPropertyEnumGetAtom(ptab.value, i);
          final jsAtomValue = jsAtomToValue(ctx, jsAtom);
          final jsProp = jsGetProperty(ctx, val, jsAtom);
          ret[_jsToDart(ctx, jsAtomValue, cache: cache)] = _jsToDart(
            ctx,
            jsProp,
            cache: cache,
          );
          jsFreeValue(ctx, jsAtomValue);
          jsFreeValue(ctx, jsProp);
          jsFreeAtom(ctx, jsAtom);
        }
        jsFree(ctx, ptab.value);
        malloc.free(ptab);
        return ret;
      }
    default:
  }
  return null;
}
