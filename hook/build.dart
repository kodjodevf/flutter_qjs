import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final targetOS = input.config.code.targetOS;
    final isWindows = targetOS == OS.windows;
    final isAndroid = targetOS == OS.android;
    final isLinux = targetOS == OS.linux;

    const quickjsDir = 'cxx/quickjs';
    final sources = [
      'cxx/ffi.c',
      '$quickjsDir/cutils.c',
      '$quickjsDir/libregexp.c',
      '$quickjsDir/libunicode.c',
      '$quickjsDir/quickjs.c',
      '$quickjsDir/dtoa.c',
    ];

    final builder = CBuilder.library(
      name: 'qjs',
      assetName: 'package:flutter_qjs/flutter_qjs.dart',
      sources: sources,
      includes: ['cxx'],
      libraries: [if (isAndroid || isLinux) 'm'],
      flags: [
        if (isWindows) ...['/Oi-', '/utf-8', '/wd4018', '/wd4244'],
        if (isAndroid) ...[
          '-Wl,-z,max-page-size=16384',
          '-Wl,--hash-style=both',
        ],
      ],
      defines: {
        'CONFIG_VERSION': '"2026-06-04"',
        'DUMP_LEAKS': '1',
        if (isWindows) ...{
          '_CRT_SECURE_NO_WARNINGS': '1',
          '_WINSOCK_DEPRECATED_NO_WARNINGS': '1',
        },
      },
    );

    await builder.run(input: input, output: output);
  });
}
