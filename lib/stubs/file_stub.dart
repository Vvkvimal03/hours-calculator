// Stub file for web - provides File class that matches dart:io File interface
// This file is used when compiling for web to avoid import errors

class File {
  final String path;
  
  File(this.path);
  
  Future<File> writeAsString(String contents, {FileMode mode = FileMode.write, bool flush = false}) async {
    throw UnsupportedError('File operations not supported on web');
  }
}

enum FileMode {
  read,
  write,
  append,
  writeOnly,
  writeOnlyAppend,
}

