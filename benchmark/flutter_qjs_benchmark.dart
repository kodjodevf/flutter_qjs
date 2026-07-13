import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_qjs_es2023/flutter_qjs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterQjsLogger.handler = (level, message, error) {
    stdout.writeln(error == null ? message : '$message: $error');
  };
  final runtime = QuickJsRuntime2();
  try {
    _runBenchmarks(runtime);
  } finally {
    runtime.dispose();
  }
  exit(0);
}

void _runBenchmarks(QuickJsRuntime2 runtime) {
  const length = 10000;
  const iterations = 20;
  final bytes = Uint8List.fromList(List<int>.generate(length, (i) => i & 0xff));
  final floats = Float64List.fromList(
    List<double>.generate(length, (i) => i.toDouble()),
  );

  _bench('evaluate large array', iterations, () {
    runtime.evaluate('Array.from({length: $length}, (_, i) => i)');
  });
  _bench('evaluateJson large array', iterations, () {
    runtime.evaluateJson('Array.from({length: $length}, (_, i) => i)');
  });
  _bench('Dart Uint8List to JS Uint8Array', iterations, () {
    final fn = runtime.evaluate('(v) => v.length').rawResult as JSInvokable;
    try {
      fn.invoke([bytes]);
    } finally {
      fn.free();
    }
  });
  _bench('Dart Float64List to JS Float64Array', iterations, () {
    final fn = runtime.evaluate('(v) => v.length').rawResult as JSInvokable;
    try {
      fn.invoke([floats]);
    } finally {
      fn.free();
    }
  });
  _bench('JS Uint8Array to Dart', iterations, () {
    runtime.evaluate('new Uint8Array($length)');
  });
  _bench('JS Float64Array to Dart', iterations, () {
    runtime.evaluate('new Float64Array($length)');
  });
}

void _bench(String name, int iterations, void Function() body) {
  body();
  final watch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  watch.stop();
  final avgUs = watch.elapsedMicroseconds / iterations;
  FlutterQjsLogger.info('$name: ${avgUs.toStringAsFixed(1)} us/op');
}
