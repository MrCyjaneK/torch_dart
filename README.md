# torch_dart

> Universal embedded Tor runner for all platforms

## Usage

```dart
final torList = await Tor.getTorList();
if (torList.isEmpty) throw Exception("No tor found");
torList[0].version; // tor X.X.X.X
torList[0].start([]); // this returns quickly, calling this more than once will crash your app if using torch .so
// array inside ^^^^ is argv as if you would call ./tor $@
```

This package does not follow standard flutter build guidelines, and requires to be built separately (or no, it can also use system libraries).

In order to build the library for all supported targets do the following:

```bash
$ ./build.sh aarch64-linux-android x86_64-linux-android armv7a-linux-androideabi aarch64-apple-darwin x86_64-apple-darwin aarch64-apple-ios aarch64-apple-ios-simulator
```