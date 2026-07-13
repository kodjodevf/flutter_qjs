/*
 * @Description: isolate
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of 'quickjs_runtime2.dart';

typedef dynamic _Decode(Map obj);
List<_Decode> _decoders = [JSError._decode, IsolateFunction._decode];

abstract class _IsolateEncodable {
  Map _encode();
}

dynamic _encodeData(dynamic data, {Map<dynamic, dynamic>? cache}) {
  if (cache == null) cache = Map();
  if (cache.containsKey(data)) return cache[data];
  if (data is Error || data is Exception)
    return _encodeData(JSError(data), cache: cache);
  if (data is _IsolateEncodable) return data._encode();
  if (data is List) {
    final ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(_encodeData(data[i], cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    final ret = {};
    cache[data] = ret;
    for (final entry in data.entries) {
      ret[_encodeData(entry.key, cache: cache)] = _encodeData(
        entry.value,
        cache: cache,
      );
    }
    return ret;
  }
  if (data is Future) {
    final futurePort = ReceivePort();
    data.then(
      (value) {
        futurePort.first.then((port) {
          futurePort.close();
          (port as SendPort).send(_encodeData(value));
        });
      },
      onError: (e) {
        futurePort.first.then((port) {
          futurePort.close();
          (port as SendPort).send({#error: _encodeData(e)});
        });
      },
    );
    return {#jsFuturePort: futurePort.sendPort};
  }
  return data;
}

dynamic _decodeData(dynamic data, {Map<dynamic, dynamic>? cache}) {
  if (cache == null) cache = Map();
  if (cache.containsKey(data)) return cache[data];
  if (data is List) {
    final ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(_decodeData(data[i], cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    for (final decoder in _decoders) {
      final decodeObj = decoder(data);
      if (decodeObj != null) return decodeObj;
    }
    if (data.containsKey(#jsFuturePort)) {
      SendPort port = data[#jsFuturePort];
      final futurePort = ReceivePort();
      port.send(futurePort.sendPort);
      final futureCompleter = Completer();
      futureCompleter.future.catchError((e) {});
      futurePort.first.then((value) {
        futurePort.close();
        if (value is Map && value.containsKey(#error)) {
          futureCompleter.completeError(_decodeData(value[#error]));
        } else {
          futureCompleter.complete(_decodeData(value));
        }
      });
      return futureCompleter.future;
    }
    final ret = {};
    cache[data] = ret;
    for (final entry in data.entries) {
      ret[_decodeData(entry.key, cache: cache)] = _decodeData(
        entry.value,
        cache: cache,
      );
    }
    return ret;
  }
  return data;
}

void _runJsIsolate(Map spawnMessage) async {
  SendPort sendPort = spawnMessage[#port];
  ReceivePort port = ReceivePort();
  sendPort.send(port.sendPort);
  final qjs = QuickJsRuntime2(
    stackSize: spawnMessage[#stackSize] ?? 1024 * 1024,
    timeout: spawnMessage[#timeout],
    memoryLimit: spawnMessage[#memoryLimit],
    hostPromiseRejectionHandler: (reason) {
      sendPort.send({
        #type: #hostPromiseRejection,
        #reason: _encodeData(reason),
      });
    },
    moduleHandler: (name) {
      final ptr = calloc<Pointer<Utf8>>();
      ptr.value = Pointer.fromAddress(ptr.address);
      sendPort.send({#type: #module, #name: name, #ptr: ptr.address});
      while (ptr.value.address == ptr.address) sleep(Duration(microseconds: 1));
      final ret = ptr.value;
      malloc.free(ptr);
      if (ret.address == -1) throw JSError('Module Not found');
      final retString = ret.toDartString();
      malloc.free(ret);
      return retString;
    },
  );
  port.listen((msg) async {
    var data;
    SendPort? msgPort = msg[#port];
    try {
      switch (msg[#type]) {
        case #evaluate:
          // Host function channel: bind provided Dart closures onto globalThis
          // before evaluating. Each is an IsolateFunction routed back to the
          // spawning isolate; returning a Future yields a JS Promise (via
          // _dartToJs). Inject-once semantics: only the message that carries
          // #functions binds them; persists across later evaluates on the same
          // engine.
          final encodedFns = msg[#functions];
          if (encodedFns != null) {
            final fns = _decodeData(encodedFns) as Map;
            final setter = qjs.evaluate('(k,v)=>{globalThis[k]=v;}').rawResult;
            try {
              fns.forEach((k, v) => (setter as JSInvokable).invoke([k, v]));
            } finally {
              if (setter is JSRef) setter.free();
            }
          }
          // QuickJsRuntime2.evaluate wraps the result in a JsEvalResult and
          // reports errors via isError instead of throwing. Unwrap here so the
          // error travels back through the #error channel and Promises resolve
          // to their settled value.
          final r = qjs.evaluate(
            msg[#command],
            name: msg[#name],
            evalFlags: msg[#flag],
          );
          if (r.isError) throw r.rawResult;
          data = await r.rawResult;
          break;
        case #close:
          data = false;
          qjs.port.close();
          qjs.close();
          port.close();
          data = true;
          break;
      }
      if (msgPort != null) msgPort.send(_encodeData(data));
    } catch (e) {
      if (msgPort != null) msgPort.send({#error: _encodeData(e)});
    }
  });
  await qjs.dispatch();
}

typedef _JsAsyncModuleHandler = Future<String> Function(String name);

class IsolateQjs {
  Future<SendPort>? _sendPort;

  /// Max stack size for quickjs.
  final int? stackSize;

  /// Max stack size for quickjs.
  final int? timeout;

  /// Max memory for quickjs.
  final int? memoryLimit;

  /// Asynchronously handler to manage js module.
  final _JsAsyncModuleHandler? moduleHandler;

  /// Handler function to manage js module.
  final _JsHostPromiseRejectionHandler? hostPromiseRejectionHandler;

  /// Host functions to expose on `globalThis`, wrapped as cross-isolate
  /// [IsolateFunction]s. Bound onto the worker's globalThis on the first
  /// [evaluate] (inject-once); invoking from JS routes back to this isolate,
  /// and a returned Future becomes a JS Promise.
  final Map<String, IsolateFunction> _hostFunctions = {};
  bool _hostFunctionsBound = false;

  /// Quickjs engine runing on isolate thread.
  ///
  /// Pass handlers to implement js-dart interaction and resolving modules. The `methodHandler` is
  /// used in isolate, so **the handler function must be a top-level function or a static method**.
  IsolateQjs({
    this.moduleHandler,
    this.stackSize,
    this.timeout,
    this.memoryLimit,
    this.hostPromiseRejectionHandler,
  });

  /// Register host functions callable from JS as `globalThis[name](...)`.
  ///
  /// Each value is a Dart closure (may return a Future → JS Promise). The
  /// closure runs on **this** (spawning) isolate, not the worker — args are
  /// marshalled in, the return value (or resolved Future) marshalled back; the
  /// worker/JS never sees Dart closure internals. **Inject-once**: must be
  /// called before the first [evaluate]; runtime mutation is rejected.
  void setHostFunctions(Map<String, Function> functions) {
    if (_hostFunctionsBound) {
      throw StateError(
        'host functions must be registered before evaluate (inject-once)',
      );
    }
    functions.forEach((k, v) {
      // Dispose any prior registration for this key so repeated/accumulating
      // pre-evaluate calls don't leak IsolateFunction handlers.
      _hostFunctions[k]?.destroy();
      _hostFunctions[k] = IsolateFunction(v);
    });
  }

  _ensureEngine() {
    if (_sendPort != null) return;
    ReceivePort port = ReceivePort();
    Isolate.spawn(_runJsIsolate, {
      #port: port.sendPort,
      #stackSize: stackSize,
      #timeout: timeout,
      #memoryLimit: memoryLimit,
    }, errorsAreFatal: true);
    final completer = Completer<SendPort>();
    port.listen(
      (msg) async {
        if (msg is SendPort && !completer.isCompleted) {
          completer.complete(msg);
          return;
        }
        switch (msg[#type]) {
          case #hostPromiseRejection:
            try {
              final err = _decodeData(msg[#reason]);
              if (hostPromiseRejectionHandler != null) {
                hostPromiseRejectionHandler!(err);
              } else {
                FlutterQjsLogger.warning('Unhandled promise rejection', err);
              }
            } catch (e) {
              FlutterQjsLogger.error('Host promise rejection handler error', e);
            }
            break;
          case #module:
            final ptr = Pointer<Pointer>.fromAddress(msg[#ptr]);
            try {
              ptr.value = (await moduleHandler!(msg[#name])).toNativeUtf8();
            } catch (e) {
              ptr.value = Pointer.fromAddress(-1);
            }
            break;
        }
      },
      onDone: () {
        close();
        if (!completer.isCompleted)
          completer.completeError(JSError('isolate close'));
      },
    );
    _sendPort = completer.future;
  }

  /// Free Runtime and close isolate thread that can be recreate when evaluate again.
  close() {
    // Host-function handlers are reclaimed by the existing IsolateFunction
    // refcount path: when the worker frees its runtime on #close, the bound
    // globalThis functions are GC'd, and their cross-isolate #free messages
    // remove the handlers registered here. Manually destroying them up-front
    // races those late messages ("handler released"), so we don't.
    _hostFunctions.clear();
    _hostFunctionsBound = false;
    final sendPort = _sendPort;
    _sendPort = null;
    if (sendPort == null) return;
    final ret = sendPort.then((sendPort) async {
      final closePort = ReceivePort();
      sendPort.send({#type: #close, #port: closePort.sendPort});
      final result = await closePort.first;
      closePort.close();
      if (result is Map && result.containsKey(#error))
        throw _decodeData(result[#error]);
      return _decodeData(result);
    });
    return ret;
  }

  /// Evaluate js script.
  Future<dynamic> evaluate(
    String command, {
    String? name,
    int? evalFlags,
  }) async {
    _ensureEngine();
    final evaluatePort = ReceivePort();
    final sendPort = await _sendPort!;
    final msg = {
      #type: #evaluate,
      #command: command,
      #name: name,
      #flag: evalFlags,
      #port: evaluatePort.sendPort,
    };
    // Inject host functions once, on the first evaluate that follows
    // setHostFunctions. Encoded as IsolateFunction refs (id + handle port).
    if (_hostFunctions.isNotEmpty && !_hostFunctionsBound) {
      msg[#functions] = _encodeData(_hostFunctions);
      _hostFunctionsBound = true;
    }
    sendPort.send(msg);
    final result = await evaluatePort.first;
    evaluatePort.close();
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error]);
    return _decodeData(result);
  }
}
