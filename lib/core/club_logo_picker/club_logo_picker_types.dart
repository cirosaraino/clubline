import 'dart:typed_data';

class PickedClubLogo {
  const PickedClubLogo({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.dataUrl,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String dataUrl;

  bool get isSvg {
    final normalizedMimeType = mimeType.trim().toLowerCase();
    final normalizedFileName = fileName.trim().toLowerCase();
    if (normalizedMimeType.contains('svg') ||
        normalizedFileName.endsWith('.svg')) {
      return true;
    }

    if (bytes.isEmpty) {
      return false;
    }

    final headerLength = bytes.length < 120 ? bytes.length : 120;
    final header = String.fromCharCodes(
      bytes.take(headerLength),
    ).trimLeft().toLowerCase();
    return header.startsWith('<?xml') || header.startsWith('<svg');
  }
}
