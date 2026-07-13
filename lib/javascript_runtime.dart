import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'flutter_qjs_logger.dart';
import 'js_eval_result.dart';

class FlutterJsPlatformEmpty extends JavascriptRuntime {
  @override
  JsEvalResult callFunction(Pointer<NativeType> fn, Pointer<NativeType> obj) {
    throw UnimplementedError();
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}

  @override
  JsEvalResult evaluate(String code, {String? sourceUrl}) {
    throw UnimplementedError();
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) {
    throw UnimplementedError();
  }

  @override
  int executePendingJob() {
    throw UnimplementedError();
  }

  @override
  String getEngineInstanceId() {
    throw UnimplementedError();
  }

  @override
  void initChannelFunctions() {
    throw UnimplementedError();
  }

  @override
  String jsonStringify(JsEvalResult jsValue) {
    throw UnimplementedError();
  }

  @override
  dynamic evaluateJson(String code, {String? sourceUrl}) {
    throw UnimplementedError();
  }

  @override
  bool setupBridge(String channelName, void Function(dynamic args) fn) {
    throw UnimplementedError();
  }

  @override
  void setInspectable(bool inspectable) {
    throw UnimplementedError();
  }
}

abstract class JavascriptRuntime {
  static bool debugEnabled = false;

  @protected
  JavascriptRuntime init() {
    initChannelFunctions();
    _setupConsoleLog();
    _setupSetTimeout();
    return this;
  }

  Map<String, dynamic> localContext = {};

  Map<String, dynamic> dartContext = {};

  void dispose();

  static final Map<String, Map<String, Function(dynamic arg)>>
  _channelFunctionsRegistered = {};

  static Map<String, Map<String, Function(dynamic arg)>>
  get channelFunctionsRegistered => _channelFunctionsRegistered;

  JsEvalResult evaluate(String code, {String? sourceUrl});

  Uint8List compile(String code, String fileName) {
    throw UnimplementedError();
  }

  JsEvalResult evaluateBytecode(Uint8List bytecode) {
    throw UnimplementedError();
  }

  Future<JsEvalResult> evaluateAsyncBytecode(Uint8List bytecode) {
    throw UnimplementedError();
  }

  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl});

  dynamic evaluateJson(String code, {String? sourceUrl});

  JsEvalResult callFunction(Pointer fn, Pointer obj);

  T? convertValue<T>(JsEvalResult jsValue);

  String jsonStringify(JsEvalResult jsValue);

  @protected
  void initChannelFunctions();

  int executePendingJob();

  void _setupConsoleLog() {
    evaluate("""
    var console = {
      log: function() {
        sendMessage('ConsoleLog', JSON.stringify(['log'].concat(Array.prototype.slice.call(arguments))));
      },
      warn: function() {
        sendMessage('ConsoleLog', JSON.stringify(['warn'].concat(Array.prototype.slice.call(arguments))));
      },
      error: function() {
        sendMessage('ConsoleLog', JSON.stringify(['error'].concat(Array.prototype.slice.call(arguments))));
      },
      info: function() {
        sendMessage('ConsoleLog', JSON.stringify(['info'].concat(Array.prototype.slice.call(arguments))));
      }
    }""");
    onMessage('ConsoleLog', (dynamic args) {
      if (args is! List || args.isEmpty) return;
      final level = args[0];
      final output =
          args.length < 2 ? '' : args.sublist(1).join(' ');
      switch (level) {
        case 'error':
          FlutterQjsLogger.error(output);
          break;
        case 'warn':
          FlutterQjsLogger.warning(output);
          break;
        default:
          FlutterQjsLogger.info(output);
      }
    });
  }

  void _setupSetTimeout() {
    evaluate(r"""
      var __NATIVE_FLUTTER_JS__setTimeoutCount = -1;
      var __NATIVE_FLUTTER_JS__setTimeoutCallbacks = {};
      function setTimeout(fnTimeout, timeout) {
        try {
          __NATIVE_FLUTTER_JS__setTimeoutCount += 1;
          var timeoutIndex = __NATIVE_FLUTTER_JS__setTimeoutCount;
          __NATIVE_FLUTTER_JS__setTimeoutCallbacks[timeoutIndex] = fnTimeout;
          sendMessage('SetTimeout', JSON.stringify({
            timeoutIndex: timeoutIndex,
            timeout: timeout || 0
          }));
          return timeoutIndex;
        } catch (e) {
          console.error('setTimeout error', e && e.message);
        }
      }
      function clearTimeout(timeoutIndex) {
        delete __NATIVE_FLUTTER_JS__setTimeoutCallbacks[timeoutIndex];
      }
      1
    """);
    onMessage('SetTimeout', (dynamic args) {
      try {
        if (args is! Map) return;
        final durationRaw = args['timeout'] ?? 0;
        final idxRaw = args['timeoutIndex'];
        final duration =
            durationRaw is num ? durationRaw.toInt() : int.tryParse('$durationRaw') ?? 0;
        final idx = idxRaw is num
            ? idxRaw.toInt()
            : int.tryParse('$idxRaw');
        if (idx == null) return;

        Timer(Duration(milliseconds: duration < 0 ? 0 : duration), () {
          final runner = evaluate(r'''
            (function(i) {
              var cb = __NATIVE_FLUTTER_JS__setTimeoutCallbacks[i];
              if (cb) {
                delete __NATIVE_FLUTTER_JS__setTimeoutCallbacks[i];
                cb();
              }
            })
          ''').rawResult;
          // JSInvokable from QuickJS binding (avoid importing runtime here).
          try {
            (runner as dynamic).invoke([idx]);
          } catch (_) {
            // Fallback: never inject index via string concatenation.
          } finally {
            try {
              (runner as dynamic).free();
            } catch (_) {}
          }
        });
      } on Exception catch (e) {
        FlutterQjsLogger.error('Exception in setTimeout callback', e);
      } on Error catch (e) {
        FlutterQjsLogger.error('Error in setTimeout callback', e);
      }
    });
  }

  /// Dart → JS message helper. Prefer not to inject untrusted strings into
  /// [evaluate]; use registered bridges + `sendMessage` from JS instead.
  @Deprecated('Prefer JS-side sendMessage bridges; string eval is unsafe')
  sendMessage({
    required String channelName,
    required List<String> args,
    String? uuid,
  }) {
    final safeChannel = jsonEncode(channelName);
    final safeArgs = jsonEncode(args);
    if (uuid != null) {
      final safeUuid = jsonEncode(uuid);
      evaluate(
        "DART_TO_QUICKJS_CHANNEL_sendMessage($safeChannel, $safeArgs, $safeUuid);",
      );
    } else {
      evaluate(
        "DART_TO_QUICKJS_CHANNEL_sendMessage($safeChannel, $safeArgs);",
      );
    }
  }

  onMessage(String channelName, dynamic Function(dynamic args) fn) {
    setupBridge(channelName, fn);
  }

  bool setupBridge(String channelName, void Function(dynamic args) fn);

  String getEngineInstanceId();

  void setInspectable(bool inspectable);

  /// Removes channel registrations for this engine (call from [dispose]).
  void disposeChannelFunctions() {
    _channelFunctionsRegistered.remove(getEngineInstanceId());
  }
}
