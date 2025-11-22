import 'dart:io';

class PlataformaInfo {
  static String get sistema =>
      Platform.operatingSystem; // android, ios, windows, linux, macos
  static String get versao => Platform.operatingSystemVersion;
}
