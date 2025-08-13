import 'dart:convert';

import 'package:torch_dart/abstract_tor.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'torch_dart_bindings_generated.dart';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('LibTorch.framework/LibTorch');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libtorch.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('libtorch.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final TorchDartBindings torBindings = TorchDartBindings(_dylib);

class TorLibrary implements Tor {
  @override
  Never start(List<String> argv) {
    final argsNative = argv.map((e) => e.toNativeUtf8()).toList();

    // Allocate the argv pointer array
    final argvPtr = calloc<Pointer<Char>>(argsNative.length);

    for (var i = 0; i < argsNative.length; i++) {
      argvPtr[i] = argsNative[i].cast<Char>();
    }

    final result = torBindings.TOR_start(argsNative.length, argvPtr);
    throw Exception('failed to start tor: $result');
  }

  @override
  String? get version {
    try {
      return torBindings.TOR_version().cast<Utf8>().toDartString();
    } catch (e) {
      return "no embedded tor";
    }
  }

  static Future<List<TorLibrary>> getTorList() async {
    try {
      final lib = TorLibrary();
      if (lib.version == "no embedded tor") {
        return [];
      }
      return [lib];
    } catch (e) {
      return [];
    }
  }

  @override
  String toString() {
    return "TorLibrary(${version ?? 'no version'})";
  }

  @override
  String toJson() {
    return json.encode({"type": "library", "version": version});
  }
}
