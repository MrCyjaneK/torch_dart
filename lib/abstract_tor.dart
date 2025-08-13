import 'package:torch_dart/tor_binary.dart';
import 'package:torch_dart/tor_library.dart';

abstract class Tor {
  String? get version;
  Never start(final List<String> argv);

  static Future<List<Tor>> getTorList() async {
    return [
      ...await TorLibrary.getTorList(),
      ...await TorBinary.getTorList(),
    ];
  }

  String toJson();
}
