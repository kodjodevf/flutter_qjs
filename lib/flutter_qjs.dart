import 'package:flutter_qjs_es2023/javascript_runtime.dart';
import './quickjs/quickjs_runtime2.dart';
import './extensions/handle_promises.dart';

export './extensions/handle_promises.dart';
export './quickjs/quickjs_runtime2.dart';
export 'flutter_qjs_logger.dart';
export 'javascript_runtime.dart';
export 'js_eval_result.dart';

/// Creates a [JavascriptRuntime] backed by QuickJS.
///
/// Limits (also accepted via [extraArgs] keys `stackSize`, `timeout`,
/// `memoryLimit` for backward compatibility):
/// - [stackSize]: JS stack bytes (default 1 MiB)
/// - [timeout]: interrupt after this many ms of JS work (0 / null = off)
/// - [memoryLimit]: heap limit bytes (null = unlimited)
JavascriptRuntime getJavascriptRuntime({
  bool forceJavascriptCoreOnAndroid = false,
  bool xhr = true,
  Map<String, dynamic>? extraArgs = const {},
  int stackSize = 1024 * 1024,
  int? timeout,
  int? memoryLimit,
}) {
  final resolvedStack = (extraArgs?['stackSize'] as int?) ?? stackSize;
  final resolvedTimeout = (extraArgs?['timeout'] as int?) ?? timeout;
  final resolvedMemory = (extraArgs?['memoryLimit'] as int?) ?? memoryLimit;

  final runtime = QuickJsRuntime2(
    stackSize: resolvedStack,
    timeout: resolvedTimeout,
    memoryLimit: resolvedMemory,
  );
  runtime.enableHandlePromises();
  return runtime;
}
