import 'dart:async';
import 'package:flutter_qjs_es2023/flutter_qjs_logger.dart';
import 'package:flutter_qjs_es2023/javascript_runtime.dart';
import 'package:flutter_qjs_es2023/js_eval_result.dart';
/// Promise handling without Timer.periodic polling of JS query helpers.
///
/// QuickJS converts JS Promises to Dart [Future] in `_jsToDart`. Awaiting that
/// Future and pumping [JavascriptRuntime.executePendingJob] is enough.
extension HandlePromises on JavascriptRuntime {
  /// Optional no-op friendly setup for callers that still invoke this.
  void enableHandlePromises() {
    // Intentionally minimal: no querable-promise registry / 20ms poll.
    localContext['handlePromisesEnabled'] = true;
  }

  Future<JsEvalResult> handlePromise(
    JsEvalResult value, {
    Duration? timeout,
  }) async {
    final future = _doHandlePromise(value);
    if (timeout != null) {
      return future.timeout(timeout);
    }
    return future;
  }

  Future<JsEvalResult> _doHandlePromise(JsEvalResult value) async {
    final raw = value.rawResult;

    // Primary path: Promise already marshaled to Dart Future.
    if (raw is Future) {
      var completed = false;
      void pumpJobs() {
        if (completed) return;
        executePendingJob();
        Future.delayed(const Duration(milliseconds: 4), pumpJobs);
      }

      pumpJobs();
      try {
        final res = await raw;
        completed = true;
        if (res is JsEvalResult) return res;
        return JsEvalResult(res?.toString() ?? 'null', res);
      } catch (e, st) {
        completed = true;
        return Future.error(e, st);
      }
    }

    // Already resolved / not a promise.
    if (value.isPromise || value.stringResult == '[object Promise]') {
      // Fallback: raw was not converted (should be rare). Pump once and return.
      executePendingJob();
      if (JavascriptRuntime.debugEnabled) {
        FlutterQjsLogger.debug(
          'handlePromise: rawResult is not a Future for Promise-like result',
        );
      }
    }

    return value;
  }
}
