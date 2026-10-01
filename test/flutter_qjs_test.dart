import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

void main() {
  test('evaluate basic JS expression', () {
    final runtime = getJavascriptRuntime();
    final result = runtime.evaluate('1 + 2');
    expect(result.rawResult, equals(3));
    runtime.dispose();
  });

  test('evaluate string concatenation', () {
    final runtime = getJavascriptRuntime();
    final result = runtime.evaluate('"hello" + " " + "world"');
    expect(result.rawResult, equals('hello world'));
    runtime.dispose();
  });
}
