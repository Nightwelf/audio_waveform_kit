import 'dart:io';
import 'dart:typed_data';

Future<void> saveBytes(String path, Uint8List bytes) =>
    File(path).writeAsBytes(bytes);
