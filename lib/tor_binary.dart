import 'dart:convert';
import 'dart:io';
import 'package:torch_dart/abstract_tor.dart';
import 'package:path/path.dart' as p;

class TorBinary implements Tor {
  TorBinary({
    required this.internalTorPath,
  });
  final String internalTorPath;

  @override
  Never start(List<String> argv) {
    Process.runSync(internalTorPath, argv);
    throw Exception('failed to start tor');
  }

  @override
  String? get version {
    final version = Process.runSync(internalTorPath, ['--version']);
    return version.stdout.toString() + version.stderr.toString();
  }

  static Future<List<TorBinary>> getTorList() async {
    final List<TorBinary> binaries = [];
    final List<String> paths =
        Platform.environment['PATH']?.split(Platform.pathSeparator) ?? [];
    if (Platform.isMacOS) {
      paths.add('/Applications/Tor Browser.app/Contents/MacOS/Tor');
    }
    for (final path in paths) {
      try {
        final torPath = p.join(path, 'tor');
        if (File(torPath).existsSync()) {
          binaries.add(TorBinary(internalTorPath: torPath));
        }
      } catch (e) {
        print('Error checking $path: $e');
      }
    }
    return binaries;
  }

  @override
  String toString() {
    return "TorBinary($internalTorPath, ${version ?? 'no version'})";
  }

  @override
  String toJson() {
    return json.encode({"type": "binary", "path": internalTorPath});
  }
}
