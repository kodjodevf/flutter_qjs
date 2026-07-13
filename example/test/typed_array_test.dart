import 'dart:typed_data';

import 'package:flutter_qjs_es2023/flutter_qjs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late JavascriptRuntime runtime;

  setUp(() {
    runtime = getJavascriptRuntime();
  });

  tearDown(() {
    runtime.dispose();
  });

  group('JS → Dart TypedArray / ArrayBuffer', () {
    test('Uint8Array round-trips as Uint8List', () {
      final r = runtime.evaluate('new Uint8Array([1, 2, 255, 0])');
      expect(r.isError, isFalse);
      final v = r.rawResult;
      expect(v, isA<Uint8List>());
      expect(v as Uint8List, equals([1, 2, 255, 0]));
    });

    test('Uint8ClampedArray → Uint8ClampedList', () {
      final r = runtime.evaluate('new Uint8ClampedArray([1, 2, 300])');
      expect(r.isError, isFalse);
      final v = r.rawResult;
      expect(v, isA<Uint8ClampedList>());
      expect((v as Uint8ClampedList).toList(), equals([1, 2, 255]));
    });

    test('Int8Array / Int16Array / Float32Array types', () {
      final i8 = runtime.evaluate('new Int8Array([-1, 0, 127])').rawResult;
      expect(i8, isA<Int8List>());
      expect((i8 as Int8List).toList(), equals([-1, 0, 127]));

      final i16 = runtime.evaluate('new Int16Array([1000, -2])').rawResult;
      expect(i16, isA<Int16List>());
      expect((i16 as Int16List).toList(), equals([1000, -2]));

      final f32 = runtime.evaluate('new Float32Array([1.5, 2.25])').rawResult;
      expect(f32, isA<Float32List>());
      expect((f32 as Float32List)[0], closeTo(1.5, 1e-5));
      expect((f32 as Float32List)[1], closeTo(2.25, 1e-5));
    });

    test('ArrayBuffer → Uint8List', () {
      final r = runtime.evaluate(r'''
        (function() {
          const b = new ArrayBuffer(4);
          const u = new Uint8Array(b);
          u[0] = 10; u[1] = 20; u[2] = 30; u[3] = 40;
          return b;
        })()
      ''');
      expect(r.isError, isFalse);
      expect(r.rawResult, isA<Uint8List>());
      expect(r.rawResult as Uint8List, equals([10, 20, 30, 40]));
    });

    test('empty Uint8Array', () {
      final r = runtime.evaluate('new Uint8Array(0)');
      expect(r.isError, isFalse);
      expect(r.rawResult, isA<Uint8List>());
      expect((r.rawResult as Uint8List).length, 0);
    });
  });

  group('Dart → JS TypedArray (via host function)', () {
    test('Uint8List becomes Uint8Array in JS', () {
      final setGlobal = runtime.evaluate('(k,v)=>{globalThis[k]=v;}').rawResult
          as JSInvokable;
      setGlobal.invoke(['dartBytes', Uint8List.fromList([9, 8, 7, 6])]);
      setGlobal.free();

      final r = runtime.evaluate(r'''
        (function() {
          const v = globalThis.dartBytes;
          return {
            isUint8Array: v instanceof Uint8Array,
            isArrayBuffer: v instanceof ArrayBuffer,
            ctor: Object.prototype.toString.call(v),
            len: v.byteLength !== undefined ? v.byteLength : v.length,
            data: Array.from(v instanceof ArrayBuffer ? new Uint8Array(v) : v)
          };
        })()
      ''');
      expect(r.isError, isFalse);
      final m = Map<String, dynamic>.from(r.rawResult as Map);
      // Optimized path should produce Uint8Array, not bare ArrayBuffer.
      expect(m['isUint8Array'], isTrue,
          reason: 'Uint8List should map to Uint8Array, got ${m['ctor']}');
      expect(m['data'], equals([9, 8, 7, 6]));
    });

    test('Uint8ClampedList / Int16List / Float64List types', () {
      final setGlobal = runtime.evaluate('(k,v)=>{globalThis[k]=v;}').rawResult
          as JSInvokable;
      setGlobal.invoke(['c', Uint8ClampedList.fromList([1, 2, 255])]);
      setGlobal.invoke(['i16', Int16List.fromList([100, -1])]);
      setGlobal.invoke(['f64', Float64List.fromList([1.25, 3.5])]);
      setGlobal.free();

      final r = runtime.evaluate(r'''
        ({
          c: globalThis.c instanceof Uint8ClampedArray,
          i16: globalThis.i16 instanceof Int16Array,
          f64: globalThis.f64 instanceof Float64Array,
          cData: Array.from(globalThis.c),
          i16Data: Array.from(globalThis.i16),
          f64Data: Array.from(globalThis.f64),
        })
      ''');
      expect(r.isError, isFalse);
      final m = Map<String, dynamic>.from(r.rawResult as Map);
      expect(m['c'], isTrue);
      expect(m['i16'], isTrue);
      expect(m['f64'], isTrue);
      expect(m['cData'], equals([1, 2, 255]));
      expect(m['i16Data'], equals([100, -1]));
      expect(m['f64Data'], equals([1.25, 3.5]));
    });

    test('round-trip Uint8List via JS identity function', () {
      final id = runtime.evaluate('(x) => x').rawResult as JSInvokable;
      final input = Uint8List.fromList([0, 1, 127, 128, 255]);
      final out = id.invoke([input]);
      id.free();
      expect(out, isA<Uint8List>());
      expect(out as Uint8List, equals(input));
    });

    test('round-trip large Uint8List (64KiB)', () {
      final id = runtime.evaluate('(x) => x').rawResult as JSInvokable;
      final input = Uint8List(64 * 1024);
      for (var i = 0; i < input.length; i++) {
        input[i] = i & 0xff;
      }
      final out = id.invoke([input]) as Uint8List;
      id.free();
      expect(out.length, input.length);
      expect(out[0], 0);
      expect(out[255], 255);
      expect(out[256], 0);
      expect(out[input.length - 1], (input.length - 1) & 0xff);
    });

    test('nested List containing Uint8List', () {
      final id = runtime.evaluate('(x) => x').rawResult as JSInvokable;
      // Single JS argument: [Uint8List, 'ok']
      final out = id.invoke([
        [Uint8List.fromList([1, 2]), 'ok'],
      ]);
      id.free();
      expect(out, isA<List>());
      final list = out as List;
      expect(list[0], isA<Uint8List>());
      expect(list[0] as Uint8List, equals([1, 2]));
      expect(list[1], 'ok');
    });
  });

  group('JS constructors still work after bridge traffic', () {
    test('create Uint8Array in JS after dart push', () {
      final setGlobal = runtime.evaluate('(k,v)=>{globalThis[k]=v;}').rawResult
          as JSInvokable;
      setGlobal.invoke(['a', Uint8List.fromList([1])]);
      setGlobal.free();
      final r = runtime.evaluate('new Uint8Array([2,3]).length');
      expect(r.rawResult, 2);
    });
  });
}
